# ADR-006: Rack switch

Date: 2026-08-14
Status: Proposed
Deciders: Mauro
Related: [ADR-004](ADR-004-home-automation-platform.md) (cameras and the Zigbee coordinator
preference), [ADR-005](ADR-005-home-assistant-host.md) (Home Assistant host), [ADR-003](ADR-003-rf-gateway.md)
(network-attached RF gateway)

## Context

### The network as it actually is

```
router → Deco → 8-port TP-Link, no PoE → 5-port TP-Link, no PoE → 5-port TP-Link, no PoE
                (distributes to all rooms)  (desk)                  (rack)
```

Three unmanaged TP-Link switches in series, none with PoE. `thuroros`, the doorbell Pi,
hangs off the 8-port because it must sit near the doorbell.

**This is a daisy chain, not a star.** Every packet leaving the rack crosses the desk
switch and then the room switch before it reaches the Deco.

### The target layout

Mauro's stated goal for where things live:

- **The desk** holds only the Mac Mini
- **The main power cabinet** holds `thuroros`, which must stay near the doorbell
- **The rack** holds everything else

The desk and the rack are physically next to each other, so the order of the two switches
in the chain is a free choice rather than a constraint.

### What is being proposed

Replace the rack's 5-port with an 8-port, and move the freed 5-port to a dedicated
physical network for the Kubernetes cluster.

**And retire the desk switch.** With only the Mac Mini left on the desk, a 5-port switch
would serve a single device. One cable from the rack does the same job with one less box,
one less power supply and one less hop. The freed 5-port becomes a spare.

### The port budget for the rack

| Port | Device |
|---|---|
| 1 | Uplink to the 8-port in the power cabinet |
| 2 | Uplink from the Kubernetes 5-port switch |
| 3 | Beelink SER5 (`midnight`), the agent host |
| 4 | HP ProDesk 600 G4, Kubernetes control plane |
| 5 | New machine, incoming, Kubernetes worker |
| 6 | Raspberry Pi 4, Home Assistant ([ADR-005](ADR-005-home-assistant-host.md)) |
| 7 | Mac Mini M2 at the desk, `mowa` and shared storage |
| 8 | Spare |

**Seven of eight, with one spare. Eight ports is the right size for the rack.**

### WiFi for the Mac Mini, considered and rejected

Mesh coverage at the desk is good, and one machine on WiFi would be acceptable for general
use. It is rejected because of *which* machine it is: the Mac Mini serves shared storage
for the lab and is the intended target for Home Assistant's off-box backups. **A backup
target on variable mesh throughput is a poor foundation, particularly for backups that
have never been restore-tested.** It sits beside the rack, so a cable costs a cable.

### PoE belongs on the room switch, not this one

[ADR-004](ADR-004-home-automation-platform.md) plans "one or two security cameras,
RTSP/ONVIF", and states a device-selection constraint in writing:

> If Zigbee ever becomes necessary, prefer an Ethernet or PoE coordinator over a USB one,
> for the same reason ADR-003 chose a network-attached RF gateway.

Both of those devices live in rooms. **Cameras and access points terminate on the 8-port
that feeds the rooms, and that switch is not the subject of this ADR.** The PoE argument
is real and it applies elsewhere — recorded here so it is not lost, and so nobody buys PoE
for the rack on the strength of it.

Nothing in the rack takes power over Ethernet. The machines there have their own supplies.

### The daisy chain is the more interesting problem, and retiring the desk switch solves it

The current order is worth stating plainly, because it costs more than the choice of
switch model:

- **All rack traffic shares one gigabit link through the desk switch.** Cluster traffic and
  storage traffic to the Mac Mini both cross it. The rack is the densest part of the
  network and it sits behind the thinnest link.
- **The desk is a dependency of the rack.** Unplugging something at the desk, or knocking
  the switch's power out, takes the rack with it. A desk is a place where cables get moved.
- **Three unmanaged hops** make any future VLAN work harder, because every hop has to pass
  tagged traffic.

**Retiring the desk switch fixes all three at once**, and it follows from the target layout
rather than being a separate project: the rack connects straight to the cabinet, and the
Mac Mini connects to the rack. Two hops instead of three, and the failure path no longer
runs through a desk.

