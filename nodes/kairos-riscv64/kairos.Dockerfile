ARG KAIROS_INIT=latest

FROM quay.io/kairos/kairos-init:${KAIROS_INIT} AS kairos-init

# Deliberately not FROM a separately-built ${BASE_IMAGE}: the CI workflow
# cross-builds this for riscv64, and docker/setup-buildx-action's
# docker-container builder runs in an isolated BuildKit instance with its own
# image store -- it can't resolve a locally --load'ed image from an earlier
# step, even within the same job (that's what every other node's registry
# push between the base and factory steps works around). Keeping the base
# packages inline here, duplicated from ./Dockerfile, means this file is the
# whole build in one step. ./Dockerfile stays as documentation and for local
# reproduction (`docker build -f nodes/kairos-riscv64/Dockerfile .`), per
# AGENTS.md's build-pipeline convention -- it just isn't part of this node's
# actual CI build.
FROM ubuntu:24.04 AS base-kairos
ARG MODEL=generic
ARG VERSION

RUN apt-get update && apt-get install -y \
    avahi-daemon \
    libnss-mdns \
    curl \
    iproute2 \
    iputils-ping \
    net-tools \
    traceroute \
    vim \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init -l debug -s install -m "${MODEL}" --version "${VERSION}" && \
    /kairos-init -l debug -s init -m "${MODEL}" --version "${VERSION}"

# k3s has no official riscv64 release yet (kairos-io/kairos#4083, and
# k3s-io/k3s#7151 -- "not prioritized, no build infra"). kairos-init's -p/
# --provider flag can't help here either: it installs a provider kairos-init
# already knows how to fetch, and riscv64 k3s isn't one of them. Fetching the
# binary directly from CARV-ICS-FORTH's actively-maintained riscv64 fork
# (https://github.com/CARV-ICS-FORTH/k3s) is the only way to get it into the
# image at all today. Swap this for the official k3s release the moment one
# exists -- there is nothing else riscv64-specific about this node.
ARG K3S_RISCV64_RELEASE=20260817
RUN curl -fL -o /usr/local/bin/k3s \
        "https://github.com/CARV-ICS-FORTH/k3s/releases/download/${K3S_RISCV64_RELEASE}/k3s-riscv64" && \
    chmod +x /usr/local/bin/k3s
