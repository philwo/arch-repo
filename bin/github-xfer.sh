#!/bin/bash
# pacman XferCommand wrapper. Installed to /etc/pacman.d/github-xfer.sh by
# setup-machine.sh and set as the global XferCommand in pacman.conf.
#
# The [philwo] repo lives on a *private* GitHub release, and pacman can't
# authenticate on its own. For private repos the plain
# https://github.com/OWNER/REPO/releases/download/TAG/FILE URL returns 404 even
# with a token; only the API asset endpoint works. `gh release download` uses that
# endpoint, so this wrapper routes github.com release URLs through gh (with the
# token from /etc/pacman.d/github-token) and passes every other URL straight to
# curl.
#
# XferCommand is global (it applies to every repo), so the curl fallback must
# behave like a normal downloader for all non-github URLs.
#
# Usage (from pacman.conf): XferCommand = /etc/pacman.d/github-xfer.sh %u %o
set -euo pipefail

url="$1"
out="$2"
token_file="/etc/pacman.d/github-token"

release_re='^https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)$'
if [[ "${url}" =~ ${release_re} ]]; then
	owner="${BASH_REMATCH[1]}"
	repo="${BASH_REMATCH[2]}"
	tag="${BASH_REMATCH[3]}"
	file="${BASH_REMATCH[4]}"
	export GH_TOKEN
	GH_TOKEN="$(cat "${token_file}")"
	exec gh release download "${tag}" -R "${owner}/${repo}" \
		--pattern "${file}" --output "${out}" --clobber
fi

exec curl --fail --location --retry 3 --output "${out}" "${url}"
