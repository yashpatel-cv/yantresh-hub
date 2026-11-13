#!/usr/bin/env bash
# Pull-based CD: re-run periodically (via yantresh-pull.timer) on the VPS.
# 1. Fast-forwards this repo, so hub changes (Caddyfile, compose) go live too.
# 2. Pulls whatever images *_IMAGE_TAG in .env points at and recreates only
#    the containers whose image or config changed.
# 3. Pings DEPLOY_PING_URL (e.g. healthchecks.io) only if everything is up,
#    so a failing deploy or crash-looping container raises an alert.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

before="$(git rev-parse HEAD)"
git pull --ff-only --quiet
caddy_changed=""
if ! git diff --quiet "$before" HEAD -- Caddyfile; then
  # Refuse to apply a Caddyfile that won't load — a bad one takes every site down.
  docker compose run --rm --no-deps -T caddy \
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
  caddy_changed=1
fi

docker compose pull --quiet
docker compose up -d --remove-orphans
# Caddyfile is a single-file bind mount: git replaces the inode, so a running
# container keeps the old file. A restart re-binds it (~1s blip).
# ponytail: brief restart; mount a directory instead if zero-downtime reload matters.
[ -z "$caddy_changed" ] || docker compose restart caddy
docker image prune -f >/dev/null

if [ -n "$(docker compose ps --status restarting --quiet)" ]; then
  echo "crash-looping: $(docker compose ps --status restarting --format '{{.Service}}')" >&2
  exit 1
fi

ping="$(sed -n 's/^DEPLOY_PING_URL=//p' .env)"
[ -z "$ping" ] || curl -fsS -m 10 --retry 3 -o /dev/null "$ping"
