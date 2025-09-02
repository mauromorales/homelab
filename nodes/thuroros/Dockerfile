FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    # to advertise the hostname on the local network
    avahi-daemon \
    libnss-mdns \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    # doorbell dependencies
    gcc \
    python3-dev \
    python3-lgpio \
    python3-requests \
    python3-pytzdata \
    && rm -rf /var/lib/apt/lists/*