#!/bin/bash
# Builds the JH7110 HDMI kernel (mainline v7.4-rc1 + the unmerged JH7110 display
# series) inside kernel/Dockerfile.kbuild. Output in $OUT: vmlinuz-<rel>,
# modules-<rel>.tar.gz, dtb/, config-jh7110hdmi.
#   docker build -t vf2-kbuild -f Dockerfile.kbuild .
#   docker run --rm -v "$PWD/work:/w" -v "$PWD/build.sh:/build.sh" vf2-kbuild /build.sh
# Runs as a cross-compile (x86_64 host, riscv64 target). Not run in CI yet.
set -euo pipefail
KERNEL_TAG=${KERNEL_TAG:-v7.4-rc1}
# Pinned to a commit of github.com/Opvolger/linux-drm-jh7110. Patches 0001-0024
# are the display stack; 0025+ are audio and PowerVR and are not applied.
PATCHES_REF=${PATCHES_REF:-76e309ca1fd89ed4a826d2387a12061f75dc4ea7}
BASE_CONFIG=${BASE_CONFIG:-/w/ubuntu-7.0.0-43.config}   # config from the Ubuntu riscv64 kernel package
T=/w/linux; O=/w/build; OUT=/w/out
export ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu-

[ -d $T ] || git clone --depth 1 --branch "$KERNEL_TAG" https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git $T
if [ ! -d /w/patches ]; then
  git clone https://github.com/Opvolger/linux-drm-jh7110 /w/patches
  git -C /w/patches checkout "$PATCHES_REF"
fi
git -C $T -c user.name=build -c user.email=build@localhost am --3way /w/patches/linux-7.4-patches/00[0-1]*.patch /w/patches/linux-7.4-patches/002[0-4]*.patch

mkdir -p $O $OUT/modroot
cp "$BASE_CONFIG" $O/.config
c() { $T/scripts/config --file $O/.config "$@"; }
c --set-str LOCALVERSION "-jh7110hdmi" -d LOCALVERSION_AUTO
c -d MODULE_SIG -d MODULE_SIG_ALL --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS ""
c -d DEBUG_INFO -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT -d DEBUG_INFO_DWARF5 -d DEBUG_INFO_BTF -e DEBUG_INFO_NONE
c -d RUST -d GCC_PLUGINS
c -m DRM_VERISILICON_DC -m DRM_INNO_HDMI -m DRM_STARFIVE_JH7110_INNO_HDMI -m PHY_STARFIVE_JH7110_INNO_HDMI \
  -m SOC_STARFIVE_JH7110_HDMI_SUBSYSTEM -m SOC_STARFIVE_JH7110_VOUT_SUBSYSTEM \
  -e DRM_FBDEV_EMULATION -e FRAMEBUFFER_CONSOLE -m SND_DESIGNWARE_I2S -m SND_SIMPLE_CARD
make -C $T O=$O olddefconfig >/dev/null
cp $O/.config $OUT/config-jh7110hdmi
for o in DRM_VERISILICON_DC DRM_INNO_HDMI DRM_STARFIVE_JH7110_INNO_HDMI PHY_STARFIVE_JH7110_INNO_HDMI; do
  grep -q "^CONFIG_$o=m" $O/.config || { echo "MISSING $o"; exit 3; }
done
make -C $T O=$O -j"$(nproc)" KBUILD_IMAGE=arch/riscv/boot/Image Image dtbs modules
REL=$(make -C $T O=$O -s kernelrelease)
make -C $T O=$O modules_install INSTALL_MOD_PATH=$OUT/modroot INSTALL_MOD_STRIP=1 >/dev/null
rm -f $OUT/modroot/lib/modules/$REL/build $OUT/modroot/lib/modules/$REL/source
cp $O/arch/riscv/boot/Image $OUT/vmlinuz-$REL
mkdir -p $OUT/dtb && cp $O/arch/riscv/boot/dts/starfive/jh7110-*.dtb $OUT/dtb/
tar -C $OUT/modroot -czf $OUT/modules-$REL.tar.gz lib
echo "$REL" > $OUT/kernelrelease
echo BUILD_DONE "$REL"
