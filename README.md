# http-in-enclave

A minimal Rust HTTP service packaged to run inside AWS Nitro Enclaves. The server exposes `/api/hello` and can be compiled into a Docker image and finally an EIF artifact suitable for enclave launches.

## Prerequisites

- Host OS: Amazon Linux 2023 Nitro Enclave-enabled EC2 instance
- Installed tooling: `docker`, `nitro-cli`, `aws-cli`, `git`

## Local Development

```bash
cargo run
curl http://127.0.0.1:3000/api/hello
```

## Quick Start on the Enclave Host

```bash
ssh ec2-user@<enclave-instance>
sudo yum install docker -y
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker

git clone https://github.com/<your-org>/http-in-enclave.git
cd http-in-enclave

# Default Dockerfile uses Alpine for smaller EIFs; Amazon Linux equivalent lives in `Dockerfile.amazonlinux` for easy reference.
```

All commands below run on the enclave host inside this repository.

## Build Docker Image (host-local)

```bash
./scripts/build-docker.sh
```

Environment knobs:
- `IMAGE_NAME` (default `http-in-enclave`)
- `IMAGE_TAG` (default `local`)
- `DOCKERFILE_PATH`, `PLATFORM` for alternate Dockerfiles/platforms (point `DOCKERFILE_PATH` to `Dockerfile.amazonlinux` to reproduce the larger base image if needed)

## Build EIF

```bash
./scripts/build-eif.sh
```

Environment knobs:
- `IMAGE_NAME`/`IMAGE_TAG` to match the locally built image
- `EIF_OUTPUT` (default `target/http-in-enclave.eif`)

## Run Enclave

```bash
./scripts/run-enclave.sh
```

Environment knobs:
- `EIF_PATH`, `ENCLAVE_NAME`, `CPU_COUNT`, `MEMORY_MIB`, `CONSOLE_FILE`
- `HOST_HTTP_PORT` (default `3000`) host-side TCP port for curling the enclave service
- `VSOCK_PORT` (default `3000`) vsock port exposed inside the enclave via socat bridge
- `HOST_EGRESS_ENABLED` (default `0`) enable host-side egress proxy
- `HOST_EGRESS_TARGET_HOST`/`HOST_EGRESS_TARGET_PORT` (defaults `127.0.0.1:4000`) host service to reach from the enclave
- `HOST_EGRESS_VSOCK_PORT` (default `4000`) vsock port used for egress traffic

After the script launches the EIF it also starts a host `socat` proxy so the host can reach the enclave HTTP server via `curl http://127.0.0.1:${HOST_HTTP_PORT}/api/hello`. When `HOST_EGRESS_ENABLED=1`, a second `socat` bridge exposes a vsock listener that forwards to a host HTTP service, making it reachable from inside the enclave at `127.0.0.1:${ENCLAVE_EGRESS_PORT}`.

### Enclave-side Egress

`scripts/enclave-entrypoint.sh` honors optional env vars:
- `ENCLAVE_EGRESS_ENABLED` (default `0`)
- `ENCLAVE_EGRESS_PORT` (default `4000`), the loopback port your enclave app calls
- `HOST_EGRESS_VSOCK_PORT` (default `4000`), must match the host script value
- `HOST_PARENT_CID` (default `3`, Nitro host CID)

Example: launch the host helper with `HOST_EGRESS_ENABLED=1 HOST_EGRESS_TARGET_PORT=4000` and set `ENCLAVE_EGRESS_ENABLED=1 ENCLAVE_EGRESS_PORT=4000` so code inside the enclave can `curl http://127.0.0.1:4000/…` and talk to the host service bound to `127.0.0.1:4000`.

Stop the enclave when finished:

```bash
./scripts/stop-enclave.sh
```

If the EC2 host reboots, all running enclaves are terminated and must be rebuilt/restarted. Re-run the Docker/EIF build only when the application changed; otherwise, just relaunch the EIF with `run-enclave.sh`. Should Nitro report `E26` (insufficient memory), increase `MEMORY_MIB` to exceed the EIF file size by ~100 MB.

Console logs are saved to `target/http-in-enclave-console.log` for troubleshooting.

## Troubleshooting

- Ensure Nitro Enclaves feature is enabled on the EC2 instance (`nitro-cli --version` should succeed).
- If `nitro-cli build-enclave` fails with missing image, confirm the Docker image exists locally via `docker images`.
- Port conflicts on the host are avoided in enclave mode, but when testing locally adjust `PORT` env var.
- If `curl` on the host fails, confirm the vsock proxy is still running (`pgrep -af socat`) and that `HOST_HTTP_PORT`/`VSOCK_PORT` match the enclave configuration.
- If egress is enabled but the enclave cannot reach the host service, check that the host socat process is running and the target service is bound to `HOST_EGRESS_TARGET_HOST:HOST_EGRESS_TARGET_PORT`.
