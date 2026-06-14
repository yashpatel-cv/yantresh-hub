# Deploy — Oracle Ampere A1 (ARM64) VPS

CD is **pull-based**: GitHub Actions in `yantresh-os` and `patel-portfolio`
build+push images to GHCR on every `main` push. The VPS never builds — a
systemd timer runs `docker compose pull && up -d` every few minutes and
recreates only containers whose image digest changed.

## 1. One-time VPS setup

```bash
ssh -i ~/.ssh/<your-vps-key> debian@<vps-ip>

# Docker + Compose plugin (Debian/Ubuntu)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker

# Firewall: only 22/80/443. Also open these in the Oracle Cloud
# security list for the VPS's subnet (Console -> VCN -> Security Lists) —
# the OS firewall alone is not enough on Oracle Cloud.
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## 2. Clone this repo and configure

```bash
sudo mkdir -p /opt/yantresh-hub && sudo chown $USER /opt/yantresh-hub
git clone <yantresh-hub-remote-url> /opt/yantresh-hub
cd /opt/yantresh-hub
cp .env.example .env
# Edit .env:
#  - DOMAIN                              -> apex (redirects to PORTFOLIO_ADDRESS)
#  - PORTFOLIO_ADDRESS, YANTRESH_ADDRESS -> real subdomains (once bought)
#  - ACME_EMAIL                          -> your email, for Let's Encrypt
#  - GHCR_OWNER                          -> your GitHub username/org (lowercase)
#  - *_IMAGE_TAG                         -> "main" to track latest, or pin a release
#  - YANTRESH_API_KEY, DEEPSEEK_API_KEY  -> real secrets
```

## 3. GHCR authentication (private images only)

If the GHCR packages are private, the VPS needs a one-time login. Use a
GitHub PAT with `read:packages` scope (classic token, or fine-grained with
package read access) — never put this in `.env` or commit it.

```bash
echo <PAT> | docker login ghcr.io -u <github-username> --password-stdin
```

This writes `~/.docker/config.json`, which `docker compose pull` reuses
automatically — including from the systemd timer's service user.

If the packages are public, skip this step.

## 4. First run

```bash
docker compose pull
docker compose up -d
docker compose ps
```

Point DNS A/AAAA records for `DOMAIN`, `PORTFOLIO_ADDRESS`, and
`YANTRESH_ADDRESS` at the VPS's public IP, then check:

```bash
curl -I https://<your-domain>            # apex -> 301 to portfolio
curl -I https://<your-portfolio-address> # portfolio
curl -I https://<your-yantresh-address>  # yantresh-api
docker compose logs caddy --tail 50      # cert issuance status
```

## 5. Install the pull-based CD timer

```bash
sudo cp deploy/yantresh-pull.service deploy/yantresh-pull.timer /etc/systemd/system/
# The service runs as a non-root user (member of the docker group) — point
# it at whichever user owns /opt/yantresh-hub, typically the one you're
# logged in as:
sudo sed -i "s/^User=.*/User=$USER/" /etc/systemd/system/yantresh-pull.service
sudo systemctl daemon-reload
sudo systemctl enable --now yantresh-pull.timer
systemctl list-timers yantresh-pull.timer
```

From now on: push to `main` in `yantresh-os` or `patel-portfolio` -> CI
builds+pushes a new `:main` image to GHCR -> within 5 minutes the timer
pulls it and recreates that one container. No SSH or GitHub secrets needed
for deploy.

If the repo is cloned somewhere other than `/opt/yantresh-hub`, edit
`WorkingDirectory`/`ExecStart` in `yantresh-pull.service` before copying it.

## 6. Manual operations

```bash
# Force an immediate pull+update
/opt/yantresh-hub/deploy/pull-update.sh

# Roll back: pin *_IMAGE_TAG in .env to a previous tag/sha, then
docker compose pull && docker compose up -d

# Tail logs
docker compose logs -f yantresh-api
```

## 7. State & backups

`yantresh_state` (ledger + fuse) and `yantresh_workspace` are named Docker
volumes. Back up with:

```bash
docker run --rm -v yantresh-hub_yantresh_state:/data -v $PWD:/backup \
  alpine tar czf /backup/yantresh_state.tar.gz -C /data .
```
