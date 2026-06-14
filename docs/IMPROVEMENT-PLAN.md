# Improvement Plan — yantresh ecosystem

> Holistic review of `yantresh-hub`, `yantresh-os`, `patel-portfolio`.
> Created 2026-06-14. Items are ordered by impact ÷ effort. Keep the
> minimalist philosophy: adopt only what earns its weight.

## Baseline (what is already good)

- Clean multi-repo split; hub holds zero application code.
- Containers hardened: `read_only`, `cap_drop: ALL`, `no-new-privileges`,
  non-root, memory caps.
- No hardcoded domains/secrets — single `.env` seam.
- `.gitattributes` LF normalization in all three repos.
- Lean deps (litellm/fastapi/uvicorn pinned with upper bounds; CLI install
  path stays minimal).
- Pull-based CD prunes dangling images each run.

## P1 — high impact, low effort

1. ~~**Compose-level healthchecks.**~~ **Done** (2026-06-14). `caddy` probes
   its admin API; `yantresh-api` probes `/healthz` via bundled python.
   Note: Docker does *not* auto-restart a merely-unhealthy running
   container — only on exit. Restart-on-unhealthy still needs an autoheal
   watcher (deferred as bloat unless a real wedge is observed).
2. ~~**Edge rate-limit on the public demo lane.**~~ **Resolved in-app**
   (verified 2026-06-14). `api.py:_check_demo_rate_limit` already enforces a
   bounded per-IP/minute limit on `/v1/demo/missions`. An edge limit would
   need a custom Caddy build (`rate_limit` is not in `caddy:2-alpine`) —
   deferred as bloat unless the app-level limit proves insufficient.
3. ~~**Global security headers at Caddy.**~~ **Done** (2026-06-14). Shared
   `(security_headers)` snippet (HSTS, nosniff, Referrer-Policy, X-Frame-
   Options, `-Server`) imported into the apex redirect and `yantresh-api`.
   Portfolio keeps its own fuller nginx set (incl. CSP) — one source per
   response.
4. ~~**Pin GitHub Actions by commit SHA.**~~ **Done** (2026-06-14). Both
   `build-push.yml` workflows pin every `actions/*` and `docker/*` step to a
   commit SHA with a `# vN` comment. Add Dependabot later to bump them.

## P2 — medium

5. ~~**State backup automation.**~~ **Done** (2026-06-14).
   `deploy/backup-state.sh` + `yantresh-backup.timer` archive the volume
   read-only daily, rotating `BACKUP_KEEP` copies. Off-host copy (e.g. to
   object storage) still open — current backups live on the same VPS.
6. ~~**Image vulnerability scan in CI.**~~ **Done** (2026-06-14). Both
   workflows run a Trivy scan on the pushed image by digest, failing on
   fixable HIGH/CRITICAL CVEs (`ignore-unfixed: true`).
7. **Optional `www.` handling.** Decide policy: redirect `www.<domain>` →
   apex (which then redirects to portfolio) or drop it. Document either way.
8. **Digest-pinned production tags.** `:main` is mutable; a re-pushed
   `:main` silently changes what the VPS runs. For reproducible rollback,
   consider tracking the deployed digest (the timer already recreates only
   on digest change — surface that digest in logs/a status file).

## P3 — lower / nice-to-have

9. **Lightweight uptime probe.** A single external check (cron `curl` +
   alert) is enough for a solo deployment; avoid a full monitoring stack.
10. **CI dependency caching.** Cache npm / pip layers to speed builds; minor
    cost saving, no architectural change.
11. **SBOM emission.** `docker buildx` can emit an SBOM attestation; useful
    if the images ever go public.

## Explicitly NOT recommended (anti-bloat)

- No Kubernetes / Swarm — single VPS, compose is correct.
- No service mesh, no Redis/queue until a real second consumer exists.
- No heavyweight monitoring stack (Prometheus+Grafana) for one node.
