# CAPC Webhook/Controller Separation

This directory contains the infrastructure to generate separate webhook and controller manifests for the CloudStack provider (CAPC), following the standardized pattern used by all Spectro CAPI providers.

## Overview

The same CAPC binary can run in two modes:
- **Webhook-only mode** (`--webhook-port=9443`): Handles admission webhooks, includes CRDs, runs in `capi-webhook-system`
- **Controller-only mode** (`--webhook-port=0`): Handles reconciliation only, can be namespace-scoped, uses `serviceAccountName: default`

## Quick Start

Generate both sets of manifests:
```bash
./run.sh
# Or for more verbose output:
./generate-all-manifests.sh
```

## Generated Files

- **`generated/core-global.yaml`**: Webhook-only manifests with CRDs
- **`generated/core-base.yaml`**: Controller-only manifests

## Structure

```
spectro/
├── base/                      # Controller-only configuration
│   ├── kustomization.yaml     # Kustomize config for capc-system namespace
│   ├── patch_service_account.yaml  # Sets serviceAccountName: default, --webhook-port=0
│   └── patch_healthcheck.yaml      # Removes health probes
├── global/                    # Webhook-only configuration  
│   ├── kustomization.yaml     # Kustomize config for capi-webhook-system namespace
│   └── patch_service_account.yaml  # Removes serviceAccountName (uses default from manager)
├── generated/                 # Output directory
└── run.sh                     # Main generation script
```


## Integration with Palette

- **Global deployment**: Palette deploys `core-global.yaml` to `capi-webhook-system` for webhooks
- **Namespaced deployment**: Palette deploys `core-base.yaml` to tenant namespaces with `--namespace=$(NAMESPACE)` for isolation
- **Namespace isolation**: Each controller instance only reconciles objects in its own namespace

## Manual Deployment

### Deploy Webhook Server (Global)
```bash
kubectl apply -f generated/core-global.yaml
```

### Deploy Controller (Namespaced)
```bash
kubectl create namespace my-tenant-ns
kubectl apply -f generated/core-base.yaml -n my-tenant-ns
```

## Key Features

- **✅ Webhook separation**: Webhooks run centrally in `capi-webhook-system`
- **✅ Namespace isolation**: Controllers only reconcile objects in their namespace
- **✅ Health probe removal**: Controller-only mode removes health probes that conflict with webhook-port=0
- **✅ Service account**: Controller uses `serviceAccountName: default` for tenant namespaces
- **✅ Standardized naming**: Matches AWS (`capa-`) and Azure (`capz-`) patterns with `capc-` prefix
- **✅ Consistent pattern**: Uses same structure and naming as other Spectro CAPI providers

## Validation

### Controller Manifests Should Include:
- `--webhook-port=0` in container args
- `serviceAccountName: default`
- No CRDs or webhook configurations
- Namespace: `capc-system`

### Webhook Manifests Should Include:  
- CRDs and `ValidatingWebhookConfiguration`/`MutatingWebhookConfiguration`
- All resources in `capi-webhook-system` namespace
- Webhook services pointing to correct namespace

## Development

When modifying the configuration:
1. Edit files in `base/` or `global/`
2. Run `./run.sh` to regenerate manifests
3. Test both controller and webhook deployments
4. Verify namespace isolation works correctly

For more details, see `executedSteps.md` which contains the complete implementation guide for applying this pattern to other CAPI providers.
