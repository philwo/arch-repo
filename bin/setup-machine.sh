#!/bin/bash
# Configure this machine to install packages from the private [philwo] pacman repo.
# Run as root:  sudo bin/setup-machine.sh
#
# It is idempotent: re-running it refreshes the token and leaves pacman.conf alone
# if the XferCommand / [philwo] section are already present.
#
# Steps:
#   1. Store a GitHub token (from `gh auth token`) root-readable in /etc/pacman.d.
#   2. Install the XferCommand wrapper that fetches private release assets via gh.
#   3. Add the global XferCommand and the [philwo] repo section to pacman.conf.
#
# The target paths can be overridden with env vars (TOKEN_FILE, XFER_DST,
# PACMAN_CONF), which is used by the tests to run against temp files.

set -euo pipefail

REPO="philwo/arch-repo"
DBNAME="philwo"
TAG="x86_64"
SERVER="https://github.com/${REPO}/releases/download/${TAG}"

TOKEN_FILE="${TOKEN_FILE:-/etc/pacman.d/github-token}"
XFER_DST="${XFER_DST:-/etc/pacman.d/github-xfer.sh}"
PACMAN_CONF="${PACMAN_CONF:-/etc/pacman.conf}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Require root only when a target isn't already writable by the current user.
if [[ ${EUID} -ne 0 ]]; then
	for d in "$(dirname "${TOKEN_FILE}")" "$(dirname "${XFER_DST}")" "${PACMAN_CONF}"; do
		if [[ ! -w "${d}" ]]; then
			echo "Need write access to ${d}. Run as root: sudo $0" >&2
			exit 1
		fi
	done
fi

# 1. Token. Read it as the invoking user so `gh` finds their credentials.
echo ">> Writing GitHub token to ${TOKEN_FILE}"
run_user="${SUDO_USER:-${USER}}"
if [[ -n "${SUDO_USER:-}" ]]; then
	token="$(sudo -u "${run_user}" gh auth token)"
else
	token="$(gh auth token)"
fi
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
	# Append the line right after the [options] header (which is unique).
	sed -i "/^\[options\]/a XferCommand = ${XFER_DST} %u %o" "${PACMAN_CONF}"
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
