#!/usr/bin/env bash
set -euo pipefail

EIF_PATH=${EIF_PATH:-target/http-in-enclave.eif}
ENCLAVE_NAME=${ENCLAVE_NAME:-http-in-enclave}
CPU_COUNT=${CPU_COUNT:-2}
MEMORY_MIB=${MEMORY_MIB:-512}
CONSOLE_FILE=${CONSOLE_FILE:-target/http-in-enclave-console.log}
HOST_HTTP_PORT=${HOST_HTTP_PORT:-3000}
VSOCK_PORT=${VSOCK_PORT:-3000}
SOCAT_BIN=${SOCAT_BIN:-socat}

if ! command -v "${SOCAT_BIN}" >/dev/null; then
    echo "socat binary '${SOCAT_BIN}' not found. Install socat on the host or point SOCAT_BIN to an existing binary." >&2
    exit 1
fi

start_vsock_proxy() {
    "${SOCAT_BIN}" TCP-LISTEN:"${HOST_HTTP_PORT}",fork,reuseaddr VSOCK-CONNECT:16:"${VSOCK_PORT}" &
    PROXY_PID=$!
    echo "Started vsock proxy (${SOCAT_BIN}) on host port ${HOST_HTTP_PORT} (PID ${PROXY_PID})"
}

cleanup_proxy() {
    if [[ -n "${PROXY_PID:-}" ]]; then
        kill "${PROXY_PID}" 2>/dev/null || true
        wait "${PROXY_PID}" 2>/dev/null || true
    fi
}

trap cleanup_proxy EXIT

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

start_vsock_proxy

echo "Streaming enclave console output. Press Ctrl+C to stop."
nitro-cli console --enclave-name "${ENCLAVE_NAME}" | tee "${CONSOLE_FILE}"
