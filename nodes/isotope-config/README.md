# Isotope with `isotope config`

A prototype. On Isotope, one wrong line in a cloud-config file in `/oem` can
leave a machine with no user to log in as: Kairos skips a file that does not
load, with the users in it, and every boot entry reads the same `/oem`.

This node layers a build of the `isotope` command from a fork branch on a
published Isotope image. It adds:

- `isotope config check` and `apply`: load a file the way the boot does,
  before a restart.
- A guard at boot that puts back the last good copy of a file that no longer
  loads.
- A unit that records each boot that ended with a user who can log in, and
  goes back to the last one when a boot left none.
- `isotope config status`, `diff`, `history` and `rollback`.

The design is `docs/superpowers/specs/2026-11-19-config-safe-apply-design.md`
on the branch the Dockerfile pins.

Run the workflow by hand. It pushes
`quay.io/mauromorales/isotope:<flavor>-<release>-<label>` and never moves a
tag that exists. A machine that runs Isotope takes it with:

```sh
isotope upgrade --image quay.io/mauromorales/isotope:sway-v0.0.22-config
```

The `isotope` command in this image is always the one of the pinned fork
commit, which is based on Isotope v0.0.22 plus the changes on `main` up to
2026-11-19. Build it on v0.0.22. On a later release the command would be
older than the image; move the pin first.

After the upgrade, the first good boot records generation 1. From then on
`sudo isotope config status` says what the config is and what the last boot
repaired. To go back, upgrade to the release image again; `/oem/.isotope-config`
is then unused and can be removed.
