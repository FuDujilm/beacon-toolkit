#!/usr/bin/env bash
set -euo pipefail

SERVER="${SERVER:-}"
EXPORT_DIR="${1:-}"
REMOTE_IMPORT_ROOT="${REMOTE_IMPORT_ROOT:-/opt/beacon/backups/import}"

if [[ -z "$SERVER" || -z "$EXPORT_DIR" ]]; then
  echo "Usage: SERVER=root@your-server $0 <local-export-dir>" >&2
  exit 1
fi

if [[ ! -d "$EXPORT_DIR" ]]; then
  echo "Local export directory does not exist: $EXPORT_DIR" >&2
  exit 1
fi

EXPORT_NAME="$(basename "$EXPORT_DIR")"
REMOTE_DIR="$REMOTE_IMPORT_ROOT/$EXPORT_NAME"

ssh "$SERVER" "mkdir -p '$REMOTE_DIR'"
scp -r "$EXPORT_DIR"/. "$SERVER:$REMOTE_DIR/"

echo "$REMOTE_DIR"
