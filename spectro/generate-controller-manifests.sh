#!/bin/bash

# Script to generate controller-only manifests for CAPC
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Generating controller-only manifests..."

# Create output directory
mkdir -p "${SCRIPT_DIR}/generated"

# Generate controller manifests (webhook-port=0)
cd "${SCRIPT_DIR}/controller"
kustomize build . > "${SCRIPT_DIR}/generated/controller-manifests.yaml"

echo "Controller-only manifests generated at: ${SCRIPT_DIR}/generated/controller-manifests.yaml"
echo ""
echo "To deploy the controller:"
echo "kubectl apply -f ${SCRIPT_DIR}/generated/controller-manifests.yaml"