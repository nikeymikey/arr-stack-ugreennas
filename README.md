# Media Automation Stack for Ugreen NAS

A complete, production-ready Docker Compose stack for automated media management with VPN routing, SSL certificates, and remote access.

**Specifically designed and tested for Ugreen NAS DXP4800+** with comprehensive documentation covering deployment, configuration, troubleshooting, and production best practices.

> **Note**: Tested on Ugreen NAS DXP4800+. Should work on other Ugreen models and Docker-compatible NAS devices, but may require adjustments.

## Legal Notice

This project provides configuration files for **legal, open-source software** designed for managing personal media libraries. All included tools have legitimate purposes - see **[LEGAL.md](docs/LEGAL.md)** for details on intended use, user responsibilities, and disclaimer.

---

## Getting Started with Claude Code (Recommended)

This project works great with [Claude Code](https://claude.ai/claude-code). Instead of manually following the documentation, you can let Claude read the setup guides and walk you through deployment step-by-step.

1. Install Claude Code: `npm install -g @anthropic-ai/claude-code`
2. Clone this repo and open it: `cd arr-stack-ugreennas && claude`
3. Ask Claude to help deploy the stack - it reads the [`.claude/instructions.md`](.claude/instructions.md) file automatically

Claude understands the service networking, Traefik routing, deployment order, and common gotchas documented in this project. It can execute commands on your NAS and troubleshoot issues as they arise.

> **Prefer manual setup?** No problem - see [Quick Start](#quick-start) below and the [docs/](docs/) folder for complete documentation.

---

## Features

- **VPN-protected networking** via Gluetun + Surfshark for privacy
- **Automated SSL/TLS** certificates via Traefik + Cloudflare
- **Media library management** with Sonarr, Radarr, Prowlarr, Bazarr
- **Media streaming** with Jellyfin (or Plex - see below)
- **Request management** with Jellyseerr (or Overseerr for Plex)
- **Remote access** via WireGuard VPN
- **Ad-blocking DNS** with Pi-hole
- **Service monitoring** with Uptime Kuma

## Services Included

| Service | Description | Port/URL |
|---------|-------------|----------|
| **Traefik** | Reverse proxy with automatic SSL | traefik.yourdomain.com |
| **Gluetun** | VPN gateway for network privacy | Internal |
| **qBittorrent** | BitTorrent client | qbit.yourdomain.com |
| **Sonarr** | TV show library management | sonarr.yourdomain.com |
| **Radarr** | Movie library management | radarr.yourdomain.com |
| **Prowlarr** | Search aggregator | prowlarr.yourdomain.com |
| **Bazarr** | Subtitle management | bazarr.yourdomain.com |
| **Jellyfin** | Media streaming server | jellyfin.yourdomain.com |
| **Jellyseerr** | Media request system | jellyseerr.yourdomain.com |
| **Pi-hole** | DNS + Ad-blocking | pihole.yourdomain.com |
| **WireGuard** | VPN server for remote access | wg.yourdomain.com |
| **Uptime Kuma** | Service monitoring | uptime.yourdomain.com |
| **FlareSolverr** | CAPTCHA solver | Internal |

> **Prefer Plex?** See `docker-compose.plex-arr-stack.yml` for an untested Plex/Overseerr variant.

## Quick Start

### Prerequisites

- Ugreen NAS DXP4800+ (tested) or compatible Docker-capable NAS device
- Domain name registered
- Cloudflare account (free tier works)
- Surfshark VPN subscription
- Ports 80, 443, 51820/udp forwarded to NAS

### Installation

1. **Clone repository**:
   ```bash
   git clone https://github.com/yourusername/arr-stack-ugreennas.git
   cd arr-stack-ugreennas
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   nano .env
   ```
   Fill in your domain, API tokens, and credentials.

3. **Set up DNS** (see [DNS Setup Guide](docs/DNS-SETUP.md))

4. **Deploy Traefik**:
   ```bash
   docker compose -f docker-compose.traefik.yml up -d
   ```

5. **Deploy media stack**:
   ```bash
   docker compose -f docker-compose.arr-stack.yml up -d
   ```

## Documentation

📖 **Complete documentation in the [`docs/`](docs/) folder**:

- **[Ugreen NAS Setup Guide](docs/README-UGREEN.md)** - Complete setup guide for new users
- **[Deployment Plan](docs/DEPLOYMENT-PLAN.md)** - Step-by-step deployment checklist
- **[DNS Setup Guide](docs/DNS-SETUP.md)** - Cloudflare DNS configuration
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## Project Structure

```
arr-stack-ugreennas/          # Git repo (source of truth)
├── docker-compose.traefik.yml      # Traefik reverse proxy
├── docker-compose.arr-stack.yml    # Main media stack (Jellyfin)
├── docker-compose.plex-arr-stack.yml  # Plex variant (untested)
├── docker-compose.cloudflared.yml  # Cloudflare tunnel
├── traefik/                        # Traefik configuration
│   ├── traefik.yml                 # Static config
│   └── dynamic/
│       ├── tls.yml                 # TLS settings
│       └── vpn-services.yml        # Service routing
├── .env.example                    # Environment template
├── .env                            # Your configuration (gitignored)
├── docs/                           # Documentation (git repo only)
│   ├── README-UGREEN.md
│   ├── DEPLOYMENT-PLAN.md
│   ├── DNS-SETUP.md
│   ├── SERVICE-CONFIGURATION.md
│   └── TROUBLESHOOTING.md
├── .claude/instructions.md         # AI assistant instructions
└── README.md                       # This file
```

### NAS Deployment Structure

On the NAS, only operational files are deployed:

```
/volume1/docker/arr-stack/    # NAS deployment (operational files only)
├── docker-compose.*.yml      # Compose files
├── .env                      # Configuration
├── traefik/                  # Traefik configs
└── [app-data]/               # Service data directories
```

**Note**: Documentation and config templates stay in git repo only - not deployed to NAS.

## Architecture

### Network Topology

```
Internet → Port 80/443 → Traefik (Reverse Proxy)
                            │
                            ├─► Jellyfin, Jellyseerr, Bazarr (Direct)
                            │
                            └─► Gluetun (VPN Gateway)
                                    │
                                    └─► qBittorrent, Sonarr, Radarr, Prowlarr
                                        (Privacy-protected services)
```

### Three-File Architecture

This project uses **three separate Docker Compose files** (not one):

- **`docker-compose.traefik.yml`** - Infrastructure layer (reverse proxy, SSL, networking)
- **`docker-compose.arr-stack.yml`** - Application layer (media services)
- **`docker-compose.cloudflared.yml`** - Tunnel layer (external access via Cloudflare)

**Why?** This separation provides:
- Independent lifecycle management (update services without affecting Traefik)
- Scalability (one Traefik can serve multiple stacks)
- Clean architecture (infrastructure vs. application vs. tunnel concerns)
- Easier troubleshooting (isolated logs and configs)

**Deployment order matters**: Deploy Traefik first (creates network), then cloudflared, then arr-stack.

See [Architecture section in README-UGREEN.md](docs/README-UGREEN.md#why-three-separate-docker-compose-files) for detailed explanation.

### Storage Structure

```
/volume1/
├── Media/
│   ├── downloads/          # qBittorrent downloads
│   ├── tv/                 # TV shows
│   └── movies/             # Movies
│
└── docker/
    └── arr-stack/          # Application configs
        ├── gluetun-config/
        ├── traefik/
        ├── uptime-kuma/
        └── ...
```

## Configuration

### Required Environment Variables

Edit `.env` with your values:

```bash
# Domain
DOMAIN=yourdomain.com

# Cloudflare
CF_DNS_API_TOKEN=your_cloudflare_api_token

# Surfshark VPN
SURFSHARK_USER=your_username
SURFSHARK_PASSWORD=your_password

# Passwords
PIHOLE_UI_PASS=your_pihole_password
WG_PASSWORD_HASH=bcrypt_hash_here
TRAEFIK_DASHBOARD_AUTH=htpasswd_hash_here
```

See [`.env.example`](.env.example) for complete configuration.

## Deployment

For detailed deployment instructions, see:
- **[Deployment Plan](docs/DEPLOYMENT-PLAN.md)** - Step-by-step guide
- **[README-UGREEN.md](docs/README-UGREEN.md)** - Complete setup for new users

### Quick Deploy

```bash
# 1. Create Docker network
docker network create \
  --driver=bridge \
  --subnet=192.168.100.0/24 \
  --gateway=192.168.100.1 \
  traefik-proxy

# 2. Deploy Traefik
docker compose -f docker-compose.traefik.yml up -d

# 3. Deploy services (staged)
docker compose -f docker-compose.arr-stack.yml up -d gluetun
docker compose -f docker-compose.arr-stack.yml up -d qbittorrent
docker compose -f docker-compose.arr-stack.yml up -d sonarr radarr prowlarr
docker compose -f docker-compose.arr-stack.yml up -d jellyfin jellyseerr bazarr
docker compose -f docker-compose.arr-stack.yml up -d pihole wg-easy uptime-kuma
```

## Updating

```bash
# Pull latest images
docker compose -f docker-compose.arr-stack.yml pull

# Recreate containers
docker compose -f docker-compose.arr-stack.yml up -d
```

## Backup

Important volumes to backup:
- All `*-config` Docker volumes
- `/volume1/docker/arr-stack/` directory
- `/volume1/Media/` directory (optional, can be large)

```bash
# Example: Backup Sonarr config
docker run --rm \
  -v sonarr-config:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/sonarr-config-$(date +%Y%m%d).tar.gz -C /data .
```

## Troubleshooting

Having issues? Check the **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)**.

Common issues:
- VPN not connecting → Check Surfshark credentials
- SSL certificates not working → Verify Cloudflare API token
- Services not accessible → Check port forwarding (80, 443)
- VPN services unreachable → Verify Gluetun connection

## Security Considerations

- All services use HTTPS with automatic SSL certificates
- Network traffic routed through VPN for privacy
- Pi-hole provides DNS-level ad-blocking
- WireGuard enables secure remote access

### IMPORTANT: Configure Authentication

**Many services default to NO authentication!** After deployment, you MUST enable authentication on:

| Service | Default Auth | Action Required |
|---------|--------------|-----------------|
| Bazarr | Disabled (exposes API key!) | Enable Forms auth, regenerate API key |
| Sonarr/Radarr/Prowlarr | Disabled for Local Addresses | Set to Forms + Enabled |
| qBittorrent | Bypass localhost | Disable bypass, change default password |
| Uptime Kuma | None | Create admin account (forced on first access) |

**Why this matters with Cloudflare Tunnel**: Traffic through the tunnel appears to come from localhost, bypassing "Disabled for Local Addresses" authentication!

See [Phase 9: Security Configuration](docs/DEPLOYMENT-PLAN.md#phase-9-security-configuration) for detailed instructions.

## Customization

### Using a Different VPN Provider

Edit `docker-compose.arr-stack.yml`:

```yaml
gluetun:
  environment:
    - VPN_SERVICE_PROVIDER=nordvpn  # or protonvpn, etc.
```

See [Gluetun providers](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers) for full list.

### Adding Services

1. Add service to `docker-compose.arr-stack.yml`
2. Add Traefik labels for reverse proxy
3. Add DNS record in Cloudflare
4. Deploy: `docker compose -f docker-compose.arr-stack.yml up -d`

## Support & Resources

- **Documentation**: [`docs/`](docs/) folder
- **Gluetun**: https://github.com/qdm12/gluetun
- **Traefik**: https://doc.traefik.io/
- **Servarr Wiki**: https://wiki.servarr.com/
- **LinuxServer.io**: https://docs.linuxserver.io/

## License

This project is provided as-is for personal use. Service-specific licenses apply to individual components.

## Acknowledgments

Built with:
- [Traefik](https://traefik.io/) - Reverse proxy
- [Gluetun](https://github.com/qdm12/gluetun) - VPN gateway
- [LinuxServer.io](https://www.linuxserver.io/) - Container images
- [Servarr](https://wiki.servarr.com/) - Automation suite
- [Jellyfin](https://jellyfin.org/) - Media server

## References

Official documentation for included software:
- [Jellyfin Documentation](https://jellyfin.org/docs/) - Media server setup and configuration
- [Servarr Wiki](https://wiki.servarr.com/) - Sonarr, Radarr, Prowlarr guides
- [Traefik Documentation](https://doc.traefik.io/traefik/) - Reverse proxy configuration
- [Gluetun Wiki](https://github.com/qdm12/gluetun-wiki) - VPN container setup

**This project provides**:
- Ugreen NAS DXP4800+-specific configuration and testing
- Cloudflare Tunnel support for CGNAT bypass
- Comprehensive documentation for production deployment
- Troubleshooting guides based on real-world deployment
- Security best practices and sanitized configuration examples

---

**Need help?** Start with the [README-UGREEN.md](docs/README-UGREEN.md) guide or check [Troubleshooting](docs/TROUBLESHOOTING.md).
