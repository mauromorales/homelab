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
