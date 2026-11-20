# Kairos riscv64 on the StarFive VisionFive 2

Kairos v4.4.0 on a real **StarFive VisionFive 2 v1.3B** (JH7110, 4x SiFive U74,
8 GB). It is the board-specific sibling of [`../kairos-riscv64`](../kairos-riscv64),
which is the generic image for QEMU. This is community work, not an official
Kairos release; tracking is in
[kairos-io/kairos#4635](https://github.com/kairos-io/kairos/issues/4635).

Tested on 2026-11-19, on a board with no fan or heatsink (55-70 C).

## What was run on the board

| Test | Result |
|---|---|
| Live ISO boot, auto-install to a USB stick | pass |
| k3s node `Ready` after install | pass |
| A/B upgrade v0.1.3 to v4.4.0 | pass |
| Rollback through the "Kairos (fallback)" GRUB entry | pass |
| Recovery upgrade (`kairos-agent upgrade --recovery`) | pass |
| State reset (`kairos-agent reset`) | pass, see "State partition" |
| Live ISO plus `kairos-agent manual-install` | pass |
| HDMI console (patched kernel, see below) | pass |

Not tested: TPM, k0s, NVMe on the final build, boot time.

## Image

[`Dockerfile`](./Dockerfile) builds one image: Kairos v4.4.0 with a patched
7.4-rc1 kernel that has the HDMI driver. The kernel is built inside the Docker
build (cross-compiled, not under QEMU). Published to
`quay.io/mauromorales/kairos-riscv64-vf2` by
[`build-kairos-riscv64-vf2.yaml`](../../.github/workflows/build-kairos-riscv64-vf2.yaml).
A manual run of that workflow with `release_version` set also builds a live ISO
and creates a draft GitHub Release, `kairos-riscv64-vf2-v<version>`.
For the stock Ubuntu kernel without HDMI, use the generic image in
[`../kairos-riscv64`](../kairos-riscv64), or build your own with `kairos-init`.

It uses the riscv64 tools from the Kairos v4.4.0 release, and the k3s fork from
[CARV-ICS-FORTH](https://github.com/CARV-ICS-FORTH/k3s), because k3s has no official
riscv64 release ([k3s-io/k3s#7151](https://github.com/k3s-io/k3s/issues/7151)).
Put your own SSH key into [`cloud-config.yaml`](./cloud-config.yaml); there is no
default password.

## Limitations

1. **U-Boot.** The factory U-Boot (2021.10) cannot read USB. Update the SPI flash
   to U-Boot/OpenSBI 2025.10 first. If you have no SD card, send the files over the
   UART (115200 baud) with YMODEM: `loady` to receive, then `sf probe; sf update`.
   After that the board boots a Kairos ISO from USB on its own.
2. **HDMI needs an out-of-tree kernel.** Mainline has no JH7110 display driver
   (DC8200 + INNO HDMI), and the Ubuntu kernel has none. With the stock image the
   monitor shows "no signal". The HDMI image uses mainline v7.4-rc1 plus the unmerged
   display series from
   [Opvolger/linux-drm-jh7110](https://github.com/Opvolger/linux-drm-jh7110)
   (patches 0001-0024). The config is [`kernel/config`](./kernel/config).
   Kairos does not yet load the board's device tree by itself: at the GRUB
   prompt, type the entry from [`kernel/grubmenu`](./kernel/grubmenu). The
   `/oem/grubmenu` hook did not show the entry in the menu on this board.
3. **Install is slow on USB.** `manual-install` took about 63 minutes to a USB
   stick, against 3m25s to NVMe. Wait for `INSTALL_EXIT` and `SYNC_DONE` before
   you power-cycle; cutting the power early leaves 0-byte EFI files.
4. **State partition.** v4.4.0 images are 3.6 GB each. On a 6.3 GB `COS_STATE` the
   passive image did not fit after a reset: `kairos-agent reset` exited 0, the
   passive image was truncated, and GRUB fell back to it and dropped into a dracut
   emergency shell. Use a larger state partition or free space before a reset; check `df` on
   `/run/initramfs/cos-state` after `kairos-agent reset`.
5. **Small issues.** The recovery boot has a different SSH host key. `poweroff`
   did not cut the power to the board. The console on the serial port is 9600
   baud once the kernel boots (`console=ttyS0`), 115200 in U-Boot and GRUB.

## Fleet

[`cloud-config.yaml`](./cloud-config.yaml) trusts the fleet console's certificate and
the internal CA-2, the same way `thuroros` does, so the node can register with the
AuroraBoot fleet server. The registration token is a secret and is not in this repo.
After the install, run the fleet server's command on the node as root:

```
curl -sfL https://<fleet-host>/api/v1/install-agent | \
  AURORABOOT_URL=https://<fleet-host> REGISTRATION_TOKEN=<token> sh
```

The board registered and connected on 2026-11-19. The fleet server cannot build
riscv64 images, so the node joins through this script, not through an artifact.

## Install

1. Update U-Boot (limitation 1).
2. Download the ISO from the [release](../../releases/tag/kairos-riscv64-vf2-v4.4.0), write it to a USB stick and boot the board from it. The live ISO has no display output: use serial or SSH.
3. Run `kairos-agent manual-install --device /dev/sdX cloud-config.yaml`.
4. Wait for it to finish (limitation 3), then remove the ISO stick and reboot. At the GRUB prompt, type the entry from `kernel/grubmenu` to get HDMI (limitation 2).
