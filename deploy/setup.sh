#!/usr/bin/env bash
# =============================================================================
# Al-Wilayat — one-shot VPS setup for Ubuntu 22.04 / 24.04
# -----------------------------------------------------------------------------
# Run as root on a fresh server:
#
#     curl -fsSL https://raw.githubusercontent.com/haffey041707/Aiba-Dynamics-Al-Wilayat/main/deploy/setup.sh -o setup.sh
#     sudo bash setup.sh
#
# Optional settings (pass as environment variables):
#     DOMAIN=example.com          enable nginx server_name + HTTPS for this domain
#     LE_EMAIL=you@example.com     email for the free Let's Encrypt certificate
#     WITH_TAFSIR=1                also download the large (~131 MB) tafsir data
#     SMTP_USER=...  SMTP_PASS=... preset email creds (else edit them later)
#
# Example with a domain + HTTPS:
#     sudo DOMAIN=al-wilayat.com LE_EMAIL=me@gmail.com bash setup.sh
#
# Safe to re-run: it updates the code and restarts the service.
# =============================================================================
set -euo pipefail

REPO="${REPO:-https://github.com/haffey041707/Aiba-Dynamics-Al-Wilayat.git}"
APP_DIR="/opt/al-wilayat"
ENV_FILE="/etc/al-wilayat.env"
DOMAIN="${DOMAIN:-}"
LE_EMAIL="${LE_EMAIL:-}"

say() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }

[ "$(id -u)" = "0" ] || { echo "Please run as root:  sudo bash setup.sh"; exit 1; }

say "Installing system packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3 python3-venv python3-pip git nginx curl

say "Fetching the code into $APP_DIR"
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" pull --ff-only
else
  git clone "$REPO" "$APP_DIR"
fi

say "Setting up the Python environment"
cd "$APP_DIR/backend"
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt

# Make the venv's python the default for the ingest scripts.
export PATH="$APP_DIR/backend/.venv/bin:$PATH"

say "Downloading content data — this can take several minutes"
echo "  • Qur'an";        .venv/bin/python ingest/fetch_quran.py        || echo "    (skipped/failed)"
echo "  • Hadith (24 books, resumable)…"
if [ -f ingest/run_all_hadith.sh ]; then
  bash ingest/run_all_hadith.sh || echo "    (hadith download incomplete — re-run setup.sh to resume)"
else
  .venv/bin/python ingest/fetch_hadith.py || echo "    (skipped/failed)"
fi
echo "  • Du'a & Ziyarat"; .venv/bin/python ingest/fetch_duas_ziyarat.py || echo "    (skipped/failed)"
.venv/bin/python ingest/fetch_ziyarat.py                                || true
if [ "${WITH_TAFSIR:-}" = "1" ]; then
  echo "  • Tafsir (large)"; .venv/bin/python ingest/fetch_tafsir.py    || echo "    (skipped/failed)"
fi

say "Configuring secrets at $ENV_FILE"
if [ ! -f "$ENV_FILE" ]; then
  SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
  cat > "$ENV_FILE" <<EOF
WILAYAT_SECRET=$SECRET
SMTP_HOST=${SMTP_HOST:-smtp.gmail.com}
SMTP_PORT=${SMTP_PORT:-587}
SMTP_USER=${SMTP_USER:-}
SMTP_FROM=${SMTP_FROM:-${SMTP_USER:-}}
SMTP_PASS=${SMTP_PASS:-}
EOF
  chmod 600 "$ENV_FILE"
  echo "  Generated a WILAYAT_SECRET. Edit $ENV_FILE later to enable reset emails."
else
  echo "  $ENV_FILE already exists — left untouched."
fi

say "Installing the systemd service"
chown -R www-data:www-data "$APP_DIR"
cp "$APP_DIR/deploy/al-wilayat.service" /etc/systemd/system/al-wilayat.service
systemctl daemon-reload
systemctl enable --now al-wilayat
sleep 2
if systemctl is-active --quiet al-wilayat; then
  echo "  Service is running."
else
  echo "  Service failed to start. Recent logs:"; journalctl -u al-wilayat -n 30 --no-pager; exit 1
fi

say "Configuring nginx"
NGX="/etc/nginx/sites-available/al-wilayat"
cp "$APP_DIR/deploy/nginx.conf" "$NGX"
if [ -n "$DOMAIN" ]; then
  sed -i "s/your-domain.com www.your-domain.com/$DOMAIN www.$DOMAIN/" "$NGX"
else
  sed -i "s/server_name .*/server_name _;/" "$NGX"
fi
ln -sf "$NGX" /etc/nginx/sites-enabled/al-wilayat
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# Open the firewall if ufw is active.
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw allow "Nginx Full" || true
fi

if [ -n "$DOMAIN" ] && [ -n "$LE_EMAIL" ]; then
  say "Requesting a free HTTPS certificate (Let's Encrypt)"
  apt-get install -y certbot python3-certbot-nginx
  certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos \
    -m "$LE_EMAIL" --redirect \
    || echo "  certbot failed — make sure $DOMAIN's DNS points to this server, then re-run."
fi

IP="$(curl -fsSL ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo
echo "==============================================================="
echo "  ✅ Al-Wilayat is live!"
if [ -n "$DOMAIN" ]; then
  echo "     https://$DOMAIN"
else
  echo "     http://$IP        (add a domain + HTTPS by re-running with DOMAIN=...)"
fi
echo
echo "  Manage:   systemctl {status|restart} al-wilayat"
echo "  Logs:     journalctl -u al-wilayat -f"
echo "  Secrets:  $ENV_FILE   (edit, then: systemctl restart al-wilayat)"
echo "==============================================================="
