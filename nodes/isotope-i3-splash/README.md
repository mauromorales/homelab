# isotope-i3-splash

Isotope i3 on a release, plus a changed boot splash, so it can be tried with
`isotope upgrade` before it ships. The workflow `build-isotope-i3-splash.yaml`
copies `splash/` from a pinned Isotope commit, builds it with the Hadron
toolchain and pushes `quay.io/mauromorales/isotope:<release>-<label>`. It
refuses a tag that exists.
