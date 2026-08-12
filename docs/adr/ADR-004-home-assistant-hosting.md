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
But future integrations depending on mDNS and multicast (ESPHome, HomeKit bridge,
Chromecast) become awkward under Kubernetes, typically resolved with
`hostNetwork: true`, at which point the pod is a VM in a trenchcoat.

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
