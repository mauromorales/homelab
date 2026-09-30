# kairos-images

Builds [Kairos](https://kairos.io) OS images for my personal homelab.

This repo holds the `Dockerfile`s, Kairos `cloud-config.yaml` files, and the
GitHub Actions pipeline that turn them into bootable Kairos images.

## Host OS

**Philosophy:** I'm building a **Special-Purpose OS (SPOS)** for each node. No generic images that need post-install tweaking. Each OS:

- **Has a specific role** baked in from the start using cloud-init–like configuration.
- **Is immutable by design**—updates come from rebuilt images, not live config changes.
- **Self-configures at first boot** with everything it needs.

I use [Kairos](https://kairos.io) to accomplish all these features.

**Build process:**  

Each image starts from an Ubuntu base image, with a few extra packages added on top of the upstream version and Kairos' own version.

Kairos Factory produces two artifacts per build:  

- **Container images** (for upgrades)  
- **Bootable media** (ISO or RAW, depending on the node)

| Image | Role | Status | Latest release |
| ----- | ---- | ------ | -------------- |
| [Kairos Ubuntu 22.04 rpi4](./nodes/thuroros/README.md) | Doorbell | ✅ 🏃 | [thuroros-v1.2.1](../../releases/tag/thuroros-v1.2.1) ([all](../../releases?q=thuroros-v&expanded=true)), image on [quay.io](https://quay.io/repository/mauromorales/thuroros?tab=tags) |
| [Kairos riscv64](./nodes/kairos-riscv64/README.md) | Community riscv64 hardware test image | 🔄 | [kairos-riscv64-v0.1.3](../../releases/tag/kairos-riscv64-v0.1.3) ([all](../../releases?q=kairos-riscv64-v&expanded=true)) |
| [Kairos rpi5](./nodes/kairos-rpi5/README.md) | Raspberry Pi 5 hardware bring-up | 🔄 | none yet |

The first link in each row is the latest release today. Update it when you cut a new one.

- ✅ Ready to be used on demand
- 🏃‍♂️ Running 
- 🔄 In development

Only **Kairos Ubuntu 22.04 rpi4** (the `nodes/thuroros` directory, to be renamed) is built by the [release pipeline](./.github/workflows/release.yaml). **Kairos riscv64** isn't part of that pipeline at all — Kairos Factory doesn't support riscv64 yet, so it has its own [build workflow](./.github/workflows/build-kairos-riscv64.yaml) that publishes to [GitHub Releases](../../releases) instead of `quay.io`. See [its README](./nodes/kairos-riscv64/README.md). **Kairos rpi5** has its own [build workflow](./.github/workflows/build-kairos-rpi5.yaml) that only checks the OS layer builds. See [its README](./nodes/kairos-rpi5/README.md).

More on this topic: [What Are Special-Purpose Operating Systems in the Cloud-Native World?](https://www.mauromorales.com/2025/04/16/what-are-special-purpose-operating-systems-in-the-cloud-native-world/)
