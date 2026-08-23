FROM registry.opensuse.org/opensuse/tumbleweed:latest

# Tumbleweed, not Ubuntu, and it's a deliberate choice, not a copy of
# kairos-riscv64's base. Ubuntu 24.04's current HWE kernel is 6.17 -- one
# version short of the mainline Linux 6.18 that carries RP1 (the Pi 5's I/O
# chip) Ethernet and USB driver support. Ubuntu's next HWE point release
# (7.0, past 6.18) isn't out yet. Tumbleweed is rolling-release and SUSE's
# own engineers wrote the RP1 kernel patches, so it's the base most likely
# to already carry that support today. Verify the running kernel version
# (`uname -r`) once this actually boots -- this is a reasoned bet, not a
# confirmed fact.

RUN zypper --non-interactive install --no-recommends \
    avahi \
    nss-mdns \
    curl \
    iproute2 \
    iputils \
    net-tools-deprecated \
    traceroute \
    vim \
    wget \
    && zypper clean --all
