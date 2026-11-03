#!/bin/sh
set -eu

# Both services execute as UID/GID 1000; their HOME and workspace are persistent volumes.
mkdir -p "$HOME/.omp" "$HOME/.pinkcollab" "$HOME/.local/bin" "$HOME/.local/npm" "$HOME/.config" "$HOME/.ssh" /workspace
chmod 700 "$HOME/.ssh"

# Keep existing PinkCollab configuration; initialize only on the first boot.
if [ ! -f "$HOME/.pinkcollab/config.yaml" ]; then
  pinkcollab init --workspace /workspace
fi

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf