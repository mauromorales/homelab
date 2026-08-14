# ADR-006: Rack switch

Date: 2026-08-14
Status: Proposed
Deciders: Mauro
Related: [ADR-004](ADR-004-home-automation-platform.md) (cameras and the Zigbee coordinator
preference), [ADR-005](ADR-005-home-assistant-host.md) (Home Assistant host), [ADR-003](ADR-003-rf-gateway.md)
(network-attached RF gateway)

## Context

The lab has two 5-port TP-Link unmanaged gigabit switches. Neither supplies PoE. They are
being given fixed roles:

| Switch | Role |
|---|---|
| 5-port, existing | A dedicated physical network for the Kubernetes cluster |
| 5-port, existing | The desk, so desk devices do not need a run to the rack |
| **New switch** | **The rack — the aggregation point for everything else** |

This ADR chooses the third one. The two existing switches are staying as they are and are
not in question.

### The port budget, which is the part that decides this

The rack switch is where everything meets. Counting what terminates there:

| Port | Device |
|---|---|
| 1 | Uplink to the router |
| 2 | Uplink from the desk 5-port switch |
| 3 | Uplink from the Kubernetes 5-port switch |
| 4 | Beelink SER5 (`midnight`), the agent host |
| 5 | HP ProDesk 600 G4, Kubernetes control plane |
| 6 | New machine, incoming, Kubernetes worker |
| 7 | Mac Mini M2, `mowa` and shared storage |
| 8 | Raspberry Pi 4, Home Assistant ([ADR-005](ADR-005-home-assistant-host.md)) |

**Eight ports, and every one of them is spoken for before anything new arrives.** That is
without the doorbell Pi (`thuroros`), without the spare Pi 5, without a laptop plugged in
temporarily, and without the cameras below. A switch that is full on the day it is
installed is the wrong switch.

### PoE is not hypothetical here, and two existing ADRs say so

[ADR-004](ADR-004-home-automation-platform.md) lists "one or two security cameras,
RTSP/ONVIF" under planned devices. Cameras of that class are overwhelmingly PoE, and their
cable runs terminate at the rack, not at the desk.

The same ADR states a device-selection constraint in writing:

> If Zigbee ever becomes necessary, prefer an Ethernet or PoE coordinator over a USB one,
> for the same reason ADR-003 chose a network-attached RF gateway.

So the lab has already committed, on paper, to preferring PoE devices where a choice
exists. **Buying a switch without PoE contradicts the direction of a decision that is
already recorded**, and the recovery is either injectors or buying the switch twice.

### Managed or not

Nothing in the lab needs VLANs today. Two things soon will:

- **A camera is an untrusted device on your LAN.** ONVIF cameras phone home, ship poor
  firmware, and are rarely updated. Segmenting them onto their own VLAN is the standard
  answer and it is much easier to do at install time than to retrofit.
- **The cluster is a teaching instrument.** VLANs, tagged trunks and port isolation are
  part of what it is there to teach, and the physical-separation approach chosen for the
  Kubernetes network only goes so far before it needs a trunk.

TP-Link's "Easy Smart" tier is the relevant one: port-based and tag-based VLANs, QoS,
IGMP snooping and LAG, configured from a web page. It is not a full managed switch and
does not pretend to be. For this lab it is the right rung — a full managed switch is more
CLI than the rack currently justifies.

## Decision

