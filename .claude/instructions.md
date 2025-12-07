# Project Instructions for Claude Code

This file provides context for Claude Code to assist with this project.

## Security

**NEVER commit secrets.** Use `${VAR_NAME}` references in compose files, real values in `.env` (gitignored).

Forbidden in tracked files: API keys, passwords, tokens, private keys, public IPs, email addresses.

## File Locations

| Location | Purpose | Sync to NAS? |
|----------|---------|--------------|
| Git repo | Source of truth | N/A |
| NAS `/volume1/docker/arr-stack/` | Deployment | Only operational files |

**Sync to NAS**: `docker-compose.*.yml`, `traefik/`, `.env`, `scripts/`
**Never sync**: `docs/`, `README.md`, `.env.example`, `.gitignore`

## NAS Access

**Host**: `your-nas.local` | **User**: `your-user`

**On auth failures (SSH, sudo), ASK user for correct password. Don't retry cached passwords.**

```bash
# SCP doesn't work on UGOS. Use stdin redirect:
sshpass -p 'PASS' ssh user@your-nas.local "cat > /path/file" < localfile

# sudo needs password piped:
sshpass -p 'PASS' ssh user@your-nas.local "echo 'PASS' | sudo -S docker ps"

# Image updates need pull + recreate (restart keeps old image):
sudo docker compose -f docker-compose.arr-stack.yml pull <service>
sudo docker compose -f docker-compose.arr-stack.yml up -d <service>
```

## Service Networking

VPN services (Sonarr, Radarr, Prowlarr, qBittorrent) use `network_mode: service:gluetun`.

| Route | Use |
|-------|-----|
| VPN → VPN (Sonarr/Radarr → qBittorrent) | `localhost` |
| Non-VPN → VPN (Jellyseerr → Sonarr) | `gluetun` |
| Any → Non-VPN (Any → Jellyfin) | container name |

**Download client config**: Sonarr/Radarr → qBittorrent: Host=`localhost`, Port=`8085` (they share Gluetun's network).

## Traefik Routing

Routes defined in `traefik/dynamic/vpn-services.yml`, NOT Docker labels.

Docker labels are minimal (`traefik.enable=true`, `traefik.docker.network=traefik-proxy`). To add routes, edit `vpn-services.yml`.

## Cloudflare Tunnel

Dashboard path: **Zero Trust → Networks → Connectors → Cloudflare Tunnels → [tunnel] → Configure → Published application routes**

All routes point to `NAS_IP:8080` (Traefik). Traefik routes by Host header.

## Pi-hole DNS (v6+)

Uses `pihole.toml`, NOT `custom.list`.

```bash
# Edit hosts array (~line 129) in container:
docker exec pihole sed -n '129p' /etc/pihole/pihole.toml
# Then: docker restart pihole
```

**TLDs**: `.local` fails in Docker (mDNS reserved). Use `.lan` for local DNS.

**Docker services for VPN-routed containers**: Add to Pi-hole so Prowlarr/Sonarr/Radarr can resolve them:
```
192.168.100.10 flaresolverr
```

## Architecture

- **3 compose files**: traefik (infra), arr-stack (apps), cloudflared (tunnel)
- **Network**: traefik-proxy (192.168.100.0/24), static IPs for all services
- **External access**: Cloudflare Tunnel (bypasses CGNAT)

## Adding Services

1. Add to `docker-compose.arr-stack.yml` with static IP
2. Add route to `traefik/dynamic/vpn-services.yml`
3. If VPN-routed: use `network_mode: service:gluetun`
4. Sync compose + traefik config to NAS

## Service Notes

| Service | Note |
|---------|------|
| Pi-hole | v6 API uses password not separate token |
| Gluetun | VPN gateway. Services using it share IP 192.168.100.3. Uses Pi-hole DNS. `FIREWALL_OUTBOUND_SUBNETS` must include LAN for HA access |
| Cloudflared | SSL terminated at Cloudflare, Traefik receives HTTP |
| wg-easy | Generate hash: `docker run --rm ghcr.io/wg-easy/wg-easy wgpw 'PASSWORD'` |
| FlareSolverr | Cloudflare bypass for Prowlarr. Configure in Prowlarr: Settings → Indexers → add FlareSolverr with Host `flaresolverr` |

## Container Updates

UGOS handles automatic updates natively (no Watchtower needed):
- **Docker → Management → Image update**
- Update detection: enabled
- Update as scheduled: weekly

## Backups

Daily backup to USB stick at `/mnt/arr-backup`. Keeps 7 days of backups.

```bash
# Install backup script
sudo cp scripts/arr-backup.sh /usr/local/bin/ && sudo chmod +x /usr/local/bin/arr-backup.sh

# Add cron job (3am daily)
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/arr-backup.sh") | sudo crontab -

# Manual backup
sudo /usr/local/bin/arr-backup.sh

# Check logs
cat /var/log/arr-backup.log
```

Backs up: compose files, .env, traefik config, all app data (Sonarr, Radarr, Prowlarr, qBittorrent, Jellyfin, Jellyseerr, Bazarr, Uptime Kuma).

## Uptime Kuma SQLite

Add monitors via SQLite (must include `user_id=1`):
```bash
docker exec uptime-kuma sqlite3 /app/data/kuma.db "INSERT INTO monitor (name, type, url, interval, accepted_statuscodes_json, ignore_tls, active, maxretries, user_id) VALUES ('Service Name', 'http', 'http://url', 60, '[\"200-299\"]', 0, 1, 3, 1);"
docker restart uptime-kuma
```

For HTTPS with self-signed cert or 401 auth page: `ignore_tls=1`, `accepted_statuscodes_json='[\"200-299\",\"401\"]'`

## .env Gotchas

**Bcrypt hashes must be quoted** (they contain `$` which Docker interprets as variables):
```bash
# Wrong
WG_PASSWORD_HASH=$2a$12$abc...
TRAEFIK_DASHBOARD_AUTH=admin:$2y$05$abc...

# Correct
WG_PASSWORD_HASH='$2a$12$abc...'
TRAEFIK_DASHBOARD_AUTH='admin:$2y$05$abc...'
```
