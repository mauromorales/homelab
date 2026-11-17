# Isotope i3 with the brcmsmac Wi-Fi firmware.
#
# The published image ships brcm/brcmfmac* only, so a Broadcom chip on the bcma
# bus (some 2010-2012 MacBook Airs) logs "brcmsmac: fail to load firmware
# brcm/bcm43xx-0.fw" and has no Wi-Fi. Both files are in linux-firmware and
# redistributable (LICENCE.broadcom_bcm43xx). Same release tag as the one
# Isotope pins, zstd-compressed like the rest of /usr/lib/firmware, and never
# under /usr/local (an installed system mounts COS_PERSISTENT over it).
#
# It also replaces /usr/bin/start-desktop with a copy that gives Flatpak apps
# the X cookie (Chromium from the first-run picker exits with "Authorization
# required" without it).
#
# Temporary: once this is verified on hardware, the same fix goes upstream to
# kairos-community/isotope and this node goes away.
ARG BASE_IMAGE=ghcr.io/kairos-community/isotope:i3-v0.0.16

FROM alpine:3 AS fw
ARG LINUX_FIRMWARE_VERSION=20261019
RUN apk add --no-cache curl zstd
WORKDIR /fw/usr/lib/firmware/brcm
RUN base="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/brcm" && \
    curl -fL --retry 5 --retry-all-errors "$base/bcm43xx-0.fw?h=${LINUX_FIRMWARE_VERSION}" -o bcm43xx-0.fw && \
    curl -fL --retry 5 --retry-all-errors "$base/bcm43xx_hdr-0.fw?h=${LINUX_FIRMWARE_VERSION}" -o bcm43xx_hdr-0.fw && \
    echo "24668c702e723d2b1caebda047ee975ce16d7edf23788bc447dc12bcaf246b0f  bcm43xx-0.fw" | sha256sum -c - && \
    echo "4aaa2ba62983d64b65f351908c59062a8a7c99100d190904c0e780d7c30f0dd0  bcm43xx_hdr-0.fw" | sha256sum -c - && \
    zstd -q --rm bcm43xx-0.fw bcm43xx_hdr-0.fw

FROM ${BASE_IMAGE}
COPY --from=fw /fw/ /
COPY --chmod=755 start-desktop /usr/bin/start-desktop
