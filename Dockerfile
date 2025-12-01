# syntax=docker/dockerfile:1

# Original Amazon Linux based Dockerfile
# FROM amazonlinux:2023 AS builder
#
# RUN dnf install -y rust cargo gcc openssl-devel pkgconfig && dnf clean all
# WORKDIR /app
# COPY Cargo.toml Cargo.lock ./
# COPY src ./src
# RUN cargo build --release
#
# FROM amazonlinux:2023
# RUN dnf install -y ca-certificates && dnf clean all
# WORKDIR /app
# COPY --from=builder /app/target/release/http-in-enclave /usr/local/bin/http-in-enclave
# EXPOSE 3000
# ENV PORT=3000
# CMD ["/usr/local/bin/http-in-enclave"]

FROM alpine:3.20 AS builder

RUN apk add --no-cache build-base curl git musl-dev openssl-dev pkgconfig
ENV PATH="/root/.cargo/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal && \
    rustup target add x86_64-unknown-linux-musl
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release --target x86_64-unknown-linux-musl

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/http-in-enclave /usr/local/bin/http-in-enclave
EXPOSE 3000
ENV PORT=3000
CMD ["/usr/local/bin/http-in-enclave"]