**Buy the [TP-Link TL-SG1016PE](https://www.tp-link.com/us/business-networking/easy-smart-switch/tl-sg1016pe/):
16 gigabit ports, 8 of them PoE+ with a 150 W budget, Easy Smart management, rack-mountable.**

Three reasons, in order of weight:

1. **Sixteen ports.** Eight is already full, as counted above. Sixteen leaves room for the
   doorbell Pi, the spare Pi 5, cameras, and whatever gets plugged in for an afternoon.
2. **PoE where the camera runs land.** 150 W across eight PoE+ ports covers two or three
   cameras, a PoE Zigbee coordinator and a PoE access point, with room left over.
3. **It is rack-mountable.** The 8-port alternatives are desktop units. This is a rack.

It also keeps the brand already in use, so the two existing switches and this one behave
the same way.

## Alternatives considered

### TP-Link LS108G, the original proposal — rejected

[LS108G](https://www.tp-link.com/us/home-networking/8-port-switch/ls108g/): 8 ports,
unmanaged, no PoE, steel case, roughly €20. It is a well-built and very cheap port
expander, and as a *desk* switch it would be a fine choice.

Rejected for the rack on three counts, any one of which is sufficient: **it is full on
day one** by the count above, **it has no PoE** despite ADR-004 planning PoE-class
devices, and **it has no VLAN support** for the camera segmentation that follows those
devices. The €20 price is real, but the cost of replacing it in six months is the whole
€20 plus the swap.

### TP-Link LS108GP — rejected

[LS108GP](https://www.tp-link.com/us/business-networking/soho-switch-poe/ls108gp/): 8
ports, all PoE+, 62 W budget, unmanaged, roughly €45. Solves PoE and nothing else. Still
eight ports, still no VLANs.

### TP-Link TL-SG108PE — rejected, and it was the close one

[TL-SG108PE](https://www.tp-link.com/us/business-networking/poe-switch/tl-sg108pe/): 8
ports with 4 PoE+ at 64 W, Easy Smart, roughly €46 to €63. This solves PoE *and*
management at a third of the price of the recommendation, and four PoE ports is genuinely
enough for the planned devices.

**It fails only on the port count** — which is the one axis with no workaround short of
adding another switch and another hop. Worth reconsidering if the port table above turns
out to be wrong, in particular if the Kubernetes switch does not uplink to the rack.

### A 16-port switch without PoE — viable if PoE is rejected

If Mauro decides cameras are not happening, a 16-port Easy Smart switch without PoE costs
substantially less and keeps the port headroom, which is the more important half of this
decision. **Do not buy an 8-port model in that case** — the port count argument stands on
its own, independently of PoE.

### A full managed switch — rejected for now

More configuration surface than the rack justifies today, and the Easy Smart tier already
covers VLANs. Revisit if the cluster work starts to need 802.1X, meaningful L3, or
per-port policy that a web page cannot express.

## Consequences

### Positive

- The rack has spare ports, so the next device does not force a purchase
- Camera runs terminate on a switch that can power them, with no injectors
- Camera and IoT segmentation is available when it is needed, rather than a retrofit
- Rack-mounted rather than a desktop box balanced on a shelf
- Same vendor and the same management model as the two existing switches

### Negative and accepted trade-offs

- **Roughly six to eight times the price of the LS108G.** This is the real cost of the
  decision and it should be weighed as such
- Sixteen ports and 150 W is more than the lab needs today. That is the point, and it is
  still overprovisioning
- PoE switches with a large budget are physically bigger and draw more idle power than a
  passive 8-port unit. Relevant to [#145](https://github.com/mauromorales/mission-control/issues/145),
  the UPS sizing ticket, which should measure it rather than assume
- Easy Smart is a ceiling. If the cluster later needs real managed features, this switch
  gets replaced rather than upgraded

### Open questions, to be answered before purchase

1. **Does the Kubernetes switch uplink to the rack switch, or is that network truly
   isolated?** If isolated, the cluster nodes need a second NIC each to reach the
   internet, and the rack switch needs one port fewer. This changes the port count and it
   is the assumption most likely to be wrong.
2. **Do the camera cable runs terminate in the rack?** If they land elsewhere, PoE belongs
   on a different switch and this decision changes.
3. **Is `thuroros`, the doorbell Pi, wired to the rack or is it on WiFi?**
4. **Is there a budget ceiling?** It decides between this recommendation and the
   TL-SG108PE.

**Prices quoted are from August 2026 European listings and are indicative.** Confirm the
current price locally before ordering; the euro price for the TL-SG1016PE was not verified
from a Belgian retailer while writing this.
