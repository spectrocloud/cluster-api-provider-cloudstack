# Spectro CAPC Manifests

This directory contains manifest generation scripts and configurations for running CAPC (Cluster API Provider CloudStack) components separately as controller-only and webhook-only pods.

## Overview

The CAPC application can be run in two modes:

1. **Controller-only mode** (`--webhook-port=0`): Runs only the reconciliation controllers
2. **Webhook-only mode** (`--webhook-port=9443`): Runs only the webhook server

Both modes use the same codebase and container image, differentiated by the `webhook-port` CLI flag.

## Directory Structure

```
spectro/
├── controller/                          # Controller-only manifests
│   ├── kustomization.yaml              # Kustomize config for controller
│   ├── namespace.yaml                  # Namespace definition
│   ├── manager_controller_patch.yaml   # Controller-specific deployment patch
│   └── kustomizeconfig.yaml           # Kustomize configuration
├── webhook/                            # Webhook-only manifests
│   ├── kustomization.yaml              # Kustomize config for webhook (includes CRDs)
│   ├── namespace.yaml                  # Namespace definition
│   ├── manager_webhook_patch.yaml      # Webhook-specific deployment patch
│   └── kustomizeconfig.yaml           # Kustomize configuration
├── generated/                          # Generated manifest files (created by scripts)
│   ├── controller-manifests.yaml      # Controller-only manifests
│   └── webhook-manifests.yaml         # Webhook-only manifests (with CRDs)
├── generate-controller-manifests.sh   # Script to generate controller manifests
├── generate-webhook-manifests.sh      # Script to generate webhook manifests
├── generate-all-manifests.sh          # Script to generate both sets of manifests
└── README.md                          # This file
```

## Usage

### Generate All Manifests

```bash
./generate-all-manifests.sh
```

### Generate Controller-Only Manifests

```bash
./generate-controller-manifests.sh
```

### Generate Webhook-Only Manifests

```bash
./generate-webhook-manifests.sh
```

## Deployment

### Controller-Only Deployment

The controller-only deployment includes:
- Manager deployment with `--webhook-port=0`
- RBAC permissions for controllers
- No webhook configurations
- No CRDs (should be deployed separately or via webhook deployment)

```bash
kubectl apply -f generated/controller-manifests.yaml
```

### Webhook-Only Deployment

The webhook-only deployment includes:
- Manager deployment with `--webhook-port=9443`
- CRDs (Custom Resource Definitions)
- Webhook configurations (MutatingWebhookConfiguration and ValidatingWebhookConfiguration)
- Webhook service
- No RBAC for controllers
- No cert-manager configurations (certificates must be managed separately)

```bash
kubectl apply -f generated/webhook-manifests.yaml
```

## Important Notes

1. **RBAC**: Only the controller deployment includes RBAC permissions. The webhook deployment does not include RBAC or cert-manager configurations as requested.

2. **CRDs**: Custom Resource Definitions are included only in the webhook deployment.

3. **Certificates**: The webhook server requires TLS certificates. You need to create a secret named `capc-webhook-service-cert` with the TLS certificate and key:

   ```bash
   kubectl create secret tls capc-webhook-service-cert \
     --cert=tls.crt \
     --key=tls.key \
     -n capc-system
   ```

4. **Image**: Both deployments use the same container image. Make sure to update the image reference in `config/manager/manager.yaml` or patch files as needed.

5. **Networking**: The webhook service runs on port 9443 and expects the admission controllers to be accessible from the Kubernetes API server.

## Customization

To customize the deployments:

1. Modify the patch files in `controller/` or `webhook/` directories
2. Update the kustomization.yaml files to add additional resources or patches
3. Regenerate the manifests using the provided scripts

## Labels and Selectors

- Controller pods use label: `control-plane: capc-controller-manager`
- Webhook pods use label: `control-plane: capc-webhook-manager`

This allows for separate selection and management of the two types of pods.