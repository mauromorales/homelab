# Runbook: reaching `home.arpa` services and the LAN over Tailscale

Goal: from off the home network (mobile data, a coffee shop, anywhere), reach
`*.home.arpa` names (see homelab ADR-009, private steering repository) and
other home-LAN devices, without a full-tunnel VPN for all traffic.

LAN is `192.168.68.0/22` (gateway `192.168.68.1`), confirmed from `midnight`'s
own interface — do not assume `/24`, it is wider than that.

## Two separate mechanisms, both needed

1. **Split DNS** — makes `*.home.arpa` names resolve over the tailnet, by
   forwarding just that domain to the LAN's AdGuard resolver.
2. **Subnet router** — makes the `192.168.68.0/22` range itself reachable, for
   anything addressed by raw LAN IP rather than a `.home.arpa` name.

Split DNS alone does not make the wider LAN reachable, and a subnet route
alone does not make `.home.arpa` names resolve unless a global nameserver
override would otherwise intercept them. Both come from Tailscale's admin
console: <https://login.tailscale.com/admin/dns>.

An **exit node** (routes *all* traffic through a home device, not just LAN
traffic) is a separate, optional third mechanism — enabled on the same
devices below but left off by default. Use it only when you deliberately want
full-tunnel behavior.

## 1. Split DNS for `home.arpa`

Admin console → DNS → **Add nameserver**:

- Nameserver: `192.168.68.59` (AdGuard, on the `homeassistant` Pi)
- Toggle **Restrict to domain** → enter `home.arpa`
- Save

This is independent of the subnet router below — tailnet-wide, not tied to
any one device being up as an exit node.

## 2. Subnet router — primary: `homeassistant` (Pi4, HAOS)

- HA UI → Settings → Add-ons → Add-on Store → install the **Tailscale**
  add-on (Home Assistant Community Add-ons). Do not use HAOS's built-in
  Settings → System → Network → Tailscale toggle instead — that integration
  has no route/exit-node flags.
- Add-on Configuration tab:
  - `advertise_routes: 192.168.68.0/22`
  - `advertise_exit_node: true` (optional — see above)
- Controls tab: turn on **Watchdog** (auto-restart on crash — this add-on is
  now LAN-critical). **Start on boot** is already on by default; **Auto
  update** / **Show in sidebar** are optional.
- Start the add-on, open its log for the login URL, sign in.
- Admin console → the `homeassistant` machine → **Review** (Subnets) and
  **Edit** (Exit Node) → approve `192.168.68.0/22` and, if enabled, "Use as
  exit node". A device only advertising routes does not route anything until
  approved here.

## 3. Subnet router — backup: `stardust` (Mac, always-on, survives power loss)

- Confirm the **standalone** Tailscale build, not the Mac App Store one:
  menu bar icon → Settings → About. The App Store build cannot do subnet
  routing or exit-node (no IP forwarding permission). Reinstall from
  <https://tailscale.com/download/mac> if needed.
- If the CLI isn't on `PATH`, either use the menu bar's "Install Tailscale
  CLI" item, or call the bundled binary directly:
  `/Applications/Tailscale.app/Contents/MacOS/Tailscale`.
- `tailscale up` requires restating every non-default flag already in effect
  (e.g. `--accept-routes`) or it refuses with an explicit error naming the
  full command to run — copy that rather than guessing:

  ```
  sudo tailscale up --advertise-exit-node --advertise-routes=192.168.68.0/22 --accept-routes
  ```

- Approve the route (and exit node, if used) for `stardust` in the admin
  console, same as step 2.

Two subnet routers advertising the same range is intentional redundancy, not
a conflict — Tailscale clients use whichever advertiser is reachable.
Failover is not automatic like DNS failover; it just means the LAN stays
reachable if one of the two devices is down.

## 4. Using it from off the home network

- `*.home.arpa` names resolve automatically — no client action.
- Raw LAN IPs in `192.168.68.0/22` are reachable automatically once a route
  is approved — no client action.
- Full-tunnel (all traffic via home) is opt-in per session: Tailscale menu →
  select exit node → `homeassistant` or `stardust`.

Verified working 2026-09-20: `home.arpa` name resolution and a LAN IP in
range both reachable from a device off the home network, no exit node
selected.
