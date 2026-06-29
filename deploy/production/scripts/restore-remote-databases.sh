#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/beacon}"
IMPORT_DIR="${1:-}"
COMPOSE_BIN="${COMPOSE_BIN:-}"

compose() {
  if [[ -n "$COMPOSE_BIN" ]]; then
    "$COMPOSE_BIN" "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    docker compose "$@"
  fi
}

if [[ -z "$IMPORT_DIR" ]]; then
  echo "Usage: $0 /opt/beacon/backups/import/<export-dir>" >&2
  exit 1
fi

if [[ ! -d "$IMPORT_DIR" ]]; then
  echo "Import directory does not exist: $IMPORT_DIR" >&2
  exit 1
fi

cd "$DEPLOY_DIR"

if [[ ! -f .env ]]; then
  echo "Missing $DEPLOY_DIR/.env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [[ ! -f "$IMPORT_DIR/beacon-api.dump" ]]; then
  echo "Missing beacon-api dump: $IMPORT_DIR/beacon-api.dump" >&2
  exit 1
fi

if [[ -f "$IMPORT_DIR/openoidc.dump" && "${OIDC_DATABASE_DRIVER:-postgres}" != "postgres" ]]; then
  echo "Production OpenOIDC must use PostgreSQL. Set OIDC_DATABASE_DRIVER=postgres in $DEPLOY_DIR/.env." >&2
  exit 1
fi

echo "Stopping application containers..."
compose stop openoidc beacon-api

echo "Backing up current remote databases..."
"$DEPLOY_DIR/scripts/backup-remote-databases.sh" >/dev/null

if [[ -f "$IMPORT_DIR/openoidc.dump" ]]; then
  echo "Restoring OpenOIDC database..."
  compose exec -T oidc-postgres psql \
    -U "$OIDC_DATABASE_USER" \
    -d "$OIDC_DATABASE_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

  compose exec -T oidc-postgres pg_restore \
    -U "$OIDC_DATABASE_USER" \
    -d "$OIDC_DATABASE_NAME" \
    --no-owner \
    --no-acl \
    --clean \
    --if-exists \
    < "$IMPORT_DIR/openoidc.dump"
else
  echo "Skipping OpenOIDC restore: no openoidc.dump in import directory."
fi

echo "Restoring beacon-api database..."
compose exec -T beacon-postgres psql \
  -U "$BEACON_DATABASE_USER" \
  -d "$BEACON_DATABASE_NAME" \
  -v ON_ERROR_STOP=1 \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

compose exec -T beacon-postgres pg_restore \
  -U "$BEACON_DATABASE_USER" \
  -d "$BEACON_DATABASE_NAME" \
  --no-owner \
  --no-acl \
  --clean \
  --if-exists \
  < "$IMPORT_DIR/beacon-api.dump"

echo "Starting application containers..."
compose up -d openoidc beacon-api

echo "Restore complete."
