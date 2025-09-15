### Single prompt to reproduce all changes

Use this single prompt:

- Modify main.go to allow running the same binary as either controller-only or webhook-only based on a new flag:
  - Add int flag --webhook-port (default 9443). Behavior:
    - If --webhook-port=0: controller-only mode. Do not create a webhook server; register reconcilers only.
    - If --webhook-port!=0 (e.g., 9443): webhook-only mode. Create webhook server with that port; register webhooks only (no reconcilers).
  - Only set ctrl.Options.WebhookServer when port != 0; keep health/ready probes and existing tlsOptions/metrics handling.
  - Keep the existing cert/key flags (webhook-cert-dir/name/key) working.
  - Implemented in main.go with proper conditional logic for webhook server creation and controller setup.

- Add a new spectro/ folder with scripts and kustomizations to generate two sets of manifests from the same code/image:
  - spectro/controller/
    - kustomization.yaml: 
      - namePrefix: capc-
      - labels: cluster.x-k8s.io/provider: "infrastructure-cloudstack"
      - resources: ../../config/manager
      - patches: manager_controller_patch.yaml
      - Do NOT include namespace, RBAC, webhooks, or cert-manager.
    - manager_controller_patch.yaml:
      - Remove serviceAccountName field entirely (uses Kubernetes default behavior)
      - Container args include:
        - --leader-elect
        - --webhook-port=0
        - --diagnostics-address=${CAPI_DIAGNOSTICS_ADDRESS:=:8443}
        - --insecure-diagnostics=${CAPI_INSECURE_DIAGNOSTICS:=false}
        - --cloudstackcluster-concurrency=${CAPC_CLOUDSTACKCLUSTER_CONCURRENCY:=10}
        - --cloudstackmachine-concurrency=${CAPC_CLOUDSTACKMACHINE_CONCURRENCY:=10}
        - --enable-cloudstack-cks-sync=${CAPC_CLOUDSTACKMACHINE_CKS_SYNC:=false}
    - Add YAML patch in kustomization.yaml to remove serviceAccountName field:
      ```yaml
      - target:
          kind: Deployment
          name: controller-manager
        patch: |-
          - op: remove
            path: /spec/template/spec/serviceAccountName
      ```
  - spectro/webhook/
    - kustomization.yaml:
      - namespace: capi-webhook-system
      - namePrefix: capc-
      - labels: cluster.x-k8s.io/provider: "infrastructure-cloudstack"
      - resources: ../../config/crd, ../../config/manager, ../../config/webhook, ../../config/certmanager
      - patches: manager_webhook_patch.yaml, webhook_ca_injection_patch.yaml, certificate_patch.yaml
      - vars:
        - CERTIFICATE_NAMESPACE: from Service/webhook-service metadata.namespace
        - CERTIFICATE_NAME: from Service/webhook-service metadata.name
        - SERVICE_NAMESPACE: from Service/webhook-service metadata.namespace
        - SERVICE_NAME: from Service/webhook-service metadata.name
      - configurations: [kustomizeconfig.yaml, certmanager_kustomizeconfig.yaml] (local files)
      - Add YAML patch to remove serviceAccountName field
    - kustomizeconfig.yaml:
      - nameReference: Service v1 → webhooks/clientConfig/service/name in MutatingWebhookConfiguration and ValidatingWebhookConfiguration
      - namespace mapping: webhooks/clientConfig/service/namespace (create: true) in both webhook configurations
      - varReference: metadata/annotations
    - certmanager_kustomizeconfig.yaml: Copy of ../../config/certmanager/kustomizeconfig.yaml for cert-manager variable substitution
    - manager_webhook_patch.yaml:
      - Label the Deployment/pod template with control-plane: capc-controller-manager (FIXED: was capc-webhook-manager)
      - Remove serviceAccountName field entirely (uses Kubernetes default behavior)
      - Set container args to include --webhook-port=9443
      - Expose container port 9443 named webhook-server
      - Mount TLS certs at /tmp/k8s-webhook-server/serving-certs from a Secret named capc-webhook-service-cert
    - webhook_ca_injection_patch.yaml:
      - Add cert-manager.io/inject-ca-from: capi-webhook-system/capc-serving-cert to MutatingWebhookConfiguration
      - Add cert-manager.io/inject-ca-from: capi-webhook-system/capc-serving-cert to ValidatingWebhookConfiguration
      - CRITICAL: Must reference certificate resource name (capc-serving-cert), not secret name
    - certificate_patch.yaml:
      - Patch Certificate resource to use correct secretName: capc-webhook-service-cert
  - Scripts (make executable):
    - spectro/generate-controller-manifests.sh: kustomize build spectro/controller → spectro/generated/controller-manifests.yaml
    - spectro/generate-webhook-manifests.sh: kustomize build spectro/webhook → spectro/generated/webhook-manifests.yaml
    - spectro/generate-all-manifests.sh: runs both scripts
  - README in spectro/ explaining usage and that:
    - Controller-only manifests: no serviceAccountName field, no RBAC, no webhooks, no CRDs, no cert-manager
    - Webhook-only manifests: include CRDs, webhook configs, and cert-manager resources, no serviceAccountName field, no RBAC, namespace is capi-webhook-system
    - Both use the same image; functionality controlled by --webhook-port
    - Automatic certificate management via cert-manager with CA injection

- Ensure generated outputs meet these checks:
  - Controller manifests:
    - Include args with --webhook-port=0
    - Do NOT contain serviceAccountName field (field completely absent)
    - Do not contain CRDs or webhook configs
    - Labels: control-plane=capc-controller-manager
  - Webhook manifests:
    - Include CRDs and Mutating/ValidatingWebhookConfiguration pointing to Service/capc-webhook-service
    - Are in namespace capi-webhook-system
    - Include cert-manager resources (Issuer and Certificate)
    - cert-manager.io/inject-ca-from annotations resolve to capi-webhook-system/capc-serving-cert (certificate name, not secret name)
    - Labels: control-plane=capc-controller-manager (matches service selector)
    - Do NOT contain serviceAccountName field (field completely absent)
    - Certificate creates secret: capc-webhook-service-cert
    - CA bundle automatically injected into webhook configurations

- Do not add or depend on namespace.yaml; do not include RBAC in controller.
- UPDATED: Webhook deployment now INCLUDES cert-manager resources for automatic certificate management.

### Testing and Validation

- Successfully tested on Kind cluster with cert-manager v1.13.3:
  - Controller deployment: ✅ --webhook-port=0, no serviceAccountName field
  - Webhook deployment: ✅ --webhook-port=9443, no serviceAccountName field, port 9443 exposed
  - Cert-manager resources: ✅ Issuer and Certificate created and READY
  - CA injection: ✅ 1536-byte CA bundles injected into both webhook configurations
  - Service selector: ✅ capc-webhook-service correctly routes to control-plane=capc-controller-manager pods
  - CRDs: ✅ All 8 CloudStack CRDs deployed successfully
  - Webhooks: ✅ 3 mutating and 3 validating webhook rules configured

### Critical Fixes Applied

1. **Service Selector Alignment**: Fixed webhook deployment labels to use `control-plane: capc-controller-manager` (matching service selector) instead of `capc-webhook-manager`
2. **CA Injection Reference**: Fixed `cert-manager.io/inject-ca-from` annotation to reference certificate resource name `capc-serving-cert` instead of secret name
3. **ServiceAccountName Removal**: Completely removed serviceAccountName field from both deployments using YAML patches with `op: remove`
4. **Cert-Manager Integration**: Added full cert-manager resource inclusion with automatic certificate generation and CA injection


