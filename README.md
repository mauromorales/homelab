# Hegemonikon

Builds the OS images for my personal homelab.

This repo holds the `Dockerfile`s, Kairos `cloud-config.yaml` files, and the
GitHub Actions pipeline that turn them into bootable Kairos images.

## Host OS

**Philosophy:** I'm building a **Special-Purpose OS (SPOS)** for each node. No generic images that need post-install tweaking. Each OS:

- **Has a specific role** baked in from the start using cloud-init–like configuration.
- **Is immutable by design**—updates come from rebuilt images, not live config changes.
- **Self-configures at first boot** with everything it needs.

I use [Kairos](https://kairos.io) to accomplish all these features.

**Build process:**  

It starts with a shared Ubuntu 24.04 base image, with a few extra packages added on top of the upstream version and Kairos' own version.

Kairos Factory produces two artifacts per build:  

- **Container images** (for upgrades)  
- **Bootable media** (ISO or RAW, depending on the node)

| Name | Role | Status |
| ---- | ---- | ------ |
| [ThurorOS](./nodes/thuroros/README.md) | Doorbell | ✅ 🏃 |
| [Kairos riscv64](./nodes/kairos-riscv64/README.md) | Community riscv64 hardware test image | 🔄 |
| [Kairos rpi5](./nodes/kairos-rpi5/README.md) | Raspberry Pi 5 hardware bring-up | 🔄 |

- ✅ Ready to be used on demand
- 🏃‍♂️ Running 
- 🔄 In development

Only **ThurorOS** is built by the [release pipeline](./.github/workflows/release.yaml). **Kairos riscv64** isn't part of that pipeline at all — Kairos Factory doesn't support riscv64 yet, so it has its own [build workflow](./.github/workflows/build-kairos-riscv64.yaml) that publishes to [GitHub Releases](../../releases) instead of `quay.io`. See [its README](./nodes/kairos-riscv64/README.md). **Kairos rpi5** has its own [build workflow](./.github/workflows/build-kairos-rpi5.yaml) that only checks the OS layer builds. See [its README](./nodes/kairos-rpi5/README.md).

More on this topic: [What Are Special-Purpose Operating Systems in the Cloud-Native World?](https://www.mauromorales.com/2025/04/16/what-are-special-purpose-operating-systems-in-the-cloud-native-world/)
