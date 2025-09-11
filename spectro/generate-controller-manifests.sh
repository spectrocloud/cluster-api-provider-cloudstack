#!/bin/bash

# Script to generate controller-only manifests for CAPC
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Generating controller-only manifests..."

# Create output directory
mkdir -p "${SCRIPT_DIR}/generated"

# Generate controller manifests
cd "${SCRIPT_DIR}"
kustomize build --load-restrictor LoadRestrictionsNone base > "${SCRIPT_DIR}/generated/core-base.yaml"

echo "Controller-only manifests generated: ${SCRIPT_DIR}/generated/core-base.yaml"
echo ""
echo "To deploy the controller:"
echo "kubectl apply -f ${SCRIPT_DIR}/generated/core-base.yaml"
