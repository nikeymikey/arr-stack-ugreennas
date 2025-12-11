# Cloudflare Tunnel Setup for Ugreen NAS

Cloudflare Tunnel creates a secure outbound connection from your NAS to Cloudflare's network, bypassing the need for port forwarding. This works even if you're behind CGNAT or your ISP blocks incoming connections.

## Why Cloudflare Tunnel?

**Use this if**:
- Port forwarding doesn't work (CGNAT, ISP blocking)
- You want DDoS protection
- You want to avoid exposing ports to the internet

**Advantages**:
- ✅ No port forwarding needed
- ✅ Works behind CGNAT
- ✅ Free tier (unlimited bandwidth)
- ✅ DDoS protection
- ✅ Access control policies
- ✅ Standard HTTPS URLs (no port numbers)

**Disadvantages**:
- ❌ Slight latency increase
- ❌ Traffic goes through Cloudflare
- ❌ Requires cloudflared daemon
- ❌ Cloudflare can see your traffic

---

## Prerequisites

- Cloudflare account (free tier works)
- Domain managed by Cloudflare DNS (yourdomain.com)
- SSH access to Ugreen NAS (enable in UGOS Control Panel → Terminal → SSH)
- Traefik already deployed

---

## Setup Steps

### Step 1: Install cloudflared on NAS

SSH into your NAS:

```bash
ssh your-username@your-nas-hostname
# Or using IP: ssh your-username@YOUR_NAS_IP
```

Download and install cloudflared:

```bash
# Download cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

# Make executable
chmod +x cloudflared-linux-amd64

# Move to system location
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

# Verify installation
cloudflared --version
```

---

### Step 2: Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This will:
1. Open a browser to Cloudflare login
2. Ask you to select your domain (yourdomain.com)
3. Save credentials to `~/.cloudflared/cert.pem`

If you're on a headless server, it will show a URL to open on another device.

---

### Step 3: Create a Tunnel

```bash
# Create tunnel named "your-tunnel"
cloudflared tunnel create your-tunnel

# Note the tunnel ID (shown in output)
# Example: Tunnel ID: abc123-def456-ghi789
```

This creates:
- Tunnel credentials: `~/.cloudflared/<tunnel-id>.json`
- Tunnel registration in Cloudflare

---

### Step 4: Configure Tunnel

Create configuration file:

```bash
sudo mkdir -p /etc/cloudflared
sudo nano /etc/cloudflared/config.yml
```

Add this configuration:

```yaml
tunnel: <YOUR_TUNNEL_ID>
credentials-file: /home/your-username/.cloudflared/<YOUR_TUNNEL_ID>.json

ingress:
  # Uptime Kuma dashboard
  - hostname: yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # Jellyfin
  - hostname: jellyfin.yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # Sonarr
  - hostname: sonarr.yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # Radarr
  - hostname: radarr.yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # Prowlarr
  - hostname: prowlarr.yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # qBittorrent
  - hostname: qbit.yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # Jellyseerr
  - hostname: jellyseerr.yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # Bazarr
  - hostname: bazarr.yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # Pi-hole
  - hostname: pihole.yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # WireGuard
  - hostname: wg.yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # Traefik dashboard
  - hostname: traefik.yourdomain.com
    service: http://YOUR_NAS_IP:8080
    originRequest:
      noTLSVerify: true

  # Catch-all rule (must be last)
  - service: http_status:404
```

**Why all point to 8080?**
- Traefik listens on port 8080 (container port 80)
- Traefik routes based on Host header
- Cloudflare sends proper Host header
- `noTLSVerify: true` because Traefik uses self-signed certs internally

---

### Step 5: Route DNS to Tunnel

```bash
# Route each subdomain through tunnel
cloudflared tunnel route dns your-tunnel yourdomain.com
cloudflared tunnel route dns your-tunnel jellyfin.yourdomain.com
cloudflared tunnel route dns your-tunnel sonarr.yourdomain.com
cloudflared tunnel route dns your-tunnel radarr.yourdomain.com
cloudflared tunnel route dns your-tunnel prowlarr.yourdomain.com
cloudflared tunnel route dns your-tunnel qbit.yourdomain.com
cloudflared tunnel route dns your-tunnel jellyseerr.yourdomain.com
cloudflared tunnel route dns your-tunnel bazarr.yourdomain.com
cloudflared tunnel route dns your-tunnel pihole.yourdomain.com
cloudflared tunnel route dns your-tunnel wg.yourdomain.com
cloudflared tunnel route dns your-tunnel uptime.yourdomain.com
cloudflared tunnel route dns your-tunnel traefik.yourdomain.com
```

This creates CNAME records in Cloudflare DNS pointing to the tunnel.

---

### Step 6: Test Tunnel

```bash
# Test tunnel configuration
cloudflared tunnel run --config /etc/cloudflared/config.yml your-tunnel
```

Watch for:
- ✅ "Registered tunnel connection"
- ✅ No errors
- ❌ "failed to sufficiently increase receive buffer size" = warning, can ignore

Test from browser: https://yourdomain.com

If working, stop with `Ctrl+C`.

---

### Step 7: Install as System Service

