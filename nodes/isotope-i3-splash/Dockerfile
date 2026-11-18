# Isotope i3 with a changed boot splash layered on a release, for testing.
#
# The splash is built from the splash/ directory the workflow copies in, with
# the same Hadron toolchain image Isotope builds it with, so it links against
# the same libc as the image it lands in. It goes to /usr/bin/kairos-splash,
# which kairos-splash.service runs before the login screen. The copy inside the
# initramfs is baked at install time and is NOT replaced by this layer, so the
# change shows only on that service's run, not during early boot.
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
