# Project instructions for Claude Code

## Ground rules
- Plan first. Show every edit as a diff before applying, and edit only files I name.
- Never read, print, edit or commit `.env`. Never put secrets in commands.
- Show me each NAS command first. Never run `docker compose down`, `docker volume rm`,
  `docker system prune`, `rm -rf` or `--remove-orphans`.
- After any edit run `git diff --stat` and report exactly what changed. I verify it myself.
- Do not edit docs/, README.md or the plex files. Do not touch Dockhand-managed containers
  (Jellyfin-HT, Syncthing, RetroAssembly and others).

## NAS
- `ssh nas` (key auth, docker group, no sudo for docker). NAS IP 192.168.50.139,
  LAN 192.168.50.0/24, TZ Europe/London.
- git is not installed on the NAS and apt is broken: never run apt. Deploy by pushing to my fork, then:
  ssh nas "cd /volume2/docker/arr-stack && docker run --rm -v /volume2/docker/arr-stack:/repo -w /repo alpine/git -c safe.directory=/repo pull"
- Deploy dir /volume2/docker/arr-stack. Media /volume1/media and /volume3/media2 (lowercase).
  App configs /volume2/docker/<app>. Docker root /volume2/@docker.

## Stack as deployed
- Compose files in use: docker-compose.traefik.yml and docker-compose.arr-stack.yml.
  Not used: cloudflared, plex. Not running: Uptime Kuma.
- Public access: Cloudflare proxied DNS for tv1 and arcade only, then an Origin Rule rewriting the port to 8443,
  then the router forward 8443, then Traefik websecure (certificates via the Cloudflare DNS challenge).
  Both routers use the cloudflare-only middleware. Everything else is lan-only on the web entrypoint (:8080)
  and is never forwarded.
- NAS admin and the WireGuard UI are reached over WireGuard (wg-easy, UDP 51820, split tunnel, DNS-only
  record wg.nikeymikey.com kept current by cloudflare-ddns). nas1 and Nginx-Proxy-Manager are retired.
- Router forwards: 8443 TCP, 51820 UDP, 22000 (Syncthing). Never forward 80, 81, 443, 9090, 9999 or 51821.
- Traefik v3.0.4 uses the file provider only (the Docker provider was removed because the NAS's Docker API
  rejects its client). Routes live in traefik/dynamic/vpn-services.yml. Validate YAML before pushing.
- Jellyfin-HT is not in the compose. It is managed in Dockhand (host network, 192.168.50.139:8096,
  user 1000:10, /dev/dri). Its Known proxies include Traefik and Cloudflare ranges.
- Gluetun uses NordVPN (OpenVPN, service credentials in .env). Sonarr, Radarr and Prowlarr share its
  network. Their health checks include an outside-connection test, and deunhealth restarts them when it fails.
- Downloads: external seedbox (rTorrent) only, delivered by Syncthing to
  /volume2/docker/syncthing/data1/sync, mounted as /data1 in Sonarr and Radarr. No torrent client on the NAS.
- Pinned: pihole, flaresolverr, gluetun (digest), wg-easy:14, traefik:v3.0. Sonarr, Radarr, Prowlarr,
  Bazarr and Seerr stay on latest and are updated by me through Dockhand.
- Static IPs on traefik-proxy: traefik .2, gluetun .3, pihole .5, wg-easy .6, seerr .8, bazarr .9,
  flaresolverr .10. Pi-hole is 10.8.1.200 on vpn-net.

## Gotchas
- .env hashes must be single-quoted. A plain restart does not re-read .env: use up -d --force-recreate.
- Gluetun restarts: Sonarr, Radarr and Prowlarr recover by themselves within about 6 minutes
  (deunhealth plus the outside check). If Gluetun was RECREATED (image change or --force-recreate),
  run: up -d gluetun sonarr radarr prowlarr.
- I edit files in Notepad on Windows, with no tabs in YAML. Use block-form YAML lists for long commands.
- sonarr-old and radarr-old are stopped rollback containers. Never run them alongside the new ones.