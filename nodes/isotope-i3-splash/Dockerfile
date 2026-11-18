# Isotope i3 with a changed boot splash layered on a release, for testing.
#
# The splash is built from the splash/ directory the workflow copies in, with
# the same Hadron toolchain image Isotope builds it with, so it links against
# the same libc as the image it lands in. It goes to /usr/bin/kairos-splash,
# which kairos-splash.service runs before the login screen, and the initramfs
# is regenerated so the copy that draws the disk passphrase screen is the new
# one too. Checked on v0.0.22: the regenerated initrd has the same file list as
# the shipped one, and its kairos-splash is the new binary.
#
# Temporary: the change goes upstream to kairos-community/isotope, and this node
# goes away once a release carries it.
ARG HADRON_VERSION=v0.6.5
ARG BASE_IMAGE=ghcr.io/kairos-community/isotope:i3-v0.0.22

FROM ghcr.io/kairos-io/hadron-toolchain:${HADRON_VERSION} AS splash-build
COPY splash/ /build/splash/
RUN cd /build/splash && make clean && make && make test && \
    ./isotope-splash | grep -q ISOTOPE && \
    ./isotope-splash --render=/tmp/frame.ppm --size=640x400 --at=2 && \
    [ "$(stat -c %s /tmp/frame.ppm)" -eq $((15 + 640 * 400 * 3)) ]

FROM ${BASE_IMAGE}
COPY --from=splash-build /build/splash/isotope-splash /usr/bin/kairos-splash

# dracut finds the splash through the 50kairos-splash module already in the image.
RUN dracut -f /boot/initrd "$(cat /boot/kernel-release)"
