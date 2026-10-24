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

**Live boot.** On a live boot (`/run/cos/live_mode` or `/run/cos/uki_install_mode` exists), `live-oem.yaml` locks the default
`kairos` user, removes the root autologin on the local consoles, and enables a login prompt on the
serial port `ttyS4`. The Kairos web installer is off (`agent.yaml`). The image ships no user and no
key. To log in, boot it with your own cloud-config, for example the config of an ISO built from the
image. Create a user other than `kairos`: the image keeps `kairos` locked, and it locks it again after
your config ran. It does nothing on an installed system or in recovery.

**Container toolkit.** The image carries `nvidia-ctk` and `nvidia-cdi-hook` (NVIDIA container toolkit
1.20.1, the `nvidia-container-toolkit-base` package, checked against the pinned sha256 of the release
archive) in `/usr/bin`. A Kubernetes device plugin writes the CDI spec at run time and points
containerd at the hook. The toolkit version must match the one the device plugin chart bundles. The
version is the build argument `NVIDIA_CTK_VERSION`. `test-image.sh` checks that both binaries exist and
that `nvidia-cdi-hook --version` reports that version.

**Runtime for the device plugin pod.** The image also carries `nvidia-container-runtime` (same toolkit
package) and a containerd drop-in, `/etc/k0s/containerd.d/nvidia.toml`, written from
`nvidia-runtime-oem.yaml`. It adds a runtime handler `nvidia`. The device plugin pod runs with
`runtimeClassName: nvidia`, so the runtime gives it the GPU device nodes and the driver libraries and the
pod needs no privileged mode. GPU pods use no runtime class; the plugin hands them the GPU through CDI.

**Two links.** `/usr/sbin/ldconfig` points to `/usr/bin/ldconfig`: the CDI hook opens `/sbin/ldconfig`
(`/sbin` is `usr/sbin`) to rebuild the library cache in a GPU container. `/usr/lib64/libnvidia-ml.so.1`
points to the driver library in `/usr/libc/lib`: the device plugin looks for NVML only in the standard
lib folders under its driver root. `test-image.sh` checks both links, and that `/usr/sbin` is still the base
image's real directory (a replaced one hides `modprobe` and breaks the CNI).

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

- The Kubernetes device plugin. The image has the toolkit hook, but a pod needs the plugin to ask for the GPU.
- Secure Boot signing. The modules are unsigned, so use a GRUB install, not a UKI with
  Secure Boot.
