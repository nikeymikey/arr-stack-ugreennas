# Project instructions for Claude Code

## Ground rules
- Plan first. Show every edit as a diff before applying, and edit only files I name.
- Never read, print, edit or commit `.env`. Never put secrets in commands.
- Show me each NAS command first. Never run `docker compose down`, `docker volume rm`,
  `docker system prune`, `rm -rf` or `--remove-orphans`.
- After any edit run `git diff --stat` and report exactly what changed. I verify it myself.
- Do not edit docs/, README.md or the plex files. Do not touch Dockhand-managed containers
  (Jellyfin-HT, Syncthing, RetroAssembly, The Lounge, cloudflare-ddns and others).

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
- Public hostnames (all four): tv1 (Jellyfin-HT, 192.168.50.139:8096), arcade (Retroassembly, :4235),
  irc (The Lounge, :9001) and requests (Seerr, container jellyseerr at 192.168.100.8:5055).
  Path: Cloudflare proxied DNS -> Origin Rule rewriting the port to 8443 (its hostname list must include
  all four) -> router forward 8443 -> Traefik websecure (certificates via the Cloudflare DNS challenge).
  Every public router uses the cloudflare-only middleware. Everything else is lan-only on the web
  entrypoint (:8080) and is never forwarded.
- Adding another public hostname needs: a proxied Cloudflare DNS record, the hostname added to the
  Origin Rule, a router (websecure, cloudflare-only, certResolver cloudflare) and a service in
  traefik/dynamic/vpn-services.yml, YAML validated before pushing, and the app's own proxy settings checked.
- The Lounge (private mode, reverseProxy: true in /volume2/docker/thelounge/config.js) and Seerr
  (Application URL https://requests.nikeymikey.com, proxy support on, Sonarr/Radarr External URLs set to
  the NAS address) are configured for public use.
- NAS admin and the WireGuard UI are reached over WireGuard (wg-easy, UDP 51820, split tunnel, DNS-only
  record wg.nikeymikey.com kept current by cloudflare-ddns). nas1 and Nginx-Proxy-Manager are retired.
- Router forwards: 8443 TCP, 51820 UDP, 22000 (Syncthing). Never forward 80, 81, 443, 8096, 9001, 9090,
  9999 or 51821.
- Traefik v3.0.4 uses the file provider only (the Docker provider was removed because the NAS's Docker API
  rejects its client). Routes live in traefik/dynamic/vpn-services.yml. Validate YAML before pushing.
- Jellyfin-HT is not in the compose. It is managed in Dockhand (host network, 192.168.50.139:8096,
  user 1000:10, /dev/dri). Its Known proxies include Traefik and Cloudflare ranges.
- Gluetun uses NordVPN (OpenVPN, service credentials in .env). Sonarr, Radarr and Prowlarr share its
  network. Their health checks include an outside-connection test, and deunhealth restarts them when it fails.
- Downloads: all on the external seedbox. Usenet (SABnzbd) is the main, automatic source and is enabled in
  Sonarr and Radarr. Torrents (rTorrent) are handled manually for now: rTorrent is disabled in Radarr
  (and in Sonarr if I disable it)". rTorrent is now disabled in both apps..
  Finished files reach the NAS via Syncthing at /volume2/docker/syncthing/data1/sync, mounted as /data1
  (remote path mapping seedbox /downloads/sync -> /data1). No download client runs on the NAS.
- Delay profiles (both apps): 0 delay, prefer Usenet. Profilarr owns them (delay sync, manual only).
- Pinned: pihole, flaresolverr, gluetun (digest), wg-easy:14, traefik:v3.0. Sonarr, Radarr, Prowlarr,
  Bazarr and Seerr stay on latest and are updated by me through Dockhand.
- Static IPs on traefik-proxy: traefik .2, gluetun .3, pihole .5, wg-easy .6, seerr .8, bazarr .9,
  flaresolverr .10. Pi-hole is 10.8.1.200 on vpn-net.

## Gotchas
- .env hashes and secrets must be single-quoted. A plain restart does not re-read .env: use up -d --force-recreate.
  .env must stay named ".env" (Windows editors can drop the dot) and be chmod 600.
- Gluetun restarts: Sonarr, Radarr and Prowlarr recover by themselves within about 6 minutes
  (deunhealth plus the outside check). If Gluetun was RECREATED (image change or --force-recreate),
  run: up -d gluetun sonarr radarr prowlarr.
- I edit files in Notepad on Windows, with no tabs in YAML. Use block-form YAML lists for long commands.
  Notepad's Replace box truncates at 127 characters, so type edits into the document body.
