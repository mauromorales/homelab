# ThurorOS

Special-purpose OS for the **doorbell relay**: a Raspberry Pi 4 (`thuroros`)
that watches a physical doorbell button and, on a press, relays a notification
to [mowa](https://github.com/mauromorales/mowa) for delivery to my phone.

For how this node fits with the rest of the lab (the end-to-end notification
flow and the `polaris`/mowa side), see the
[node architecture](../architecture.md#doorbell-notifications).

A Kairos image (Ubuntu 22.04 base, `rpi4` model) that self-configures on first
boot from [`cloud-config.yaml`](./cloud-config.yaml).

## Services

Two systemd services, both sharing `/usr/local/doorbell/config.json` — a Kairos
persistent path, so it survives reboots and image upgrades.

### `doorbell`

A Python script (`lgpio`) that monitors GPIO pin 23. On a press it reads the
current recipient and message from the config file and `POST`s them to mowa at
`http://polaris.local:8080/api/messages`. It checks the per-recipient
`results[].success` in mowa's response, and bounds the request with a
`(3.05s, 10s)` timeout so a stuck relay can't freeze the button handler (mowa
sends synchronously through the Messages AppleScript bridge, which can
occasionally wedge — it logs a timeout and keeps running).

### `doorbell-web`

A tiny stdlib HTTP server on `:8080` serving a config page at
`http://thuroros.local:8080/doorbell`. It lets me switch the recipient between
the `admin` and `family` groups and change the message text without rebuilding
the image, writing the shared config file.

## Configuration

`/usr/local/doorbell/config.json`:

```json
{"to": "admin", "message": "🔔 Someone is at the door 🚪"}
```

- **`to`** — `admin` or `family` (must match a group defined in mowa).
- **`message`** — the notification text; defaults to the doorbell message.

Change either at `http://thuroros.local:8080/doorbell`.

## Deployment

Changes to `cloud-config.yaml` trigger an image rebuild
([`build-thuroros.yaml`](../../.github/workflows/build-thuroros.yaml)); the new
image is flashed or upgraded onto the Pi. Releases are cut by tagging (see
[`release.yaml`](../../.github/workflows/release.yaml)).
