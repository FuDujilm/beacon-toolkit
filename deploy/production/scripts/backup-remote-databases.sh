#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/beacon}"
BACKUP_DIR="${BACKUP_DIR:-$DEPLOY_DIR/backups/remote-before-restore-$(date +%Y%m%d-%H%M%S)}"
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

cd "$DEPLOY_DIR"

if [[ ! -f .env ]]; then
  echo "Missing $DEPLOY_DIR/.env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

mkdir -p "$BACKUP_DIR"

if [[ "${OIDC_DATABASE_DRIVER:-postgres}" != "postgres" ]]; then
  echo "Production OpenOIDC must use PostgreSQL. Set OIDC_DATABASE_DRIVER=postgres in $DEPLOY_DIR/.env." >&2
  exit 1
fi

compose exec -T oidc-postgres pg_dump \
  -U "$OIDC_DATABASE_USER" \
  -d "$OIDC_DATABASE_NAME" \
  --format=custom \
  --no-owner \
  --no-acl \
  > "$BACKUP_DIR/openoidc.dump"

compose exec -T beacon-postgres pg_dump \
  -U "$BEACON_DATABASE_USER" \
  -d "$BEACON_DATABASE_NAME" \
  --format=custom \
  --no-owner \
  --no-acl \
  > "$BACKUP_DIR/beacon-api.dump"

echo "$BACKUP_DIR"
