# Runbook: AdGuard Home DNS on the `homeassistant` node

Host: the Raspberry Pi 4 named `homeassistant` in the hardware table, running Home
Assistant OS from a USB SSD. The AdGuard Home add-on runs on it and serves DNS for every
device in the house. It is reached through Home Assistant's ingress — **Settings →
Add-ons → AdGuard Home → Open Web UI** — so it has no port of its own, and a port scan of
the host shows only 53 and the Home Assistant UI.

This runbook exists because Safari looked broken on two devices for weeks, Chrome looked
fine on the same network, and the cause was one dropdown in AdGuard Home.

## The rule this runbook is really about

**When two devices fail the same way, suspect what they share, not what they run.**

A Mac and an iPhone both showed it, which reads at first like evidence against the
browser they have in common. It is the opposite. They also share a network, and on that
network they share exactly one DNS server. "Both run Safari" needs Safari to be broken on
two operating systems. "Both use the same resolver" needs one box to be misconfigured.
The shared infrastructure is the cheaper hypothesis, and it was the right one.

The corollary is the actual bug, and it generalises to any DNS filter:

**A filter that answers `0.0.0.0` has not blocked the name. It has pointed the client at
an address that never answers.** `NXDOMAIN` ends the request in microseconds. `0.0.0.0`
is a syntactically valid A record, so a client dutifully opens a TCP connection to it and
waits out the full timeout. The page stalls instead of failing. Blocking should *fail*,
not *resolve*.

## The case

**Symptom.** Safari on macOS and iOS stalled on page loads, on and off, for weeks. Chrome
on the same machine and the same network never did. Restarting the DNS service appeared
to fix some sites and never fixed others.

**What was blamed, wrongly:** Safari, on both platforms, because it was the visible
common factor.

**The evidence that settled it.**

- The Mac had exactly **one** nameserver configured, the `homeassistant` node, with no
  secondary. So did the phone, by DHCP. That is the real common factor.
- Blocked names came back as `0.0.0.0` for A and `::` for AAAA, with `status: NOERROR`
  and `ANSWER: 1`. A valid answer, not a refusal.
- The blocked-response TTL was 10 seconds, so every blocked tracker on a page was
  re-queried every 10 seconds.
- Uncached query times were 21, 25, 26, 137 and 165 ms. The long tail was upstream
  latency with no parallelism to hide it.
- Roughly 60 domains were checked against the filter. **The blocklist itself was clean:**
  no certificate or OCSP endpoint, no push, no iCloud core service, no software update,
  no captive-portal check, no CDN. Only advertising and telemetry, as intended. The
  blocklist was never the problem, and an allowlist would not have fixed anything.

**Root cause.** AdGuard Home's **Default** blocking mode returns `0.0.0.0`/`::` for
hosts-style rules. Tracker-heavy pages therefore accumulated one TCP timeout per blocked
resource; clean pages were unaffected. That is the on-again-off-again pattern, and it
tracks the page's tracker count, not the network.

## Why Chrome is a useless control for this

Chrome ships its own resolver and its own cache, and its network stack treats a `0.0.0.0`
answer as an immediate error rather than an address to dial. WebKit lets the connection
attempt proceed to the timeout. **Chrome hides exactly this misconfiguration.**

So "it works in Chrome" is not evidence that DNS is healthy, and a browser comparison
cannot discriminate here. Query the resolver directly with `dig` instead, and read the
status line rather than the rendered page.

**A cache flush is the other useless test.** `sudo killall -HUP mDNSResponder` clears
cached answers. A name on the blocklist is re-blocked on the very next query, so it can
never be fixed by flushing. "Some names recovered and others never did" is the signature
of a filter, not of a stale cache — the ones that recovered were never blocked.

## The settings that matter

All are under **Settings → DNS settings** in the AdGuard Home add-on.

| Setting | Wrong value | Correct value | Why |
|---|---|---|---|
| **Blocking mode** | Default (`0.0.0.0`/`::`) | **NXDOMAIN** | The fix. Blocked names fail instantly instead of stalling on a TCP timeout. |
| **Blocked response TTL** | 10 | **300** | Stops every blocked tracker being re-queried every 10 seconds. |
| **Fallback DNS servers** | empty | two public resolvers | Redundancy *inside* AdGuard, where filtering still applies. See below. |
| **Upstream mode** | sequential | **Parallel requests** | Queries every upstream at once, takes the first answer, removes the latency tail. |
| **Optimistic caching** (Cache configuration) | off | **on** | Serves the cached answer immediately and refreshes behind the request. |

