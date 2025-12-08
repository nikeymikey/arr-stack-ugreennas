# Service Configuration Guide

Complete guide for configuring all services in the media library management stack after initial deployment.

**Last Updated**: 2025-12-07

---

## Current Status Summary

### Infrastructure (No Config Needed)
| Service | Status | Notes |
|---------|--------|-------|
| Traefik | ✅ Done | SSL working, routing active |
| Cloudflared | ✅ Done | Tunnel connected |
| Gluetun | ✅ Done | VPN active (37.120.159.132) |
| FlareSolverr | ✅ Done | Running, used by Prowlarr |

### Security (Auth Enabled)
| Service | Status | Notes |
|---------|--------|-------|
| Sonarr | ✅ Auth enabled | Shows login page |
| Radarr | ✅ Auth enabled | Shows login page |
| Prowlarr | ✅ Auth enabled | Shows login page |
| qBittorrent | ✅ Auth enabled | Shows login page |
| Bazarr | ✅ Auth enabled | Forms auth configured |
| Uptime Kuma | ✅ Auth enabled | Admin account created |
| Pi-hole | ✅ Auth enabled | Password from .env |
| WireGuard | ✅ Auth enabled | Password hash from .env |
| Jellyfin | ✅ Built-in | Requires account creation |
| Jellyseerr | ✅ Built-in | Uses Jellyfin auth |

### Application Configuration
| Service | Status | Notes |
|---------|--------|-------|
| qBittorrent | ✅ Done | Password changed, categories set (sonarr, radarr) |
| Sonarr | ✅ Done | Root folder /media/tv, download client configured |
| Radarr | ✅ Done | Root folder /media/movies, download client configured |
| Prowlarr | ✅ Done | Indexers added, linked to Sonarr/Radarr |
| Jellyfin | ✅ Done | Libraries configured |
| Jellyseerr | ✅ Done | Linked to Jellyfin, Sonarr, Radarr |
| Bazarr | ✅ Done | Linked to Sonarr/Radarr, providers configured |
| Uptime Kuma | ✅ Done | Monitors configured (v2.x) |
| Pi-hole | ⏳ Optional | Custom DNS, ad lists |
| WireGuard | ⏳ Optional | Create client configs |

---

## Configuration Order

**Configure services in this order** (dependencies flow downward):

```
1. qBittorrent (download client)
       ↓
2. Sonarr & Radarr (need qBittorrent)
       ↓
3. Prowlarr (needs Sonarr & Radarr API keys)
       ↓
4. Jellyfin (media server)
       ↓
5. Jellyseerr (needs Jellyfin + Sonarr + Radarr)
       ↓
6. Bazarr (needs Sonarr + Radarr)
       ↓
7. Uptime Kuma (monitoring - add all services)
       ↓
8. Pi-hole & WireGuard (optional, independent)
```

---

## Step-by-Step Configuration

### 1. qBittorrent

**URL**: https://qbit.moosenas.cc

**Default Credentials**: `admin` / `adminadmin`

#### Steps:
1. Login with default credentials
2. **Change password immediately**:
   - Tools → Options → Web UI
   - Change password
   - Uncheck "Bypass authentication for clients on localhost"
3. **Configure download paths**:
   - Tools → Options → Downloads
   - Default Save Path: `/downloads`
4. **Create categories** (used by Sonarr/Radarr):
   - Right-click in left panel → Add Category
   - Name: `sonarr`, Save path: `/downloads/sonarr`
   - Name: `radarr`, Save path: `/downloads/radarr`
   - **Important**: Both Name AND Save path must be set
   - **Note**: qBittorrent doesn't allow renaming categories - delete and recreate if needed
