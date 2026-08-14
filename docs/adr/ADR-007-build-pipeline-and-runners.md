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

**Run the builds on self-hosted runners, in a VM on `midnight`, keeping GitHub Actions as
the pipeline. Keep `homelab` public for now, and revisit visibility only after the runners
work and storage has been measured.**

Sequenced, so each step is provable before the next one starts:

1. **One amd64 runner, in a VM on `midnight`.** Change `runs-on` for the amd64 jobs and
   prove a build produces the same artifact as the hosted pipeline does.
2. **One arm64 runner on the spare Raspberry Pi 5**, so `thuroros` builds natively. Move it
   to the Jetson Thor when that machine lands, since the Thor is the faster arm64 builder.
3. **Measure the artifact storage** a full release actually consumes.
4. **Only then re-open the visibility question**, with numbers rather than an assumption.

### The runner goes in a VM, not on the host

**A runner executes whatever the workflow says.** `midnight` holds `mauro-agent`'s
credentials, every clone, and the agent sessions themselves. A private repository with no
fork pull requests makes the risk small, but "small" is not "absent", and the isolation is
cheap.

This also agrees with the machine-level rule that the host is not reconfigured for
experiments. A VM is a thing that can be deleted; a runner installed on the host is not.

## Alternatives considered

### Keep GitHub-hosted runners and keep the repository public — the status quo

Free, working, and zero effort. It is a perfectly good answer to the *cost* question and no
answer at all to the *dogfooding* one, which is the motivation that matters more. It also
leaves the visibility question permanently blocked.

Worth stating: **nothing is broken today.** This ADR is not fixing a failure.

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

- The factory runs on Mauro's own hardware, which is the user path and where upstream bugs
  will surface
- Native arm64 builds instead of hosted arm64 runners
- The visibility question becomes answerable rather than permanently blocked
- No workflow rewrite. `runs-on` labels change; the rest stands
- A first, well-scoped use for the Jetson Thor

### Negative and accepted trade-offs

- **Builds now depend on machines being up.** A hosted runner is somebody else's problem;
  a self-hosted one is not. Expect the failure mode "the build did not run because the VM
  was off"
- Two runners to maintain, on two architectures
- A VM on `midnight` consumes memory that the agent sessions currently have
- **Storage may still be billed** if the repository goes private, and that is unmeasured
- Kubernetes-native CI is deferred, so the GitOps ambition is recorded rather than met

### Open questions

1. **How much artifact storage does a full release consume?** This decides whether the
   visibility question is actually unblocked. Measure before deciding.
2. **Does the Pi 5 have the disk and memory to build an image?** If not, arm64 waits for
   the Thor and `thuroros` keeps using the hosted arm64 runner while the repository stays
   public.
3. **Where does the runner VM's storage live**, given that shared storage is itself
   undecided?
