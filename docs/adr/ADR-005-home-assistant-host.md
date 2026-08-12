# ADR-005: Home Assistant host

Date: 2026-08-13
Status: Accepted
Deciders: Mauro
Related: [ADR-004](ADR-004-home-automation-platform.md) (why Home Assistant), [ADR-003](ADR-003-rf-gateway.md) (433 MHz RF gateway), [ADR-002](ADR-002-gpu-node-acquisition.md) (GPU node)

## Context

[ADR-004](ADR-004-home-automation-platform.md) chose Home Assistant. This ADR chooses
the machine and the installation method.

### Constraint relaxed by ADR-003

Choosing WiFi and MQTT over USB removed the usual hard coupling. With a USB dongle,
Home Assistant must run on the machine physically holding it, with passthrough
complications if virtualized. Network-attached means **placement of the platform and
placement of the RF gateway are fully decoupled**. Home Assistant can live anywhere on
the LAN while the RFX sits wherever the RF propagation is best.

That freedom is what makes this a real decision rather than a foregone one.

### Available hosts

| Machine | Status |
|---|---|
| Beelink SER5 | Occupied, agentic flow / netboot / AuroraBoot |
| HP ProDesk 600 G4 | Earmarked as Kubernetes control plane |
| New machine (incoming) | Earmarked as Kubernetes worker |
| **Raspberry Pi 4 (second unit)** | **Spare** |
| **Raspberry Pi 5** | **Spare** |

The first Raspberry Pi 4 is not available: it runs the doorbell relay as `thuroros`.

### Competing motivation

There is a genuine desire to run this on Kubernetes to build hands-on cluster
experience. This ADR treats that as a real goal to be satisfied, not dismissed, but
argues it should be satisfied by a different workload.

## Decision

**Run Home Assistant OS on the spare Raspberry Pi 4, booting from USB SSD.**

- **Distribution:** HA OS, not HA Container
- **Storage:** USB SSD boot, explicitly *not* SD card
- **Broker:** Mosquitto via the HA add-on store, on the same box
- **Pi 5:** left free for other purposes

**Kubernetes learning is redirected to workloads that suit the platform**, namely
Immich and, once cameras arrive, Frigate. Frigate is the better of the two: it is
continuous, GPU-backed, and wants to sit near the card acquired in
[ADR-002](ADR-002-gpu-node-acquisition.md). Home Assistant subscribes to its events
over MQTT, so camera compute lives on the cluster while household control does not.

## Alternatives considered

### Kubernetes deployment on the ProDesk cluster, rejected

**Workload mismatch.** Home Assistant is a stateful singleton. It does not scale
horizontally, does not tolerate rescheduling well, and its recorder database is SQLite
performing constant small writes. With local-path provisioning the volume pins the pod
to a single node, so the scheduling benefit is lost while the complexity is retained.
The lesson learned would be *how to host a pet on a platform designed for cattle*:
real, but narrow.

**Loss of HA OS.** Kubernetes implies HA Container: no Supervisor, no add-on store.
Mosquitto becomes a hand-wired deployment with manual credential management, and
backup and restore become self-managed concerns.

**Availability coupling.** The control plane is a single node and it will be
*deliberately perturbed*, since that is the entire point of a learning cluster. Every
failed experiment would take the blinds and lights down with it. Household
infrastructure and a lab one intentionally breaks are opposing requirements.

**Networking friction.** Not currently blocking, because ADR-003 chose WiFi and MQTT,
so the RFX is merely a TCP endpoint. Integrations depending on mDNS and multicast are
more awkward under Kubernetes, though the prior art below shows this objection is the
weakest of the four.

### Prior art reviewed

Seven community implementations were examined, because the question deserves evidence
rather than assertion:

