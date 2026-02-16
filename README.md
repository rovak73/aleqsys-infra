# Aleqsys Infrastructure (aleqsys-infra)

Infrastructure management and server configuration for the Aleqsys platform (`aleqsys.com`). This repository serves as the single source of truth for server-side configurations, enabling reproducible deployments and disaster recovery.

## Overview

This repository manages the "glue" that keeps the Aleqsys services running. It handles:

- **Reverse Proxy**: Caddy configuration for automatic SSL and routing
- **Service Management**: systemd unit files for Gunicorn, Celery, and other backend tasks
- **Containerization**: Docker Compose setups for isolated services like n8n and observability tools
- **Monitoring**: Automated scripts for health checks, disk usage, and service watchdogs
- **CI/CD**: Validation pipelines to ensure configurations are syntax-correct before deployment

## Server Details

- **IP Address**: `34.148.211.128`
- **Main App Repo**: `/home/rovak/dev/aleqsys.com`
- **Primary Stack**: Caddy, Docker, Python/Django, Svelte 5

## Directory Structure

```text
aleqsys-infra/
├── caddy/                      # Caddyfile configurations (Production & Staging)
│   ├── Caddyfile
│   └── Caddyfile.staging
├── docker/                     # Docker Compose files
│   ├── n8n/
│   │   └── docker-compose.yml
│   └── postgres/
│       └── docker-compose.yml
├── scripts/                    # Infrastructure monitoring and maintenance
│   ├── health-check.sh         # HTTP endpoint monitoring
│   ├── disk-monitor.sh         # Disk usage tracking + Docker cleanup
│   └── service-watchdog.sh     # systemd service state monitoring
├── systemd/                    # Unit files for gunicorn, celery, etc.
│   ├── gunicorn.service
│   ├── gunicorn-staging.service
│   ├── celery.service
│   └── phoenix.service
├── .github/workflows/          # CI/CD pipelines
│   ├── validate-configs.yml    # Pre-merge validation
│   └── deploy-configs.yml      # Atomic deployment workflow
└── .env.example                # Environment variable template
```

## Prerequisites

- SSH access to the production server (34.148.211.128)
- `docker` and `docker-compose` installed
- `caddy` web server installed (managed via systemd)
- `python3` and `poetry` (for application management)

## Setup Instructions

### 1. Server Initialization

On a fresh server, install the core components:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose caddy git shellcheck
```

### 2. Repository Configuration

Clone this repository and set up the environment:

```bash
git clone <repo-url> /opt/aleqsys-infra
cd /opt/aleqsys-infra
cp .env.example .env
# Update .env with production secrets and correct BASE_DOMAIN
```

### 3. Deploying Components

#### Caddy (Web Server)

```bash
# Copy Caddyfile to system location
sudo cp caddy/Caddyfile /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

#### systemd Services

```bash
# Copy service files
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload

# Enable and start services
sudo systemctl enable gunicorn celery caddy
sudo systemctl start gunicorn celery caddy
```

#### Docker Services

```bash
# Start n8n
cd docker/n8n && docker-compose up -d

# Start PostgreSQL
cd docker/postgres && docker-compose up -d
```

#### Monitoring Scripts

Set up cron jobs for monitoring:

```bash
# Edit crontab
sudo crontab -e

# Add these lines:
# Run health check every 5 minutes
*/5 * * * * /opt/aleqsys-infra/scripts/health-check.sh >> /var/log/health-check.log 2>&1

# Run disk monitor every hour
0 * * * * /opt/aleqsys-infra/scripts/disk-monitor.sh >> /var/log/disk-monitor.log 2>&1

# Run service watchdog every 5 minutes
*/5 * * * * /opt/aleqsys-infra/scripts/service-watchdog.sh >> /var/log/watchdog.log 2>&1
```

## Configuration Guide

### Domain Strategy

The infrastructure relies on the `BASE_DOMAIN` variable in `.env`:

- `aleqsys.com` (Base domain - redirects to www)
- `www.aleqsys.com` (Marketing site)
- `app.aleqsys.com` (Main application)
- `staging.aleqsys.com` (Staging environment)
- `n8n.aleqsys.com` (Automation platform)

### Cross-Repository Updates

When you update `BASE_DOMAIN` in this repo, you must also update:

1. **Main App Repository** (`aleqsys.com`):
   - `aleqsys_app/settings/production.py` - Update `ALLOWED_HOSTS`
   - `frontend/src/lib/config.ts` - Update API URLs
   - `frontend/.env.example` - Update `VITE_BASE_DOMAIN`

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# Domain Configuration
BASE_DOMAIN=aleqsys.com
WWW_DOMAIN=www.aleqsys.com
APP_DOMAIN=app.aleqsys.com
STAGING_DOMAIN=staging.aleqsys.com
N8N_DOMAIN=n8n.aleqsys.com

# Django Settings
DEBUG=false
SECRET_KEY=your_django_secret_key_here
DJANGO_SETTINGS_MODULE=aleqsys_app.settings.production

# Database
DATABASE_URL=postgresql://USER:PASSWORD@HOST:PORT/DB_NAME

# Redis
REDIS_URL=redis://localhost:6379/0

# Cloudflare
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token_here
CLOUDFLARE_ZONE_ID=your_zone_id_here

# n8n
N8N_USER=your_n8n_username_here
N8N_PASSWORD=your_n8n_password_here

