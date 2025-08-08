FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    avahi-daemon \
    ca-certificates \
    curl \
    git \
    libnss-mdns \
    && rm -rf /var/lib/apt/lists/*

# Install k9s (Linux binary, arch-specific)
ARG TARGETARCH
ARG K9S_VERSION=v0.50.9
ARG K9S_URL=https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${TARGETARCH}.tar.gz
RUN set -eux; \
    tmpdir="$(mktemp -d)"; \
    cd "$tmpdir"; \
    curl -fsSL "$K9S_URL" -o k9s.tar.gz; \
    tar -xzf k9s.tar.gz; \
    mv k9s /usr/local/bin/k9s; \
    chmod +x /usr/local/bin/k9s; \
    cd /; \
    rm -rf "$tmpdir"
