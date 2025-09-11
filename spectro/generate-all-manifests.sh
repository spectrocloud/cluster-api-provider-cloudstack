#!/bin/bash

# Script to generate both controller and webhook manifests for CAPC
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Generating all CAPC manifests..."
echo ""

# Use the standardized run.sh approach
"${SCRIPT_DIR}/run.sh"

echo ""
echo "All manifests generated successfully!"
echo ""
echo "Generated files:"
echo "  - Controller-only: ${SCRIPT_DIR}/generated/core-base.yaml"
echo "  - Webhook-only:    ${SCRIPT_DIR}/generated/core-global.yaml"
