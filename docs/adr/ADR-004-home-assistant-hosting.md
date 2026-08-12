# ADR-004: Home Assistant hosting platform

Date: 2026-08-12
Status: Accepted
Deciders: Mauro
Related: [ADR-003](ADR-003-rf-gateway.md) (433 MHz RF gateway), [ADR-002](ADR-002-gpu-node-acquisition.md) (GPU node)

## Context

ADR-003 selected the RFXCOM RFX-433EMC as the 433 MHz gateway, running MQTT over
WiFi. That decision surfaced a prerequisite: the RFX is a *bridge*, and requires
something on the far side of it. The dependency chain is:

```
Home Assistant  ->  MQTT broker  ->  RFX-433EMC  ->  A-OK screens / DiO lights
```

Home Assistant is therefore now on the critical path and needs a host.

### Constraint relaxed by ADR-003

Choosing WiFi/MQTT over USB removed the usual hard coupling. With a USB dongle, HA
must run on the machine physically holding it, with passthrough complications if
virtualized. Network-attached means **HA placement and RFX placement are fully
decoupled**. HA can live anywhere on the LAN while the RFX sits wherever the RF
propagation is best, mid-level near the stairwell.

### Available hosts

| Machine | Status |
|---|---|
| Beelink SER5 | Occupied, agentic flow / netboot / AuroraBoot |
| HP ProDesk 600 G4 | Earmarked as Kubernetes control plane |
| New machine (incoming) | Earmarked as Kubernetes worker |
| **Raspberry Pi 4** | **Spare** |
| **Raspberry Pi 5** | **Spare** |

### Competing motivation

There is a genuine desire to run this on Kubernetes to build hands-on cluster
experience. This ADR treats that as a real goal to be satisfied, not dismissed, but
argues it should be satisfied by a *different workload*.

## Decision

**Run Home Assistant OS on the spare Raspberry Pi 4, booting from USB SSD.**

- **Distribution:** HA OS, not HA Container
- **Storage:** USB SSD boot, explicitly *not* SD card
- **Broker:** Mosquitto via the HA add-on store, on the same box
- **Pi 5:** left free for other purposes

**Kubernetes learning is redirected to Immich**, which is a materially better fit for
the platform and teaches more.

## Alternatives considered

### Kubernetes deployment on the ProDesk cluster, rejected

**Workload mismatch.** HA is a stateful singleton. It does not scale horizontally,
does not tolerate rescheduling well, and its recorder database is SQLite performing
constant small writes. It needs a PersistentVolume; with local-path provisioning that
pins the pod to a single node, so the scheduling benefit is lost while the complexity
is retained. The lesson learned would be *how to host a pet on a platform designed
for cattle*: real, but narrow.

**Loss of HA OS.** Kubernetes implies HA Container: no Supervisor, no add-on store.
Mosquitto becomes a hand-wired separate deployment with manual credential management,
and backup/restore becomes a self-managed concern. This is precisely the friction
identified during RFX setup planning.

**Availability coupling.** The control plane is a single ProDesk node, and it will be
*deliberately perturbed*, since that is the entire point of a learning cluster. Every
failed experiment would take the blinds and lights down with it. Household
infrastructure and a lab one intentionally breaks are opposing requirements.

**Networking friction (future).** Not currently blocking, because ADR-003 chose
WiFi/MQTT, so the RFX is merely a TCP endpoint and USB passthrough is a non-issue.
Future integrations depending on mDNS and multicast (ESPHome, HomeKit bridge,
Chromecast) are more awkward under Kubernetes, though see the prior art below:
this objection turns out to be the weakest of the four.

### Prior art reviewed

Seven community implementations were examined before settling this, because the
question deserves evidence rather than assertion:

