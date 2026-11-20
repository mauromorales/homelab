# Kairos v4.4.0 for the StarFive VisionFive 2 (JH7110), riscv64, with the HDMI kernel.
# Build: docker buildx build --platform linux/riscv64 -t kairos-vf2 .
#
# Stage 1 builds the kernel (mainline + the unmerged JH7110 display series). It
# runs on the build machine's own architecture and cross-compiles, so it does not
# go through QEMU. Stage 2 is the Kairos image, built for riscv64.
FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS kernel
ARG KERNEL_TAG=v7.4-rc1
# Commit of github.com/Opvolger/linux-drm-jh7110. Patches 0001-0024 are the
# display stack; 0025 and up are audio and PowerVR and are not applied.
ARG PATCHES_REF=76e309ca1fd89ed4a826d2387a12061f75dc4ea7
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential gcc-riscv64-linux-gnu bc bison flex libssl-dev libelf-dev \
      dwarves rsync kmod cpio xz-utils zstd python3 perl device-tree-compiler git gawk ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${KERNEL_TAG}" \
      https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git /linux && \
    git clone https://github.com/Opvolger/linux-drm-jh7110 /patches && \
    git -C /patches checkout "${PATCHES_REF}" && \
    git -C /linux -c user.name=build -c user.email=build@localhost am --3way \
      /patches/linux-7.4-patches/000*.patch /patches/linux-7.4-patches/001*.patch /patches/linux-7.4-patches/002[0-4]*.patch
# kernel/config is the Ubuntu 7.0 riscv64 config with the display stack as modules
# (DRM_VERISILICON_DC, DRM_INNO_HDMI, DRM_STARFIVE_JH7110_INNO_HDMI,
# PHY_STARFIVE_JH7110_INNO_HDMI), framebuffer console on, module signing off.
COPY kernel/config /out/.config
RUN export ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- && \
    cp /out/.config /linux/.config && make -C /linux olddefconfig && \
    for o in DRM_VERISILICON_DC DRM_INNO_HDMI DRM_STARFIVE_JH7110_INNO_HDMI PHY_STARFIVE_JH7110_INNO_HDMI; do \
      grep -q "^CONFIG_$o=m" /linux/.config || { echo "missing $o"; exit 1; }; done && \
    make -C /linux -j"$(nproc)" KBUILD_IMAGE=arch/riscv/boot/Image Image dtbs modules && \
    REL=$(make -C /linux -s kernelrelease) && echo "$REL" > /out/kernelrelease && \
    make -C /linux modules_install INSTALL_MOD_PATH=/out/root INSTALL_MOD_STRIP=1 && \
    rm -f /out/root/lib/modules/$REL/build /out/root/lib/modules/$REL/source && \
    cp /linux/arch/riscv/boot/Image /out/vmlinuz && \
    mkdir -p /out/dtb && cp /linux/arch/riscv/boot/dts/starfive/jh7110-*.dtb /out/dtb/

FROM ubuntu:24.04
# KAIROS_VERSION is the upstream Kairos release the tools come from. VERSION is
# the version of this image (our own, passed in by the workflow); it ends up in
# the image's os-release, as with ../kairos-riscv64.
ARG KAIROS_VERSION=v4.4.0
ARG VERSION=0.0.0
ARG K3S_RISCV64_RELEASE=20260817

# kairos-init, provider-kairos and the Kairos tools come from the Kairos release:
# the quay.io/kairos/kairos-init image has no riscv64 build.
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*
RUN curl -fL "https://github.com/kairos-io/kairos/releases/download/${KAIROS_VERSION}/kairos-init-${KAIROS_VERSION}-linux-riscv64.tar.gz" \
      | tar -xz -C /usr/local/bin kairos-init
# Install step without the Ubuntu kernel packages.
RUN kairos-init -l debug -s install --skip-step installKernel --version "${VERSION}"
# Our kernel: modules in /lib/modules/<rel>, image as /boot/vmlinuz-<rel>, DTBs in /boot/dtb.
COPY --from=kernel /out/root/lib/modules/ /lib/modules/
COPY --from=kernel /out/kernelrelease /tmp/kernelrelease
COPY --from=kernel /out/vmlinuz /tmp/vmlinuz
COPY --from=kernel /out/dtb/ /boot/dtb/
RUN REL=$(cat /tmp/kernelrelease) && mv /tmp/vmlinuz /boot/vmlinuz-$REL && depmod $REL && rm /tmp/kernelrelease
# The init step picks the newest /lib/modules/<rel>, links /boot/vmlinuz and builds the initrd.
RUN kairos-init -l debug -s init --version "${VERSION}"

# k3s has no official riscv64 release; use the CARV-ICS-FORTH fork. Same approach
# and reasons as ../kairos-riscv64/kairos.Dockerfile.
RUN curl -fL -o /usr/bin/k3s "https://github.com/CARV-ICS-FORTH/k3s/releases/download/${K3S_RISCV64_RELEASE}/k3s-riscv64" && \
    chmod +x /usr/bin/k3s && \
    curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh && chmod +x /tmp/k3s-install.sh && \
    INSTALL_K3S_BIN_DIR=/usr/bin INSTALL_K3S_SKIP_DOWNLOAD=true INSTALL_K3S_SKIP_ENABLE=true \
    INSTALL_K3S_SKIP_SELINUX_RPM=true /tmp/k3s-install.sh && rm -f /tmp/k3s-install.sh
# The cloud-config `k3s:` stanza is read by provider-kairos at boot.
RUN mkdir -p /system/providers && \
    curl -fL "https://github.com/kairos-io/kairos/releases/download/${KAIROS_VERSION}/provider-kairos-${KAIROS_VERSION}-linux-riscv64.tar.gz" \
      | tar -xz -O provider-kairos > /system/providers/agent-provider-kairos && \
    chmod +x /system/providers/agent-provider-kairos && \
    ln -sf /system/providers/agent-provider-kairos /usr/bin/kairos
