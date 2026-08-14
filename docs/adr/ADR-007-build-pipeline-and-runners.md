# ADR-007: Where homelab images get built

Date: 2026-08-14
Status: Proposed
Deciders: Mauro
Related: [ADR-001](ADR-001-agent-host-os.md) (the agent host), [ADR-006](ADR-006-rack-switch.md)
(rack switch and the netboot segment)

## Context

Every node image is built in GitHub Actions: four `build-<node>.yaml` workflows for
testing, and `release.yaml` for tagged releases. All of them run on GitHub-hosted runners,
and two jobs — `thuroros` and one release job — run on `ubuntu-24.04-arm`.

**This is free today only because the repository is public.**

Two separate motivations push at it.

### Motivation 1: keeping the option to make the repository private

An earlier plan to make `homelab` private was dropped, partly because GitHub-hosted
minutes would start being billed. That objection is answerable, and it should be answered
rather than left as a permanent veto on the visibility question.

### Motivation 2: dogfooding, which is the better reason

Mauro maintains Kairos. **A Kairos maintainer building Kairos images on his own hardware
is the user path**, and the GitHub-hosted pipeline hides every problem that path has. Bugs
found by running the factory locally are upstream tickets, which is the point of the
experiment rather than a side effect.

There is a further ambition attached: a build pipeline that is GitOps-shaped and
Kubernetes-native, rather than a hosted CI product.

### What was verified, and what was not

**Self-hosted runners are free.** GitHub's billing documentation states that "GitHub
Actions usage is free for self-hosted runners and for public repositories", and
self-hosted minutes do not count against the included quota on private repositories.
Checked 2026-08-14.

**Two costs survive that**, and both are specific to this repository rather than general:

1. **The arm64 jobs.** `runs-on: ubuntu-24.04-arm` is a GitHub-hosted arm64 runner. Those
   are free for public repositories and billed for private ones. Self-hosting arm64 needs
   arm64 hardware: the spare Raspberry Pi 5 now, the Jetson Thor when it arrives.
2. **Artifact storage.** Every build passes `summary_artifacts: true`, and OS images are
   measured in gigabytes. Included artifact storage is 500 MB on Free and 1 GB on Pro,
   **shared with GitHub Packages**. Free compute does not imply free storage. **This one is
   not fully established** — the documentation was ambiguous on whether artifacts produced
   by self-hosted runners are exempt, so it must be measured on the real billing page
   before anyone relies on it.

## Decision

**Keep GitHub-hosted runners for as long as the repository is public. Change nothing about
the pipeline.**

**Pursue the dogfooding separately, by building an image by hand on `midnight`** — the
`docker build` stage, then the factory stage through AuroraBoot — and write down what that
takes. That is the user path. A self-hosted runner is not.

### Why a self-hosted runner is the wrong tool for the stated goal

An earlier draft of this ADR recommended self-hosted runners in a VM, on dogfooding
grounds. **That reasoning does not hold**, and the objection is Mauro's:

- **On cost, it buys nothing.** Hosted runners are already free on a public repository.
- **On dogfooding, it buys almost nothing.** A self-hosted runner executes the same
  workflow, calling the same reusable factory workflow, with the same inputs. It moves the
  compute and changes nothing a Kairos user would experience. The differences are disk
  size, preinstalled tooling and Docker version — real, but not the thing worth testing.
- **It adds a failure mode**: "the build did not run because the VM was off."

**The genuinely untested path is the one `AGENTS.md` already names**: the factory stage is
"CI-only; there is no simple local equivalent". That sentence is the dogfooding target. A
runner leaves it exactly as untested as it is today, because the runner still invokes the
CI path.

### When this decision changes

Three triggers, any one of which makes self-hosted runners the right answer:

1. **The repository goes private.** Hosted minutes and hosted arm64 both start being
   billed. This is the only trigger that is about money.
2. **Hosted runners hit their limits.** Image builds are large and hosted runners ship
   about 14 GB of free disk. If builds start failing on space, or take long enough to
   obstruct iteration, self-hosting is the fix.
3. **The cluster exists and can host CI**, at which point the interesting move is
   Kubernetes-native rather than a self-hosted GitHub runner — see below.

Until one of those happens, this ADR's answer is to leave a working, free pipeline alone.

## Alternatives considered

### Self-hosted runners in a VM on `midnight` — rejected for now, and it was the first draft's recommendation

Correct for a private repository, and premature for a public one. The reasoning is in the
Decision section above, because the rejection is the substance of this ADR rather than a
footnote to it.

Keep the shape in mind for when a trigger fires: a VM rather than the host, because a
runner executes whatever the workflow says and `midnight` holds `mauro-agent`'s
credentials and every clone. That constraint does not expire.

### Forgejo or Gitea Actions, self-hosted — rejected, and not on technical grounds

Attractive: full independence from GitHub billing, a forge that fits the GitOps direction,
and Actions-compatible workflows.

**It conflicts with how this project is reviewed.** Pull requests on GitHub are the review
loop — the steering repository's own rules make every change a PR because that is how
Mauro reviews from a phone. Moving the forge moves that loop to a service that has to be
reachable, backed up, and maintained by the person who is also the only reviewer.

**A self-hosted forge is a bigger commitment than a self-hosted runner, and it is a
different decision.** If it is wanted later, it deserves its own ADR rather than arriving
as a side effect of a CI change. Note that Gitea's runner could be adopted without moving
the forge, which is the cheap half of this idea.

### Kubernetes-native CI — Tekton, Argo Workflows, or similar — deferred, not rejected

**This is the stated destination**, and it cannot be built yet. The cluster does not exist:
[ADR-005](ADR-005-home-assistant-host.md) records that as a live fact, and it is why the
Kubernetes learning work was pointed at Immich and Frigate rather than at household
control.

Two things to know before it is attempted:

- **Image builds want privileged containers.** Building OS images inside Kubernetes is not
  the gentle first workload for a new cluster.
- **A build pipeline that lives on the cluster cannot easily build the cluster's own
  nodes.** Bootstrapping order matters here in a way it does not for an application.

**Revisit when the cluster is multi-node and is no longer the thing being deliberately
broken** — the same condition [ADR-005](ADR-005-home-assistant-host.md) set for moving
Home Assistant onto it.

### Build locally with scripts and no CI at all — rejected

The simplest form of "build locally", and it removes more than it saves: no per-pull-request
validation, and no signal when a Dependabot bump breaks a base image. It replaces a
pipeline with remembering to run one.

**Self-hosted runners keep the pipeline and move only the compute**, which is the part
worth moving.

## Consequences

### Positive

- Nothing to build, maintain, or keep switched on. The pipeline that works keeps working
- The dogfooding effort points at the part that is actually untested — the local factory
  path — instead of at a runner that would still call CI
- The triggers for revisiting are written down, so the question returns on evidence rather
  than on a hunch

### Negative and accepted trade-offs

- **The visibility question stays blocked**, and that is now explicit rather than implied:
  going private means solving arm64 and storage first
- No progress toward the GitOps and Kubernetes-native ambition. Recorded, not met
- Builds keep depending on GitHub. If hosted runners change terms again, this ADR is what
  gets re-read

### Open questions

1. **Can the factory stage be run locally at all, and what does it take?** This is the
   dogfooding question, and it is worth a real attempt regardless of what CI does.
2. **How much artifact storage does a full release consume?** Only matters if trigger 1
   fires, and it should be measured before that decision rather than during it.
3. **Are hosted runners close to their disk limit today?** If a build is already near
   14 GB, trigger 2 is nearer than it looks.