- [pajikos/home-assistant-helm-chart](https://github.com/pajikos/home-assistant-helm-chart), the most popular and most actively maintained
- [mysticrenji/home-assistant-on-kubernetes](https://github.com/mysticrenji/home-assistant-on-kubernetes)
- [swrm.io, Home Assistant on Kubernetes](https://swrm.io/posts/homeassistant_kubernetes/)
- [jaygould.co.uk, Setting up Home Assistant on k3s](https://jaygould.co.uk/2024-01-01-setting-up-home-assistant-kubernetes-k3s/)
- [blog.quadmeup.com, How to run Home Assistant in Kubernetes](https://blog.quadmeup.com/2025/04/07/how-to-run-home-assistant-in-kubernetes/)
- [tpmullan.com, Running Home Assistant on Kubernetes instead of the usual Docker path](https://tpmullan.com/2026/05/12/running-home-assistant-on-kubernetes-instead-of-the-usual-docker-path/), the most complete treatment and the strongest case for the cluster
- [przemekhys/homeassistant-operator](https://github.com/przemekhys/homeassistant-operator), the only one offering a capability the Pi route cannot

**The tooling is better than a first pass suggests, and two objections weaken.**

The pajikos chart defaults to `controller.type: StatefulSet`, which is the correct
primitive for a stateful singleton, and supports `podReplacementPolicy: Always` for
faster replacement on node failure. It defaults to `hostNetwork: false` and documents
USB dongle passthrough as a `CharDevice` hostPath. swrm.io goes further on discovery,
using Multus CNI to attach the pod directly to the VLAN carrying the multicast
traffic, which is cleaner than the `hostNetwork: true` that the mysticrenji chart
defaults to. So the networking objection largely dissolves, and it was already close
to moot here given ADR-003 put the RF gateway on MQTT over WiFi rather than USB.

**The two objections that decide this do not move.**

*No add-on store, though the replacement is a known pattern.* All seven run HA
Container; none retains the Supervisor. The pajikos chart offers exactly one add-on,
code-server. The mysticrenji chart ships its own Mosquitto and Z-Wave JS deployments
because there is nothing to install them from.

tpmullan gives the coherent version of this: put Home Assistant, MQTT, ESPHome, the
Matter server and the device bridges in a *single multi-container pod*, so they share
one network namespace and keep reaching each other over localhost exactly as they did
under Compose. That is a real answer, not a workaround, and it is worth knowing.
The cost is stated plainly by its own author: Home Assistant is no longer the place
those services are installed or updated, so every add-on becomes an image, a set of
environment variables, a config file, a volume and an update policy that you own. In
their words, it "is not a better default for someone who wants Home Assistant to be
the platform".

Worth separating out, because it is easy to conflate: **HACS is unaffected.** It
installs custom integrations into the `/config` directory rather than managing
containers, so it works normally under Kubernetes as long as that directory persists.
The loss is add-ons, not the community store.

This still decides it here, because one-click Mosquitto is the concrete win of the Pi
route and the RFX needs a broker on the far side.

*Still a singleton.* Every implementation is single-replica, and not one moves the
recorder off SQLite onto Postgres. Storage is ReadWriteOnce in all but quadmeup, who
uses CephFS ReadWriteMany, which removes the volume pinning without removing the
singleton. Where real hardware is involved the pod gets pinned anyway: quadmeup pins
by node label for the Zigbee dongle, so the scheduling freedom is spent either way.
A StatefulSet makes hosting a pet correct rather than unnecessary, which is the
narrow lesson this ADR already identified. The upstream position is unchanged, as
quadmeup puts it: "officially, Home Assistant does not support running on
Kubernetes".

Nothing in any of them touches the availability coupling, because that is a property
of a single control plane that gets deliberately perturbed, not something a chart
can fix.

### The one genuine capability gain, and why it still waits

The homeassistant-operator is the only option reviewed that offers something neither
HA OS nor Docker Compose can. It exposes Home Assistant's own configuration as
custom resources: automations, scenes, scripts, areas, floors, labels, integrations
and secrets, reconciled from Git. It also handles device passthrough, backups,
scheduling and network policy, and signs its release artifacts. That is a real
argument for the cluster rather than a workaround for being on it, and it is the
only such argument in seven sources.

Two things hold it back for now.

**Adoption.** Seven stars, no forks, a single maintainer, and parts of the API still
`v1alpha1`. The engineering looks careful, with end-to-end tests, admission webhooks
and an OpenSSF scorecard, but household lighting and blinds are a poor first place to
depend on a project with no user base. If the author stops, the fallback is owning a
Go operator.

**It does not solve the add-on problem either.** There is no Supervisor and no
add-on management. Mosquitto remains a separate deployment to run and configure.

**Most of the benefit is available without any of this.** Home Assistant already
stores automations, scenes and scripts as YAML under `/config`. Putting that
directory in Git on the Pi gives version control, review and rollback of the same
material, without an operator, a cluster or a CRD API in the path between a broken
automation and the lights. The operator's genuine addition over that is reconciliation
and drift correction, which is worth having eventually and is not worth household
downtime now.

Worth watching. If it gains adoption by the time the revisit conditions below hold,
it becomes the reason to move rather than a footnote.

**The clearest decision rule found comes from the most pro-Kubernetes source.**
tpmullan opens with "I would not recommend Kubernetes as the default Home Assistant
install" and lists six conditions that should all hold first:

1. You already run Kubernetes for other home lab services
2. You already have GitOps or a similar deployment workflow
3. You are comfortable owning the add-on replacements yourself
4. You understand your local discovery and callback requirements
5. You can provide a real LAN identity when integrations need it
6. You have a rollback path that does not depend on wishful thinking

This lab currently fails 1, 2 and 6. The cluster does not exist yet, there is no
GitOps workflow, and the rollback path is the thing being learned. Their summary is
the honest one: this "is only worth it if the platform already exists and is already
part of how you operate the lab".

**Revisit when those six hold**, in particular a cluster that exists, is multi-node
and is no longer the thing being deliberately broken. At that point this is a
migration with a known shape rather than a from-scratch build: the pajikos chart for
the workload, a multi-container pod for the add-on replacements, Multus or a bridge
CNI for LAN identity, `Recreate` with image pre-pull for rollouts, and a Postgres
recorder to retire the SQLite constraint.

### Beelink SER5, rejected

Ample headroom, but already carrying the agentic flow and netboot/AuroraBoot duties.
HA needs to be boring and always-on; co-locating it with a machine under active
tinkering means every reboot takes the house with it.

### HP ProDesk 600 G4 (bare metal, no k8s), rejected

Already allocated to the Kubernetes control plane role.

### Raspberry Pi 5, viable but not chosen

Would work fine. The Pi 4 is selected instead because HA is comfortably within a Pi
4's capability for a house this size, and it keeps the more capable Pi 5 available.

## Consequences

### Positive

- **One-click Mosquitto.** The HA OS add-on store auto-configures the broker against
  HA's own user accounts, removing a hand-wiring step from the RFX setup.
- **Boring by design.** A dedicated, rarely-touched appliance host matches HA's role
  as household infrastructure rather than homelab.
- **Supervisor benefits retained:** managed backups, add-ons, guided updates.
- **Kubernetes goal preserved**, redirected to a workload that exercises more of the
  platform.
- **Pi 5 stays uncommitted.**

### Negative and accepted trade-offs

- Adds another physical always-on device rather than consolidating onto existing
  hardware.
- No HA redundancy. A single Pi is a single point of failure for household control.
  Mitigated by the fact that the physical controls (DiO remotes, A-OK wall plate)
  continue to work independently of HA. **Degradation is graceful: the house does not
  become unusable.**
- Kubernetes experience deferred to a later workload rather than gained immediately.

### Reversibility

**This is not a one-way door.** Migrating HA onto Kubernetes later is a
backup-and-restore operation. If the cluster matures into something stable enough to
carry household services, the move remains available at low cost.

## Kubernetes learning: redirected target

**Immich** is the better first-class Kubernetes workload:

| Property | Home Assistant | Immich |
|---|---|---|
| Stateless tier | No | Yes (web/API) |
| External database | No (embedded SQLite) | Yes (Postgres) |
| Horizontal scaling story | None | Genuine (workers) |
| Tolerates rescheduling | Poorly | Well |
| Household-critical | Yes | No |

Immich exercises PersistentVolumes, Secrets, Ingress, service decomposition, and GPU
scheduling, which is substantially more platform surface than HA would, on a workload
whose downtime nobody in the house notices.

## Implementation notes

- **Boot from USB SSD, not SD card.** The HA recorder database performs continuous
  small writes and will destroy an SD card. This is the single most common cause of
  Pi-hosted HA failure.
- Configure Mosquitto via the add-on store *before* configuring MQTT on the RFX, so
  the broker exists when ADR-003's validation plan reaches the reception checks.
- Enable HA's scheduled backups early, and verify at least one restore, given this is
  a single-node deployment.
- Pin the Pi's IP via DHCP reservation, as with the RFX.
