# check=skip=InvalidDefaultArgInFrom
# BASE_IMAGE has no default on purpose: the CI workflow always supplies it
# (kairos-rpi5-base's pushed image), and a build without it should fail
# loudly rather than silently resolve to an empty FROM.
ARG KAIROS_INIT=latest
ARG BASE_IMAGE

FROM quay.io/kairos/kairos-init:${KAIROS_INIT} AS kairos-init

FROM ${BASE_IMAGE} AS base-kairos
ARG MODEL=generic
ARG VERSION

# --model generic, same reason kairos-riscv64 uses it: kairos-init has no
# rpi5 model preset yet (only rpi3/rpi4), and that preset is exactly where
# the real blocker lives -- kairos-io/kairos#2010 says plainly "Model 5 is
# currently not supported because of how Kairos uses U-boot to boot the
# device." generic skips the board-specific packaging kairos-init would
# otherwise pull in, which means THIS BUILD DOES NOT SOLVE THE BOOT CHAIN.
# It produces the OS layer only. Getting u-boot and Pi 5 firmware onto the
# boot partition correctly is the open, unverified part -- see this node's
# README before assuming this image boots.
RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init -l debug -s install -m "${MODEL}" --version "${VERSION}" && \
    /kairos-init -l debug -s init -m "${MODEL}" --version "${VERSION}"
