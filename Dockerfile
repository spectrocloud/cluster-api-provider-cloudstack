ARG BUILDER_GOLANG_VERSION
ARG ARCH

FROM --platform=$ARCH us-docker.pkg.dev/palette-images/build-base-images/golang:${BUILDER_GOLANG_VERSION}-alpine as toolchain

ARG goproxy=https://proxy.golang.org
ENV GOPROXY=$goproxy

ARG CRYPTO_LIB
ENV GOEXPERIMENT=${CRYPTO_LIB:+boringcrypto}

FROM toolchain as builder
WORKDIR /workspace

RUN apk update
RUN apk add git gcc g++ curl

COPY go.mod go.mod
COPY go.sum go.sum

RUN  --mount=type=cache,target=/root/.local/share/golang \
     --mount=type=cache,target=/go/pkg/mod \
     go mod download

COPY ./ ./

ARG ARCH
ARG LDFLAGS
RUN  --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.local/share/golang \
    if [ ${CRYPTO_LIB} ]; \
    then \
      GOARCH=${ARCH} go-build-fips.sh -a -o manager . ;\
    else \
      GOARCH=${ARCH} go-build-static.sh -a -o manager . ;\
    fi
RUN if [ "${CRYPTO_LIB}" ]; then assert-static.sh manager; fi
RUN if [ "${CRYPTO_LIB}" ]; then assert-fips.sh manager; fi

ENTRYPOINT [ "/start.sh", "/workspace/manager" ]

FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /workspace/manager .
USER 65532:65532
ENTRYPOINT ["/manager"]