# ADR-002: GPU node as the next hardware acquisition

Date: 2026-08-12
Status: Accepted
Deciders: Mauro

## Context

Kairos users run GPU nodes at the edge. There is currently no hardware anywhere in the fleet on which to test that an NVIDIA driver bundle survives an immutable A/B upgrade. Six machines (MacBook Air M5, Mac mini M4, Mac mini M2, Beelink SER5, HP ProDesk 600 G4 Mini, work laptop) and not one has a PCIe slot capable of hosting a graphics card.

There is also a dated commitment. The Codemotion Milan talk, *"Your GPU node is a snowflake: shipping AI infrastructure as a versioned artifact"*, is accepted and scheduled. Its demo arc is a healthy Kairos GPU node running inference, deliberately broken by a driver/CUDA mismatch, then atomically rolled back. Experience to date is software-side only; no driver has been installed on real GPU hardware.

The justification is narrow and worth stating plainly: **a CUDA GPU in a chassis cheap enough to destroy, running Kairos.** Everything else such a machine offers duplicates existing capacity.

In particular, **trusted boot is not a reason to buy.** Secure Boot, UKI, TPM 2.0 and dm-verity work on machines already owned. An earlier draft listed trusted boot testing as a benefit; it isn't one, and treating it as such inflated the case.

Local inference, Whisper offload, and photo captioning are genuine secondary uses but none would justify the acquisition alone.

This ADR covers a different machine from [ADR-001](ADR-001-agent-host-os.md), which covers the agent host (midnight, the Beelink SER5). The two do not conflict: different machine, different job.

### Why not rent

Cloud GPU providers overwhelmingly restrict customers to a supported distro list. A demo whose subject is replacing and rolling back the operating system is not portable to a host where the OS is the provider's. Cherry Servers is the known exception, but building a conference demo on one vendor's IPMI policy is a single point of failure eight weeks out. Rental remains a fallback, not a substitute.

## Decision

Acquire a **used workstation-class machine with a working CUDA GPU** as the next hardware addition. Second-hand deliberately: the point is a GPU in a chassis cheap enough to treat as expendable, not a capable inference server.

The chosen class is an **HP Z4 G4 generation Xeon W workstation with a Quadro RTX 4000 8GB**, on these requirements:

- A CUDA-capable GPU that current CUDA still supports (Kepler-era cards are out, CUDA 12 dropped them)
- PSU headroom and PCIe auxiliary power for a future card
- Onboard Ethernet, since the machine joins a k3s cluster
- TPM 2.0 present
- Bought from an incorporated seller, online rather than in store, so statutory conformity rights and the 14-day withdrawal period both apply

**Defer any GPU upgrade** until a named workload requires it.

Purchase specifics, meaning vendor, price, and the priced alternatives, are recorded privately in mission-control ADR-011.

## Trade-off analysis

**The card is consumable; the chassis is the asset.** What persists is two x16 slots, 48 PCIe lanes, a 750W supply and auxiliary power. The card in it now is the cheapest thing about it.

**8GB is enough for the stated purpose.** Driver install, kernel modules, container toolkit, deliberate CUDA mismatch and rollback are all architecture-independent. Milan does not care that the card is Turing. Turing's limits bite on inference *serving* work (no bf16, no fp8, second-class in vLLM), which is not the differentiator being built here.

**Any GPU upgrade is a replacement, not an addition.** Two constraints, either sufficient on its own:

1. *Power.* Most RTX 5060 Ti models need a single 8-pin, fed by the bundled dual-6-to-8 adapter, consuming both of the Z4's 6-pins.
2. *Software.* Mixing sm_75 and sm_120 means compiling for both, and vLLM tensor parallel effectively requires matched cards. llama.cpp will split layers but runs at the slower card's pace.

The upgrade destination is **Blackwell, not Ada**: a current-generation 16GB card is both cheaper and newer than a previous-generation professional 16GB one. When that happens, the Turing card gets sold.

