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

`hegemon` skips both. It boots the **upstream Kairos release image** directly:

```
kairos-hadron-v0.5.1-standard-amd64-generic-v4.3.0-k0sv1.36.4+k0s.0.iso
```

(check [kairos-io/kairos releases](https://github.com/kairos-io/kairos/releases)
for a newer `v0.5.1`/k0s pairing before installing — this repo does not track
that version for you the way it tracks `thuroros`'s image)

This node runs a **Hadron**-based image, not the Ubuntu-based flavor
`protos`/`thuroros` use. Hadron ships no package manager — everything has to
be baked into the image or run as a container. `hegemon` doesn't need
anything baked in beyond what upstream's own `standard` + k0s build already
provides, so there is nothing here that a custom Factory build would add.
This `cloud-config.yaml` is all the customization the node needs: hostname,
an SSH user, and `k0s: enabled: true`.

**Consequence:** upgrades come from a newer upstream release, not from a tag
pushed to this repo. There is no `nodes/hegemon/Dockerfile`, no per-node CI
workflow, and nothing to release here.

## Cluster role

`k0s: enabled: true` with no `--enable-worker` arg. Controller only —
`hegemon` does not schedule workloads; `helios` is the worker for that.

## Installing it

Built and served via the AuroraBoot fleet server, which netboots the ProDesk
over PXE:

1. In the fleet dashboard, build an artifact from the release above with this
   directory's `cloud-config.yaml` attached.
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
