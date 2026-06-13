#!/usr/bin/env bash
# Pull-based CD: re-run periodically (via yantresh-pull.timer) on the VPS.
# Pulls whatever images *_IMAGE_TAG in .env currently points at and
# recreates only the containers whose image digest changed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

docker compose pull --quiet
docker compose up -d --remove-orphans
docker image prune -f >/dev/null