**The chassis has a ceiling of roughly 225W to graphics.** A 6-pin supplies 75W and the PCIe slot another 75W, so 2x 6-pin plus the slot is the real budget. The 750W PSU rating is not the constraint; the connectors are.

| Card | Power | Fits? |
|---|---|---|
| RTX 5060 Ti 16GB | ~180W | Yes, dual-6-to-8 adapter, spec-correct |
| RTX PRO 2000 Blackwell 16GB | ~70W | Yes, comfortably |
| RTX PRO 4000 Blackwell 24GB | ~140W | Yes |
| RTX PRO 4500 Blackwell 32GB | ~200W | Yes, at the limit |
| RTX 5070 Ti / 5080 / 5090 | 300-575W | **No**, needs 2x 8-pin or 12VHPWR |

The ceiling excludes gaming flagships and includes the entire professional Blackwell range up to 32GB. Given the workload is node lifecycle rather than inference throughput, that exclusion is unlikely to bind. It does mean paying the professional-card premium for anything above 16GB.

**Never bridge the gap with Molex- or SATA-to-8-pin adapters.** If a card above ~225W is ever genuinely needed, the answer is a second machine, not a PSU swap: the Z4 G4 uses an HP proprietary unit that is not a standard ATX part.

**What this machine is not for.** Local inference will not displace hosted models. 8B-class models sit below the small hosted tiers, and Sonnet-class capability needs 48GB+ of VRAM. Local models here are scoped to classification, routing, Whisper, embeddings, reranking and vision.

**Architecture reference:** Pascal (sm_60), Turing (sm_75), Ampere (sm_86), Ada (sm_89), Blackwell (sm_120). bf16 from Ampere; fp8 from Ada.

## Consequences

**Easier**

- Kairos NVIDIA driver testing under immutable A/B upgrades becomes possible for the first time
- The Milan demo stops depending on a colleague's vacation schedule or a rental provider's distro list
- Whisper, embeddings, reranking and local photo captioning become available without cloud round-trips
- Website scraping, tagging and triage with a small model becomes a real cluster workload: a scraper Job, a queue, and an inference Deployment pinned to the GPU node
- Content follows: blog post, video, plausibly a second talk

**Harder**

- Seventh machine, ~70W idle, and a non-trivial annual electricity cost if always on
- No BMC. Xeon W on C422 has no AMT, so a JetKVM plus a network-controlled plug is needed for remote recovery
- Turing is a depreciating asset; llama.cpp/Ollama is the near-term path, not vLLM
- Graphics power is capped at ~225W by the two 6-pin connectors, so mid-range and professional cards only, with no path to a flagship without a second machine
- 8GB constrains context more than model size. Expect 8-16k usable context on an 8B model at Q4

**The identified failure mode**

The machine arrives and the GPU workstreams don't start, leaving a slow Xeon that duplicates the Beelink. The mitigation is a dated commitment, not further analysis: **first driver install, deliberate CUDA mismatch, and rollback within one week of delivery.** Slipping that date is the signal that no further hardware spend is warranted.

## Action items

1. [ ] On arrival, before installing anything: boot a Kairos live USB and verify POST, TPM 2.0 in BIOS, **onboard Ethernet**, both 6-pin connectors present, and that the GPU enumerates. The listing showed "Lan poort: Nee", almost certainly a template error, but the cluster depends on it. If it is not an error, the 14-day withdrawal period is the fallback
2. [ ] Check whether the ProDesk 600 G4 Mini has AMT (Ctrl+P at boot for MEBx); if so, no KVM needed there
3. [ ] Test local inference on the Mac mini M4 first (Ollama, Qwen3 14B) to validate the workflow at zero cost
4. [ ] **Week 1: driver install by hand, deliberate mismatch, rollback.** The gate on everything else
5. [ ] Defer the 16GB Blackwell upgrade until a named workload requires it. Most models need a single 8-pin, so use the bundled dual-6-to-8 adapter, never a single-6-to-8
