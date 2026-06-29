# Beacon Production Deployment

This directory contains the production deployment template for:

- OpenOIDC
- beacon-api
- beacon-api admin frontend
- nginx HTTP reverse proxy
- PostgreSQL for OpenOIDC
- PostgreSQL for beacon-api
- Redis for OpenOIDC

The recommended server path is:

```text
/opt/beacon/
  compose.yml
  .env
  nginx/default.conf
  src/OpenOIDC
  src/beacon-api
```

## 1. DNS

Create two DNS records pointing to the production server:

```text
id.hamcy.work      A    47.109.58.184
beacon.hamcy.work  A    47.109.58.184
```

Then set the same domains in `.env`:

```text
OIDC_DOMAIN=id.hamcy.work
BEACON_DOMAIN=beacon.hamcy.work
```

This stack only exposes HTTP. Put CDN HTTPS in front of it:

```text
CDN HTTPS id.hamcy.work      -> origin http://47.109.58.184:5000
CDN HTTPS beacon.hamcy.work  -> origin http://47.109.58.184:5000
```

OpenOIDC and beacon-api still use `https://id.hamcy.work` and `https://beacon.hamcy.work` as public URLs because users enter through the CDN.

## 2. Server Bootstrap

Install Docker and prepare the deployment directory:

```bash
apt update
apt install -y ca-certificates curl git ufw
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
  > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

mkdir -p /opt/beacon/src /opt/beacon/nginx /opt/beacon/backups
```

Firewall:

```bash
ufw allow OpenSSH
ufw allow 5000/tcp
ufw --force enable
```

## 3. Upload Deployment Files

Copy these files to the server:

```text
deploy/production/compose.yml       -> /opt/beacon/compose.yml
deploy/production/.env.example      -> /opt/beacon/.env
deploy/production/nginx/default.conf -> /opt/beacon/nginx/default.conf
```

Edit `/opt/beacon/.env` and replace every `replace-with-*` value.

Generate strong secrets:

```bash
openssl rand -base64 48
```

For production, keep OpenOIDC on PostgreSQL:

```text
OIDC_DATABASE_DRIVER=postgres
```

The previous local OpenOIDC SQLite database is intentionally not migrated. Production starts a fresh OpenOIDC PostgreSQL database; recreate OAuth clients/users from OpenOIDC admin after first start.

## 4. Put Source Code on the Server

Recommended layout:

```bash
cd /opt/beacon/src
git clone <OpenOIDC repo url> OpenOIDC
git clone <beacon-api repo url> beacon-api
```

If the repositories are private, configure a deploy key or GitHub token on the server.

## 5. First Start: OpenOIDC

Start PostgreSQL, Redis, OpenOIDC, and the reverse proxy:

```bash
cd /opt/beacon
docker compose up -d oidc-postgres oidc-redis openoidc proxy
docker compose logs -f openoidc
```

Open:

```text
https://<OIDC_DOMAIN>
```

Login with:

```text
OIDC_ADMIN_EMAIL
OIDC_ADMIN_PASSWORD
```

Create an OAuth client for beacon-api / admin:

```text
Client ID:      value of BEACON_OAUTH_CLIENT_ID
Client Secret:  value of BEACON_OAUTH_CLIENT_SECRET
Redirect URI:   https://<BEACON_DOMAIN>/admin/callback
```

The admin account should have trust/security level `3` or higher if `BEACON_ADMIN_MIN_SECURITY_LEVEL=3`.

## 6. Start beacon-api

```bash
cd /opt/beacon
docker compose up -d beacon-postgres beacon-api
docker compose logs -f beacon-api
```

Health check:

```bash
curl -fsS https://<BEACON_DOMAIN>/health
```

Admin:

```text
https://<BEACON_DOMAIN>/admin
```

Swagger:

```text
https://<BEACON_DOMAIN>/swagger-ui
```

## 7. Upgrade