Reversing the order instead — rack first, desk behind it — would fix the dependency
direction but keep the extra hop and the extra box, for one device.

### Managed or not

Nothing needs VLANs today. The cluster is a teaching instrument, and VLANs, tagged trunks
and port isolation are part of what it exists to teach. TP-Link's "Easy Smart" tier adds
port-based and tag-based VLANs, QoS, IGMP snooping and LAG from a web page, for roughly
€10 more than the unmanaged equivalent. It is not a full managed switch and does not
pretend to be.

Ten euros to keep that door open, on the switch in front of the cluster, is cheap. It is
the only real argument against the plain unmanaged unit.

## Decision

**Buy a TP-Link TL-SG108E for the rack: 8 gigabit ports, Easy Smart, no PoE. Roughly €25
to €35.**

**Re-cable the rack to hang off the cabinet 8-port directly, and retire the desk switch.**
The Mac Mini takes a cable from the rack. The cabling matters more than the model choice
and costs one cable.

Three reasons:

1. **Eight ports fits**, with one spare — as counted above.
2. **No PoE, because nothing in the rack needs it.** Camera and coordinator PoE is a
   question for the room switch, later, when those devices exist.
3. **Easy Smart, for about €10 over unmanaged**, so the cluster has VLANs available when
   the learning work reaches them. This is the only part of the decision that is
   speculative, and it is the cheapest part.

## Alternatives considered

### TP-Link LS108G, Mauro's original proposal — viable, and nearly right

[LS108G](https://www.tp-link.com/us/home-networking/8-port-switch/ls108g/): 8 ports,
unmanaged, no PoE, steel case, roughly €20.

**The port count judgement was correct.** An earlier draft of this ADR rejected it as
"full on day one"; that was based on a wrong picture of the topology, which assumed the
rack switch carried a router uplink. It does not — it carries one uplink to the desk. The
count is seven of eight.

It is rejected only on the VLAN question, and only by about €10. **If VLANs are not
wanted, buy this one.** It is the same family as the two existing 5-ports and it will
behave identically.

### TL-SG108PE, 4 PoE+ ports at 64 W — rejected

Roughly €46 to €63. Nothing in the rack draws PoE, so this is paying for a feature at the
wrong location. Reconsider it for the **room** switch when cameras arrive.

### TL-SG1016PE, 16 ports with 8 PoE+ — rejected

Roughly six to eight times the price of the LS108G, for ports the rack does not need and
PoE at the wrong end of the house. This was the recommendation in the first draft of this
ADR, before the topology was known. It was wrong.

### Keep the 5-port in the rack — rejected

Five ports cannot carry the seven devices listed above, and the Kubernetes switch has to
come from somewhere. Replacing it is the reason this ADR exists.

## Consequences

### Positive

- Correct size, with one spare port, at a cost close to Mauro's original proposal
- VLANs available in front of the cluster when the learning work needs them
- Same vendor and management model as the existing switches
- The re-cabling removes the desk from the rack's failure path at no cost, and drops the
  chain from three unmanaged hops to two
- One less box and one less power supply at the desk, and a spare 5-port switch

### Negative and accepted trade-offs

- **Easy Smart is a ceiling.** If the cluster later needs 802.1X, real L3 or per-port
  policy, this switch is replaced rather than upgraded
- **VLAN support in the rack is of limited use while the other three hops are unmanaged.**
  Tagged traffic has to cross them. It buys isolation *within* the rack now, and a
  starting point later — not end-to-end segmentation today
- Roughly €10 more than the unmanaged unit, for a feature that may go unused
- **No PoE anywhere in the lab, still.** That decision is deferred, not made. It comes due
  when the first camera is bought, and it lands on the room switch

### Open questions

1. **Can the rack be re-cabled to the cabinet directly**, or is the existing run the only
   physical path available? The port count holds either way; only the hop count changes.
2. **Where would camera runs terminate?** Assumed to be the cabinet switch. If they would
   come to the rack instead, this ADR changes and PoE returns to the table.
3. **What happens to the spare 5-port** once the desk switch is retired? A second
   Kubernetes segment and a cold spare are both reasonable. Not decided here.

**Prices are indicative, from August 2026 listings, and were not verified at a Belgian
retailer.** Confirm locally before ordering.
