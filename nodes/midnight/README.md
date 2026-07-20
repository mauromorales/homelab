# midnight — Beelink SER5 (agent host)

Status: active. Interim OS: Fedora (scaffolding). Target OS: Kairos Ubuntu 24.04 LTS flavor (see [ADR-001](../../docs/adr/ADR-001-agent-host-os.md)), later Hadron.
Role: always-on agent host for a 6-month agentic development experiment.
Last updated: 2026-07-19.

## Identity

| Item | Value |
|---|---|
| Model | Beelink SER5 (AMD Ryzen, 32 GB RAM) |
| Hostname | midnight |
| Primary NIC | `enp1s0` (Realtek, onboard Ethernet) |
| MAC (WoL target) | redacted — kept in private notes |
| Boot mode | UEFI |
| Secure Boot | Disabled |

## BIOS configuration (verified 2026-07-19)

Enter BIOS: press `Del` repeatedly at the Beelink logo. Save & exit: `F4`.

| Setting | Location | Value | Purpose |
|---|---|---|---|
| AC Power Loss | Advanced → AMD CBS → FCH Common Options → Ac Power Loss Options | **Always On** | Box boots on any power restoration; enables remote recovery by power-cycling (smart plug / power strip) |
| Wake (WLAN/WoL power enable) | Advanced → AMD PBS | Enabled | Keeps NIC powered in S5 for Wake-on-LAN |
| Boot mode | — | UEFI | |
| Secure Boot | — | Disabled | Fine for now; revisit for the trusted-boot milestone (see below) |

### Boot order (deliberate — do not reorder)

1. SD
2. USB device
3. Hard disk: Fedora
4. CD/DVD
5. Network: UEFI PXE IPv4
6. UEFI AP: Built-in EFI Shell

Rationale: disk-first with one-time override. Normal boots never touch PXE (no DHCP timeout, no reinstall footgun). Reinstalls are triggered from inside the OS with `efibootmgr --bootnext <pxe-entry-id>` for a single boot, with AuroraBoot serving the image (month-2 milestone). SD/USB above disk fail through instantly when empty — but **do not leave a bootable USB stick inserted** on an unattended reboot.

The built-in EFI shell (entry 6) is inert in normal operation and only reachable if everything above it fails. It is a recovery asset: it can manually launch `.efi` binaries from disk (`FS0:` then run the binary) or repair boot entries via `bcfg`. Note for the trusted-boot milestone: a firmware shell that launches arbitrary EFI binaries is part of the attack surface; Secure Boot policy must account for it.

### TODO in BIOS (next physical access)

- [ ] Verify SVM (AMD virtualization) is enabled: Advanced → CPU Configuration. Needed for libvirt/QEMU image-build VMs.

## Capabilities discovered

- **PXE boot (UEFI IPv4)**: enables network reinstall of Kairos via AuroraBoot. Target flow (month 2): agent updates image definition → CI builds → start AuroraBoot → `efibootmgr --bootnext <id>` → reboot → box reinstalls itself. Requires DHCP/netboot infra on the LAN; set up while physically home.
- **fTPM**: available. Enables Kairos trusted boot testing on real hardware (UKI, measured boot, TPM-backed encryption) — month-3+ milestone. Requires re-enabling Secure Boot with enrolled keys; plan a dedicated ADR before touching it.

## Wake-on-LAN

NIC supports magic-packet wake (`Supports Wake-on: pumbg`); ships disabled (`Wake-on: d`).

Enabled live with:

```sh
sudo ethtool -s enp1s0 wol g
```

**Persistence (required — ethtool setting resets on reboot).** Via NetworkManager:

```sh
nmcli -f NAME,DEVICE connection show          # find the connection for enp1s0
sudo nmcli connection modify "<name>" 802-3-ethernet.wake-on-lan magic
```

Verify after a cold boot: `sudo ethtool enp1s0 | grep Wake` must show `Wake-on: g`.

Wake from another machine on the LAN:

```sh
wakeonlan <mac-address>
```

- [ ] End-to-end test performed from full power-off (S5): PENDING / result: ___

## Host OS notes (Fedora interim)

- SELinux enforcing; clean so far (`sudo ausearch -m avc -ts recent` → no matches). If sandbox/libvirt operations fail mysteriously, check AVC denials before blaming tooling; fix with targeted booleans, do not disable.
- Installed for Claude Code sandboxing: `bubblewrap`, `socat`.
- Suspend masked for 24/7 operation:

```sh
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

- [ ] Capture `efibootmgr` output here (boot entry IDs, especially the PXE entry, for the BootNext self-rebuild flow):

```
(paste output)
```
