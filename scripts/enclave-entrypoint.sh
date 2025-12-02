#!/bin/sh
set -eu

PORT=${PORT:-3000}
VSOCK_PORT=${VSOCK_PORT:-$PORT}
APP_BIN=${APP_BIN:-/usr/local/bin/http-in-enclave}

if [ "$#" -eq 0 ]; then
    set -- "$APP_BIN"
fi

log() {
    echo "[enclave-entrypoint] $*"
}

log "configuring loopback"
ip addr add 127.0.0.1/32 dev lo >/dev/null 2>&1 || true
ip link set dev lo up

log "starting vsock ingress on port ${VSOCK_PORT} -> 127.0.0.1:${PORT}"
socat VSOCK-LISTEN:${VSOCK_PORT},fork,reuseaddr TCP:127.0.0.1:${PORT} &
SOCAT_PID=$!

cleanup() {
    if kill -0 "$SOCAT_PID" >/dev/null 2>&1; then
        kill "$SOCAT_PID" >/dev/null 2>&1 || true
        wait "$SOCAT_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

log "launching application: $*"
exec "$@"

