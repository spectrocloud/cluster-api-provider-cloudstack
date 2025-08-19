### Single prompt to reproduce all changes

Use this single prompt:

- Modify main.go to allow running the same binary as either controller-only or webhook-only based on a new flag:
  - Add int flag --webhook-port (default 9443). Behavior:
    - If --webhook-port=0: controller-only mode. Do not create a webhook server; register reconcilers only.
    - If --webhook-port!=0 (e.g., 9443): webhook-only mode. Create webhook server with that port; register webhooks only (no reconcilers).
  - Only set ctrl.Options.WebhookServer when port != 0; keep health/ready probes and existing tlsOptions/metrics handling.
  - Keep the existing cert/key flags (webhook-cert-dir/name/key) working.

- Add a new spectro/ folder with scripts and kustomizations to generate two sets of manifests from the same code/image:
  - spectro/controller/
    - kustomization.yaml: 
      - namePrefix: capc-
      - labels: cluster.x-k8s.io/provider: "infrastructure-cloudstack"
      - resources: ../../config/manager
      - patches: manager_controller_patch.yaml
      - Do NOT include namespace, RBAC, webhooks, or cert-manager.
    - manager_controller_patch.yaml:
      - Set spec.template.spec.serviceAccountName: default
      - Container args include:
        - --leader-elect
        - --webhook-port=0
        - --diagnostics-address=${CAPI_DIAGNOSTICS_ADDRESS:=:8443}
        - --insecure-diagnostics=${CAPI_INSECURE_DIAGNOSTICS:=false}
        - --cloudstackcluster-concurrency=${CAPC_CLOUDSTACKCLUSTER_CONCURRENCY:=10}
        - --cloudstackmachine-concurrency=${CAPC_CLOUDSTACKMACHINE_CONCURRENCY:=10}
        - --enable-cloudstack-cks-sync=${CAPC_CLOUDSTACKMACHINE_CKS_SYNC:=false}
  - spectro/webhook/
    - kustomization.yaml:
      - namespace: capi-webhook-system
      - namePrefix: capc-
      - labels: cluster.x-k8s.io/provider: "infrastructure-cloudstack"
      - resources: ../../config/crd, ../../config/manager, ../../config/webhook
      - patches: manager_webhook_patch.yaml
      - vars:
        - CERTIFICATE_NAMESPACE: from Service/webhook-service metadata.namespace
        - CERTIFICATE_NAME: from Service/webhook-service metadata.name
        - SERVICE_NAMESPACE: from Service/webhook-service metadata.namespace
        - SERVICE_NAME: from Service/webhook-service metadata.name
      - configurations: [kustomizeconfig.yaml] (local file below)
    - kustomizeconfig.yaml:
      - nameReference: Service v1 → webhooks/clientConfig/service/name in MutatingWebhookConfiguration and ValidatingWebhookConfiguration
      - namespace mapping: webhooks/clientConfig/service/namespace (create: true) in both webhook configurations
      - varReference: metadata/annotations
    - manager_webhook_patch.yaml:
      - Label the Deployment/pod template with control-plane: capc-webhook-manager
      - Set container args to include --webhook-port=9443
      - Expose container port 9443 named webhook-server
      - Mount TLS certs at /tmp/k8s-webhook-server/serving-certs from a Secret named capc-webhook-service-cert
      - Do NOT add RBAC or cert-manager
  - Scripts (make executable):
    - spectro/generate-controller-manifests.sh: kustomize build spectro/controller → spectro/generated/controller-manifests.yaml
    - spectro/generate-webhook-manifests.sh: kustomize build spectro/webhook → spectro/generated/webhook-manifests.yaml
    - spectro/generate-all-manifests.sh: runs both scripts
  - README in spectro/ explaining usage and that:
    - Controller-only manifests: no namespace patch, no RBAC, no webhooks, no CRDs, no cert-manager
    - Webhook-only manifests: include CRDs and webhook configs, no RBAC, no cert-manager, namespace is capi-webhook-system
    - Both use the same image; functionality controlled by --webhook-port

- Ensure generated outputs meet these checks:
  - Controller manifests:
    - Include args with --webhook-port=0
    - Use serviceAccountName: default
    - Do not contain CRDs or webhook configs
  - Webhook manifests:
    - Include CRDs and Mutating/ValidatingWebhookConfiguration pointing to Service/webhook-service
    - Are in namespace capi-webhook-system
    - cert-manager.io/inject-ca-from annotations resolve to capi-webhook-system/capc-webhook-service
    - No RBAC or cert-manager resources included

- Do not add or depend on namespace.yaml; do not include RBAC in controller; do not include cert-manager in webhook.