# Monitoring
DISK_THRESHOLD=90
SLACK_WEBHOOK_URL=your_slack_webhook_url_here_optional
```

## Deployment Workflow

### Atomic Deployment Pattern

To prevent downtime and configuration errors, we use an atomic deployment pattern:

1. **Upload**: Place the new configuration in a temporary location
2. **Validate**: Run validation tools on the temp files
3. **Move**: If validation passes, move files to their destination
4. **Reload**: Trigger a graceful reload (zero-downtime)

```bash
# Example for Caddy
sudo cp caddy/Caddyfile /tmp/Caddyfile.new
sudo caddy validate --config /tmp/Caddyfile.new
sudo mv /tmp/Caddyfile.new /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

### Zero-Downtime Reloads

All services support zero-downtime reloads using the HUP signal:

- **Caddy**: `sudo systemctl reload caddy`
- **Gunicorn**: `sudo systemctl reload gunicorn` (sends HUP signal)
- **Celery**: Graceful shutdown with `SIGTERM`, then restart

### Staging → Production Promotion

1. Update and test configurations in staging variants (e.g., `Caddyfile.staging`)
2. Verify changes at `staging.aleqsys.com`
3. Merge validated changes into production configuration files
4. Perform an **Atomic Reload** (see above)

## CI/CD Pipelines

### Pre-Merge Validation

Every commit and PR is automatically validated by GitHub Actions:

- **Caddyfile**: Syntax check via `caddy validate`
- **systemd**: Unit file verification via `systemd-analyze`
- **Scripts**: Linting via `shellcheck`

See `.github/workflows/validate-configs.yml` for details.

### Automated Deployment

The deployment workflow (`deploy-configs.yml`) handles:

- Staging deployment first
- Health check validation
- Production deployment (with manual approval)
- Automatic rollback on failure

## Monitoring

### Health Check Script

Monitors HTTP endpoints and outputs JSON:

```bash
./scripts/health-check.sh
```

Output:

```json
{
  "timestamp": "2026-02-16T10:00:00Z",
  "checks": {
    "app": { "status": "healthy", "response_time_ms": 45 },
    "n8n": { "status": "healthy", "response_time_ms": 23 }
  },
  "overall": "healthy"
}
```

### Disk Monitor

Checks disk usage and cleans up Docker resources:

```bash
./scripts/disk-monitor.sh
```

Features:

- Alerts at 90% disk usage (configurable via `DISK_THRESHOLD`)
- Runs `docker system prune -f --volumes` to free space
- Sends Slack notifications if configured

### Service Watchdog

Monitors systemd services and reports status:

```bash
./scripts/service-watchdog.sh
```

Monitors: `gunicorn`, `gunicorn-staging`, `celery`, `phoenix`, `caddy`

## Troubleshooting

### Logs

- **systemd Services**: `journalctl -u <service-name> -f`
- **Caddy**: `journalctl -u caddy -f`
- **Docker**: `docker logs <container-name>`

### Common Issues

#### Disk Full

Check if `disk-monitor.sh` is running:

```bash
df -h /
docker system df
```

Manual cleanup:

```bash
docker system prune -a --volumes
```

#### Caddy Start Failure

Usually a port conflict (80/443) or invalid syntax:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
journalctl -u caddy -n 50
```

#### Service Degraded

Check service status:

```bash
sudo systemctl status gunicorn celery caddy
```

Common causes:

- Missing environment variables in `.env`
- Database connection issues
- Permission problems

#### Docker Container Issues

```bash
# Check running containers
docker ps

# Check container logs
docker logs n8n
docker logs postgres

# Restart containers
cd docker/n8n && docker-compose restart
cd docker/postgres && docker-compose restart
```

## Disaster Recovery

### Server Rebuild Procedure

1. **Provision new VPS** and assign the production IP (`34.148.211.128`)

2. **Install prerequisites**:

   ```bash
   sudo apt update
   sudo apt install -y docker.io docker-compose caddy git
   ```

3. **Clone repositories**:

   ```bash
   # Infrastructure repo
   git clone <repo-url> /opt/aleqsys-infra

   # Main app repo
   git clone <app-repo-url> /var/www/aleqsys.com
   ```

4. **Configure environment**:

   ```bash
   cd /opt/aleqsys-infra
   cp .env.example .env
   # Edit .env with production values
   ```

5. **Deploy configurations**:

   ```bash
   sudo cp caddy/Caddyfile /etc/caddy/
   sudo cp systemd/*.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```

6. **Restore database** from backup:

   ```bash
   # Restore from latest backup
   pg_restore -d aleqsys /path/to/backup.sql
   ```

7. **Start services**:

   ```bash
   sudo systemctl enable --now gunicorn celery caddy
   cd docker/n8n && docker-compose up -d
   cd docker/postgres && docker-compose up -d
   ```

8. **Verify health**:
   ```bash
   ./scripts/health-check.sh
   ./scripts/service-watchdog.sh
   ```

## Security

- **No secrets in repo**: Use `.env` file (not committed)
- **Dedicated deploy user**: Use `deploy-infra` user with limited sudo
- **SSH key authentication**: No password-based SSH
- **Atomic deployments**: Never partial config updates

## Contributing

1. Make changes in a feature branch
2. Test in staging environment first
3. Run validation: `caddy validate`, `systemd-analyze`, `shellcheck`
4. Submit PR - CI will validate automatically
5. Merge only after staging verification

## License

Private - For Aleqsys internal use only.

## Support

For issues or questions:

- Check logs: `journalctl -u <service>`
- Run health check: `./scripts/health-check.sh`
- Review this README
- Contact: admin@aleqsys.com
