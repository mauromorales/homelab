# Kairos Hadron NVIDIA amd64

A [Kairos](https://kairos.io) Hadron image with the NVIDIA open kernel modules and the
userspace driver, for an amd64 machine with an NVIDIA GPU. It carries the k0s flavor of
Hadron, so the node can join a k0s cluster as a worker.

| | |
|---|---|
| Base | `quay.io/kairos/hadron:v0.5.1-standard-amd64-generic-v4.3.0-k0s-v1.36.4-k0s.0` |
| Driver | NVIDIA 595.91.07, open kernel modules built against the Hadron kernel |
| Image | `quay.io/mauromorales/helios` |
| Tag | `v0.5.1-nvidia-595.91.07-k0s-v1.36.4-r<N>` |

The `Dockerfile` is adapted from the
[`examples/add-packages/Dockerfile.nvidia`](https://github.com/kairos-io/hadron/blob/ce78a7c/examples/add-packages/Dockerfile.nvidia)
example in kairos-io/hadron (commit `ce78a7c`). Changes from that example:

- The base is the k0s image of Hadron v0.5.1.
- `NVIDIA_USERSPACE_VERSION` sets the userspace driver version. It equals `NVIDIA_VERSION`
  by default. A different value builds a deliberate mismatch, for testing a driver rollback.
- NVIDIA's `LICENSE` file is in `/usr/share/licenses/nvidia-driver/`. The NVIDIA driver
  agreement allows distribution with an operating system if the binaries are unmodified
  and the agreement goes to each recipient.
- The serial console is `ttyS4,115200`. Kairos sets `console=ttyS0` for every model it
  does not list, and the Linux serial driver keeps the first serial console only. A machine
  with AMT Serial-over-LAN on `ttyS4` needs the change in the image. A cloud-config
  `extra_cmdline` is appended after the built-in line, so it cannot replace it.

## Check an image

```sh
nodes/helios/test-image.sh <image> [module-version [userspace-version]]
```

The script exports the image and checks, without booting it: the `ttyS4` console line, the
module version, the userspace version, the licence file, and the `livenet` dracut module
in the initrd (the module a netboot needs to fetch its root over HTTP). It exits 1 on any
failed check.

## Build

CI builds the image on every change under this directory, runs `test-image.sh`, and pushes
a tag that expires after 2 days.

For a durable tag, run the workflow `Build Kairos Hadron NVIDIA image` by hand and enter
the tag. For a mismatch build, also enter `nvidia_userspace_version`.

To build on your machine:

```sh
docker build --build-arg JOBS=$(nproc) -t helios:local nodes/helios
nodes/helios/test-image.sh helios:local
```

The kernel module build takes a while. It downloads the Linux source for the exact kernel
version of the Hadron image, because the modules must match that kernel.

## Not in this image

- The NVIDIA container toolkit. Pods cannot use the GPU with this image alone.
- Secure Boot signing. The modules are unsigned, so use a GRUB install, not a UKI with
  Secure Boot.
