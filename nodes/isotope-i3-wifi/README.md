# Isotope i3 with Broadcom brcmsmac Wi-Fi firmware

Isotope `i3-v0.0.16` on an Intel MacBook Air logs
`brcmsmac: fail to load firmware brcm/bcm43xx-0.fw`, because the image selects
`brcm/brcmfmac` firmware only. This node layers the two brcmsmac files from
linux-firmware on the published image and builds the installer ISO with
Isotope's own `auroraboot/build.sh`.

Run the workflow by hand (`workflow_dispatch`); the ISO is a build artifact.
After the Wi-Fi works on the real machine, the one-line change goes upstream
to `kairos-community/isotope` (add `brcm/bcm43xx` to the firmware patterns)
and this node is removed.

It also carries a changed `/usr/bin/start-desktop`. Flatpak apps such as
Chromium failed on the i3 session with "Authorization required, but no
authorization protocol specified", because the sandbox cannot read the X
cookie that ly keeps at `$XDG_RUNTIME_DIR/lyxauth`. The script now runs
`flatpak override --user` with that file at each login.
