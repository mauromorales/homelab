# VisionFive 2 (JH7110) image, stock Ubuntu kernel. Kairos v4.4.0, riscv64, k3s.
# Build: docker buildx build --platform linux/riscv64 -f kairos.Dockerfile -t kairos-vf2 .
#
# kairos-init, provider-kairos and the Kairos tools come from the Kairos v4.4.0
# release assets: the quay.io/kairos/kairos-init image has no riscv64 build.
FROM ubuntu:24.04
ARG VERSION=v4.4.0
ARG K3S_RISCV64_RELEASE=20260817

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN curl -fL "https://github.com/kairos-io/kairos/releases/download/${VERSION}/kairos-init-${VERSION}-linux-riscv64.tar.gz" \
      | tar -xz -C /usr/local/bin kairos-init
RUN kairos-init -l debug -s install --version "${VERSION}" && \
    kairos-init -l debug -s init --version "${VERSION}"

# k3s has no official riscv64 release; use the CARV-ICS-FORTH fork. Same approach
# and reasons as ../kairos-riscv64/kairos.Dockerfile.
RUN curl -fL -o /usr/bin/k3s "https://github.com/CARV-ICS-FORTH/k3s/releases/download/${K3S_RISCV64_RELEASE}/k3s-riscv64" && \
    chmod +x /usr/bin/k3s && \
    curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh && chmod +x /tmp/k3s-install.sh && \
    INSTALL_K3S_BIN_DIR=/usr/bin INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_SKIP_ENABLE=true \
    INSTALL_K3S_SKIP_SELINUX_RPM=true /tmp/k3s-install.sh && rm -f /tmp/k3s-install.sh

# The cloud-config `k3s:` stanza is read by provider-kairos at boot.
RUN mkdir -p /system/providers && \
    curl -fL "https://github.com/kairos-io/kairos/releases/download/${VERSION}/provider-kairos-${VERSION}-linux-riscv64.tar.gz" \
      | tar -xz -O provider-kairos > /system/providers/agent-provider-kairos && \
    chmod +x /system/providers/agent-provider-kairos && \
    ln -sf /system/providers/agent-provider-kairos /usr/bin/kairos
