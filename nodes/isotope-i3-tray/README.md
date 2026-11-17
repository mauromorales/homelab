# isotope-i3-tray

Isotope i3 on a release, plus the tray plain-text fix and the Flatpak X-cookie
launcher, so both can be tried with `isotope upgrade` before they ship.

The workflow `build-isotope-i3-tray.yaml` copies `update/` and `start-desktop`
into this directory from pinned Isotope commits, builds the image and pushes
`quay.io/mauromorales/isotope:<release>-<label>`. It refuses a tag that exists.
