FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    # to advertise the hostname on the local network
    avahi-daemon \
    libnss-mdns \
    # avahi-resolve and avahi-browse, to debug mDNS from the node itself.
    # avahi-daemon ships the daemon and libnss-mdns the resolver, but neither
    # ships the command line tools.
    avahi-utils \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    # doorbell dependencies
    gcc \
    python3-dev \
    python3-lgpio \
    python3-requests \
    python3-tz \
    python3-paho-mqtt \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    # reverse proxy, so the config UI answers on port 80 at /
    nginx \
    # generates the self-signed cert nginx serves over HTTPS, and applies
    # the static netplan config written by cloud-config.yaml
    openssl \
    netplan.io \
    && rm -rf /var/lib/apt/lists/*
