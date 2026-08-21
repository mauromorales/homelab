# KairOS riscv64

An experimental Kairos image for **riscv64**, built so people with real riscv64
hardware can boot it and tell me whether it works. This is not a real node in
the [hardware table](../../README.md#hardware) — there's no riscv64 machine in
the lab. It exists purely to produce a shareable test image while
[kairos-io/kairos#4083](https://github.com/kairos-io/kairos/issues/4083)
(full riscv64 support) is still in progress upstream.

## Why this node looks different from the others

Every other node in this repo goes through
[`kairos-io/kairos-factory-action`](https://github.com/kairos-io/kairos-factory-action),
the reusable workflow that turns a base image into the final Kairos artifacts.
That action hard-rejects any architecture other than `amd64`/`arm64`
(`reusable-factory.yaml`: *"arch must be 'amd64' or 'arm64'"*), so it can't
build this node. `build-kairos-riscv64.yaml` runs `kairos-init` and
[AuroraBoot](https://github.com/kairos-io/AuroraBoot) directly instead of
going through the factory.

It also builds AuroraBoot from source rather than pulling
`quay.io/kairos/auroraboot:latest`. The published container is stale for
riscv64: the fix that makes ISO building work at all
([kairos-sdk#762](https://github.com/kairos-io/kairos-sdk/pull/762)) has been
in AuroraBoot's own `go.mod` for months, but no container tag has been
rebuilt since the fix's kairos-sdk release shipped. Building from `main`
picks it up immediately; a fresh AuroraBoot release will make this step
unnecessary.

## k3s

[k3s](https://k3s.io) has no official riscv64 release yet — see
[k3s-io/k3s#7151](https://github.com/k3s-io/k3s/issues/7151). This image
bundles a binary from
[CARV-ICS-FORTH's actively-maintained riscv64 fork](https://github.com/CARV-ICS-FORTH/k3s)
instead, fetched directly in [`kairos.Dockerfile`](./kairos.Dockerfile) rather
than through `kairos-init`'s `--provider` mechanism — that flag installs a
provider `kairos-init` already knows how to fetch, and riscv64 k3s isn't one
of them yet. Swap it for the official k3s release the moment one exists.

k3s starts automatically on boot as a systemd service
([`cloud-config.yaml`](./cloud-config.yaml)), with one flag that matters:
`--snapshotter=native`. Kairos's root filesystem is itself an overlay, and
containerd's default `overlayfs` snapshotter can't mount overlay-on-overlay.
This isn't riscv64-specific — it's the same class of problem
[k0s's own riscv64 CI hit and worked around](https://github.com/k0sproject/k0s/pull/7414)
by avoiding overlay mounts. Worth remembering for any future Kairos + k3s/k0s
work, on any architecture.

## Getting the image

This node isn't wired into the shared `v*` release pipeline
([`release.yaml`](../../.github/workflows/release.yaml)) — it's too
experimental to sit alongside the maintained nodes there, and its ISO is too
large for GitHub's free Actions artifact storage. Pushing a
`kairos-riscv64-v*` tag builds it and attaches the ISO to a
[GitHub Release](../../../../releases) instead. Every `push`/`pull_request`
touching this node also runs the build to validate changes, without
publishing anything.

## Testing it

Download the ISO from the release, boot it (`qemu-system-riscv64` or real
riscv64 hardware — UEFI, `virt` machine type if emulated), and it should reach
a login prompt with k3s already running:

```console
$ kubectl get nodes
```

If you get real riscv64 hardware to boot this, or if it doesn't, either way
I'd like to know — open an issue on this repo.
