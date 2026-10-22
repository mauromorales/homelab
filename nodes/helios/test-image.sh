#!/usr/bin/env bash
# Check a built Kairos Hadron NVIDIA image without booting it.
# Usage: test-image.sh <image> [module-version [userspace-version]]
# The userspace version defaults to the module version. A deliberate mismatch build passes both.
# Needs docker, zstd, modinfo and lsinitrd on the host.
set -euo pipefail

image="${1:?usage: test-image.sh <image> [module-version [userspace-version]]}"
want="${2:-595.91.07}"
want_user="${3:-$want}"

work="$(mktemp -d "${TMPDIR:-/var/tmp}/test-image.XXXXXX")"
cid=""
cleanup() {
  [ -n "$cid" ] && docker rm -f "$cid" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

fail=0
pass() { echo "PASS  $1"; }
miss() { echo "FAIL  $1"; fail=1; }

cid="$(docker create "$image" /bin/true)"
docker export "$cid" | tar -x -C "$work" \
  --wildcards 'etc/cos/bootargs.cfg' 'boot/initrd*' 'usr/lib/modules/*' \
  'usr/libc/lib/libnvidia-ml.so.*' 'usr/libc/lib/libcuda.so.*' 'usr/bin/nvidia-smi' \
  'usr/lib/firmware/nvidia/*' 'usr/share/licenses/nvidia-driver/*' 2>/dev/null || true

# 1. The serial console is ttyS4, and ttyS0 is not the default.
cfg="$work/etc/cos/bootargs.cfg"
if [ -f "$cfg" ] && grep -q 'baseExtraConsole="console=ttyS4,115200"' "$cfg"; then
  pass "bootargs.cfg sets console=ttyS4,115200"
else
  miss "bootargs.cfg does not set console=ttyS4,115200"
fi
if [ -f "$cfg" ] && grep -q 'baseExtraConsole="console=ttyS0"' "$cfg"; then
  miss "bootargs.cfg still has the console=ttyS0 default"
else
  pass "bootargs.cfg has no console=ttyS0 default"
fi

# 2a. The module sits under the one kernel the image boots, matches its vermagic, and is indexed.
kdirs=("$work"/usr/lib/modules/*/)
if [ "${#kdirs[@]}" -ne 1 ] || [ ! -d "${kdirs[0]}" ]; then
  miss "want exactly one kernel directory in /usr/lib/modules, found ${#kdirs[@]}"
else
  kdir="${kdirs[0]%/}"
  kname="${kdir##*/}"
  kmod="$(find "$kdir" -name 'nvidia.ko*' -print -quit 2>/dev/null || true)"
  if [ -z "$kmod" ]; then
    miss "nvidia.ko is not under /usr/lib/modules/$kname"
  else
    pass "nvidia.ko is under /usr/lib/modules/$kname"
    case "$kmod" in
      *.zst) zstd -dcq "$kmod" > "$work/vermagic.ko" ;;
      *)     cp "$kmod" "$work/vermagic.ko" ;;
    esac
    vm="$(modinfo -F vermagic "$work/vermagic.ko" 2>/dev/null || true)"
    case "$vm" in
      "$kname"*) pass "vermagic matches $kname" ;;
      *) miss "vermagic '${vm:-unknown}' does not match $kname" ;;
    esac
  fi
  if grep -q 'nvidia\.ko' "$kdir/modules.dep" 2>/dev/null; then
    pass "modules.dep lists nvidia.ko"
  else
    miss "modules.dep does not list nvidia.ko"
  fi
fi

# 2. The kernel module version is the expected one.
ko="$(find "$work/usr/lib/modules" -name 'nvidia.ko*' -print -quit 2>/dev/null || true)"
if [ -z "$ko" ]; then
  miss "no nvidia.ko in /usr/lib/modules"
else
  case "$ko" in
    *.zst) zstd -dcq "$ko" > "$work/nvidia.ko" ;;
    *)     cp "$ko" "$work/nvidia.ko" ;;
  esac
  got="$(modinfo -F version "$work/nvidia.ko" 2>/dev/null || true)"
  if [ "$got" = "$want" ]; then
    pass "nvidia.ko version is $got"
  else
    miss "nvidia.ko version is '${got:-unknown}', want $want"
  fi
fi

# 3. The userspace library version is the expected one.
lib="$(find "$work/usr/libc/lib" -name 'libnvidia-ml.so.*.*' -print -quit 2>/dev/null || true)"
if [ -z "$lib" ]; then
  miss "no libnvidia-ml.so.<version> in /usr/libc/lib"
elif [ "${lib##*.so.}" = "$want_user" ]; then
  pass "userspace library version is ${lib##*.so.}"
else
  miss "userspace library version is ${lib##*.so.}, want $want_user"
fi

# 3b. The other userspace pieces CUDA needs are there, and so is the GSP firmware (Turing needs it).
for f in "usr/libc/lib/libcuda.so.$want_user" "usr/bin/nvidia-smi" "usr/lib/firmware/nvidia/$want_user/gsp_tu10x.bin"; do
  if [ -e "$work/$f" ]; then pass "$f is in the image"; else miss "$f is missing"; fi
done

# 4. NVIDIA's licence is in the image.
if [ -s "$work/usr/share/licenses/nvidia-driver/LICENSE.txt" ]; then
  pass "NVIDIA licence is in the image"
else
  miss "NVIDIA licence is missing"
fi

# 5. The initrd can fetch a live root over HTTP (needed for netboot).
initrd="$(find "$work/boot" -maxdepth 1 -name 'initrd*' -print -quit 2>/dev/null || true)"
if [ -z "$initrd" ]; then
  miss "no initrd in /boot"
elif ! command -v lsinitrd >/dev/null; then
  miss "lsinitrd is not installed, cannot check the initrd"
else
  modules="$(lsinitrd -f usr/lib/dracut/modules.txt "$initrd" 2>/dev/null || true)"
  if printf '%s\n' "$modules" | grep -qx livenet; then
    pass "initrd has the livenet dracut module"
  else
    miss "initrd has no livenet dracut module"
  fi
fi

exit "$fail"
