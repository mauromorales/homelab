# Isotope i3 with two fixes layered on a release, for testing before they ship.
#
# - tray: the update tray shows `kairos-agent upgrade` output as plain text (no
#   colour-code boxes). Built from the update/ directory the workflow copies in.
# - launcher: start-desktop lets Flatpak apps use the X cookie, so Chromium
#   opens. Copied in by the workflow from Isotope main.
#
# Temporary: both go upstream to kairos-community/isotope, and this node goes
# away once a release carries them. /usr/bin, never /usr/local (an installed
# system mounts COS_PERSISTENT over /usr/local).
ARG BASE_IMAGE=ghcr.io/kairos-community/isotope:i3-v0.0.17

FROM golang:1.25.0-alpine3.22 AS update-build
WORKDIR /src
COPY update/go.mod update/go.sum ./
RUN go mod download
COPY update/ ./
# Only the tray tests: the rest need a dbus-daemon, which this stage lacks.
RUN CGO_ENABLED=0 go test -run 'StripANSI|StreamCommandPlainText' ./... \
    && CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/isotope . \
    && { /out/isotope --nonsense >/dev/null 2>&1; [ $? -eq 2 ]; }

FROM ${BASE_IMAGE}
COPY --from=update-build /out/isotope /usr/bin/isotope
COPY --chmod=755 start-desktop /usr/bin/start-desktop
