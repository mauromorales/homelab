# ADR-004: Home automation platform

Date: 2026-08-13
Status: Accepted
Deciders: Mauro
Related: [ADR-003](ADR-003-rf-gateway.md) (433 MHz RF gateway), [ADR-005](ADR-005-home-assistant-host.md) (where it runs)

## Context

ADR-003 chose the RFXCOM RFX-433EMC as the 433.92 MHz gateway, speaking MQTT over
WiFi. The RFX is a bridge and needs something on the far side of it:

```
platform  ->  MQTT broker  ->  RFX-433EMC  ->  A-OK screens / DiO lights
```

This ADR picks the platform. [ADR-005](ADR-005-home-assistant-host.md) picks the
machine it runs on. They are separate decisions and were split deliberately, because
the hosting argument is long and would otherwise bury the platform question.

### What the house actually has, and is likely to get

The platform choice should be sized to the real device list rather than to what a
home automation platform *could* do.

**Today**

| Device | Protocol | Reached via |
|---|---|---|
| Motorized screens (Winsol, A-OK AC133-01D wall unit) | 433.92 MHz | RFX-433EMC over MQTT |
| Lighting (DiO 1.0, Chacon) | 433.92 MHz | RFX-433EMC over MQTT |
| Doorbell (`thuroros`) | Custom, own implementation | HTTP, already in the homelab repo |

**Planned or plausible**

| Device | Protocol | Notes |
|---|---|---|
| Netatmo | Vendor cloud API | Wanted. Cloud polling, see the requirement note below |
| One or two security cameras | RTSP / ONVIF | Detection belongs on the cluster, not here |
| A couple of smart plugs | Prefer 433 MHz or MQTT-native | Avoid Zigbee-only models, see below |
| Interlinked fire detectors | Dedicated safety RF band | Interlink must not depend on any hub, see below |

That is a small, slow-moving set. It is deliberately not the "thousand integrations"
case, and the decision below is made on the list as it stands rather than on
hypothetical growth.

### The local-only requirement needs scoping

ADR-003 states the requirement as "local control, no cloud dependency, no vendor
account". Netatmo is a cloud-polling integration requiring an internet connection and
a vendor account, so the roadmap contradicts the requirement as written.

The requirement is therefore scoped, not abandoned: **the RF control path for lights,
screens and life-safety devices stays local and hub-independent.** Cloud integrations
are acceptable for conveniences that may degrade without consequence. A blind that
will not close because an API is down is an annoyance; a light or a smoke alarm that
depends on someone else's uptime is not acceptable.

## Decision

**Use Home Assistant as the home automation platform.**

Two devices on the roadmap decide it, and neither is on the list today:

**Netatmo.** Home Assistant ships a first-class, actively maintained Netatmo
integration used by roughly 4% of installations, covering weather stations, cameras,
video doorbells, thermostats and Legrand plugs and shutters. In the main alternative
considered below, the equivalent is a community Node-RED node with 8 stars, last
touched in 2022, with the rest of that ecosystem between 3 and 13 stars and mostly
abandoned since 2019. The realistic alternative is hand-rolling OAuth2 with token
refresh. One integration also covers three separate roadmap items.

**Cameras.** Whatever platform is chosen, serious camera work means
[Frigate](https://github.com/blakeblackshear/frigate) as a separate service. Home
Assistant integrates with it over MQTT and supplies the part that is genuinely hard
to rebuild: notifications with snapshots to a phone.

## Alternatives considered

### A composed stack: MQTT broker plus Node-RED, rejected

The most credible alternative, and unusually viable here because ADR-003 put the RF
gateway on the network rather than on USB. There is no dongle to pass through, so an
automation engine could drive the screens and lights over MQTT from anywhere.

For lights, blinds, the doorbell and MQTT-native plugs, this genuinely would work.
It fails on the two roadmap items above, and it fails progressively: every future
device becomes an integration to write rather than one to install. Rejected because
the two things wanted next are exactly the two things it does worst.

### openHAB, rejected

Same architecture, smaller ecosystem. Notably its own Helm chart enforces a single
replica and fails the deploy if set higher, to prevent concurrent writes corrupting
the volume. That is a competing platform independently confirming the shape of the
problem rather than solving it.

### Domoticz, Homebridge, ioBroker, rejected

Domoticz is the same stateful singleton with a much smaller ecosystem. Homebridge is
a HomeKit bridge rather than a platform. ioBroker is the only architectural outlier,
with a multi-host mode, but that is for distributing adapters rather than for
availability, and the ecosystem is smaller and largely German-speaking. None offers
anything the device list needs.

## Consequences

### Positive

- Netatmo, cameras and future devices are installations rather than projects
- Frigate integrates over MQTT, so camera compute can live on the cluster while the
  controller stays boring, see [ADR-005](ADR-005-home-assistant-host.md)
- Mobile notifications with snapshots come for free, which is the hardest part of a
  camera setup to rebuild
- The physical controls keep working with the platform down, so degradation is
  graceful

### Negative and accepted trade-offs

- Home Assistant is a stateful singleton and always will be. This constrains hosting,
  which is the whole subject of ADR-005
- The Netatmo integration is cloud-dependent, so those devices stop working when the
  vendor or the internet does
- Adopting Home Assistant means adopting its release cadence and occasional breaking
  changes

## Device selection constraints that follow

**Smart plugs: prefer 433 MHz or MQTT-native.** Shelly or Tasmota devices join over
WiFi and MQTT with nothing plugged into the host. A Zigbee-only plug drags in a
coordinator, and if that coordinator is a USB stick it re-pins the platform to one
machine, undoing what ADR-003 achieved. If Zigbee ever becomes necessary, prefer an
Ethernet or PoE coordinator over a USB one, for the same reason ADR-003 chose a
network-attached RF gateway.

**Fire detectors: the interlink must not depend on Home Assistant.** This is the one
device class where the platform must stay out of the safety path.

Most Zigbee smoke detectors do not interlink in hardware. There is an open issue
against the Zigbee stack about exactly this missing capability, and the common
workaround is a Home Assistant blueprint that links them in software. That makes the
platform safety-critical: alarms fail to propagate if Home Assistant is down, updating
or removed. That is the wrong trade for life safety, regardless of how reliable the
platform is.

The correct shape is alarms that interlink among themselves on a dedicated safety RF
band, independent of any hub. The Ei Electronics and Aico RadioLINK family is the
reference example: 868.499 MHz, a band restricted to safety products, with a
multi-path repeating mesh and house coding to prevent cross-talk between neighboring
systems, up to 12 devices.

Two consequences worth stating before buying:

1. **That band is not 433.92 MHz, so the RFX-433EMC will not see these alarms.**
   Do not assume the existing gateway provides visibility.
2. **Interlink and visibility are separate requirements.** Buy the alarms for the
   interlink, which works with no hub at all, and treat Home Assistant notification
   as a later, optional addition that may need its own bridge. Never let the reverse
   happen.
