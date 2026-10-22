#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-apk}"
SYMBOLS_DIR="${2:-build/app/outputs/symbols}"
ALLOW_LOCAL_DEBUG_SIGNING="${3:-${ALLOW_LOCAL_DEBUG_SIGNING:-false}}"
ENFORCE_PRODUCTION_SIGNING="${4:-${ENFORCE_PRODUCTION_SIGNING:-false}}"

echo "=========================================="
echo " My Root — Flutter Hardened Release Build"
echo " Target: ${TARGET}"
echo " Symbol Directory: ${SYMBOLS_DIR}"

EXTRA_ARGS=()

if [ "${ENFORCE_PRODUCTION_SIGNING}" = "true" ]; then
    echo " Policy: PRODUCTION SIGNING ENFORCED (-PenforceProductionSigning=true)"
    EXTRA_ARGS+=("-PenforceProductionSigning=true")
fi

if [ "${ALLOW_LOCAL_DEBUG_SIGNING}" = "true" ]; then
    echo " Mode: NON-PRODUCTION Local Debug Signing"
    echo " WARNING: Artifact will be signed with Android debug key."
    echo "          This artifact MUST NOT be deployed to production."
    EXTRA_ARGS+=("-PallowLocalDebugSigning=true")
else
    echo " Mode: PRODUCTION SIGNING REQUIRED"
    echo " NOTICE: Build will fail closed if production signing"
    echo "         credentials are not explicitly configured."
fi
echo "=========================================="

mkdir -p "${SYMBOLS_DIR}"

flutter build "${TARGET}" --release --obfuscate --split-debug-info="${SYMBOLS_DIR}" "${EXTRA_ARGS[@]}"

echo "=========================================="
echo " Release build completed successfully!"
echo " Symbol files saved to: ${SYMBOLS_DIR}"
echo " Retain symbol files securely for crash symbolication."
echo "=========================================="
