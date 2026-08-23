# check=skip=InvalidDefaultArgInFrom
# BASE_IMAGE has no default on purpose: the CI workflow always supplies it
# (kairos-riscv64-base's pushed image), and a build without it should fail
# loudly rather than silently resolve to an empty FROM.
ARG KAIROS_INIT=latest
ARG BASE_IMAGE

FROM quay.io/kairos/kairos-init:${KAIROS_INIT} AS kairos-init

# BASE_IMAGE is nodes/kairos-riscv64/Dockerfile, built and pushed to quay.io
# by this node's own -base CI job (mirrors every other node's
# base-then-factory split). ./Dockerfile stays as documentation and for
# local reproduction
# (`docker build -f nodes/kairos-riscv64/Dockerfile .`), per AGENTS.md's
# build-pipeline convention, but its actual content now only exists once:
# it's what the CI build runs too, not a duplicate of the packages below.
FROM ${BASE_IMAGE} AS base-kairos
ARG MODEL=generic
ARG VERSION

RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init -l debug -s install -m "${MODEL}" --version "${VERSION}" && \
    /kairos-init -l debug -s init -m "${MODEL}" --version "${VERSION}"

# k3s has no official riscv64 release yet (kairos-io/kairos#4083, and
# k3s-io/k3s#7151 -- "not prioritized, no build infra"). kairos-init's -p/
# --provider flag can't help here either: provider-kairos's own BuildEvent
# handler (the thing -p k3s actually triggers) downloads get.k3s.io and runs
# it without INSTALL_K3S_SKIP_DOWNLOAD, so it still tries to fetch an
# official riscv64 binary that doesn't exist, and fails.
#
# This replicates that same handler's install (provider-kairos's
# buildEvent.go: INSTALL_K3S_BIN_DIR=/usr/bin INSTALL_K3S_SKIP_ENABLE=true),
# but pre-places CARV-ICS-FORTH's actively-maintained riscv64 fork
# (https://github.com/CARV-ICS-FORTH/k3s) at the path the installer expects
# and adds INSTALL_K3S_SKIP_DOWNLOAD=true, so get.k3s.io's script only does
# what still works on riscv64: write the real systemd unit and enable it,
# instead of hand-writing that unit from scratch. Swap this whole block for
# a plain `kairos-init -p k3s` the moment an official riscv64 release
# exists -- there is nothing else riscv64-specific about this node.
ARG K3S_RISCV64_RELEASE=20260817
RUN curl -fL -o /usr/bin/k3s \
        "https://github.com/CARV-ICS-FORTH/k3s/releases/download/${K3S_RISCV64_RELEASE}/k3s-riscv64" && \
    chmod +x /usr/bin/k3s && \
    curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh && \
    chmod +x /tmp/k3s-install.sh && \
    INSTALL_K3S_BIN_DIR=/usr/bin \
    INSTALL_K3S_SKIP_DOWNLOAD=true \
    INSTALL_K3S_SKIP_ENABLE=true \
    INSTALL_K3S_SKIP_SELINUX_RPM=true \
    /tmp/k3s-install.sh && \
    rm -f /tmp/k3s-install.sh

# The k3s.service unit above is necessary but not sufficient: the cloud-config
# `k3s:` stanza is read at boot by a separate binary, provider-kairos (the
# kairos-agent plugin registered under /system/providers/agent-provider-kairos,
# symlinked to /usr/bin/kairos), not by kairos-agent itself. kairos-init's own
# GetInstallProviderBinaries step normally fetches this from provider-kairos's
# GitHub releases when a provider is requested, but falls back to an embedded
# binary (amd64/arm64 only) when no version override is given, and this step
# was never reached here since -p/--provider isn't used on this node (see the
# comment above). provider-kairos does publish a riscv64 release, so fetch it
# the same way kairos-init would, instead of leaving the stanza with nothing
# to read it.
ARG PROVIDER_KAIROS_VERSION=v2.16.4
RUN mkdir -p /system/providers && \
    curl -fL -o /tmp/provider-kairos.tar.gz \
        "https://github.com/kairos-io/provider-kairos/releases/download/${PROVIDER_KAIROS_VERSION}/provider-kairos-${PROVIDER_KAIROS_VERSION}-linux-riscv64.tar.gz" && \
    tar -xzf /tmp/provider-kairos.tar.gz -O provider-kairos > /system/providers/agent-provider-kairos && \
    chmod +x /system/providers/agent-provider-kairos && \
    ln -sf /system/providers/agent-provider-kairos /usr/bin/kairos && \
    rm -f /tmp/provider-kairos.tar.gz
