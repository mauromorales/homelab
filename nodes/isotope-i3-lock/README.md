# isotope-i3-lock

Isotope i3 on a release, plus an i3lock that shows its unlock ring from the
start and at a smaller size. The workflow `build-isotope-i3-lock.yaml` builds
Isotope's `i3lock` stage from a pinned fork commit, layers the result on the
release and pushes `quay.io/mauromorales/isotope:<release>-<label>`. It refuses
a tag that exists.
