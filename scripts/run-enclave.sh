#!/usr/bin/env bash
set -euo pipefail

EIF_PATH=${EIF_PATH:-target/http-in-enclave.eif}
ENCLAVE_NAME=${ENCLAVE_NAME:-http-in-enclave}
CPU_COUNT=${CPU_COUNT:-2}
MEMORY_MIB=${MEMORY_MIB:-512}
CONSOLE_FILE=${CONSOLE_FILE:-target/http-in-enclave-console.log}

if ! command -v nitro-cli >/dev/null; then
    echo "nitro-cli not found in PATH" >&2
    exit 1
fi

if [[ ! -f "${EIF_PATH}" ]]; then
    echo "EIF file not found at ${EIF_PATH}. Run scripts/build-eif.sh first." >&2
    exit 1
fi

if nitro-cli describe-enclaves | grep -q "\"EnclaveName\": \"${ENCLAVE_NAME}\""; then
    echo "Enclave ${ENCLAVE_NAME} already running. Terminate it before starting a new one." >&2
    exit 1
fi

nitro-cli run-enclave \
    --eif-path "${EIF_PATH}" \
    --cpu-count "${CPU_COUNT}" \
    --memory "${MEMORY_MIB}" \
    --enclave-cid 16 \
    --debug-mode \
    --enclave-name "${ENCLAVE_NAME}"

echo "Streaming enclave console output. Press Ctrl+C to stop."
nitro-cli console --enclave-name "${ENCLAVE_NAME}" | tee "${CONSOLE_FILE}"

