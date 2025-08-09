FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    # to advertise the hostname on the local network
    avahi-daemon \
    libnss-mdns \
    && rm -rf /var/lib/apt/lists/*

# Installation of binaries needs to be done to /usr/bin/ instead of /usr/local/bin/
# this is because kairos is mounting on /usr/local/bin/ so it will just not be available
#
# k9s
ARG TARGETARCH
ARG K9S_VERSION=v0.50.9
ARG K9S_URL=https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${TARGETARCH}.tar.gz
RUN set -eux; \
    tmpdir="$(mktemp -d)"; \
    cd "$tmpdir"; \
    curl -fsSL "$K9S_URL" -o k9s.tar.gz; \
    tar -xzf k9s.tar.gz; \
    mv k9s /usr/bin/k9s; \
    chmod +x /usr/bin/k9s; \
    cd /; \
    rm -rf "$tmpdir"
