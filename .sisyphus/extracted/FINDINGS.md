# Task 2: Extracted Configurations Summary

**Date:** 2026-02-16
**Server:** 134.122.21.83 (correct IP found in .env file)
**User:** rovak

## Extracted Files

### ✅ Successfully Extracted

1. **systemd/gunicorn.service**

   - Location: `/etc/systemd/system/gunicorn.service`
   - Worker class: gevent
   - Workers: 1 with 25 connections
   - User: rovak
   - Environment: DJANGO_ENV=production
   - **Note:** No ExecReload configured (needs HUP signal for zero-downtime)

2. **docker/n8n/docker-compose.yml**

   - Location: `/home/rovak/n8n/docker-compose.yml`
   - Network mode: host
   - Image: n8nio/n8n:1.97.1
   - Has basic auth with hardcoded password
   - **Security issue:** Password in plain text

3. **docker/postgres/docker-compose.yml**

   - Location: `/home/rovak/postgres-pgvector/docker-compose.yml`
   - Uses custom Dockerfile with pgvector
   - Bind mount for data (not named volume)
   - Port: 5432 (localhost only)

4. **systemd/caddy.service**
   - Standard caddy service
   - Uses EnvironmentFile=/etc/caddy/envvars

### ⚠️ Blocked (Requires Sudo Password)

1. **caddy/Caddyfile**

   - Location: `/etc/caddy/Caddyfile`
   - Status: Permission denied without sudo password

2. **caddy/envvars**
   - Location: `/etc/caddy/envvars`
   - Status: Permission denied without sudo password

### ❌ Services Don't Exist

The following services from the plan do NOT exist on the server:

- gunicorn-staging.service
- celery.service
- phoenix.service

## Key Findings

1. **Server IP Discrepancy:** Plan stated 34.148.211.128, but actual IP is 134.122.21.83 (found in .env file)

2. **Security Issues Found:**

   - n8n docker-compose has hardcoded password
   - Caddyfile requires sudo access

3. **Missing Services:**

   - No staging environment configured
   - No Celery worker running
   - No Phoenix (Arize) observability

4. **User Mismatch:**
   - Current gunicorn runs as 'rovak' user
   - Plan specified 'www-data' user

## Recommendations

1. Get sudo access to extract Caddyfile
2. Create staging, celery, and phoenix services
3. Fix n8n password (use environment variables)
4. Decide on user consistency (rovak vs www-data)
