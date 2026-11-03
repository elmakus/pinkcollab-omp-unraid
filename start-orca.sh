#!/bin/sh
set -eu

# A real reachable LAN/VPN address is required for pairing links.
: "${ORCA_PAIRING_ADDRESS:?Set ORCA_PAIRING_ADDRESS to the LAN or VPN IP or hostname of the Unraid host}"

exec /usr/local/bin/orca-ide serve --port 6768 --pairing-address "$ORCA_PAIRING_ADDRESS"
