# Isotope i3 with a changed screen lock, layered on a release for testing.
#
# i3lock is rebuilt by Isotope's own `i3lock` build stage, from the fork commit
# the workflow pins (it draws the unlock ring from the start, at a size for
# small screens). The workflow builds that stage into the local image
# i3lock-stage:dev and this file copies its output over the release's i3lock.
# The PAM file and the i3 config are untouched.
#
# Temporary: the change goes upstream to kairos-community/isotope, and this node
# goes away once a release carries it.
ARG BASE_IMAGE=ghcr.io/kairos-community/isotope:i3-v0.0.22

FROM ${BASE_IMAGE}
COPY --from=i3lock-stage:dev /i3lock /
