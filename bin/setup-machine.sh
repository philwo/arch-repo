#!/bin/bash
# Configure this machine to install packages from the private [philwo] pacman repo.
# Run as root:  sudo bin/setup-machine.sh
#
# It is idempotent: re-running it refreshes the token and leaves pacman.conf alone
# if the [philwo] section is already present.
#
# Steps:
#   1. Store a GitHub token (from `gh auth token`) root-readable in /etc/pacman.d.
#   2. Install the XferCommand wrapper that adds auth for github.com downloads.
#   3. Add the global XferCommand and the [philwo] repo section to pacman.conf.

set -euo pipefail

REPO="philwo/arch-repo"
DBNAME="philwo"
TAG="x86_64"
SERVER="https://github.com/${REPO}/releases/download/${TAG}"

TOKEN_FILE="/etc/pacman.d/github-token"
XFER_DST="/etc/pacman.d/github-xfer.sh"
PACMAN_CONF="/etc/pacman.conf"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ${EUID} -ne 0 ]]; then
	echo "Run this as root: sudo $0" >&2
	exit 1
fi

# 1. Token. Read it as the invoking user so `gh` finds their credentials.
echo ">> Writing GitHub token to ${TOKEN_FILE}"
run_user="${SUDO_USER:-${USER}}"
token="$(sudo -u "${run_user}" gh auth token)"
if [[ -z "${token}" ]]; then
	echo "Could not get a token from 'gh auth token'. Run 'gh auth login' first." >&2
	exit 1
fi
install -Dm600 /dev/stdin "${TOKEN_FILE}" <<< "${token}"

# 2. XferCommand wrapper.
echo ">> Installing XferCommand wrapper to ${XFER_DST}"
install -Dm755 "${REPO_ROOT}/bin/github-xfer.sh" "${XFER_DST}"

# 3. pacman.conf. Add the global XferCommand once, and the repo section once.
if ! grep -q "^XferCommand = ${XFER_DST}" "${PACMAN_CONF}"; then
	echo ">> Adding XferCommand to [options] in ${PACMAN_CONF}"
	# Insert right after the [options] header.
	sed -i "0,/^\[options\]/s||[options]\nXferCommand = ${XFER_DST} %u %o|" "${PACMAN_CONF}"
else
	echo ">> XferCommand already present, leaving it"
fi

if ! grep -q "^\[${DBNAME}\]" "${PACMAN_CONF}"; then
	echo ">> Adding [${DBNAME}] repo to ${PACMAN_CONF}"
	cat >> "${PACMAN_CONF}" <<EOF

[${DBNAME}]
SigLevel = Optional TrustAll
Server = ${SERVER}
EOF
else
	echo ">> [${DBNAME}] already present, leaving it"
fi

echo ">> Done. Now run: sudo pacman -Sy && sudo pacman -S <package>"
