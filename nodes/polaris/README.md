# polaris — Mac mini (always-on service host)

Status: active. OS: macOS.
Role: unattended service host. Runs `mowa` (mauromorales/mowa) as a launchd agent, nobody at the keyboard.
Last updated: 2026-08-28.

Private counterpart with the full setup detail: `docs/runbooks/polaris-service-host.md`
in the steering repository (mission-control, private).

## Why an "agent," not a "daemon"

`mowa` needs a GUI login session, so it installs as a launchd **agent**, not a
daemon. That drives everything below: the machine must log in on its own
after every boot, with nobody there to type a password.

This trades some physical security for unattended availability — a login
that starts itself is a login anyone at the machine can also reach. Treat it
like any other unattended server: physical access to the box is physical
access to the account.

## 1. Power behavior — restart after a power cut, never sleep

```sh
sudo pmset -a autorestart 1 sleep 0 displaysleep 0 disksleep 0 womp 1
```

- `autorestart 1` — the machine starts up again after a power failure. This is the setting that matters most for an unattended box.
- `sleep 0 displaysleep 0 disksleep 0` — never sleep.
- `womp 1` — wake on LAN.

## 2. Automatic login

Required because the service is a launchd agent (see above). System Settings →
Users & Groups, after FileVault is off. Or:

```sh
sudo sysadminctl -autologin set -userName <user> -password 'PASSWORD'
sysadminctl -autologin status
```

## 3. Screen lock off

Automatic login only gets you a session once. A screen lock takes it away
again. System Settings → Lock Screen → "Require password after screen saver
begins" → **Never**, screen saver set to **Never**.

## 4. Launchd agent

```sh
mowa install                             # writes the plist and bootstraps the agent
```

On first run, macOS prompts for permission to drive Messages and Reminders.
Grant those at the console before leaving the machine unattended — a headless
session can't answer that prompt later.

## 5. Verification

```sh
pmset -g custom | grep -E 'autorestart|sleep|womp'
launchctl list | grep mowa
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:8080/
```

`launchctl list` — a number in the PID column means the agent is running; `-`
means it is not.

## 6. The test that actually counts

Every setting above can read correct on a machine that never comes back:

1. Pull the power cord.
2. Plug it back in.
3. Touch nothing.
4. From another machine on the same network: `curl http://polaris.local:8080/`.

If that returns, the machine is done.

## Troubleshooting

**No keyboard at the login window.** Click the user avatar first — the
password field only appears then. Check Accessibility → Mouse Keys and Slow
Keys before suspecting the keyboard itself; either setting makes a working
keyboard look completely dead while the mouse still works.

**Reading CPU right after a spike.** `ps`'s `%CPU` is averaged over a
process's whole lifetime, so it lags. `top -l 1` shows `0.0%` for everything,
because it has no earlier sample yet. Use two samples and read the second:

```sh
top -l 2 -o cpu -n 8 -stats pid,cpu,command | tail -10
```

**Reading memory.** `top`'s "unused" figure excludes cached and purgeable
pages and looks alarming when nothing is wrong. `memory_pressure -Q` and
`sysctl vm.swapusage` are the numbers that matter; zero swap used means
memory is not the problem.
