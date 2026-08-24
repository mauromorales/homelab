# Kairos rpi5 (experimental, hardware bring-up)

An attempt at Kairos on a **Raspberry Pi 5**. This is not a supported Kairos
target — `kairos-init` has no `--model rpi5` (only `rpi3`/`rpi4`), and
[kairos-io/kairos#2010](https://github.com/kairos-io/kairos/issues/2010)
says why: *"Model 5 is currently not supported because of how Kairos uses
U-boot to boot the device."* This node exists to find out how close a
manual build can get on real hardware, using the spare Pi 5 already in the
lab, and to report back to that issue with anything learned.

## What this build does, and does not, solve

**Does:** produces the Kairos OS layer — `kairos-init -s install` /
`-s init` with `--model generic`, on an openSUSE Tumbleweed base — the same
approach [`kairos-riscv64`](../kairos-riscv64/) uses for a board with no
`kairos-init` model support.

**Does not:** get that layer onto a Pi 5 in a way it can actually boot.
`generic` deliberately skips board-specific packaging, which on a
supported model (`rpi4`) is exactly what pulls in the right u-boot build
and firmware. Reproducing that for the Pi 5 by hand — the boot partition
layout, which u-boot build, RP1 firmware placement — is genuinely open.
Nobody upstream has solved it either; see the issue.

## Why Tumbleweed, not Ubuntu (matching kairos-riscv64)

The reason to test this at all right now: mainline Linux **6.18.0** added
RP1 (the Pi 5's I/O companion chip) Ethernet and USB driver support —
confirmed by reading `configs/rpi_arm64_defconfig` in u-boot's own repo
(`CONFIG_PCI=y` is set; `CONFIG_NVME_PCI`/`CONFIG_NVME` are not, so PCIe
enumeration works but boot-from-NVMe/USB doesn't yet — that part's still
blocked). Ubuntu 24.04's current HWE kernel is 6.17, one version short.
Ubuntu's next HWE point release (7.0, past 6.18) isn't out at the time of
writing. Tumbleweed is rolling and SUSE's own team wrote the RP1 patches,
so it's the base most likely to already carry that support.

**This is a reasoned bet, not a confirmed fact.** First thing to check
after any boot: `uname -r`, and whether it's actually ≥6.18.

## What's confirmed to work, and what isn't, as of this node's creation

| | Status |
|---|---|
| SD-card boot in u-boot | Works — confirmed on [kairos-io/kairos#2010](https://github.com/kairos-io/kairos/issues/2010) |
| USB/NVMe boot in u-boot | Doesn't — `CONFIG_NVME_PCI` absent from `rpi_arm64_defconfig` |
| RP1 Ethernet, once Linux is running | Should work on kernel ≥6.18 — unverified on Kairos specifically |
| RP1 USB, once Linux is running | Should work on kernel ≥6.18 — unverified on Kairos specifically |
| Getting the built OS layer onto a bootable SD card | **Attempted, unverified.** `build-kairos-rpi5.yaml` now produces an ISO the same way `kairos-riscv64` does — whether the Pi 5 actually boots it is untested |

## How to test

1. `build-kairos-rpi5.yaml` now builds an ISO on `workflow_dispatch`, and
   publishes it as a GitHub Release when a `release_version` is given
   (e.g. `0.1.0-alpha`) — same mechanism `kairos-riscv64` uses.
2. **The ISO itself is an untested guess.** `auroraboot build-iso` produces
   a UEFI-bootable ISO. Whether the Pi 5's firmware/u-boot chain can boot
   that at all — versus needing a traditional RPi raw `.img` flashed to an
   SD card — has not been confirmed on real hardware. Flashing it and
   trying is the test.
3. If/when it boots: check `uname -r` (≥6.18 is the bet this node's base
   image choice depends on — see above), `ip a` for the Ethernet interface
   coming up with a DHCP lease, and `lsusb`/`dmesg` for USB enumeration.
4. Report back on [kairos-io/kairos#2010](https://github.com/kairos-io/kairos/issues/2010)
   either way — a failure with specifics is as useful to that thread as a
   success.
