# yantresh-hub

Deployment hub. Infra only — no application code lives here. Runs Caddy +
one container per project, on one Oracle Ampere A1 (ARM64) VPS.

This repo's name is not referenced anywhere inside it. Rename the folder
and/or the git remote freely; nothing here breaks.

## Layout

```
Caddyfile          one address block per project (env-driven, see .env.example)
docker-compose.yml one service per project, builds from projects/<name>
.env.example       the ONLY place domains/addresses/secrets are set
projects/<name>    each project's own repo (git submodule once it has a remote)
docs/SETUP.md      living architecture + status doc — update on every change
```

## Adding a project

1. `git submodule add <repo-url> projects/<name>`
2. `docker-compose.yml`: add a `<name>-api` service (`build: ./projects/<name>`)
3. `.env`: add `<NAME>_ADDRESS=<name>.${DOMAIN}` (or a standalone domain)
4. `Caddyfile`: add `{$<NAME>_ADDRESS} { reverse_proxy <name>-api:<port> }`
5. DNS: point `<NAME>_ADDRESS` at this host
6. Update `docs/SETUP.md`

## Moving a project to its own domain

Change its `*_ADDRESS` value in `.env` + update DNS. No Caddyfile edit.

## Deploy

```bash
cp .env.example .env   # fill in DOMAIN, *_ADDRESS, secrets
git submodule update --init --recursive
docker compose up -d --build
```

## Status

`projects/yantresh-os` and `projects/patel-portfolio` are not yet submodules —
both repos exist locally but have no remote yet. See `docs/SETUP.md`.