- Commands with several layers of quotes: run them inside an interactive `ssh nas` session, not as
  ssh nas "..." from PowerShell (PowerShell expands $(...) locally and breaks the quoting).
- sonarr-old and radarr-old are stopped rollback containers. Never run them alongside the new ones.
- Never run mass searches ("Search all", "Cutoff unmet", bulk series searches) in Sonarr or Radarr:
  there are many upgrade candidates after the Profilarr sync and it would flood the seedbox.
  Check /volume3 free space (it is nearly full) before any large batch of upgrades.
- Backups: scripts/arr-backup-volume2.sh runs at 03:00 from root's crontab and writes to
  /home/Nikeymikey/backups/arr-stack (14 days kept; includes Sonarr, Radarr, Bazarr, Seerr, Gluetun,
  Syncthing, The Lounge, Jellyfin-HT, Prowlarr, Pi-hole, wg-easy, Profilarr, Tracearr (pg_dump),
  Rewindarr, Maintainerr, Tdarr, Whisparr v2 and v3 and the stack files). It stops Sonarr, Radarr,
  Prowlarr, Bazarr, Seerr, Profilarr, Rewindarr, Maintainerr, Tdarr, Whisparr and Whisparr3 for about
  five minutes. The old scripts/arr-backup.sh assumes
  another layout and must never be installed. Add each new app's lines to the script only after its
  container is healthy, then run bash -n and a manual backup.
- Never paste long lines into nano (a paste once got mangled and broke the crontab). Write root's crontab
  with: sudo tee /tmp/rootcron <<'EOF' ... EOF, then sudo crontab /tmp/rootcron.
- cron.log holds a copy of the backup script's normal output as well as any errors. Four pg_dump lines
  ("warning: circular foreign-key constraints", "detail: continuous_agg" and two "hint" lines) appear
  every night and are normal. Only other extra lines mean trouble.
- SSH port forwarding is enabled by `AllowTcpForwarding yes` at line 87 of /etc/ssh/sshd_config
  (backup /etc/ssh/sshd_config.bak-20261102) so the Maintainerr tunnel works. A UGOS update may reset
  it: if the tunnel fails with "administratively prohibited", redo the edit, run sshd -t, then reload sshd.

## Extras (docker-compose.extras.yml, project name arr-extras)
- Always: docker compose -f docker-compose.extras.yml up -d <service>. Never combine it with the other compose files.
- No Traefik routes for the extras yet. Reach them on 192.168.50.139:<port>.
- Static IPs on traefik-proxy: profilarr .11; reserved tracearr .12, rewindarr .14, maintainerr .15, tdarr .16,
  whisparr .17, whisparr3 .18. .13 is reserved for uptime-kuma.
- Profilarr v2.3.1 (+profilarr-parser, internal network) at http://192.168.50.139:6868.
  Config /volume2/docker/profilarr/config. /volume2/docker/profilarr/data is old v1 data (incompatible, unused).
  ORIGIN takes ONE url in 2.3.1. Stopped during the nightly backup.
- Profilarr manages: quality profiles (Radarr: 1080p Balanced, 1080p Quality, 2160p Quality, 2160p Remux,
  720p Quality; Sonarr: 1080p Balanced, 1080p Compact, 2160p Quality, 2160p Remux) and delay profiles
  (0 delay, prefer Usenet). All syncs are manual; jobs (upgrades, renames, cleanup) are off.
  Media-management sync: never.
- Syncing any profile rewrites shared custom formats used by every Dictionarry profile. Back up first.
- Linking a new instance in Profilarr applies a default 600-min delay profile automatically. Check delay
  profiles after linking.
- "Upgrades Allowed" is on in the Sonarr/Radarr profiles (RSS upgrades happen); Profilarr's upgrade job is off.
- Tracearr 3.1.5 at http://192.168.50.139:3000, runs as user 1000:10 (UGOS refuses the image's own uid 1001
  on bind mounts). tracearr-db (timescaledb-ha pg18.4-ts2.29.1) and tracearr-redis (redis 8.2-alpine) on
  internal network tracearr-internal, no published ports. Data in /volume2/docker/tracearr/{pgdata,redis,
  backup,image-cache}. Polls Jellyfin-HT directly (server "MikesServer2"); Tracearr Jellyfin plugin installed (0.6.0.0): live events arrive via [PluginSSE] lines; 404s now mean trouble. .env: TRACEARR_JWT_SECRET, TRACEARR_COOKIE_SECRET, TRACEARR_DB_PASSWORD
  (hex only). BETTER_AUTH_URL unset (set to the LAN URL only if login breaks).
