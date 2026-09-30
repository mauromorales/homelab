# Hegemonikon

Builds the OS images for my personal homelab.

![hegemonikon-logo](./assets/hegemonikon-logo.png)

This repo holds the `Dockerfile`s, Kairos `cloud-config.yaml` files, and the
GitHub Actions pipeline that turn them into bootable Kairos images. Hardware
inventory, network layout, and the rest of the lab's architecture live in a
private repo, not here.

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
| [ProtOS](./nodes/protos/README.md) | K8s Homelab | ⏸️ |
| [Kairos](./nodes/kairos/README.md) | Kairos with debugging tools | ⏸️ |
| [NoOS](./nodes/noos/README.md) | Local-AI | ⏸️ |
| [Kairos riscv64](./nodes/kairos-riscv64/README.md) | Community riscv64 hardware test image | 🔄 |

- ✅ Ready to be used on demand
- 🏃‍♂️ Running 
- 🚀 Ready to be deployed
- 🔄 In development
- ⏸️ On hold — excluded from the release pipeline pending testing

Only **ThurorOS** is currently built by the [release pipeline](./.github/workflows/release.yaml); the other nodes are on hold until they have been tested. **Kairos riscv64** isn't part of that pipeline at all — Kairos Factory doesn't support riscv64 yet, so it has its own [build workflow](./.github/workflows/build-kairos-riscv64.yaml) that publishes to [GitHub Releases](../../releases) instead of `quay.io`. See [its README](./nodes/kairos-riscv64/README.md).

More on this topic: [What Are Special-Purpose Operating Systems in the Cloud-Native World?](https://www.mauromorales.com/2025/04/16/what-are-special-purpose-operating-systems-in-the-cloud-native-world/)
