# Current setup (living doc)

> Update this on every architecture/topology change. Last updated: 2026-06-13.

## Repos

| Repo | Role | Remote |
|---|---|---|
| `yantresh-hub` (this repo) | Caddy + compose + `.env` — the only place domains/addresses/secrets live | none yet |
| `yantresh-os` | Amatya/Karta agent + FastAPI seam (`api.py`), own Dockerfile | none yet |
| `patel-portfolio` | Astro static site, own Dockerfile | none yet |

None of the three have a GitHub remote yet — `projects/yantresh-os` and
`projects/patel-portfolio` are placeholders (`.gitkeep`) until each repo has
a remote to submodule from.

## Routing — subdomain per project, no portfolio embedding

```
DNS → VPS (Oracle Ampere A1, ARM64, debian@<vps-ip>)
            │
          Caddy (TLS, auto-cert)
   ┌────────┴─────────┐
{$DOMAIN}        {$YANTRESH_ADDRESS}
portfolio:8080   yantresh-api:8000
```

- `{$DOMAIN}` → portfolio (plain static site, standalone — no API awareness)
- `{$YANTRESH_ADDRESS}` → yantresh-api, full surface (private lane needs
  `X-API-Key`; demo lane is whatever yantresh-os itself exposes — not
  specially routed by the hub)
- Every value above is a `.env` line. No domain/project name is hardcoded
  in `Caddyfile` or `docker-compose.yml`.

**Adding project N**: one service block + one Caddy block + one `.env` line
+ one DNS record. See `README.md`.

**Moving a project to its own domain**: change its `*_ADDRESS` line in
`.env` + DNS. Zero file edits in `Caddyfile`/compose.

## Dropped from earlier design

Last session built a portfolio-embedded "mission console" (same-origin
`/api/*` demo lane, `config.js` rendering, rate-limited Caddy matcher). Per
user decision (2026-06-13): **no portfolio embedding** — each project is
subdomain-only. None of that work was merged into the real repos; nothing
to undo.

## Outstanding

- Push `yantresh-os` and `patel-portfolio` to remotes, then
  `git submodule add` them into `projects/`.
- Buy a domain, set `DOMAIN` + `YANTRESH_ADDRESS` in `.env`.
- DNS: A/AAAA for `{$DOMAIN}` and `{$YANTRESH_ADDRESS}` → VPS IP.
- Provision VPS (Docker + Compose), `caddy validate` the Caddyfile.
- First deploy + smoke test.