- [pajikos/home-assistant-helm-chart](https://github.com/pajikos/home-assistant-helm-chart), the most popular and most actively maintained
- [mysticrenji/home-assistant-on-kubernetes](https://github.com/mysticrenji/home-assistant-on-kubernetes)
- [swrm.io, Home Assistant on Kubernetes](https://swrm.io/posts/homeassistant_kubernetes/)
- [jaygould.co.uk, Setting up Home Assistant on k3s](https://jaygould.co.uk/2024-01-01-setting-up-home-assistant-kubernetes-k3s/)
- [blog.quadmeup.com, How to run Home Assistant in Kubernetes](https://blog.quadmeup.com/2025/04/07/how-to-run-home-assistant-in-kubernetes/)
- [tpmullan.com, Running Home Assistant on Kubernetes instead of the usual Docker path](https://tpmullan.com/2026/05/12/running-home-assistant-on-kubernetes-instead-of-the-usual-docker-path/), the most complete treatment and the strongest case for the cluster
- [przemekhys/homeassistant-operator](https://github.com/przemekhys/homeassistant-operator), the only one offering a capability the Pi route cannot

**The tooling is better than a first pass suggests.** The pajikos chart defaults to a
StatefulSet, the correct primitive for a stateful singleton, supports
`podReplacementPolicy` for faster replacement on node failure, defaults
`hostNetwork: false`, and documents USB passthrough as a `CharDevice`. swrm.io goes
further on discovery, using Multus CNI to attach the pod directly to the VLAN carrying
the multicast traffic, which is cleaner than the `hostNetwork: true` that the
mysticrenji chart defaults to. The networking objection largely dissolves.

**The add-on problem has a coherent answer, and it is still a cost.** tpmullan puts
Home Assistant, MQTT, ESPHome, the Matter server and device bridges in a single
multi-container pod, so they share one network namespace and keep reaching each other
over localhost exactly as under Compose. That is a real design. Its own author states
the cost plainly: Home Assistant is no longer where those services are installed or
updated, so every add-on becomes an image, environment variables, a config file, a
volume and an update policy that you own. In their words it "is not a better default
for someone who wants Home Assistant to be the platform".

Worth separating, because it is easy to conflate: **HACS is unaffected.** It installs
custom integrations into `/config` rather than managing containers, so it works
normally. The loss is add-ons, not the community store.

**Still a singleton, everywhere.** All seven are single-replica, and not one moves the
recorder off SQLite onto Postgres. Storage is ReadWriteOnce except quadmeup, who uses
CephFS ReadWriteMany, removing volume pinning without removing the singleton. Where
real hardware is involved the pod gets pinned anyway. The upstream position is
unchanged, as quadmeup puts it: "officially, Home Assistant does not support running
on Kubernetes".

**The one genuine capability gain.** The homeassistant-operator exposes Home
Assistant's own configuration as custom resources: automations, scenes, scripts,
areas, floors, integrations and secrets, reconciled from Git. That is an argument for
the cluster rather than about surviving on it, and the only one in seven sources. It
waits anyway: seven stars, no forks, one maintainer and parts of the API at
`v1alpha1` is a poor dependency for household lighting, and it has no answer for
add-ons either. Most of its benefit is available by putting `/config` in Git on the
Pi, since automations, scenes and scripts are already YAML there. What the operator
adds beyond that is reconciliation and drift correction, worth having eventually and
not worth household downtime now.

**The clearest decision rule comes from the most pro-Kubernetes source.** tpmullan
opens with "I would not recommend Kubernetes as the default Home Assistant install"
and lists six conditions that should all hold first:

1. You already run Kubernetes for other home lab services
2. You already have GitOps or a similar deployment workflow
3. You are comfortable owning the add-on replacements yourself
4. You understand your local discovery and callback requirements
5. You can provide a real LAN identity when integrations need it
6. You have a rollback path that does not depend on wishful thinking

This lab currently fails 1, 2 and 6. The cluster does not exist yet, there is no
GitOps workflow, and the rollback path is the thing being learned.

### Beelink SER5, rejected

Ample headroom, but already carrying the agentic flow and netboot duties. Home
Assistant needs to be boring and always-on; co-locating it with a machine under active
tinkering means every reboot takes the house with it.

### HP ProDesk 600 G4 as bare metal, rejected

Already allocated to the Kubernetes control plane role.

### Raspberry Pi 5, viable but not chosen

Would work fine. The Pi 4 is chosen because Home Assistant is comfortably within its
capability for a house this size and this device count, and it keeps the more capable
Pi 5 available.

## Consequences

### Positive

- **One-click Mosquitto.** The add-on store auto-configures the broker against Home
  Assistant's own accounts, removing a hand-wiring step from the RFX setup
- **Boring by design.** A dedicated, rarely-touched appliance host matches the role.
  The device list in ADR-004 is small and slow-moving, which is an argument for the
  appliance model rather than against it: the advantages of a cluster deployment,
  GitOps and observability, pay off under frequent change, and there will not be any
- Supervisor benefits retained: managed backups, add-ons, guided updates
- Kubernetes goal preserved and pointed at Immich and Frigate
- Pi 5 stays uncommitted

### Negative and accepted trade-offs

- Another always-on device rather than consolidating onto existing hardware
- No redundancy. A single Pi is a single point of failure for household control.
  Mitigated because the physical controls keep working independently, and because
  ADR-004 keeps fire alarm interlink out of the platform entirely
- Kubernetes experience deferred to a later workload rather than gained immediately

### Reversibility

**This is not a one-way door.** Migrating onto Kubernetes later is a backup and
restore operation. **Revisit when tpmullan's six conditions hold**, in particular a
cluster that exists, is multi-node, and is no longer the thing being deliberately
broken. At that point this is a migration with a known shape rather than a
from-scratch build: the pajikos chart for the workload, a multi-container pod for the
add-on replacements, Multus or a bridge CNI for LAN identity, `Recreate` with image
pre-pull for rollouts, and a Postgres recorder to retire the SQLite constraint.

## Implementation notes

- **Boot from USB SSD, not SD card.** The recorder performs continuous small writes
  and will destroy an SD card. This is the single most common cause of Pi-hosted
  Home Assistant failure
- Configure Mosquitto via the add-on store *before* configuring MQTT on the RFX, so
  the broker exists when ADR-003's validation plan reaches the reception checks
- Enable scheduled backups early and verify at least one restore, given this is a
  single-node deployment
- Pin the Pi's IP via DHCP reservation, as with the RFX
- Consider putting `/config` in Git. It gives version control, review and rollback of
  automations, scenes and scripts, which is most of what the Kubernetes operator route
  offers, with nothing between a broken automation and the lights