- Backup: pg_dump of tracearr-db while running (not stopped) plus tracearr/backup; Redis skipped. The four
  "pg_dump: warning/detail/hint ... circular foreign-key ... continuous_agg" lines in cron.log are normal.
  Restore into an empty TimescaleDB with timescaledb_pre_restore() / timescaledb_post_restore().
- .env must stay named ".env" (Windows editors can drop the dot) and chmod 600.
- /home/Nikeymikey/backups/pre-profilarr-sync-20261102 = state before any Profilarr sync (delay profiles
  already 600 min there). Not auto-pruned; delete by hand when no longer needed.
  - Maintainerr 3.31.0 has NO login: LAN only at http://192.168.50.139:6246 (owner's choice, 2026-11-07).
  Never add a Traefik route or forward. Runs as user 1000:10. Data /volume2/docker/maintainerr/data (backup skips data/ui).
  Linked: Jellyfin (API key "Maintainerr"), Radarr, Sonarr. Not linked: Seerr. No media mount.
- Rule groups: every group must be action "Do nothing" (arrAction 4), have Radarr/Sonarr selected (with no
  *arr the only actions are Delete-from-Jellyfin or Do nothing) and "Keep in Maintainerr only" on. Groups are
  currently INACTIVE. "Take action after days" only appears for real actions.
- Active groups run automatically every 8 h (00:00, 08:00, 16:00) without Run Rules.
- Some Maintainerr GET routes change state (/api/collections/activate|deactivate/:id). Read-only checks use
  /api/rules, /api/collections, /api/collections/media/:id/content/:page only.
- Keep Jellyfin "Group movies/shows into collections" OFF (Dashboard > Libraries > Display), Maintainerr #2554.
  TMDb Box Sets plugin collections affect rules that use collection fields.
- Whisparr v2 (whisparr, hotio v2-2.2.0-release.231) at http://192.168.50.139:6969 and Whisparr v3 "Eros"
  (whisparr3, hotio v3-3.6.5-release.1886, Radarr-based, API /api/v3) at http://192.168.50.139:6970.
  LAN only with Forms login: never add a Traefik route, DNS record or forward. Both run with
  PUID=1000/PGID=10 (hotio s6 fails under user:). Not managed by Profilarr (no Whisparr support).
- Media: v2 /volume1/media-private, v3 /volume1/media-private-v3. Both are UGOS shared folders: create
  new library folders in the UGOS GUI, not with mkdir (plain folders are invisible in the GUI).
  Downloads: Syncthing folders data1/whisparr and data1/whisparr3, mounted as /downloads.
- Seedbox: SABnzbd category and rTorrent label whisparr / whisparr3, rTorrent dir
  /sda/0006/downloads/<label>. v3 remote path maps: /sda/0006/downloads/whisparr3/ and
  /downloads/whisparr3/ -> /downloads/. v2 has only the /sda map: its SABnzbd downloads are
  imported by hand, by choice.
- Prowlarr apps "Whisparr" and "Whisparr v3", both tag adult (PornoLab is adult-only).
- hotio Whisparr v3 creates user 'whisparr' on first start and prints its password in docker logs.
  Never grep auth lines from its logs.
- Tdarr 2.96.01 (tdarr, http://127.0.0.1:8265 on the NAS only; reach it through an SSH tunnel). TEST PHASE.
  Write-enabled on the two private libraries ONLY: /volume1/media-private -> /media-private and
  /volume1/media-private-v3 -> /media-private-v3. /media1 and /media2 stay :ro: never run Tdarr on the
  main libraries and never make those mounts writable.
- Quick Sync: /dev/dri passed through, group_add 105 (render; card0 is 44). The image adds abc (1000:10) to
  both groups at start. hevc_qsv verified in tdarr-ffmpeg. Jellyfin-HT shares the iGPU: one GPU transcode
  worker at most, CPU and health-check workers 0, library schedule off-peak only.
- Cache /volume2/docker/tdarr/cache -> /tdarr-cache. Scratch /volume2/docker/tdarr/test/{in,out} -> /tdarr-test
  (copies of library files only).
- Guards: node starts paused (startPaused=true), all workers 0 in compose, auto plugin update off, no login.
  Do not unpause, raise workers or point a library at /media-private or /media-private-v3 until the owner
  approves the test results. Flow: skip hevc/av1, skip 10-bit, skip above 1080p and below 720p, skip under
  2 Mbps (1080p) / 1 Mbps (720p), hevc_qsv global_quality 23 (1080p) / 22 (720p), copy all audio and
  subtitles, keep the container, keep the output only if it is smaller. Test outputs go to /tdarr-test/out;
  never add Replace Original File until the owner approves.
  
  
