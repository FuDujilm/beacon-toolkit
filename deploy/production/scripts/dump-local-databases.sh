#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROJECT_DIR="$(cd "$TOOLKIT_DIR/.." && pwd)"

BEACON_API_DIR="${BEACON_API_DIR:-$PROJECT_DIR/beacon-api}"
OPENOIDC_DIR="${OPENOIDC_DIR:-$PROJECT_DIR/OpenOIDC}"
OUT_DIR="${OUT_DIR:-$TOOLKIT_DIR/deploy/production/backups/local-export-$(date +%Y%m%d-%H%M%S)}"

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

load_env() {
  set -a
  # shellcheck disable=SC1090
  source "$1"
  set +a
}

dump_beacon_api() {
  require_file "$BEACON_API_DIR/.env"
  load_env "$BEACON_API_DIR/.env"
  if [[ -z "${DATABASE_URL:-}" ]]; then
    echo "DATABASE_URL is empty in $BEACON_API_DIR/.env" >&2
    exit 1
  fi

  mkdir -p "$OUT_DIR"
  pg_dump --format=custom --no-owner --no-acl \
    --file "$OUT_DIR/beacon-api.dump" \
    "$DATABASE_URL"
}

dump_openoidc() {
  if [[ "${EXPORT_OPENOIDC:-false}" != "true" ]]; then
    return
  fi

  require_file "$OPENOIDC_DIR/.env"
  load_env "$OPENOIDC_DIR/.env"
  mkdir -p "$OUT_DIR"

  local driver="${OIDC_DATABASE_DRIVER:-postgres}"
  if [[ "$driver" != "postgres" ]]; then
    echo "OpenOIDC local export only supports PostgreSQL now. Set OIDC_DATABASE_DRIVER=postgres in $OPENOIDC_DIR/.env." >&2
    exit 1
  fi

  if [[ -z "${OIDC_DATABASE_HOST:-}" ||
        -z "${OIDC_DATABASE_PORT:-}" ||
        -z "${OIDC_DATABASE_USER:-}" ||
        -z "${OIDC_DATABASE_PASSWORD:-}" ||
        -z "${OIDC_DATABASE_NAME:-}" ]]; then
    echo "OpenOIDC PostgreSQL settings are incomplete in $OPENOIDC_DIR/.env" >&2
    exit 1
  fi

  PGPASSWORD="$OIDC_DATABASE_PASSWORD" pg_dump \
    --host "$OIDC_DATABASE_HOST" \
    --port "$OIDC_DATABASE_PORT" \
    --username "$OIDC_DATABASE_USER" \
    --dbname "$OIDC_DATABASE_NAME" \
    --format=custom \
    --no-owner \
    --no-acl \
    --file "$OUT_DIR/openoidc.dump"
}

write_manifest() {
  cat > "$OUT_DIR/manifest.txt" <<EOF
created_at=$(date -Is)
beacon_api_dir=$BEACON_API_DIR
openidc_dir=$OPENOIDC_DIR
beacon_api_dump=beacon-api.dump
openidc_dump=$(if [[ -f "$OUT_DIR/openoidc.dump" ]]; then echo openoidc.dump; else echo ""; fi)
EOF
}

main() {
  require_command pg_dump
  dump_beacon_api
  dump_openoidc
  write_manifest
  echo "$OUT_DIR"
}

main "$@"
