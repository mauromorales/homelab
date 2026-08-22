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
