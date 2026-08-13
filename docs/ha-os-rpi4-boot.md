# Runbook: diagnosing a Home Assistant OS boot on the Raspberry Pi 4

Host: the spare Raspberry Pi 4 chosen in [ADR-005](adr/ADR-005-home-assistant-host.md),
running Home Assistant OS from a USB SSD.

This runbook exists because a board that was booting perfectly looked dead for several
hours. Four pieces of hardware were swapped before the real cause turned up, and none of
those swaps could have found it. The fix is worth a paragraph. The reason the swaps were
wasted is worth the rest of the page.

## The rule this runbook is really about

**Before you call something broken, say what your evidence would look like if the thing
were merely invisible. If the answer is "exactly the same", the test is worthless — find
another test.**

That is the general form. The specific form here: a display that goes dark and a machine
that stops booting produce an identical screen. Every experiment that only looks at the
screen is blind to the difference, no matter how many parts it replaces.

The corollary is the one that ended it:

**Timing that repeats across changed hardware is a software event.** Hardware faults —
marginal power, a flaky cable, a dying port — vary. Software reaches the same instruction
at the same moment every time. So when the same event lands within a few hundred
milliseconds across four different hardware configurations, hardware is already ruled
out, and no further swap will tell you anything.

## The case

**Symptom.** HDMI console output stopped about 4.5 seconds into the kernel boot. The
screen then showed NO SIGNAL, and nothing further appeared.

**What was swapped, none of it necessary:** the power supply, a powered USB hub, the SSD
between USB ports, and the keyboard.

**The evidence that settled it.**

- The cutoff landed at kernel time 4.4027s, 4.7080s, 4.6497s and 4.4972s across the four
  configurations — a spread of roughly 300 ms. Deterministic, therefore software.
- `[drm] Initialized v3d 1.0.0 for fec00000.v3d` appeared two or three lines before the
  cutoff in every single run.
- The U-Boot RAUC counter printed "1 attempts remaining" on the first boot and "2
  attempts remaining" on every boot after it. That counter only resets when userspace
  marks the slot good, so pinned at 2 means **every boot had already succeeded**.
- `Finished File System Check on /dev/disk/by-label/hassos-boot` — clean, no I/O errors.
- Port 8123 answered with connection refused, **not** with a name resolution failure.
  mDNS was replying, so the network stack was up. Port 4357 served the observer page.

**Root cause.** `vc4-kms-v3d` takes over the display from the firmware's
simple-framebuffer at that point in the boot. HDMI is torn down and renegotiated, and the
HDMI capture card never re-syncs afterwards. The console was gone; the board was not. It
had booted correctly every time.

## Fast checks, in the order that settles it quickest

1. **Open the observer on port 4357 before you try port 8123.** The observer answers
   while Home Assistant Core is still starting, so it distinguishes "still booting" from
   "not running" — but read the next section for what it does *not* tell you.
2. **Tell NO SIGNAL apart from a frozen console.** NO SIGNAL means the display link
   dropped, which is a display problem. A console frozen mid-line means the kernel
   stopped, which is not. They are different failures and they look similar only if you
   stop looking.
3. **Read the RAUC attempts counter in U-Boot.** A counter that does not decrease means
   the previous boot reached userspace and marked its slot good.
4. **Run `ha os info`** to read the boot slots and confirm which one is active.

Checks 1, 3 and 4 all work with no display at all. That is the point: none of them can be
fooled by the failure mode that cost the four swaps.

## The observer answers for the Supervisor, not for Core

Port 4357 reporting `Supervisor: Connected, Supported, Healthy` says the Supervisor is
healthy. It says nothing about Home Assistant Core.

So this combination is a real and specific state:

| Port 4357 | Port 8123 | Meaning |
|---|---|---|
| Serves the observer page | Refuses the connection | Supervisor is up, Core is down or still starting |
| No answer | No answer | The host or the network is the problem, not Core |

Confirmed on this board: the observer returned HTTP 200 and healthy while 8123 refused
the TCP connection outright — `connect` failing in under a millisecond, not a slow
response and not an error page. Ports 22 and 80 were closed too, which is normal for
stock HA OS without the SSH add-on.

**Diagnose that as a Core or container question. It is not a networking question.** If
the box answers on 4357 at all, then mDNS, the LAN, the cable and the addressing are all
working, and re-checking them is another test with no discriminating power.

To check the host itself is reachable, `ping homeassistant.local` and read the TTL: TTL 64
with sub-millisecond round trips means the host is on the same subnet with no router hop.

## Restoring the HDMI console

Change **one variable at a time** and record the result before starting the next. Three
fixes applied together prove nothing about which one worked.

1. Try the other HDMI port — HDMI0, the one nearest the USB-C jack.
2. In `config.txt` on the `hassos-boot` partition, set `hdmi_group=1`, `hdmi_mode=16`,
   `hdmi_force_hotplug=1` and `hdmi_drive=2`. This pins a mode the capture card can hold
   through the handover.
3. Replace `dtoverlay=vc4-kms-v3d` with `dtoverlay=vc4-fkms-v3d`, which keeps the
   firmware framebuffer path instead of handing over to full KMS.

## Set up the serial console first, not last

Add `enable_uart=1` to `config.txt` and attach a USB-TTL adapter to GPIO 14 and 15 at
115200 baud.

This should have been step one. A UART console does not go through the display pipeline,
so it survives exactly the event that broke the HDMI capture, and it prints the boot from
U-Boot onwards. Once it exists, HDMI is never the debugging bottleneck on this board
again.

## Known noise — do not chase these

- **`F2FS-fs (sda3): Magic Mismatch`** is benign. `sda3` is the erofs system slot; the
  kernel simply probes F2FS before it gets to erofs.
- **U-Boot `mmc0`/`mmc1` timeouts**, printing `Card did not respond to voltage select! :
  -110`, are cosmetic. They cost about 10 seconds before U-Boot reaches the SSD. An empty
  or flaky SD slot is the likely cause; removing the card is the test. Slow is not broken.

## Storage notes

- **Boot from the USB SSD, never an SD card.** The recorder writes continuously and will
  wear an SD card out. This is the most common cause of Pi-hosted Home Assistant failure,
  and it is why [ADR-005](adr/ADR-005-home-assistant-host.md) specifies SSD boot.
- **Check the SSD is on a USB 3 port and negotiates SuperSpeed.** On this board it was
  found behind a VIA Labs USB 2.0 hub (`2109:3431`) running at 480 Mbps, which loses USB
  3 entirely. Read the negotiated link speed from `dmesg` rather than trusting the port
  it looks plugged into.
- **Leave UAS enabled.** `scsi host0: uas` is active on the SanDisk drive (`0781:5580`)
  with no I/O errors. **Only if real I/O errors appear**, disable it with
  `usb-storage.quirks=0781:5580:u` in `cmdline.txt` — and note that this costs
  throughput, so it is a fix for a proven problem, not a precaution.
