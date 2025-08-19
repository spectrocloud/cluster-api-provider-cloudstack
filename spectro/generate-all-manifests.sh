#!/bin/bash

# Script to generate both controller and webhook manifests for CAPC
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Generating all CAPC manifests..."

# Generate controller manifests
"${SCRIPT_DIR}/generate-controller-manifests.sh"

echo ""

# Generate webhook manifests
"${SCRIPT_DIR}/generate-webhook-manifests.sh"

echo ""
echo "All manifests generated successfully!"
echo ""
echo "Generated files:"
echo "  - Controller-only: ${SCRIPT_DIR}/generated/controller-manifests.yaml"
echo "  - Webhook-only:    ${SCRIPT_DIR}/generated/webhook-manifests.yaml"