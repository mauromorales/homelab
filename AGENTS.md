# AGENTS.md

This file provides guidance to coding agents working with code in this
repository. It is the canonical copy.

`CLAUDE.md` in the repository root is a **symlink to this file**, not a second
copy. That is deliberate and load-bearing: Claude Code discovers `CLAUDE.md`,
so removing the symlink or replacing it with a real file would either lose this
guidance or leave two copies to drift apart. Keep the content here and the
symlink there.

## What this repo is

`kairos-images` — community-built Kairos images, defined as code. There is
no application to run locally: the repository *is* the declarative source for a
set of immutable OS images, each built with [Kairos](https://kairos.io) from an
Ubuntu base plus a first-boot `cloud-config.yaml`. Images are produced in CI
and published to `quay.io/mauromorales/<image>`. To change how an image
behaves, edit its `Dockerfile`/`cloud-config.yaml` and let the pipeline
rebuild.

## Image layout

Each image lives in `nodes/<name>/` and follows the same shape:

- `Dockerfile` — the **base image**: an Ubuntu image with a few extra apt
  packages layered on. This is *not* the final OS; it is the input to Kairos.
- `cloud-config.yaml` — Kairos first-boot config: the heart of the image. Sets
  `hostname`, users and their SSH keys, and `stages.initramfs` steps that write
  scripts and systemd units, then enable them.
- `README.md` — what the image is for and how it works (thuroros's is the
  detailed example).

| Image | Role | Arch / model | Released? |
|---|---|---|---|
| `thuroros` (to be renamed Kairos Ubuntu 22.04 rpi4) | Doorbell relay (Raspberry Pi) | arm64 / `rpi4` | **yes — the only released image** |
| `kairos-riscv64` | Community riscv64 hardware test image | riscv64 / `generic` | experimental — see below |
| `kairos-rpi5` | Raspberry Pi 5 hardware bring-up | arm64 / `generic` | experimental — CI validates the OS layer only, no boot artifact yet, see below |

`kairos-riscv64` doesn't fit the release pattern: `kairos-io/kairos-factory-action`
hard-rejects any arch other than amd64/arm64, so it can't go through
`release.yaml`'s factory-based pipeline at all. It has its own
`build-kairos-riscv64.yaml`, which validates on push/PR like every other image
but only publishes a GitHub Release (not a `quay.io` image) when manually
triggered with a version input — see `nodes/kairos-riscv64/README.md`.

`kairos-rpi5` is further along the same road: `kairos-init` has no `rpi5`
model at all yet (only `rpi3`/`rpi4`), so this isn't just outside the
factory pipeline, it has no release path either. `build-kairos-rpi5.yaml`
validates that the `--model generic` OS layer builds — nothing more.
Turning that into a bootable SD image needs the Pi 5 boot chain (u-boot,
firmware) worked out by hand first; see `nodes/kairos-rpi5/README.md`.

## Build pipeline (all builds happen in GitHub Actions)

`thuroros` is a **two-stage build**:

1. **Base image** — a plain `docker build` of `nodes/<name>/Dockerfile`, pushed
   as `quay.io/mauromorales/<name>:base-<sha>`. This step you *can* reproduce
   locally: `docker build -f nodes/<name>/Dockerfile nodes/<name>`.
2. **Kairos Factory** — the reusable workflow
   `kairos-io/kairos-factory-action/.github/workflows/reusable-factory.yaml`
   consumes that base image plus the image's `cloud-config.yaml` and emits the
   Kairos artifacts (container image for upgrades, and ISO/RAW bootable media).
   This stage is CI-only; there is no simple local equivalent.

`thuroros` additionally passes `dockerfile_path: nodes/thuroros/kairos.Dockerfile`
to the factory — a custom layer that runs `kairos-init` explicitly.

### Workflows

- `.github/workflows/build-<name>.yaml` — **per-image CI** for testing. Triggers
  on `push`/`pull_request` that touch that image's files. Builds the base image
  and runs the factory with `quay.expires-after=2d` so test artifacts are
  ephemeral. Use these to validate a change to a Dockerfile or cloud-config.
  `build-kairos-riscv64.yaml` and `build-kairos-rpi5.yaml` are the two special
  cases described above.
- `.github/workflows/release.yaml` — **releases**, triggered by pushing a
  `thuroros-v*` tag. Builds and publishes a durable image. A bare `v*` tag
  triggers nothing.

To cut a release: push a `thuroros-v<semver>` git tag, e.g.
`thuroros-v1.1.2`. `release.yaml` does create a GitHub Release (verified
2026-08-25 against `thuroros-v1.1.2`), but with no file assets attached --
the image itself is the artifact, published to `quay.io`. To test an image
change: open a PR touching `nodes/<name>/` and let `build-<name>.yaml` run.

## Conventions worth knowing

- **systemd units are created from `cloud-config.yaml`, not shipped as files.**
  The pattern: write the unit under `stages.initramfs` via `files:`, then a
  final `commands:` step `ln -sf`s it into
  `/etc/systemd/system/multi-user.target.wants/` to enable it (the root fs is
  immutable at boot, so this manual enable replaces `systemctl enable`).
- **Persistent state lives on Kairos persistent paths.** e.g. thuroros keeps
  its runtime config at `/usr/local/doorbell/config.json` so it survives reboots
  and image upgrades. Root is otherwise read-only — services that need a
  writable dir use systemd `RuntimeDirectory=`.
