#!/bin/bash

# Script to generate webhook-only manifests for CAPC
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Generating webhook-only manifests..."

# Create output directory
mkdir -p "${SCRIPT_DIR}/generated"

# Generate webhook manifests
cd "${SCRIPT_DIR}"
kustomize build --load-restrictor LoadRestrictionsNone global > "${SCRIPT_DIR}/generated/core-global.yaml"

echo "Webhook-only manifests (with CRDs) generated: ${SCRIPT_DIR}/generated/core-global.yaml"
echo ""
echo "To deploy the webhook server:"
echo "kubectl apply -f ${SCRIPT_DIR}/generated/core-global.yaml"
echo ""
echo "Note: You may need to create TLS certificates for the webhook service."
echo "The webhook expects certificates at /tmp/k8s-webhook-server/serving-certs/ in the container."
