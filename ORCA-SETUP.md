# Orca Server alongside PinkCollab on Unraid

The same Docker image contains official Oh My Pi (OMP), PinkCollab Gateway and official Orca IDE's headless `orca-ide serve`. They run as UID/GID 1000, supervised by supervisord.

## Networking

- PinkCollab keeps its existing private port 8788 and Cloudflare Tunnel route.
- Orca uses port **6768/TCP** on the Unraid LAN; no WAN port-forwarding.
- Set `ORCA_PAIRING_ADDRESS` to the reachable Unraid LAN/VPN address (currently `192.168.2.104`).
- For outside-home use, connect UniFi Teleport first, then open Orca Mobile.
- The Docker `ibraproxy` network remains unchanged.

## Persistent volumes

- `/mnt/user/appdata/pinkcollab-omp` maps to `/home/agent` — OMP config/history, PinkCollab data and Orca data.
- `/mnt/cachedl/omp-workspace` maps to `/workspace`.
- PinkCollab and Orca start *different* OMP processes; concurrent edits to the same project need coordination. They do **not** share one live session.

## Pair desktop Linux

Install the official Orca IDE desktop application on Linux and open **Settings → Remote Orca Servers → Add Server**. The server prints a one-time private pairing link to its Docker logs when it first starts. Do not publish this link.

Once paired, select the Unraid remote server, then add `/workspace` and start OMP on the remote host. On Linux the CLI executable is called `orca-ide`.

## Pair Android

Install the Android app from the official Orca download page. Use Orca's mobile pairing from the desktop client or the server's mobile pairing procedure. The mobile client should connect to the same Orca server, not start a local OMP.

See: https://www.onorca.dev/docs/remote-servers and https://www.onorca.dev/docs/mobile

## Security

- Orca defaults to permissive agent execution. In Orca Settings → Agents → Agent Permissions choose **Manual** before enabling privileged SSH or host access.
- Do not publicly expose 6768. Orca uses revocable pairing tokens; a token link is a credential.
- Never add API keys or the `/home/agent` volume to this repository.

## Health and rollback

```sh
docker inspect --format '{{.State.Health.Status}}' pinkcollab-omp
docker exec pinkcollab-omp node /usr/local/bin/healthcheck.js
docker exec pinkcollab-omp orca-ide --version
docker exec pinkcollab-omp omp --version
docker logs --tail 50 pinkcollab-omp
```

Back up `/home/agent` before deployment, retain the exact previous image ID and the previous Unraid XML template. If the combined container fails, recreate the container with the previous image and two original volume mappings; do not restore older appdata unless migration actually modified it.

The Orca version is SHA-256-pinned in the Dockerfile. Updating it requires editing both version and digest and passing the CI smoke tests. Orca does not auto-update in this headless container.
