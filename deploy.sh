#!/bin/bash
# =============================================================================
# deploy.sh - deploys the homelab-infra repo onto Unraid.
# Run it after every git pull (manually, from infra-poller.sh, or from a CI
# webhook). Safe to run repeatedly - everything is idempotent.
#
# Repo layout this expects (repo root = directory containing this script):
#   user-scripts/<name>/script          -> installed into the User Scripts plugin
#   borg/exclude.txt                    -> /mnt/user/appdata/borg/exclude.txt
#   compose/<stack>/docker-compose.yml  -> docker compose up -d (idempotent)
#   work/                               -> your own scripts (not deployed, just stored)
# =============================================================================
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
USCRIPTS_DST="/boot/config/plugins/user.scripts/scripts"
COMPOSE_DIR="$REPO/compose"

log(){ echo "[$(date '+%F %T')] $*"; }

# 1) User Scripts: mirror user-scripts/<name>/script into the plugin directory
if [ -d "$REPO/user-scripts" ]; then
  for d in "$REPO/user-scripts"/*/; do
    [ -f "$d/script" ] || continue
    name="$(basename "$d")"
    mkdir -p "$USCRIPTS_DST/$name"
    cp -f "$d/script" "$USCRIPTS_DST/$name/script"
    chmod +x "$USCRIPTS_DST/$name/script"
    log "user script deployed: $name"
  done
fi

# 1b) borg exclude file -> /mnt/user/appdata/borg/exclude.txt (script reads it there)
if [ -f "$REPO/borg/exclude.txt" ]; then
  mkdir -p /mnt/user/appdata/borg
  cp -f "$REPO/borg/exclude.txt" /mnt/user/appdata/borg/exclude.txt
  log "borg exclude.txt deployed"
fi

# 2) compose stacks: docker compose up -d (creates new, updates changed)
if [ -d "$COMPOSE_DIR" ]; then
  for f in "$COMPOSE_DIR"/*/docker-compose.yml; do
    [ -f "$f" ] || continue
    stack="$(basename "$(dirname "$f")")"
    log "deploying stack: $stack"
    docker compose -f "$f" up -d
  done
fi

log "deploy done"