Cache size was also raised from the 4 MB default to 32 MB (`33554432`).

**Measured effect**, 15 uncached queries before and after: a 21–165 ms spread became
avg 26 ms, max 55 ms. Cached queries answer in 3–4 ms, which is the Wi-Fi round trip to
the Pi and cannot go lower.

## Verifying

The blocking mode is the one that matters, and one command settles it:

```
dig @homeassistant.local doubleclick.net A | grep -E "status:|ANSWER:"
```

Correct: `status: NXDOMAIN` with `ANSWER: 0`.
Broken: `status: NOERROR` with `ANSWER: 1` and a `0.0.0.0` record.

AdGuard identifies itself in the authority record of a blocked answer, which is a quick
way to confirm which filter you are actually talking to:

```
SOA  fake-for-negative-caching.adguard.com.
```

Read the blocked-response TTL from the same record — it is the SOA's own TTL field, and
it should be 300:

```
dig @homeassistant.local doubleclick.net A | awk '/SOA/{print "TTL:", $2}'
```

Then confirm the filter did not take anything real down with it. Any name printing
nothing here is a regression:

```
for d in apple.com icloud.com github.com ocsp.apple.com ocsp2.apple.com \
         captive.apple.com time.apple.com courier.push.apple.com \
         setup.icloud.com gdmf.apple.com swcdn.apple.com \
         fonts.gstatic.com cdnjs.cloudflare.com js.stripe.com; do
  printf "%-28s %s\n" "$d" "$(dig @homeassistant.local +short "$d" A | tail -1)"
done
```

## What not to do

- **Do not add a second DNS server on a client, or as a secondary in DHCP.** macOS and
  iOS do not reliably prefer the first entry, so a share of queries would go straight to
  the public resolver and skip the filter. The result is *inconsistent* blocking, which
  is harder to diagnose than no blocking at all. Redundancy belongs in AdGuard's
  **Fallback DNS servers** field, where filter rules are still applied before any
  upstream is consulted. Every client should point at `homeassistant.local` and nothing
  else.
- **Do not enable IPv6 on the router to "help" this.** The lab has no IPv6 today. Turning
  it on makes the router advertise its own IPv6 resolver over RA, and clients then route
  around the filter entirely. That is a bypass, not a fix, and it was not related to this
  fault.
- **Do not add allowlist entries speculatively.** The blocklist here was verified clean
  against ~60 domains. Allowlist a name only after `dig` shows that name returning
  `NXDOMAIN` *and* a real thing is broken by it.
- **Do not diagnose this from a browser.** See the Chrome section above.

## Known noise — do not chase these

- **`gateway.push.apple.com` returns `NXDOMAIN`.** Public resolvers return `NXDOMAIN` for
  it too. Apple retired the name. The push endpoints that matter — `courier.push.apple.com`,
  `1-courier.push.apple.com`, `api.push.apple.com`, `init.push.apple.com` — all resolve
  normally, and push works. Verify against a public resolver before calling any empty
  answer a regression.
- **Apple telemetry names are blocked and that is intended.** `metrics.icloud.com`,
  `securemetrics.apple.com`, `supportmetrics.apple.com`, `iadsdk.apple.com` and
  `news-events.apple.com` are all on the blocklist. None of them is required for Safari,
  iCloud, push or updates.
- **`cdn.segment.com` is blocked and is the only borderline entry.** It is analytics, but
  some sites load chat widgets and checkout flows through it. Allowlist it if a site
  misbehaves, not before.
- **A different A record than a public resolver returns is not a fault.** Apple and
  Google front-ends are geo-steered, so `configuration.apple.com` and
  `init.itunes.apple.com` legitimately differ between resolvers.

## Recovering when the Pi is down

There is one DNS server for the house, so the `homeassistant` node is a single point of
failure for name resolution. AdGuard's fallback servers cover a failed *upstream*; they
do not cover the Pi itself being off.

If the node is down and the house needs DNS immediately, set a public resolver on the one
affected machine, and **put it back afterwards**:

```
sudo networksetup -setdnsservers Wi-Fi 9.9.9.9
sudo networksetup -setdnsservers Wi-Fi empty      # revert to DHCP, i.e. back to the Pi
```

`empty` is the literal argument that restores DHCP. Leaving a machine pinned to a public
resolver is the "inconsistent blocking" trap above, arrived at by a different route.
