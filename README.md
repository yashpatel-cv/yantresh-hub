# yantresh-hub

Deployment hub. Infra only — no application code lives here. Runs Caddy +
one container per project, pulled from GHCR, on one Oracle Ampere A1
(ARM64) VPS.

This repo's name is not referenced anywhere inside it. Rename the folder
and/or the git remote freely; nothing here breaks.

## Layout

```
Caddyfile          one address block per project (env-driven, see .env.example)
docker-compose.yml one service per project, image: ghcr.io/<owner>/<name>:<tag>
.env.example       the ONLY place domains/addresses/secrets/image refs are set
deploy/            pull-based CD: script + systemd service/timer (see DEPLOY.md)
docs/SETUP.md      living architecture + status doc — update on every change
```

Each project (`yantresh-os`, `patel-portfolio`, ...) lives in its own repo
and CI-builds+pushes its image to GHCR. This repo never builds — it only
pulls.

## Adding a project

1. Project repo: add a CI workflow that builds+pushes
   `ghcr.io/<owner>/<name>:main` (mirror `yantresh-os/.github/workflows/build-push.yml`).
2. `docker-compose.yml`: add a `<name>-api` service —
   `image: ghcr.io/${GHCR_OWNER}/<name>:${<NAME>_IMAGE_TAG:-main}`
3. `.env`: add `<NAME>_ADDRESS=<name>.${DOMAIN}` and `<NAME>_IMAGE_TAG=main`
4. `Caddyfile`: add `{$<NAME>_ADDRESS} { reverse_proxy <name>-api:<port> }`
5. DNS: point `<NAME>_ADDRESS` at this host
6. Update `docs/SETUP.md`

## Moving a project to its own domain

Change its `*_ADDRESS` value in `.env` + update DNS. 