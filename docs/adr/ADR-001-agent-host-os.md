# ADR-001: Agent Host OS — Kairos Ubuntu 24.04 LTS flavor

Date: 2026-07-19
Status: Accepted
Deciders: Mauro (with Claude as design assistant)

## Context

The Beelink SER5 mini PC (see `nodes/midnight/README.md` in the homelab repo) is the always-on agent host for a 6-month agentic development experiment. The machine must run unattended, be remotely recoverable, and eventually dogfood Kairos itself ("the AI dev infrastructure runs on the immutable OS it maintains"). The first Kairos milestone is an agent-host image built during vacation weeks 1–2, flashed on return; a later milestone migrates to Hadron.

The host executes a large volume of unattended shell activity: Claude Code sessions, sandboxed bash (bubblewrap), install scripts, CI-adjacent tooling, libvirt/QEMU VMs. The OS layer should be the most boring, most compatible part of the stack — novelty budget is spent elsewhere (orchestration, harness, image pipeline).

Sequencing: Fedora (already installed) serves as interim scaffolding so no pre-departure time is spent reinstalling; the Kairos image replaces it on return.

## Decision

Base the agent-host image on the **Kairos Ubuntu 24.04 LTS flavor**, headless (no GUI — the architecture has no graphical component on this machine).

## Alternatives considered

**Ubuntu 26.04 LTS flavor — rejected for now.** 26.04 (released 2026-04-23) is a deliberately transitional release: sudo-rs replaces sudo as default (known incompatibilities, e.g. missing `--preserve-env`, changed output formats that break script parsing — it broke Git's own CI), Rust coreutils replace most GNU coreutils (~88% GNU test compatibility at release), cgroup v1 removed with no fallback, Python 3.12 → 3.13. An unattended agent host executing thousands of third-party scripts and tutorials' worth of assumptions is the worst possible early adopter for a userland transition. 24.04 is supported into 2029, well beyond the experiment window. A future migration to 26.04 is planned as a documented experiment ("what breaks") once the system is stable — a content opportunity, not a dependency.

**Debian-based flavor — acceptable substitute.** Equally boring userland; not chosen only because the Ubuntu 24.04 flavor is the more exercised path in the Kairos ecosystem. Revisit if flavor maintenance status suggests otherwise.

**Hadron — deferred, not rejected.** Target for a later milestone (~month 4). No package manager means everything must be baked into the image or containerized; a valuable engineering story once the system is stable, a poor week-1 dependency.

**Stay on Fedora (non-Kairos) — rejected as endstate.** Forfeits the dogfooding goal; kept only as interim scaffolding, which also demonstrates portability (the system's identity lives in git — skills, configs, image definitions — not in the host OS).

## Consequences

- The vacation flagship task is building this image: cloud-config baking in the agent user, Claude Code (pinned version), sandbox deps (bubblewrap, socat), Tailscale (pinned, with pre-auth key), gh, worktree layout, masked suspend targets. Iterated in libvirt/QEMU VMs on the SER5; success criterion: flash-and-go on return (~1 hour migration).
- Version pinning is policy: the image definition pins Claude Code and Tailscale versions explicitly; upgrades are deliberate image rebuilds, not drift.
- Future ADRs anticipated: PXE/AuroraBoot self-rebuild flow (month 2), trusted boot with fTPM + Secure Boot re-enablement (month 3+), 26.04 migration, Hadron migration (~month 4).
