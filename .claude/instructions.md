# Project Instructions for Claude Code

## Ground rules
- Plan first. Don't edit or run anything until I approve the plan.
- Only edit docker-compose.arr-stack.yml, docker-compose.traefik.yml,
  docker-compose.cloudflared.yml, traefik/ and this file. Never edit docs/, README.md
  or the plex compose. Show every edit as a diff first.
- Never read, print, edit or commit `.env`. I manage it by hand on the NAS.
- Never put passwords or tokens in commands. If sudo or auth is needed, stop and ask me.
- Show me each NAS command before running it. Never run `docker compose down`,
  `docker volume rm`, `docker system prune` or `rm -rf` without explicit approval.
- Never run an old container and its replacement on the same config folder at once.

## NAS access
- Use `ssh nas` (key auth; my user is in the docker group, so no sudo for docker).
- scp doesn't work on UGOS. Deploy by committing to my fork, then:
  `ssh nas "cd /volume2/docker/arr-stack && git pull"`
- NAS IP: 192.168.50.139 (LAN 192.168.50.0/24). Timezone: Europe/London.
- I manage the existing containers with Dockhand. Dockhand may restart stopped
  containers, so use `docker update --restart=no <name>` when retiring one.

## Storage layout (lowercase, never create /volume1/Media)
- Media: /volume1/media and /volume3/media2.
- App config: /volume2/docker/<app>/ (e.g. /volume2/docker/jellyfinht/config).
- Docker root: /volume2/@docker. Deploy dir (clone of my fork): /volume2/docker/arr-stack.

## Approach: adopt existing containers, don't migrate data
- My current containers are Jellyfin-HT, sonarr, radarr (names are case-sensitive).
  The repo's services should reuse their existing config folders as bind mounts
  (not named volumes) and keep their existing container-side media paths, so no
  library paths change and nothing is copied.
- Jellyfin-HT runs as user 1000:10, group_add 105 and passes /dev/dri for Intel
  hardware transcoding. Carry these over, and pin the exact image tag it runs now.
- PUID/PGID for Sonarr/Radarr must match the owner of their existing config folders,
  not the repo's hardcoded 1000:1000.
- Cutover is one app at a time: stop it, `docker update --restart=no <name>`,
  `docker rename <name> <name>-old`, then start the repo's service. Keep the -old
  containers for rollback.
- The old unused `gluetun` container must be removed before the repo's one starts.

## My differences from upstream
- VPN: NordVPN via Gluetun, OpenVPN, service credentials
  (NORDVPN_USER / NORDVPN_PASSWORD in .env). Not Surfshark.
- Downloads: external seedbox only. No Transmission, qBittorrent or torrent client on
  the NAS (remove qBittorrent from the compose: service, port 8085, volume). Never
  create an rsync cron.
- Syncthing (already running, managed in Dockhand; never redeploy or touch it) syncs
  the seedbox into /volume2/docker/syncthing/data1/sync. Sonarr/Radarr mount that
  folder as /data1 (NOT the parent data1). Their Remote Path Mappings depend on it.
  Copy every existing mount exactly as `docker inspect` shows it now, keep PUID=1000
  PGID=10. Imports copy into the library (different filesystem): expected.
- Remove the leftover /volume2/docker/transmission/downloads:/downloads mount from
  Sonarr/Radarr only after I confirm no setting uses /downloads.
- Replace 192.168.0.136 with 192.168.50.139 and 192.168.0.0/24 with 192.168.50.0/24
  (gluetun FIREWALL_OUTBOUND_SUBNETS). Keep the 192.168.100.0/24 Docker network.

## Service networking
- Sonarr, Radarr, Prowlarr use `network_mode: service:gluetun` (shared IP 192.168.100.3).
- VPN to VPN: `localhost`. Non-VPN to VPN (Jellyseerr/Bazarr to Sonarr): `gluetun`.
  Anything to a non-VPN container: container name.
- FlareSolverr is 192.168.100.10. Prowlarr resolves it by name only if Pi-hole has
  `192.168.100.10 flaresolverr` in its hosts; otherwise use the IP.
- Static IPs on traefik-proxy: traefik .2, gluetun .3, jellyfin .4, pihole .5,
  wg-easy .6, jellyseerr .8, bazarr .9, flaresolverr .10, cloudflared .12, uptime-kuma .13.
- Pi-hole v6 uses pihole.toml, not custom.list. Use `.lan`, never `.local`.
- Because Sonarr/Radarr move behind Gluetun, anything that pointed at another
  container by name must use an IP or a Pi-hole hosts entry.

## Traefik / Cloudflare
- Routes live in traefik/dynamic/vpn-services.yml, not Docker labels.
- Traefik host ports: 8080 (HTTP), 8443, dashboard 9090. Do NOT move UGOS nginx.
- Cloudflare Tunnel routes point to 192.168.50.139:8080. Publish only Jellyfin
  and Jellyseerr.
- Do not stop, remove or reconfigure Nginx-Proxy-Manager or cloudflare-ddns until I
  confirm remote access works through Traefik. Never publish the UGOS admin UI.

## Deployment order
Network `traefik-proxy` -> traefik -> cloudflared -> arr-stack (gluetun first; verify
the VPN IP with `docker exec gluetun wget -qO- https://ipinfo.io/ip`). Deploy from
/volume2/docker/arr-stack over SSH, not by pasting compose files into Dockhand
(the repo uses relative paths like ./traefik/).

## Gotchas
- .env bcrypt hashes must be single-quoted (they contain `$`).
- Image updates need `pull` then `up -d` (restart keeps the old image).
- Pin image tags (Jellyfin = the version running now, wg-easy:14). UGOS auto-updates weekly.
- Sonarr/Radarr/Prowlarr/Bazarr must have Forms auth enabled.
