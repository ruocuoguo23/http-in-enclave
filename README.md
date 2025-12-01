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
```

All commands below run on the enclave host inside this repository.

## Build Docker Image (host-local)

```bash
./scripts/build-docker.sh
```

Environment knobs:
- `IMAGE_NAME` (default `http-in-enclave`)
- `IMAGE_TAG` (default `local`)
- `DOCKERFILE_PATH`, `PLATFORM` for alternate Dockerfiles/platforms

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

Stop the enclave when finished:

```bash
nitro-cli terminate-enclave --enclave-name http-in-enclave
```

Console logs are saved to `target/http-in-enclave-console.log` for troubleshooting.

## Troubleshooting

- Ensure Nitro Enclaves feature is enabled on the EC2 instance (`nitro-cli --version` should succeed).
- If `nitro-cli build-enclave` fails with missing image, confirm the Docker image exists locally via `docker images`.
- Port conflicts on the host are avoided in enclave mode, but when testing locally adjust `PORT` env var.

