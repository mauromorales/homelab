# Isotope with `isotope config`: a bad cloud-config file cannot lock the user out.
#
# Kairos applies the cloud-config in /oem on every boot and skips a file that
# does not load, with the users in it. This image replaces the `isotope`
# command with a build that adds `isotope config` (check, apply, status, diff,
# rollback), a guard that puts back the last good copy of a file that no
# longer loads, and a unit that records each good boot.
#
# The source is a branch of a fork, pinned by commit. It is a prototype:
# nothing here is upstream yet. Any flavor works; the default is sway.
ARG BASE_IMAGE=ghcr.io/kairos-community/isotope:sway-v0.0.22

FROM golang:1.25.0-alpine3.22 AS build
ARG ISOTOPE_REPO=https://github.com/mauro-agent/isotope.git
ARG ISOTOPE_COMMIT=49689ddc7114054f593b1de96e4301553a3d5396
RUN apk add --no-cache git
WORKDIR /src
RUN git init -q . && git remote add origin "$ISOTOPE_REPO" && \
    git fetch -q --depth 1 origin "$ISOTOPE_COMMIT" && git checkout -q FETCH_HEAD
# The same build as Isotope's own Dockerfile: static, and the tests run first.
RUN cd update && CGO_ENABLED=0 go test ./... && \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/isotope . && \
    { /out/isotope --nonsense >/dev/null 2>&1; [ $? -eq 2 ]; }

FROM ${BASE_IMAGE}
COPY --from=build /out/isotope /usr/bin/isotope
COPY --from=build /src/rootfs/system/oem/07_isotope_config_guard.yaml /system/oem/07_isotope_config_guard.yaml
COPY --from=build /src/rootfs/usr/lib/systemd/system/isotope-config-commit.service /usr/lib/systemd/system/isotope-config-commit.service
RUN systemctl enable isotope-config-commit.service && \
    test -L /etc/systemd/system/multi-user.target.wants/isotope-config-commit.service && \
    isotope config help >/dev/null
