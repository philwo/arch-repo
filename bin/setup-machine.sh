#!/bin/bash
# Configure this machine to install packages from the [philwo] pacman repo.
# The repo is public, so pacman fetches the release assets directly - no token or
# custom downloader needed. Run as root:  sudo bin/setup-machine.sh
#
# Idempotent: leaves pacman.conf alone if the [philwo] section is already present.
# PACMAN_CONF can be overridden (used by the tests).

set -euo pipefail

REPO="philwo/arch-repo"
DBNAME="philwo"
TAG="x86_64"
SERVER="https://github.com/${REPO}/releases/download/${TAG}"
PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"

if [[ ! -w "${PACMAN_CONF}" && ${EUID} -ne 0 ]]; then
	echo "Need write access to ${PACMAN_CONF}. Run as root: sudo $0" >&2
	exit 1
fi

if grep -q "^\[${DBNAME}\]" "${PACMAN_CONF}"; then
	echo ">> [${DBNAME}] already present in ${PACMAN_CONF}, nothing to do"
else
	echo ">> Adding [${DBNAME}] repo to ${PACMAN_CONF}"
	cat >> "${PACMAN_CONF}" <<EOF

[${DBNAME}]
SigLevel = Optional TrustAll
Server = ${SERVER}
EOF
fi

echo ">> Done. Now run: sudo pacman -Sy && sudo pacman -S <package>"
