#!/bin/bash
# pacman XferCommand wrapper. This is installed to /etc/pacman.d/github-xfer.sh by
# setup-machine.sh and set as the global XferCommand in pacman.conf.
#
# XferCommand is global (it applies to every repo), so this must behave like a
# normal downloader for all URLs and only add GitHub auth for github.com hosts.
# That is needed because the [philwo] repo lives on a *private* GitHub release, and
# pacman itself can't authenticate.
#
# curl drops the Authorization header when GitHub redirects the download to its
# signed asset URL on a different host. That is the behavior we want: github.com
# authorizes the request, the signed URL then carries its own token.
#
# Usage (from pacman.conf): XferCommand = /etc/pacman.d/github-xfer.sh %u %o
set -euo pipefail

url="$1"
out="$2"
token_file="/etc/pacman.d/github-token"

curl_args=(--fail --location --retry 3 --output "${out}")

case "${url}" in
	https://github.com/* | https://*.githubusercontent.com/*)
		if [[ -r "${token_file}" ]]; then
			curl_args+=(--header "Authorization: Bearer $(cat "${token_file}")")
		fi
		;;
esac

exec curl "${curl_args[@]}" "${url}"
