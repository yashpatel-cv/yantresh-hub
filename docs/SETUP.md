# Current setup (living doc)

> Update this on every architecture/topology change. Last updated: 2026-06-27.

## Repos

| Repo | Role | Remote |
|---|---|---|
| `yantresh-hub` (this repo) | Caddy + compose + `.env` — the only place domains/addresses/secrets/image refs live | `git@github.com:yashpatel-cv/yantresh-hub.git` |
| `yantresh-os` | Amatya/Karta agent + FastAPI seam (`api.py`), own Dockerfile + CI (GHCR) | `https://github.com/yashpatel-cv/yantresh-os` |
| `patel-portfolio` | Astro static site, own Dockerfile + CI (GHCR) | `https://github.com/yashpatel-cv/patel-portfolio` |
| `srotantra` | Data Scale Engine — product identity-resolution + FTS5 search API, own Dockerfile + CI (GHCR) | `https://github.com/yashpatel-cv/srotantra` |
| `yantresh-commerce` | Commerce storefront, demo tenant, admin, Medusa API, worker, Postgres, Redis; own GHCR images | `https://github.com/yashpatel-cv/yantresh-commerce` |

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
- Yantresh Commerce has fixed public hostnames in `Caddyfile`; keep those
  exact names to avoid collisions with `yantresh-os`.
- Full VPS setup (Docker, firewall, GHCR auth, timer install): `DEPLOY.md`.

## Routing — subdomain per project, bare apex redirects

```
DNS → VPS (Oracle Ampere A1, ARM64, debian@<vps-ip>)
            │
          Caddy (TLS, auto-cert, ACME_EMAIL)
   ┌────────┴──────────┬──────────────────┬────────────────────┬────────────────────────────┐
{$DOMAIN}    {$PORTFOLIO_ADDRESS}  {$YANTRESH_ADDRESS}  {$SROTANTRA_ADDRESS}  Yantresh Commerce hosts
301 redirect  portfolio:8080       yantresh-api:8000    srotantra-api:8000    commerce services
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
- `commerce.yantresh.com` → main Yantresh Commerce platform/storefront.
- `demo-store.yantresh.com` → demo tenant/storefront.
- `shop-admin.yantresh.com` → Yantresh Commerce admin surface.
- `shop-api.yantresh.com` → Yantresh Commerce API.
- Existing hub projects keep env-driven hostnames. Yantresh Commerce uses
  fixed `*.yantresh.com` hostnames and grouped `.env` image/runtime vars.
- Caddy is the only public entrypoint. Yantresh Commerce opens no extra
  public ports; traffic reaches its containers through Caddy reverse proxies
  on standard 80/443.

**Adding project N**: one service block + one Caddy block + one `.env` line
(`*_ADDRESS` + `*_IMAGE_TAG`) + one DNS record + CI workflow in that
project's repo. See `README.md`.

**Moving a project to its own domain**: change its `*_ADDRESS` line in
`.env` + DNS. Zero file edits
