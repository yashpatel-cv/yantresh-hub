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

1. **Compose-level healthchecks.** `caddy` and `yantresh-api` have none;
   only the portfolio image bakes one. Without them `docker compose ps`
   can't tell "running" from "healthy", and a wedged container is not
   restarted. Add `healthcheck:` blocks (curl `/healthz` / Caddy admin).
2. **Edge rate-limit on the public demo lane.** `/v1/demo/missions` is
   unauthenticated. Add a Caddy `rate_limit` (or keep it inside yantresh-os
   if already enforced — verify) to cap abuse independent of the app.
3. **Global security headers at Caddy.** Portfolio sets headers in nginx,
   but the apex redirect and `yantresh-api` responses don't. Add an
   `header` directive (HSTS, X-Content-Type-Options, Referrer-Policy) in a
   shared Caddy snippet.
4. **Pin GitHub Actions by commit SHA.** Mutable `@v4` tags are a supply-
   chain risk. Pin `actions/*` and `docker/*` to SHAs (Dependabot/Renovate
   can keep them current).

## P2 — medium

5. **State backup automation.** `yantresh_state` (ledger + fuse) is
   backed up only by a manual command in DEPLOY.md. Add a small
   `yantresh-backup.timer` writing a rotated tarball to disk (or object
   storage).
6. **Image vulnerability scan in CI.** Add a Trivy step to each
   `build-push.yml` (fail on HIGH/CRITICAL). Cheap, catches base-image CVEs
   before they reach the VPS.
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
