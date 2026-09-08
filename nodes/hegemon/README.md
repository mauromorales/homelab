# Hegemon

The k0s cluster's control plane. An HP ProDesk 600 G4 Mini (`hegemon`): the
ProDesk runs the control plane, `helios` (the Z4 G4) joins as its worker.
Hosted control planes (k0smotron) stay deferred for now, so this is a plain
single control plane, not a hosted one.

The name follows the lab's own: `hegemon` (ἡγεμών, "leader, the one who
commands") is the direct root of *Hegemonikon*, this repo's own name.

## Why this node breaks the pattern

Every other node here — `thuroros`, `protos` — is a **base Dockerfile plus a
Kairos Factory build**, published by this repo's own CI to `quay.io`. See the
top-level `CLAUDE.md`/`AGENTS.md` for that shape.

`hegemon` skips both. There is no `nodes/hegemon/Dockerfile`, no per-node CI
workflow, and no `quay.io/mauromorales/hegemon` image — this repo owns no
build pipeline for this node at all.

That does **not** mean no build happens. The AuroraBoot fleet server's
"Artifact Builder" always runs a real build (its own Kairos-Factory-style
pipeline) before it can serve or netboot anything, even for its ready-made
`Hadron` template. There is no "just point at a published `.iso` and skip
building" option. What this node skips is a build **this repo owns and
maintains** — the fleet server's own generic `Hadron` template (pick
architecture, model, k0s version) already covers everything `hegemon` needs,
so there's nothing homelab-specific to add.

This node runs a **Hadron**-based image, not the Ubuntu-based flavor
`protos`/`thuroros` use. Hadron ships no package manager — everything has to
be baked into the image or run as a container. `hegemon` doesn't need
anything baked in beyond what the fleet server's plain `Hadron` + k0s
template already produces, so a custom Factory build in this repo would add
a second image pipeline for no gain. This `cloud-config.yaml` is all the
customization the node needs: hostname, an SSH user, and `k0s: enabled: true`.

**Consequence:** the exact `kairos-init` version baked into the image is
whatever's pinned in the AuroraBoot instance building it, not anything this
repo tracks or controls (unlike `thuroros`'s image, which this repo versions
by tag). Check what's actually deployed before assuming a specific version.

## Cluster role

`k0s: enabled: true` with no `--enable-worker` arg. Controller only —
`hegemon` does not schedule workloads; `helios` is the worker for that.

## Installing it

Built and served via the AuroraBoot fleet server, which netboots the ProDesk
over PXE:

1. In the fleet dashboard's Artifact Builder, pick the `Hadron` template
   (amd64, `generic`, k0s), and attach this directory's `cloud-config.yaml`.
2. Power on the ProDesk with network boot enabled in the BIOS boot order.
3. AuroraBoot answers the PXE request over ProxyDHCP — it does not run its
   own DHCP server, so this works alongside the household router without a
   separate isolated network segment.

## Still open

- **Storage** for the cluster is not yet decided.
- **Day-2 tooling** — AuroraBoot fleet vs. `kairos-operator`, once this node
  is a cluster member with something to reconcile.
- **Ingress and secrets** for whatever runs on the cluster.

Nothing above is baked into `cloud-config.yaml` yet, on purpose: none of it is
decided.
