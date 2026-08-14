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

- **The desk** holds only `stardust`
- **The main power cabinet** holds `thuroros`, which must stay near the doorbell
- **The rack** holds everything else, including `polaris`, the Mac Mini that runs
  [mowa](https://github.com/mauromorales/mowa)

"Everything else" is larger than the servers. The lab also holds, or expects to hold, a
Raspberry Pi 5, a Radxa board, a work laptop, an NVIDIA Jetson Thor, and a RISC-V board
once [#99](https://github.com/mauromorales/mission-control/issues/99) picks one. **These
are not an afterthought — testing Kairos on real boards is the point of the lab**, and
each one wants a wired port while it is being worked on.

The desk and the rack are physically next to each other, so the order of the two switches
in the chain is a free choice rather than a constraint.

```
router → Deco → 8-port, no PoE ─┬─ thuroros (doorbell)
                (power cabinet) ├─ … the rooms
                                │
                                └─ 16-port, NEW (rack) ─┬─ midnight
                                                        ├─ HP ProDesk (control plane)
                                                        ├─ new worker
                                                        ├─ Home Assistant Pi
                                                        ├─ polaris (mowa)
                                                        ├─ Jetson Thor
                                                        ├─ Raspberry Pi 5
                                                        ├─ Radxa
                                                        ├─ RISC-V board (planned)
                                                        ├─ work laptop
                                                        ├─ 5-port (isolated segment)
                                                        └─ spare ×4

stardust (desk) → WiFi, or a cable to the rack
```

The desk switch is gone, and the chain is two hops deep instead of three.

### What is being proposed

Replace the rack's 5-port with a 16-port, and move the freed 5-port to a dedicated
physical segment — for the Kubernetes cluster, for netboot testing, or as a cold spare.
That choice is out of scope here.

**And retire the desk switch.** With only `stardust` left on the desk, a 5-port switch
would serve a single device. Either one cable from the rack, or WiFi — see below. Either
way the switch goes, along with a box, a power supply and a hop. The freed 5-port becomes
a spare.

### The port budget for the rack

**Permanent residents**

| # | Device |
|---|---|
| 1 | Uplink to the 8-port in the power cabinet |
| 2 | Uplink from the 5-port on the isolated segment |
| 3 | Beelink SER5 (`midnight`), the agent host |
| 4 | HP ProDesk 600 G4, Kubernetes control plane |
| 5 | New machine, incoming, Kubernetes worker |
| 6 | Raspberry Pi 4, Home Assistant ([ADR-005](ADR-005-home-assistant-host.md)) |
| 7 | `polaris`, Mac Mini M2, runs `mowa` |
| 8 | NVIDIA Jetson Thor |

**Boards and machines that come and go**

| # | Device |
|---|---|
| 9 | Raspberry Pi 5 |
| 10 | Radxa board |
| 11 | RISC-V board, once [#99](https://github.com/mauromorales/mission-control/issues/99) chooses one |
| 12 | Work laptop |
| 13 | `stardust`, if the desk is wired rather than on WiFi |

**Thirteen, against eight ports.** An 8-port switch is not merely tight, it is short by
five before anything unplanned arrives.

The second group is genuinely intermittent — no more than two or three of those boards are
usually powered at once — so the honest number is somewhere between nine and thirteen.
**It is above eight either way, and that is what decides this ADR.**

### WiFi for `stardust` — acceptable

Mesh coverage at the desk is good, and `stardust` is a workstation rather than
infrastructure. **Nothing in the lab depends on it being reachable**, so variable
throughput costs its user some convenience and costs the lab nothing.

This is a genuine choice rather than a compromise. Wire it if the desk is tidy enough to
want one more cable; leave it on WiFi otherwise.

**The reasoning would be different for `polaris`**, which serves `mowa` and may later
serve shared storage. That machine is in the rack and wired, so the question does not
arise.

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

### The boards need a network the Deco does not control

This is the part that makes VLAN support concrete rather than speculative.

Kairos boards are provisioned by netboot. AuroraBoot runs on `midnight` and has to serve
DHCP and TFTP to the machine being installed. **A second DHCP server on the main LAN
fights the Deco**, and the loser is whichever device asks at the wrong moment — including
the household ones. So netboot testing wants a segment where `midnight` can serve DHCP
without touching anything the house depends on.

There are two ways to get one, and the switch choice decides which is available:

- **Physically**, on the freed 5-port switch. Works with any switch, costs a cable, and is
  limited to five devices.
- **As a VLAN** on the rack switch, which needs an Easy Smart or better. Any port can join
  the netboot segment, and it can be changed from a web page rather than by moving cables.

**The second is the reason to pay for management, and it is not hypothetical** — it is how
the riscv64 and Jetson work will actually be done. Note also that this reframes the
5-port's role: "the Kubernetes segment" was one candidate use, and an isolated netboot
segment is another. That choice is out of scope here.

### Managed or not

Nothing needs VLANs today. The cluster is a teaching instrument, and VLANs, tagged trunks
and port isolation are part of what it exists to teach. TP-Link's "Easy Smart" tier adds
port-based and tag-based VLANs, QoS, IGMP snooping and LAG from a web page, for roughly
€10 more than the unmanaged equivalent. It is not a full managed switch and does not
pretend to be.

Ten euros to keep that door open, on the switch in front of the cluster, is cheap. It is
the only real argument against the plain unmanaged unit.

## Decision

**Buy a TP-Link TL-SG1016DE for the rack: 16 gigabit ports, Easy Smart, no PoE,
19-inch rack-mountable. €74.99 at MediaMarkt.be, checked 2026-08-14.**

**Re-cable the rack to hang off the cabinet 8-port directly, and retire the desk switch.**
The Mac Mini takes a cable from the rack. The cabling matters more than the model choice
and costs one cable.

Three reasons:

1. **Thirteen devices, and eight ports cannot hold them.** The boards are the lab's
   purpose, not its overflow.
2. **No PoE, because nothing in the rack needs it.** Camera and coordinator PoE is a
   question for the cabinet switch, later, when those devices exist.
3. **Easy Smart, because netboot needs an isolated segment** and a VLAN gives one on any
   port without moving cables. This was the speculative part of an earlier draft. It is not
   speculative any more.

It is also rack-mountable, which the 8-port desktop units are not, and this is a rack.

## Alternatives considered

### TP-Link LS108G, Mauro's original proposal — rejected

[LS108G](https://www.tp-link.com/us/home-networking/8-port-switch/ls108g/): 8 ports,
unmanaged, no PoE, steel case, roughly €20.

Eight ports against thirteen devices, and no VLAN for the netboot segment. It remains an
excellent switch for what it is, and the freed 5-port covers the same need more cheaply if
the answer turns out to be "add another small switch".

### TP-Link TL-SG108E, 8 ports Easy Smart — rejected

Roughly €25 to €35. Solves the VLAN half and fails on the port count, exactly like the
LS108G. **This was the recommendation of the previous revision of this ADR**, written
before the board inventory was known.

### TP-Link TL-SG116E, 16 ports Easy Smart — viable, and about €58

Functionally equivalent to the recommendation at a lower price. **The difference is form
factor: it is a desktop unit, not 19-inch rack-mountable.** In a rack that matters more
than the €15, but not by much. Buy it if the rack has a shelf and the saving is wanted.

### TL-SG108PE, 4 PoE+ ports at 64 W — rejected

Roughly €46 to €63. Nothing in the rack draws PoE, so this is paying for a feature at the
wrong location. Reconsider it for the **room** switch when cameras arrive.

### TL-SG1016PE, 16 ports with 8 PoE+ — rejected

The same 16 ports as the recommendation, plus PoE at the wrong end of the house, for
roughly twice the price. **This was the first draft's recommendation, and the port count
turned out to be right for a reason that draft never gave** — dev boards, not cameras.
The PoE half is still wrong.

### Keep the 5-port in the rack — rejected

Five ports cannot carry thirteen devices, and the isolated segment needs a switch of its
own. Replacing it is the reason this ADR exists.

### Stack two 8-port switches instead — rejected

Two cheap 8-ports cost about the same as one 16-port and give 14 usable ports after the
link between them. They also add a hop, a second power supply, and a bottleneck on the
link — and neither would carry VLANs unless both are Easy Smart, at which point the saving
is gone.

## Consequences

### Positive

- Correct size, with roughly four spare ports, so the next board does not force a purchase
- A netboot VLAN is available on any port, without a second DHCP server on the household
  LAN and without moving cables
- Same vendor and management model as the existing switches
- The re-cabling removes the desk from the rack's failure path at no cost, and drops the
  chain from three unmanaged hops to two
- One less box and one less power supply at the desk, and a spare 5-port switch
- `stardust` on WiFi is a supported outcome rather than a fallback, since nothing in the
  lab depends on that machine

### Negative and accepted trade-offs

- **Easy Smart is a ceiling.** If the cluster later needs 802.1X, real L3 or per-port
  policy, this switch is replaced rather than upgraded
- **VLAN support in the rack is of limited use while the other three hops are unmanaged.**
  Tagged traffic has to cross them. It buys isolation *within* the rack now, and a
  starting point later — not end-to-end segmentation today
- Roughly €50 to €60 more than Mauro's original proposal. That is the real cost of the
  decision and it should be weighed as such
- Sixteen ports draws more idle power than an 8-port unit. Relevant to
  [#145](https://github.com/mauromorales/mission-control/issues/145), the UPS sizing
  ticket, which should measure it rather than assume
- **No PoE anywhere in the lab, still.** That decision is deferred, not made. It comes due
  when the first camera is bought, and it lands on the room switch

### Open questions

1. **Can the rack be re-cabled to the cabinet directly**, or is the existing run the only
   physical path available? The port count holds either way; only the hop count changes.
2. **Where would camera runs terminate?** Assumed to be the cabinet switch. If they would
   come to the rack instead, this ADR changes and PoE returns to the table.
3. **What happens to the spare 5-port** once the desk switch is retired? A second
   Kubernetes segment and a cold spare are both reasonable. Not decided here.
4. **Where does shared storage live?** Undecided, and it deserves its own ADR. It is out of
   scope here, but it could add a device to the rack and therefore claim the spare port.

### Prices, checked at Belgian retailers on 2026-08-14

| Retailer | Price | Availability |
|---|---|---|
| MediaMarkt.be | **€74.99** | Online in stock, next-day if ordered before 23:30 |
| Alternate.be | €79.90 | In stock |
| bol.com BE | €84.00 | Third-party seller, four-day delivery |

**All three are online with delivery. No shelf stock in Ghent was confirmed.** Krefel's
site returned a server error and Coolblue blocks automated requests, so neither was
checked; Coolblue has a Ghent store and is worth a phone call if the switch is wanted the
same day.

Prices for the alternatives above are from August 2026 listings and are indicative rather
than checked.
