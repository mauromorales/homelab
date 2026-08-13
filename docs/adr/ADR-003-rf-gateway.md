# ADR-003: 433 MHz RF gateway for home automation

Date: 2026-08-12
Status: Accepted
Deciders: Mauro

## Context

Two families of existing 433.92 MHz devices in the house need to be brought under
Home Assistant control without replacing the physical hardware.

**Motorized screens.** Winsol-branded, but the wall control is an **A-OK (Ningbo
AOK) AC133-01D**:

- RF transmitter, 433.92 MHz
- 3V CR2032 button cell
- `LEARN` button on the rear
- Three-button up / stop / down layout

Winsol resells generic Chinese tubular motors here rather than Somfy. This matters:
there is no Somfy RTS or io-homecontrol licensing wall, and the A-OK protocol has
been reverse-engineered publicly (e.g. `akirjavainen/A-OK`).

**Lighting.** DiO 1.0 modules, the classic Chacon 433.92 MHz protocol, handled as
AC/ARC.

**Building constraints.** Small footprint, concentrated floorplan. Interior walls
are non-structural plasterboard, effectively transparent at 433 MHz. The real RF
obstacles are the structural walls and floor slabs. A stairwell provides a vertical
void spanning the floors.

**Requirement:** local control for this RF layer, with no cloud dependency and no
vendor account. Scoped in [ADR-004](ADR-004-home-automation-platform.md): the control path for
lights, screens and life-safety devices stays local and hub-independent, while cloud
integrations are acceptable for conveniences that may degrade without consequence.

## Decision

Adopt a single **RFXCOM RFX-433EMC** transceiver as the house-wide 433.92 MHz
gateway.

- **Firmware mode:** MQTT over WiFi, *not* USB
- **Placement:** mid-level, adjacent to the stairwell
- **Antenna:** 433 MHz magnetic base antenna with 1 m cable, positioned
  independently of the box
- **Power:** existing quality USB-C supply; vendor PSU not purchased initially

One device covers both device families. A-OK and Chacon/DI.O are both on RFXCOM's
supported protocol list.

## Alternatives considered

| Option | Rejected because |
|---|---|
| **ESP32 + CC1101** | Cheapest by a wide margin and fully open, but it only solves one protocol at a time and requires per-protocol implementation work. Poor fit when the same box must serve both A-OK screens and DiO lights. Remains the fallback if RFXCOM support proves incomplete. |
| **RFXtrx433XL** | **End of life.** Superseded by the RFX-433EMC; the widespread out-of-stock status across NL/BE retailers is sell-through of remaining inventory. Buying end-of-life hardware for a marginal saving is a poor trade. |
| **Broadlink RM4** | Roughly a third the price, but RF learning is reported unreliable on blind protocols. It either fails to capture the code, or captures something the motor ignores. |
| **A-OK WiFi bridge** | Tuya-based and cloud-anchored. Violates the local-only requirement. |

## Consequences

### Positive

- **One box, both protocols.** A-OK and Chacon/DI.O are vendor-listed as supported.
- **Bidirectional listening.** The RFX is a transceiver, so it *hears* the existing
  physical remotes and wall switches. When someone uses the AC133 wall plate or a
  DiO remote directly, HA observes the command and updates state. This substantially
  mitigates the usual "HA thinks the light is off" desync problem.
- **MQTT Auto Discovery.** Devices appear in HA without a separate integration or
  driver.
- **Placement decoupled from host.** WiFi mode means the box goes where the RF is
  good, not where the HA host lives. Directly relevant given RFXCOM's own guidance
  to keep the unit away from Pis, routers, power cables and metal conduit.
- **Horizontal scaling path.** The MQTT firmware supports more than one RFX unit in a
  single HA instance, which the USB-attached XL could not. If an upper floor proves
  marginal, add a second unit rather than chasing antenna gain.

### Negative and accepted trade-offs

- **One-way protocols.** No true position feedback from the motors. Covers will be
  assumed-state in HA with time-based position estimation. Acceptable for screens.
  It would be more irritating for lighting, which is why 433 MHz is *not* recommended
  for any future lighting expansion; prefer Zigbee there.
- **Vendor lock to a closed box.** Less hackable than the ESP32 route, and RFXCOM
  firmware is not open source.
- **USB integration instability.** There were 2025 reports of the classic `rfxtrx`
  USB integration timing out against the EMC-generation hardware. The MQTT path
  sidesteps this entirely. This is a decision driver, not just a preference.

## Validation plan

1. Place the unit mid-level near the stairwell, antenna in open air.
2. Verify reception of the existing AC133 wall transmitter and DiO remotes on every
   level before committing to final mounting.
3. Confirm whether AC133 is fixed-code (as advertised) or rolling. Sniff the same
   button twice and compare bitstreams:
   - **Identical:** clone the existing transmitter ID; the motor is never touched.
   - **Differing:** generate a fresh ID and pair via the rear `LEARN` button.
4. Only add a second RFX unit if a measured coverage gap exists.

## Open questions

- **Antenna connector:** confirm SMA against RP-SMA on the RFX-433EMC before
  assuming the magnetic base antenna mates directly.
- **Vendor PSU spec:** the product listing describes 5V 5A 27W PD while the add-on
  blurb says 5V/3A. Clarify with RFXCOM if that accessory is ever ordered.
- **RF noise floor:** if receive range disappoints, swap the power supply as the
  first diagnostic *before* relocating the box. Cheap switching supplies are a known
  contributor to the 433 MHz noise floor, and the noise floor directly determines
  range.

## Notes

The original assumption that the Winsol screens were Somfy-based was **incorrect**,
and would have led to buying RTS-capable hardware at 433.42 MHz. The device label on
the rear of the wall plate settled it. Worth generalizing: identify the actual RF
module before selecting a gateway, since vendor branding on European window
furnishings frequently masks a generic OEM motor.