```bash
cd /opt/beacon/src/OpenOIDC
git pull

cd /opt/beacon/src/beacon-api
git pull

cd /opt/beacon
docker compose build openoidc beacon-api
docker compose up -d
docker compose logs -f --tail=200 openoidc beacon-api
```

## 8. Backup

Manual backup:

```bash
cd /opt/beacon
mkdir -p backups
docker compose exec -T oidc-postgres pg_dump -U "$OIDC_DATABASE_USER" "$OIDC_DATABASE_NAME" \
  > "backups/openidc-$(date +%F-%H%M%S).sql"
docker compose exec -T beacon-postgres pg_dump -U "$BEACON_DATABASE_USER" "$BEACON_DATABASE_NAME" \
  > "backups/beacon-api-$(date +%F-%H%M%S).sql"
```

Add a cron job after the first successful deployment.

## 9. Migrate Local beacon-api Database To Production

The migration is split into three phases:

1. Dump local databases.
2. Upload the dump directory to the production server.
3. Restore into the Docker Compose PostgreSQL containers.

This process overwrites the target beacon-api database after creating a remote backup. OpenOIDC SQLite is not migrated. By default OpenOIDC starts fresh on PostgreSQL.

### 9.1 Dump Local Databases

Run from the `beacon-toolkit` repository:

```bash
bash deploy/production/scripts/dump-local-databases.sh
```

The script prints the export directory, for example:

```text
/data/D/Project/beacon-toolkit/deploy/production/backups/local-export-20260629-180000
```

Expected output files:

```text
beacon-api.dump
manifest.txt
```

If you later need to migrate a PostgreSQL OpenOIDC database too, run the dump with `EXPORT_OPENOIDC=true`; SQLite OpenOIDC exports are intentionally unsupported.

### 9.2 Upload Export To Server

Use SSH key authentication if possible. If password login is enabled, `ssh/scp` will ask for the password interactively.

```bash
SERVER=root@47.109.58.184 \
bash deploy/production/scripts/upload-export-to-server.sh \
  deploy/production/backups/local-export-YYYYMMDD-HHMMSS
```

The script prints the remote import directory, for example:

```text
/opt/beacon/backups/import/local-export-20260629-180000
```

### 9.3 Install Restore Scripts On Server

Copy the scripts directory to the server once:

```bash
scp -r deploy/production/scripts root@47.109.58.184:/opt/beacon/
ssh root@47.109.58.184 'chmod +x /opt/beacon/scripts/*.sh'
```

### 9.4 Restore On Server

Run on the production server:

```bash
cd /opt/beacon
bash scripts/restore-remote-databases.sh \
  /opt/beacon/backups/import/local-export-YYYYMMDD-HHMMSS
```

The restore script:

- stops `openidc` and `beacon-api`
- backs up existing remote databases into `/opt/beacon/backups/remote-before-restore-*`
- restores OpenOIDC only if `openidc.dump` exists in the import directory
- drops and recreates the `public` schema in the beacon-api target database
- restores `beacon-api.dump`
- starts `openidc` and `beacon-api`

### 9.5 Verify

```bash
curl -fsS https://<OIDC_DOMAIN>/.well-known/openid-configuration
curl -fsS https://<BEACON_DOMAIN>/health
docker compose logs --tail=200 openoidc beacon-api
```

Then check:

- OpenOIDC admin login works.
- The beacon-api admin OAuth login callback works.
- Existing Beacon users, QSO logs, QSL links, and admin settings are present.

## 10. Security Checklist

- Do not commit `.env`.
- Use long random database passwords.
- Use a long random `BEACON_JWT_SECRET`.
- Use a long random `OIDC_SECRETS_CLIENT_SECRET_ENCRYPTION_KEY`.
- Keep ports 3002, 8080, 5432, and 6379 closed to the public internet.
- Only expose 22 and the CDN origin HTTP port, normally 5000.
- Rotate the bootstrap admin password after first login.
- Back up OpenOIDC signing keys and PostgreSQL data.
