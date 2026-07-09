## Raspberry Pi 4 image

This node ships a **raw disk image**. Raw images exceed GitHub's 2 GiB
per-file release-asset limit, so the image is not attached to this release —
it is published as an OCI artifact in quay instead:

- `quay.io/mauromorales/thuroros:__TAG__-img` — the raw disk image (flash this)
- `quay.io/mauromorales/thuroros:__TAG__` — the container image (for `kairos upgrade`)

### 1. Extract the raw image (Docker only, no luet)

The `-img` tag is a `scratch` image that just carries the raw file under
`/artifacts`, so you can pull it out with plain Docker:

```bash
export IMAGE=quay.io/mauromorales/thuroros:__TAG__-img
container=$(docker create "$IMAGE" noop)   # scratch image: dummy arg, never executed
docker cp "$container:/artifacts/." .
docker rm "$container"
```

The `.raw` file lands in the current directory.

### 2. Flash it to the SD card

```bash
sudo dd if="$(ls kairos-*-rpi4-__TAG__.raw)" of=/dev/mmcblk0 bs=4M status=progress conv=fsync
sync
```

> Replace `/dev/mmcblk0` with your SD card device, and double-check it's the
> card — not a system disk — before running `dd`.
