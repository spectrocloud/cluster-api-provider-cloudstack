### Single prompt to implement CAPI provider webhook/controller separation

I need to implement webhook/controller separation for a CAPI provider following the standardized pattern used by AWS (CAPA), Azure (CAPZ), and CloudStack (CAPC). Please help me:

1. **Modify main.go** to support running the same binary in two modes:
   - Add `--webhook-port` flag (int, provider-specific default)
   - If `--webhook-port=0`: controller-only mode (register reconcilers only, no webhook server)
   - If `--webhook-port!=0`: webhook-only mode (register webhooks only, no reconcilers)
   - Note: Check existing provider defaults - some default to webhook mode, others to controller mode
   - Use this pattern:
     ```go
     if webhookPort == 0 {
         registerControllers(ctx, mgr)
     } else {
         registerWebhooks(mgr)
     }
     ```

2. **Create spectro/ folder structure** with standardized naming:
   ```
   spectro/
   ├── base/                     # Controller-only manifests
   │   ├── kustomization.yaml    # Uses namePrefix: cap[X]-, namespace: cap[X]-system
   │   ├── patch_service_account.yaml  # Sets serviceAccountName: default, --webhook-port=0
   │   └── patch_healthcheck.yaml      # Removes health probes
   ├── global/                   # Webhook-only manifests  
   │   ├── kustomization.yaml    # Uses namespace: capi-webhook-system, includes CRDs
   │   └── patch_service_account.yaml  # Removes serviceAccountName
   ├── generated/                # Output directory
   └── run.sh                    # Generation script
   ```

3. **Base configuration** (controller-only):
   - **kustomization.yaml**: Use kustomize v1beta1 format, include only `../../config/manager`
   - **patch_service_account.yaml**: JSON patch to set or remove serviceAccountName as needed. Provider-specific flags (e.g. --webhook-port=0) may be handled in separate patches if required.
   - **patch_healthcheck.yaml**: JSON patch to remove liveness/readiness probes
   - Target namespace: `cap[provider-prefix]-system` (e.g., `capc-system`)

4. **Global configuration** (webhook-only):
   - **kustomization.yaml**: Include `../../config/crd`, `../../config/manager`, `../../config/webhook`, `../../config/certmanager`
   - **patch_service_account.yaml**: JSON patch to remove serviceAccountName entirely
   - Target namespace: `capi-webhook-system`
   - Apply manager_webhook_patch.yaml and webhookcainjection_patch.yaml from config/default if they exist
   - Include configurations section for kustomizeconfig.yaml
   - Add vars section for CERTIFICATE_NAMESPACE, CERTIFICATE_NAME, SERVICE_NAMESPACE, SERVICE_NAME

5. **Generation script** (run.sh):
   ```bash
   #!/bin/bash
   rm -f generated/*
   kustomize build --load-restrictor LoadRestrictionsNone global > ./generated/core-global.yaml
   kustomize build --load-restrictor LoadRestrictionsNone base > ./generated/core-base.yaml
   ```

6. **Additional scripts** for compatibility:
   - `generate-controller-manifests.sh`: Calls base kustomization → core-base.yaml
   - `generate-webhook-manifests.sh`: Calls global kustomization → core-global.yaml
   - `generate-all-manifests.sh`: Calls run.sh

**Requirements:**
- Use JSON patches (RFC 6902) not strategic merge
- Controller manifests: `--webhook-port=0`, `serviceAccountName: default`, no CRDs/webhooks
- Webhook manifests: Include CRDs, webhooks, Certificate, Issuer, and cert-manager CA injection annotations
- Target namespace: `capi-webhook-system` for webhook, `cap[provider-prefix]-system` for controller
- Skip RBAC for both (handled by Palette)
- Use kustomize v1beta1 format with proper labels
- Match naming pattern: prefix should be `cap[X]-` where X is provider abbreviation
- Output files: `core-global.yaml` (webhook), `core-base.yaml` (controller)

**Global kustomization template:**
```yaml
namespace: capi-webhook-system
namePrefix: cap[provider-prefix]-

resources:
- ../../config/crd
- ../../config/manager
- ../../config/webhook
- ../../config/certmanager

configurations:
- ../../config/default/kustomizeconfig.yaml

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
labels:
- includeSelectors: true
  pairs:
    cluster.x-k8s.io/provider: infrastructure-[provider]
patches:
- path: patch_service_account.yaml
  target:
    group: apps
    kind: Deployment
    name: controller-manager
    namespace: system
    version: v1
- path: ../../config/default/manager_image_patch.yaml
  target:
    group: apps
    kind: Deployment
    name: controller-manager
    version: v1
- path: ../../config/default/manager_webhook_patch.yaml
  target:
    group: apps
    kind: Deployment
    name: controller-manager
    version: v1
- path: ../../config/default/webhookcainjection_patch.yaml

vars:
- name: CERTIFICATE_NAMESPACE
  objref:
    kind: Certificate
    group: cert-manager.io
    version: v1
    name: serving-cert
  fieldref:
    fieldpath: metadata.namespace
- name: CERTIFICATE_NAME
  objref:
    kind: Certificate
    group: cert-manager.io
    version: v1
    name: serving-cert
  fieldref:
    fieldpath: metadata.name
- name: SERVICE_NAMESPACE
  objref:
    kind: Service
    version: v1
    name: webhook-service
  fieldref:
    fieldpath: metadata.namespace
- name: SERVICE_NAME
  objref:
    kind: Service
    version: v1
    name: webhook-service
```

**Expected webhook manifest contents:**
- Certificate resource: `cap[prefix]-serving-cert` in `capi-webhook-system`
- Issuer resource: `cap[prefix]-selfsigned-issuer` in `capi-webhook-system`
- All CRDs have `cert-manager.io/inject-ca-from: capi-webhook-system/cap[prefix]-serving-cert`
- MutatingWebhookConfiguration has `cert-manager.io/inject-ca-from` annotation
- ValidatingWebhookConfiguration has `cert-manager.io/inject-ca-from` annotation
- DNS names in Certificate match webhook service name and namespace

**Provider-specific details to customize:**
- Replace `[provider-prefix]` with actual prefix (e.g., `capc` for CloudStack)
- Replace `[provider]` with provider name (e.g., `cloudstack`)
- Add provider-specific controller flags to patch_service_account.yaml
- Add any provider-specific patches if needed (like Azure's CRD webhook namespace patches)
- Ensure config/certmanager and config/default/webhookcainjection_patch.yaml exist



