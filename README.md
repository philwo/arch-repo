# arch-repo

My custom Arch Linux (pacman) package repo. The recipes live here in git. The built
packages and the pacman database are published as assets on a GitHub Release, and
pacman installs them from there.

- pacman repo name: `[philwo]`
- release tag that holds the packages: `x86_64`
- hosting repo (private): `philwo/arch-repo`

## Layout

```
packages/<name>/PKGBUILD   one directory per package
bin/build.sh               build packages and publish them to the release
bin/setup-machine.sh       configure a machine to install from this repo (sudo)
bin/github-xfer.sh         pacman download wrapper (installed by setup-machine.sh)
dist/                      local staging for release uploads (gitignored)
```

## Add or update a package

1. Copy `packages/hello-philwo` to `packages/<name>` and edit the `PKGBUILD`.
   Follow the same style as my AUR packages in `~/src/aur`.
2. Build and publish:

   ```
   bin/build.sh <name>     # or: bin/build.sh   to build everything
   ```

   This runs `makepkg`, adds the package to the `philwo` database, and uploads the
   package plus the updated database to the `x86_64` release. Old packages already
   in the release are kept, so the database stays consistent.
3. Commit the recipe changes and push.

## Install on a machine

Because the repo is private, pacman can't fetch the release assets on its own (for
private repos even the plain `releases/download` URL 404s, so a token alone is not
enough). A small `XferCommand` wrapper routes `github.com` release downloads through
`gh release download`, which uses the API asset endpoint that private repos need.
You need `gh` and `curl` installed (both are in the official repos). Set it up once:

```
sudo bin/setup-machine.sh
```

This stores your `gh` token in `/etc/pacman.d/github-token` (mode 600), installs the
wrapper to `/etc/pacman.d/github-xfer.sh`, and adds the `XferCommand` line plus the
`[philwo]` section to `/etc/pacman.conf`. Then:

```
sudo pacman -Sy
sudo pacman -S hello-philwo
```

Note: `XferCommand` is global (it applies to every repo), so the wrapper passes all
non-github URLs straight through to `curl`. If your token expires, re-run
`sudo bin/setup-machine.sh` to refresh it.

## Notes

- `XferCommand` is global: setting it makes pacman use the wrapper (curl) for every
  repo instead of its built-in downloader, so `ParallelDownloads` no longer applies.
  On a machine where you care about that, this is the cost of pulling from a private
  repo.
- Packages are not signed (`SigLevel = Optional TrustAll`). Signing with a GPG key
  is a possible future improvement.
- Only `x86_64` is published today. An `aarch64` tag could be added for Apple
  Silicon or ARM machines later.
