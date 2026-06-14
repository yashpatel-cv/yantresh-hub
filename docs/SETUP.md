# Current setup (living doc)

> Update this on every architecture/topology change. Last updated: 2026-06-14.

## Repos

| Repo | Role | Remote |
|---|---|---|
| `yantresh-hub` (this repo) | Caddy + compose + `.env` — the only place domains/addresses/secrets/image refs live | `git@github.com:yashpatel-cv/yantresh-hub.git` |
| `yantresh-os` | Amatya/Karta agent + FastAPI seam (`api.py`), own Dockerfile + CI (GHCR) | `https://github.com/yashpatel-cv/yantresh-os` |
| `patel-portfolio` | Astro static site, own Dockerfile + CI (GHCR) | `https://github.com/yashpatel-cv/patel-portfolio` |
| `srotantra` | Data Scale Engine — product identity-resolution + FTS5 search API, own Dockerfile + CI (GHCR) | `https://github.com/yashpatel-cv/srotantra` |

## Image flow — pull-based CD

```
push to main
   │
   ▼
project repo CI (build-push.yml)
   │  docker/build-push-action, linux/arm64+amd64
   ▼
ghcr.io/<owner>/<name>:main (+ sha, +semver on tags)
   │
   ▼  (yantresh-pull.timer, every 5 min)
VPS: docker compose pull && up -d --remove-orphans
```

- `yantresh-hub` never builds images — `docker-compose.yml` only has
  `image:` refs (`ghcr.io/${GHCR_OWNER}/<name>:${<NAME>_IMAGE_TAG}`).
- `GHCR_OWNER` and `*_IMAGE_TAG` are `.env` lines — no owner/repo name is
  hardcoded in `Caddyfile` or `docker-compose.yml`.
- Full VPS setup (Docker, firewall, GHCR auth, timer install): `DEPLOY.md`.

## Routing — subdomain per project, bare apex redirects

```
DNS → VPS (Oracle Ampere A1, ARM64, debian@<vps-ip>)
            │
          Caddy (TLS, auto-cert, ACME_EMAIL)
   ┌────────┴──────────┬──────────────────┬────────────────────┐
{$DOMAIN}    {$PORTFOLIO_ADDRESS}  {$YANTRESH_ADDRESS}  {$SROTANTRA_ADDRESS}
301 redirect  portfolio:8080       yantresh-api:8000    srotantra-api:8000
   → portfolio
```

- `{$DOMAIN}` (bare apex) → 301 redirect to `{$PORTFOLIO_ADDRESS}`, path +
  query preserved. Serves no content itself.
- `{$PORTFOLIO_ADDRESS}` → portfolio (plain static site, standalone — no
  API awareness). Default `portfolio.<domain>`.
- `{$YANTRESH_ADDRESS}` → yantresh-api, full surface (private lane needs
  `X-API-Key`; demo lane is whatever yantresh-os itself exposes — not
  specially routed by the hub)
- `{$SROTANTRA_ADDRESS}` → srotantra-api, read-only product-search API
  (`/v1/search`, `/v1/products/{id}`, `/v1/stats`). Seeds a demo db on first
  boot; build the real db from sources into the `srotantra_data` volume.
- Every value above is a `.env` line. No domain/project name is hardcoded
  in `Caddyfile` or `docker-compose.yml`.

**Adding project N**: one service block + one Caddy block + one `.env` line
(`*_ADDRESS` + `*_IMAGE_TAG`) + one DNS record + CI workflow in that
project's repo. See `README.md`.

**Moving a project to its own domain**: change its `*_ADDRESS` line in
`.env` + DNS. Zero file edits