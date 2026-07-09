# arch-repo

My custom Arch Linux (pacman) package repo. The recipes live here in git. The built
packages and the pacman database are published as assets on a GitHub Release, and
pacman installs them from there.

- pacman repo name: `[philwo]`
- release tag that holds the packages: `x86_64`
- hosting repo (public): `philwo/arch-repo`

## Layout

```
packages/<name>/PKGBUILD   one directory per package
bin/build.sh               build packages and publish them to the release
bin/setup-machine.sh       add the [philwo] repo to a machine's pacman.conf (sudo)
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

The repo is public, so pacman fetches the release assets directly with its built-in
downloader - no token, no custom `XferCommand`. Add the repo once:

```
sudo bin/setup-machine.sh
```

This appends the `[philwo]` section to `/etc/pacman.conf`. Or add it by hand:

```
[philwo]
SigLevel = Optional TrustAll
Server = https://github.com/philwo/arch-repo/releases/download/x86_64
```

Then:

```
sudo pacman -Sy
sudo pacman -S hello-philwo
```

Building and publishing (`bin/build.sh`) still needs `gh` authenticated as the repo
owner. Installing does not.

## Notes

- Packages are not signed (`SigLevel = Optional TrustAll`). Signing with a GPG key
  is a possible future improvement.
- Only `x86_64` is published today. An `aarch64` tag could be added for Apple
  Silicon or ARM machines later.
