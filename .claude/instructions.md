# Project Instructions for Claude Code

## Ground rules
- Plan first. Don't edit or run anything until I approve the plan.
- Only edit docker-compose.arr-stack.yml, docker-compose.traefik.yml,
  docker-compose.cloudflared.yml, traefik/ and this file. Never edit docs/, README.md
  or the plex compose. Show every edit as a diff first.
- Never read, print, edit or commit `.env`. I manage it by hand on the NAS.
- Never put secrets, public IPs or personal email addresses in tracked files.
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
  Exception: new repo-managed apps (gluetun, jellyseerr, bazarr, uptime-kuma) keep
  config under /volume2/docker/arr-stack/<app>/ (inside the deploy clone, gitignored).
- Docker root: /volume2/@docker. Deploy dir (clone of my fork): /volume2/docker/arr-stack.

## Approach: adopt existing containers, don't migrate data
- The repo adopts my existing sonarr and radarr (names are case-sensitive).
  Its services reuse their existing config folders as bind mounts
  (not named volumes) and keep their existing container-side media paths, so no
  library paths change and nothing is copied.
- Jellyfin-HT is NOT in the compose. It stays as-is in Dockhand (host network).
  Traefik routes to it at http://192.168.50.139:8096; Jellyseerr uses the same URL.
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
- Sonarr/Radarr have no /downloads mount (verified with docker inspect 2026-10-29).
- Bazarr runs as PUID=1000 PGID=10 and uses the same media paths as Sonarr/Radarr:
  /series, /series2, /media, /media2.
- Replace 192.168.0.136 with 192.168.50.139 and 192.168.0.0/24 with 192.168.50.0/24
  (gluetun FIREWALL_OUTBOUND_SUBNETS). Keep the 192.168.100.0/24 Docker network.

## Service networking
- Sonarr, Radarr, Prowlarr use `network_mode: service:gluetun` (shared IP 192.168.100.3).
- VPN to VPN: `localhost`. Non-VPN to VPN (Jellyseerr/Bazarr to Sonarr): `gluetun`.
  Anything to a non-VPN container: container name.
- FlareSolverr is 192.168.100.10. Prowlarr resolves it by name only if Pi-hole has
  `192.168.100.10 flaresolverr` in its hosts; otherwise use the IP.
- Static IPs on traefik-proxy: traefik .2, gluetun .3, jellyfin .4, pihole .5,
  wg-easy .6, jellyseerr .8, bazarr .9, flaresolverr .10, uptime-kuma .13.
  (.4 and .12 are unused: Jellyfin-HT is on the host network, no cloudflared.)
- Pi-hole v6 uses pihole.toml, not custom.list. Use `.lan`, never `.local`.
- Because Sonarr/Radarr move behind Gluetun, anything that pointed at another
  container by name must use an IP or a Pi-hole hosts entry.

## Traefik / Cloudflare
- Routes live in traefik/dynamic/vpn-services.yml, not Docker labels. It must be the
  only routes file in traefik/dynamic (Traefik loads every file there).
  Exception: the Traefik dashboard router stays in docker-compose.traefik.yml labels
  (basic-auth hash from .env), on `web` with lan-only.
- Traefik host ports: 8080 (HTTP), 8443, dashboard 9090. Do NOT move UGOS nginx.
- No cloudflared and no Cloudflare Tunnel. Public access is Cloudflare proxied DNS
  plus a Cloudflare Origin Rule rewriting the destination port to 8443 -> router
  port-forward -> 192.168.50.139:8443 (websecure). Certs: Let's Encrypt DNS challenge
  (CF_DNS_API_TOKEN), wildcard *.nikeymikey.com.
- Public routers (websecure): tv1.nikeymikey.com (Jellyfin :8096) and
  arcade.nikeymikey.com (:4235) only. Everything else is on the `web` entrypoint
  (:8080) with the lan-only middleware (192.168.50.0/24). Never port-forward 8080.
- nas1.nikeymikey.com stays on Nginx-Proxy-Manager behind Cloudflare Access until
  WireGuard works. Never route it through Traefik.
- Never publish the UGOS admin UI, the Traefik dashboard or port 9090.
- Do not stop, remove or reconfigure Nginx-Proxy-Manager or cloudflare-ddns until I
  confirm.

## Deployment order
Network `traefik-proxy` -> traefik -> arr-stack (gluetun first, then sonarr, then
radarr, one at a time; verify
the VPN IP with `docker exec gluetun wget -qO- https://ipinfo.io/ip`). Deploy from
/volume2/docker/arr-stack over SSH, not by pasting compose files into Dockhand
(the repo uses relative paths like ./traefik/).
- gluetun publishes 8989/7878, so retire the old sonarr and radarr just before
  `docker compose ... up -d gluetun`. Always name services with `up -d`.

## Gotchas
- .env bcrypt hashes must be single-quoted (they contain `$`).
- Image updates need `pull` then `up -d` (restart keeps the old image).
- Pin image tags (wg-easy:14). UGOS auto-updates weekly.
- Sonarr/Radarr/Prowlarr/Bazarr must have Forms auth enabled.