```bash
# Install service
sudo cloudflared service install

# Copy config to system location (if not already there)
sudo cp /etc/cloudflared/config.yml /etc/cloudflared/config.yml

# Copy credentials
sudo cp ~/.cloudflared/<TUNNEL_ID>.json /etc/cloudflared/

# Update config to use system path
sudo nano /etc/cloudflared/config.yml
# Change credentials-file to: /etc/cloudflared/<TUNNEL_ID>.json

# Start service
sudo systemctl start cloudflared

# Enable on boot
sudo systemctl enable cloudflared

# Check status
sudo systemctl status cloudflared
```

---

### Step 8: Update Cloudflare DNS Settings

In Cloudflare dashboard:

1. Go to DNS settings
2. Find CNAME records created by tunnel
3. **IMPORTANT**: Set to "DNS only" (gray cloud icon)
   - NOT "Proxied" (orange cloud)
   - Tunnel already handles proxying

---

## Verification

Test all services:

```bash
# From external network (phone cellular, different ISP)
curl -I https://yourdomain.com
curl -I https://jellyfin.yourdomain.com
curl -I https://sonarr.yourdomain.com
```

All should return HTTP 200 or 308 (redirect).

---

## Troubleshooting

### Tunnel not connecting

```bash
# Check service status
sudo systemctl status cloudflared

# Check logs
sudo journalctl -u cloudflared -f

# Restart service
sudo systemctl restart cloudflared
```

### DNS not resolving

```bash
# Check DNS records
dig yourdomain.com +short

# Should show CNAME to <TUNNEL_ID>.cfargotunnel.com
```

### 502 Bad Gateway

- Tunnel is running but can't reach backend (Traefik)
- Check Traefik is running: `docker ps | grep traefik`
- Check config.yml has correct IP and port

### SSL certificate errors

- **Expected**: Cloudflare handles SSL, Traefik sees HTTP
- Traefik should be configured to not redirect HTTP→HTTPS
- Or use `noTLSVerify: true` in tunnel config

---

## Removing Port Forwarding

Once tunnel is working, you can:

1. Remove port forwarding rules from router (80, 443)
2. Keep WireGuard port forwarding (51820 UDP) for VPN access
3. Update DNS records if needed

---

## Costs

- **Cloudflare Tunnel**: Free (unlimited bandwidth)
- **Cloudflare DNS**: Free
- **DDoS protection**: Free (automatic)

Paid features (optional):
- Access policies (who can access services)
- Teams dashboard
- More tunnel instances

---

## Recommended: Dashboard + Docker (Simplest Method)

This is the easiest approach - configure routes via Cloudflare dashboard and run cloudflared as a Docker container:

### Step 1: Create Tunnel in Cloudflare Dashboard

1. Go to **[Cloudflare Zero Trust](https://one.dash.cloudflare.com/)**
2. Navigate to **Networks → Connectors → Cloudflare Tunnels**
3. Click **Create a tunnel**
4. Choose **Cloudflared** as connector type
5. Name your tunnel (e.g., `nas-tunnel`)
6. Copy the **tunnel token** shown

### Step 2: Add to Docker Compose

```yaml
# docker-compose.cloudflared.yml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=your_tunnel_token_here
    networks:
      traefik-proxy:
        ipv4_address: 192.168.100.12
    restart: unless-stopped
```

### Step 3: Configure Routes in Dashboard

1. In Cloudflare Zero Trust, go to **Networks → Connectors → Cloudflare Tunnels**
2. Click on your tunnel → **Configure**
3. Go to **Published application routes** tab
4. Click **Add an application**
5. For each service, add:
   - **Subdomain**: `jellyfin` (or service name)
   - **Domain**: `yourdomain.com`
   - **Service Type**: `HTTP`
   - **URL**: `YOUR_NAS_IP:8080` (Traefik port)
6. Repeat for each service:
   - `jellyfin.yourdomain.com` → `YOUR_NAS_IP:8080`
   - `sonarr.yourdomain.com` → `YOUR_NAS_IP:8080`
   - `radarr.yourdomain.com` → `YOUR_NAS_IP:8080`
   - `prowlarr.yourdomain.com` → `YOUR_NAS_IP:8080`
   - `qbit.yourdomain.com` → `YOUR_NAS_IP:8080`
   - `jellyseerr.yourdomain.com` → `YOUR_NAS_IP:8080`
   - `bazarr.yourdomain.com` → `YOUR_NAS_IP:8080`
   - `pihole.yourdomain.com` → `YOUR_NAS_IP:8080`
   - `wg.yourdomain.com` → `YOUR_NAS_IP:8080`
   - `traefik.yourdomain.com` → `YOUR_NAS_IP:8080`
   - `uptime.yourdomain.com` → `YOUR_NAS_IP:8080`

**Why all point to port 8080?**
- Traefik listens on port 8080 (mapped from container port 80)
- Traefik routes based on Host header
- Cloudflare sends the proper Host header automatically

### Step 4: Deploy

```bash
cd /volume1/docker/arr-stack
docker compose -f docker-compose.cloudflared.yml up -d
```

---

## Alternative: CLI-Based Configuration

For advanced users who prefer config files over dashboard:

---

## Security Considerations

- **Cloudflare sees your traffic**: Not end-to-end encrypted beyond Cloudflare
- **Access control**: Consider adding Cloudflare Access for authentication
- **Rate limiting**: Consider Cloudflare WAF rules to prevent abuse
- **Traefik auth**: Keep Traefik dashboard auth enabled

---

**Last Updated**: 2025-12-07
