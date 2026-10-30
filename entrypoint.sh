#!/bin/sh
set -eu

# Gateway and OMP run as the same non-root Linux user.
mkdir -p "$HOME/.omp" "$HOME/.pinkcollab" "$HOME/.local/bin" "$HOME/.local/npm" "$HOME/.config" /workspace

# Initialize without trying to install a systemd service inside Docker.
if [ ! -f "$HOME/.pinkcollab/config.yaml" ]; then
  pinkcollab init --workspace /workspace
fi

# Gateway binds to loopback:8787. This UNENCRYPTED upstream is only for an
# HTTPS reverse proxy on a trusted LAN/VPN. NEVER public-port-forward it.
socat TCP-LISTEN:8788,bind=0.0.0.0,reuseaddr,fork TCP:127.0.0.1:8787 &

exec pinkcollab serve
