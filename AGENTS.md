# AGENTS.md

This file provides guidance to coding agents working with code in this
repository. It is the canonical copy.

`CLAUDE.md` in the repository root is a **symlink to this file**, not a second
copy. That is deliberate and load-bearing: Claude Code discovers `CLAUDE.md`,
so removing the symlink or replacing it with a real file would either lose this
guidance or leave two copies to drift apart. Keep the content here and the
symlink there.

## What this repo is

"Hegemonikon" — a personal homelab defined as code. There is no application to
run locally: the repository *is* the declarative source for a set of immutable,
**special-purpose OS images** (one per node), each built with
[Kairos](https://kairos.io) from an Ubuntu base plus a first-boot
`cloud-config.yaml`. Images are produced in CI and published to
`quay.io/mauromorales/<node>`; hosts are updated by rebuilding and re-flashing
images, never by editing a running system. To change how a node behaves, edit
its `Dockerfile`/`cloud-config.yaml` and let the pipeline rebuild — do not
reach for live-host configuration.

## Node layout

Each node lives in `nodes/<name>/` and follows the same shape:

- `Dockerfile` — the **base image**: an Ubuntu image with a few extra apt
  packages layered on. This is *not* the final OS; it is the input to Kairos.
- `cloud-config.yaml` — Kairos first-boot config: the heart of the node. Sets
  `hostname`, users (SSH keys pulled from GitHub via `github:mauromorales`),
  optional `k0s` config, and `stages.initramfs` steps that write scripts,
  systemd units, and k8s manifests, then enable them.
- `README.md` — role and architecture (thuroros's is the detailed example).

| Node | Role | Arch / model | Released? |
|---|---|---|---|
| `thuroros` | Doorbell relay (Raspberry Pi) | arm64 / `rpi4` | **yes — the only active image** |
| `protos` | K8s homelab node | amd64 / `generic` | on hold |
| `kairos` | Kairos + debugging tools | amd64 / `generic` | on hold |
| `noos` | Local-AI node | amd64 / `generic` | on hold |
| `kairos-riscv64` | Community riscv64 hardware test image, not a real node | riscv64 / `generic` | experimental — see below |
| `midnight` | Always-on agent host (Beelink SER5) | amd64 | **not an image yet — see below** |

"On hold" nodes are gated with `false &&` prefixed onto each job's tag-scoped
`if:` in `release.yaml`; re-enable a node by removing the `false && ` prefix
from both its `-base` job and its factory job (see the note at the top of the
file).

`kairos-riscv64` doesn't fit that pattern either: `kairos-io/kairos-factory-action`
hard-rejects any arch other than amd64/arm64, so it can't go through
`release.yaml`'s factory-based pipeline at all. It has its own
`build-kairos-riscv64.yaml`, which validates on push/PR like every other node
but only publishes a GitHub Release (not a `quay.io` image) when manually
triggered with a version input — see `nodes/kairos-riscv64/README.md`.

`midnight` is the exception to the pattern: it is **documentation-only** so far
(`README.md`, no `Dockerfile`/`cloud-config.yaml`). It currently runs interim
Fedora as scaffolding and targets a Kairos Ubuntu 24.04 image later; its README
documents hardware, BIOS/boot-order, Wake-on-LAN, and PXE/fTPM specifics for
that migration. When building its image, follow the standard two-file node shape
above. The decision to base it on Kairos Ubuntu 24.04 is recorded in homelab
ADR-001, which now lives in the private steering repository (see below).

## Architecture decisions are NOT in this repository

`docs/adr/` used to hold them. It is gone. **Every ADR for this lab now lives in
Mauro's private steering repository, under `docs/adr/homelab/`.** The file names
did not change.

The reason: this repository is public, and the ADRs had grown to describe the
network layout, the machines in the rack and the household devices. Moving them
was chosen over making this repository private, which would have started billing
GitHub Actions minutes. Decided 2026-08-14.

**Check there before revisiting a settled choice, and add new ADRs there.** Do
not recreate `docs/adr/` here.

## Runbooks (`docs/*.md`)

Operational procedures live as flat files in `docs/`, and they **did not move**.
A runbook records how to diagnose or perform something on real hardware, and it
belongs beside the thing it operates. An ADR records why a choice was made.
Existing runbooks:

- [`docs/ha-os-rpi4-boot.md`](docs/ha-os-rpi4-boot.md) — diagnosing a Home
  Assistant OS boot on the Raspberry Pi 4, and the display-handover failure
  that makes a healthy board look dead.

## Build pipeline (all builds happen in GitHub Actions)

Every node is a **two-stage build**:

1. **Base image** — a plain `docker build` of `nodes/<node>/Dockerfile`, pushed
   as `quay.io/mauromorales/<node>:base-<sha>`. This step you *can* reproduce
   locally: `docker build -f nodes/<node>/Dockerfile nodes/<node>`.
2. **Kairos Factory** — the reusable workflow
   `kairos-io/kairos-factory-action/.github/workflows/reusable-factory.yaml`
   consumes that base image plus the node's `cloud-config.yaml` and emits the
   Kairos artifacts (container image for upgrades, and ISO/RAW bootable media).
   This stage is CI-only; there is no simple local equivalent.

`thuroros` additionally passes `dockerfile_path: nodes/thuroros/kairos.Dockerfile`
to the factory — a custom layer that runs `kairos-init` explicitly. The other
nodes use the factory's default Kairos layering.

### Workflows

- `.github/workflows/build-<node>.yaml` — **per-node CI** for testing. Triggers
  on `push`/`pull_request` that touch that node's files. Builds the base image
  and runs the factory with `quay.expires-after=2d` so test artifacts are
  ephemeral. Use these to validate a change to a Dockerfile or cloud-config.
- `.github/workflows/release.yaml` — **releases**, triggered by pushing a
  `<node>-v*` tag. Builds and publishes a durable image for that one node.
  Each node versions and releases independently (mission-control#352); a bare
  `v*` tag triggers nothing.

To cut a release for one node: push a `<node>-v<semver>` git tag, e.g.
`thuroros-v1.1.2`. `release.yaml` doesn't create a GitHub Release itself, only
the quay.io image; create the Release separately if you want one, scoped to
the same tag. To test a node change: open a PR touching `nodes/<node>/` and
let `build-<node>.yaml` run.

## Cross-node conventions worth knowing

- **Discovery is mDNS, not static IPs.** Nodes run `avahi-daemon` +
  `libnss-mdns` and address each other as `<hostname>.local` (e.g. thuroros
  POSTs to `polaris.local`, protos syncs to `epictetus.local`). When adding a
  service that talks to another node, prefer a `.local` name.
- **systemd units are created from `cloud-config.yaml`, not shipped as files.**
  The pattern: write the unit under `stages.initramfs` via `files:`, then a
  final `commands:` step `ln -sf`s it into
  `/etc/systemd/system/multi-user.target.wants/` to enable it (the root fs is
  immutable at boot, so this manual enable replaces `systemctl enable`).
- **Persistent state lives on Kairos persistent paths.** e.g. thuroros keeps
  its runtime config at `/usr/local/doorbell/config.json` so it survives reboots
  and image upgrades. Root is otherwise read-only — services that need a
  writable dir use systemd `RuntimeDirectory=`.
- **k0s** is the Kubernetes distro (`protos`/`noos`); nodes regenerate their
  kubeconfig via a `.path` unit watching `/var/lib/k0s/pki/admin.conf`.