5. **Optional - Connection settings**:
   - Tools → Options → Connection
   - Disable UPnP (doesn't work behind VPN)

**Save the new password** - you'll need it for Sonarr/Radarr!

---

### 2. Sonarr (TV Shows)

**URL**: https://sonarr.moosenas.cc

#### Steps:
1. Login (you set the password during auth setup)
2. **Add Root Folder**:
   - Settings → Media Management → Root Folders → Add Root Folder
   - Path: `/media/tv`
3. **Add Download Client**:
   - Settings → Download Clients → + → qBittorrent
   - Host: `gluetun` (use hostname, not IP address)
   - Port: `8085`
   - Username: (your qBittorrent username)
   - Password: (your qBittorrent password)
   - Category: `sonarr`
   - Click "Test" then "Save"

   **Why `gluetun` not `qbittorrent`?** qBittorrent runs inside Gluetun's network (for VPN routing), so you connect via Gluetun's hostname.

   **Why hostname not IP?** Hostnames are more readable and resilient - Docker resolves them automatically. If you used `192.168.100.3` it would work, but `gluetun` is better practice.
4. **Configure Quality Profiles** (optional):
   - Settings → Profiles
   - Edit or create profiles (e.g., "HD-1080p", "Any")
5. **Get API Key** (needed for Prowlarr, Jellyseerr, Bazarr):
   - Settings → General → Security
   - Copy the **API Key**

**Save the API Key!**

---

### 3. Radarr (Movies)

**URL**: https://radarr.moosenas.cc

#### Steps:
1. Login
2. **Add Root Folder**:
   - Settings → Media Management → Root Folders → Add Root Folder
   - Path: `/media/movies`
3. **Add Download Client**:
   - Settings → Download Clients → + → qBittorrent
   - Host: `gluetun` (use hostname, not IP address)
   - Port: `8085`
   - Username: (your qBittorrent username)
   - Password: (your qBittorrent password)
   - Category: `radarr`
   - Click "Test" then "Save"
4. **Configure Quality Profiles** (optional):
   - Settings → Profiles
5. **Get API Key**:
   - Settings → General → Security
   - Copy the **API Key**

**Save the API Key!**

---

### 4. Prowlarr (Indexers)

**URL**: https://prowlarr.moosenas.cc

#### Steps:
1. Login
2. **Add FlareSolverr** (for Cloudflare-protected sites):
   - Settings → Indexers → Add → FlareSolverr
   - Host: `http://flaresolverr:8191`
   - Tags: `flaresolverr`
   - Click "Test" then "Save"
3. **Add Indexers**:
   - Indexers → Add Indexer
   - Search for your preferred indexers
   - For CAPTCHA-protected sites, add the `flaresolverr` tag
4. **Link to Sonarr**:
   - Settings → Apps → + → Sonarr
   - Sync Level: `Full Sync`
   - Prowlarr Server: `http://localhost:9696`
   - Sonarr Server: `http://localhost:8989`
   - API Key: (paste Sonarr API key)
   - Click "Test" then "Save"
5. **Link to Radarr**:
   - Settings → Apps → + → Radarr
   - Sync Level: `Full Sync`
   - Prowlarr Server: `http://localhost:9696`
   - Radarr Server: `http://localhost:7878`
   - API Key: (paste Radarr API key)
   - Click "Test" then "Save"

   **Why `localhost`?** Prowlarr, Sonarr, Radarr, and qBittorrent all use `network_mode: service:gluetun` - they share Gluetun's network stack. From their perspective, they're all on the same host, so use `localhost` not container names.

6. **Sync Indexers**:
   - Settings → Apps → Sync App Indexers (button at bottom)

---

### 5. Jellyfin (Media Server)

**URL**: https://jellyfin.moosenas.cc

#### Steps:
1. If first time: Complete setup wizard
   - Create admin account
   - Set language
2. **Add Media Libraries**:
   - Dashboard → Libraries → Add Media Library
   - **Movies**:
     - Content Type: Movies
     - Folders: `/media/movies`
   - **TV Shows**:
     - Content Type: Shows
     - Folders: `/media/tv`
3. **Optional - Hardware Acceleration**:
   - Dashboard → Playback → Transcoding
   - Hardware acceleration: VAAPI (if supported)
4. **Create Additional Users** (optional):
   - Dashboard → Users → +

---

### 6. Jellyseerr (Requests)

**URL**: https://jellyseerr.moosenas.cc

#### Steps:
1. First visit shows setup wizard
2. **Sign in with Jellyfin**:
   - Choose "Use your Jellyfin account"
   - Jellyfin URL: `http://jellyfin:8096`
   - Click "Sign In"
   - Enter your Jellyfin admin credentials
3. **Configure Jellyfin**:
   - Settings → Jellyfin
   - Should auto-populate from sign-in
   - Click "Sync Libraries"
4. **Add Sonarr**:
   - Settings → Services → Sonarr → Add
   - Default Server: Yes
   - Server Name: `Sonarr`
   - Hostname: `gluetun`
   - Port: `8989`
   - API Key: (paste Sonarr API key)
   - Click "Test" then "Save"
   - Select default quality profile and root folder
5. **Add Radarr**:
   - Settings → Services → Radarr → Add
   - Default Server: Yes
   - Server Name: `Radarr`
   - Hostname: `gluetun`
   - Port: `7878`
   - API Key: (paste Radarr API key)
   - Click "Test" then "Save"
   - Select default quality profile and root folder

   **Why `gluetun`?** Sonarr/Radarr use `network_mode: service:gluetun`, so they're only reachable via Gluetun's hostname from other containers.

---

### 7. Bazarr (Subtitles)

**URL**: https://bazarr.moosenas.cc

#### Steps:
1. Login (you configured auth earlier)
2. **Add Sonarr**:
   - Settings → Sonarr
   - Toggle **Enabled** slider ON first
   - Address: `gluetun`
   - Port: `8989`
   - API Key: (paste Sonarr API key)
   - Click "Test" then "Save"
3. **Add Radarr**:
   - Settings → Radarr
   - Toggle **Enabled** slider ON first
   - Address: `gluetun`
   - Port: `7878`
   - API Key: (paste Radarr API key)
   - Click "Test" then "Save"

   **Why `gluetun`?** Sonarr/Radarr use `network_mode: service:gluetun`, so they're only reachable via Gluetun's hostname from other containers like Bazarr.

4. **Configure Subtitle Providers**:
   - Settings → Providers
   - Recommended: OpenSubtitles.com (free account), Podnapisi (no account)
   - For Latvian: subtitri.id.lv
   - Add multiple providers for better coverage
5. **Configure Languages**:
   - Settings → Languages
   - Add languages to **Languages Filter** (e.g., English, Latvian)
   - Create a **Languages Profile** with your preferred languages in priority order
   - Set as default for **Series** and **Movies** under "Default Language Profiles For Newly Added Shows"
6. **Apply profile to existing media**:
   - Go to **Series** → Select all → **Edit** → Set language profile
   - Go to **Movies** → Select all → **Edit** → Set language profile
   - Without this step, existing media won't get subtitles!

---

### 7. Uptime Kuma (Monitoring)

**URL**: https://uptime.moosenas.cc

#### Step 1: Setup Docker Host (required for Docker monitors)

1. **Settings** (gear icon) → **Docker Hosts**
2. Click **Setup Docker Host**
3. Configure:
   - **Friendly Name**: `NAS`
   - **Connection Type**: `Socket`
   - **Docker Daemon**: `/var/run/docker.sock`
4. Click **Test** - should show green checkmark
5. **Save**

#### Step 2: Configure Notifications (optional but recommended)

1. **Settings** → **Notifications**
2. Click **Setup Notification**
3. Choose notification type (Home Assistant, Discord, Email, etc.)

**For Home Assistant**:
- **Notification Name**: `Home Assistant`
- **Home Assistant URL**: `http://homeassistant.lan:8123` (use `.lan` not `.local` - see note below)
- **Long-Lived Access Token**: Create in HA → Profile → Long-Lived Access Tokens
- Click **Test** then **Save**
- Enable **Default enabled** to use for all monitors

**Note**: Use `.lan` TLD, not `.local`. Docker containers can't resolve `.local` domains (mDNS reserved). See [Pi-hole DNS troubleshooting](TROUBLESHOOTING.md#pi-hole-local-dns-not-resolving-v6).

#### Step 3: Add Docker Container Monitors (infrastructure only)

Only needed for containers without HTTP endpoints:

| Container Name | Friendly Name |
|----------------|---------------|
| `gluetun` | VPN Gateway |
| `cloudflared` | Cloudflare Tunnel |

For each:
1. **Add New Monitor**
2. **Monitor Type**: Docker Container
3. **Container Name**: (exact name from table)
4. **Docker Host**: Select `NAS`
5. **Heartbeat Interval**: 60 seconds
6. **Save**

#### Step 4: Add HTTP Monitors (recommended)

HTTP monitors verify services actually respond, not just that containers are running.

**Three ways to add monitors:**

1. **UI** - Click through web interface (~30 sec per monitor)

2. **Backup/Import** - Settings → Backup → Export, edit JSON, Import

3. **Direct SQLite** - Fast but risky, requires restart:
   ```bash
   docker exec uptime-kuma sqlite3 /app/data/kuma.db "
   INSERT INTO monitor (name, active, user_id, interval, url, type, maxretries) VALUES
   ('ServiceName', 1, 1, 60, 'http://hostname:port/path', 'http', 3);
   "
   docker restart uptime-kuma
   ```

| URL | Friendly Name |
|-----|---------------|
| `http://jellyfin:8096/health` | Jellyfin |
| `http://gluetun:8989/ping` | Sonarr |
| `http://gluetun:7878/ping` | Radarr |
| `http://gluetun:9696/ping` | Prowlarr |
| `http://gluetun:8085` | qBittorrent |
| `http://jellyseerr:5055/api/v1/status` | Jellyseerr |
| `http://bazarr:6767/ping` | Bazarr |
| `http://pihole:80/admin` | Pi-hole |
| `http://flaresolverr:8191` | FlareSolverr |
| `http://homeassistant.lan:8123` | Home Assistant |

**Note**: VPN-routed services (Sonarr, Radarr, Prowlarr, qBittorrent) use `gluetun` hostname since they share its network stack via `network_mode: service:gluetun`.

For each:
1. **Add New Monitor**
2. **Monitor Type**: HTTP(s)
3. **URL**: (from table above)
4. **Friendly Name**: (from table above)
5. **Heartbeat Interval**: 60 seconds
6. **Retries**: 3
7. **Save**

#### Step 5: Create Status Page (optional)

1. **Status Pages** → **New Status Page**
2. Add monitors to display
3. Customize appearance
4. Share the public URL

---

### 8. Pi-hole (Optional)

**URL**: https://pihole.moosenas.cc/admin

**Password**: From your `.env` file (`PIHOLE_UI_PASS`)

#### Optional Configuration:
1. **Add Custom Ad Lists**:
   - Adlists → Add
2. **Configure Local DNS**:
   - Local DNS → DNS Records
   - Add local hostnames
3. **Set as Network DNS**:
   - Configure router to use Pi-hole IP (192.168.100.5) as DNS
   - Or configure individual devices

---

### 9. WireGuard (Optional)

**URL**: https://wg.moosenas.cc

**Password**: The plain-text password you used to generate the hash in `.env`

#### Steps:
1. Login
2. **Create Client Configs**:
   - Click "New"
   - Name the client (e.g., "iPhone", "Laptop")
   - Download or scan QR code
3. **Import to Client**:
   - Install WireGuard app on device
   - Import config or scan QR
4. **Port Forwarding** (required):
   - Forward UDP port 51820 to your NAS IP on your router

---

### 10. Home Assistant Notifications (Optional)

Send notifications from Sonarr/Radarr/etc directly to Home Assistant using webhooks.

#### Step 1: Create HA Automation

In Home Assistant: Settings → Automations → Create → Edit in YAML:

```yaml
alias: Arr Stack Notifications
trigger:
  - platform: webhook
    webhook_id: arr-notifications
    local_only: false
action:
  - service: notify.persistent_notification
    data:
      title: >
        {% if trigger.json.series %}
          {{ trigger.json.series.title }}
        {% elif trigger.json.movie %}
          {{ trigger.json.movie.title }}
        {% else %}
          {{ trigger.json.eventType }}
        {% endif %}
      message: >
        {% if trigger.json.episodes %}
          S{{ trigger.json.episodes[0].seasonNumber }}E{{ trigger.json.episodes[0].episodeNumber }} - {{ trigger.json.episodes[0].title }}
        {% elif trigger.json.movie %}
          ({{ trigger.json.movie.year }}) - {{ trigger.json.eventType }}
        {% else %}
          {{ trigger.json.eventType }}
        {% endif %}
```

Change `notify.persistent_notification` to `notify.mobile_app_your_phone` for push notifications.

#### Step 2: Configure Arr Apps

Same webhook URL for all apps: `http://homeassistant.lan:8123/api/webhook/arr-notifications`

**Prerequisite**: Gluetun's `FIREWALL_OUTBOUND_SUBNETS` must include your LAN (192.168.0.0/24) for VPN services to reach Home Assistant.

**Sonarr**: Settings → Connect → Add → Webhook
- URL: `http://homeassistant.lan:8123/api/webhook/arr-notifications`
- Events: On Grab, On Download, On Upgrade

**Radarr**: Settings → Connect → Add → Webhook
- Same URL, same events

**Bazarr** (optional): Settings → Notifications → Webhook

Click **Test** in each app to verify.

---

## Quick Reference: API Keys & Internal URLs

Keep this handy while configuring:

**VPN-routed services** (use `localhost` to reach each other):
| Service | Internal URL | Port | API Key Location |
|---------|--------------|------|------------------|
| Sonarr | http://localhost:8989 | 8989 | Settings → General |
| Radarr | http://localhost:7878 | 7878 | Settings → General |
| Prowlarr | http://localhost:9696 | 9696 | Settings → General |
| qBittorrent | localhost:8085 | 8085 | N/A (uses password) |

**Other services** (use container hostname):
| Service | Internal URL | Port | API Key Location |
|---------|--------------|------|------------------|
| Jellyfin | http://jellyfin:8096 | 8096 | Dashboard → API Keys |
| FlareSolverr | http://flaresolverr:8191 | 8191 | N/A |
| Bazarr | http://bazarr:6767 | 6767 | Settings → General |

---

## Verification Checklist

After configuration, verify the workflow:

- [ ] VPN working: Gluetun shows non-home IP
- [ ] qBittorrent accessible with new password
- [ ] Sonarr can connect to qBittorrent (test in Download Clients)
- [ ] Radarr can connect to qBittorrent
- [ ] Prowlarr synced indexers to Sonarr/Radarr
- [ ] Jellyfin shows media libraries
- [ ] Jellyseerr can search and request media
- [ ] Bazarr connected to Sonarr/Radarr
- [ ] Uptime Kuma monitors are green

### Test the Integration:

Verify all services can communicate:
1. Jellyseerr can connect to Jellyfin, Sonarr, Radarr
2. Sonarr/Radarr can connect to qBittorrent (via Gluetun)
3. Prowlarr indexers sync to Sonarr/Radarr
4. Bazarr can fetch metadata from Sonarr/Radarr
5. Jellyfin detects media in library folders
6. Uptime Kuma shows all services healthy

---

## Troubleshooting

### Use hostnames, not IP addresses (usually)

- **Usually use container hostnames** when linking services internally
- Docker resolves hostnames automatically
- Hostnames are more readable and resilient than IPs
- Example: `gluetun` instead of `192.168.100.3`

### Exception: VPN-routed services use `localhost`

- Services with `network_mode: service:gluetun` share the same network stack
- This includes: Prowlarr, Sonarr, Radarr, qBittorrent
- These services must use `localhost` to reach each other, not container names
- Example: In Prowlarr, use `http://localhost:8989` for Sonarr (not `http://sonarr:8989`)

### "Connection refused" when linking services

- Use container names, not external URLs
- Example: `http://sonarr:8989` NOT `https://sonarr.moosenas.cc`

### qBittorrent host should be "gluetun"

- qBittorrent uses `network_mode: service:gluetun`
- It shares Gluetun's network stack
- Connect via `gluetun:8085` (hostname, not IP)

### Prowlarr indexers not syncing

- Verify API keys are correct
- Click "Sync App Indexers" in Settings → Apps
- Check Prowlarr logs for errors

### Jellyseerr can't find Jellyfin

- Use internal URL: `http://jellyfin:8096`
- Ensure Jellyfin setup is complete
- Try signing out and back in

---

**Need more help?** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
