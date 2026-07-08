#!/bin/bash
# Build one or more custom packages and publish them to the GitHub Release that
# backs the [philwo] pacman repo.
#
# Usage:
#   bin/build.sh              # build every package under packages/
#   bin/build.sh hello-philwo # build only the named package(s)
#
# What it does:
#   1. Downloads the current release assets (DB + existing packages) into a
#      gitignored dist/ staging dir, so repo-add updates the DB incrementally and
#      previously published packages survive.
#   2. Runs makepkg for each requested package.
#   3. Adds the freshly built packages to the philwo.db database.
#   4. Uploads the DB and the new packages back to the release.

set -euo pipefail

REPO="philwo/arch-repo"
DBNAME="philwo"
TAG="x86_64"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_ROOT="${REPO_ROOT}/packages"
DIST="${REPO_ROOT}/dist/${TAG}"

# Which packages to build: args, or every dir under packages/.
if [[ $# -gt 0 ]]; then
	pkgs=("$@")
else
	pkgs=()
	for d in "${PKG_ROOT}"/*/; do
		[[ -f "${d}/PKGBUILD" ]] && pkgs+=("$(basename "${d}")")
	done
fi
if [[ ${#pkgs[@]} -eq 0 ]]; then
	echo "No packages to build under ${PKG_ROOT}" >&2
	exit 1
fi

# Start from a clean staging dir so the build is deterministic.
rm -rf "${DIST}"
mkdir -p "${DIST}"

# Pull only the current database from the release so repo-add can update it
# incrementally. The old package files stay in the release untouched; we don't need
# them locally, and we won't re-upload them. Ignore failure: the release (or the DB)
# may not exist yet on the very first run.
echo ">> Fetching current database (if any)"
gh release download "${TAG}" -R "${REPO}" -D "${DIST}" \
	--pattern "${DBNAME}.db.tar.gz" --pattern "${DBNAME}.files.tar.gz" \
	2>/dev/null || true

# Build each package and collect the resulting archives.
built=()
for name in "${pkgs[@]}"; do
	dir="${PKG_ROOT}/${name}"
	if [[ ! -f "${dir}/PKGBUILD" ]]; then
		echo "No PKGBUILD for '${name}' in ${dir}" >&2
		exit 1
	fi
	echo ">> Building ${name}"
	( cd "${dir}" && makepkg -Cf )
	while IFS= read -r f; do
		cp -f "${f}" "${DIST}/"
		built+=("$(basename "${f}")")
	done < <(find "${dir}" -maxdepth 1 -name '*.pkg.tar.zst')
done

if [[ ${#built[@]} -eq 0 ]]; then
	echo "makepkg produced no packages" >&2
	exit 1
fi

# Add the newly built packages to the database (creating it on the first run).
# repo-add won't refresh an entry whose pkgver-pkgrel is unchanged, but each
# makepkg run produces byte-different output. Remove the entry first so the DB
# always records the current build's checksum and stays in sync with the upload.
echo ">> Updating ${DBNAME} database"
names=()
for f in "${built[@]}"; do
	names+=("$(bsdtar -xOqf "${DIST}/${f}" .PKGINFO | sed -n 's/^pkgname = //p')")
done
if [[ -f "${DIST}/${DBNAME}.db.tar.gz" ]]; then
	( cd "${DIST}" && repo-remove "${DBNAME}.db.tar.gz" "${names[@]}" 2>/dev/null || true )
fi
( cd "${DIST}" && repo-add --new "${DBNAME}.db.tar.gz" "${built[@]}" )

# pacman fetches assets literally named "<db>.db" / "<db>.files"; release assets
# can't be symlinks, and repo-add leaves those names as symlinks to the .tar.gz,
# so replace them with real copies (--remove-destination drops the symlink first).
( cd "${DIST}" \
	&& cp -f --remove-destination "${DBNAME}.db.tar.gz" "${DBNAME}.db" \
	&& cp -f --remove-destination "${DBNAME}.files.tar.gz" "${DBNAME}.files" )

# Create the release on first run, then upload everything (clobbering old assets).
if ! gh release view "${TAG}" -R "${REPO}" >/dev/null 2>&1; then
	echo ">> Creating release ${TAG}"
	gh release create "${TAG}" -R "${REPO}" \
		--title "philwo pacman repo (${TAG})" \
		--notes "Custom Arch packages. Configure a machine with bin/setup-machine.sh." \
		--latest=false
fi

echo ">> Uploading assets to release ${TAG}"
mapfile -t assets < <(find "${DIST}" -maxdepth 1 -type f \
	\( -name "${DBNAME}.db" -o -name "${DBNAME}.files" \
	-o -name "${DBNAME}.db.tar.gz" -o -name "${DBNAME}.files.tar.gz" \
	-o -name '*.pkg.tar.zst' \))
gh release upload "${TAG}" -R "${REPO}" --clobber "${assets[@]}"

echo ">> Done. Published: ${built[*]}"
