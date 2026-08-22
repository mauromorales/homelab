FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    # to advertise the hostname on the local network
    avahi-daemon \
    libnss-mdns \
    # debugging tools
    curl \
    iproute2 \
    iputils-ping \
    net-tools \
    traceroute \
    vim \
    wget \
    && rm -rf /var/lib/apt/lists/*