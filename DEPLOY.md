# Deploying Al-Wilayat on your own server (VPS)

This publishes the app as its own website (e.g. `https://your-domain.com`) on a
small Ubuntu server. You'll run the FastAPI app with **systemd**, put **nginx**
in front of it, and add **free HTTPS** with certbot.

Plan: ~30–45 minutes. Cost: a $5/mo VPS + (optional) a domain name.

---

## 0. What you need
- A VPS running **Ubuntu 22.04/24.04** (Hetzner, DigitalOcean, AWS Lightsail…).
- (Optional but recommended) a **domain name**.
- SSH access to the server (`ssh root@SERVER_IP`).

## 1. Point your domain at the server  *(skip if no domain yet)*
In your domain registrar's DNS, add an **A record**:
- `@`  → your server's IP
- `www` → your server's IP

## 2. Install the basics (on the server)
```bash
apt update && apt -y upgrade
apt -y install python3 python3-venv python3-pip git nginx
```

## 3. Get the code
```bash
mkdir -p /opt && cd /opt
git clone https://github.com/haffey041707/Aiba-Dynamics-Al-Wilayat.git al-wilayat
cd al-wilayat/backend
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt
```

## 4. Download the content data (Qur'an / Hadith / Tafsir)
The large datasets aren't in git — fetch them once on the server:
```bash
cd /opt/al-wilayat/backend
.venv/bin/python ingest/fetch_quran.py
.venv/bin/python ingest/fetch_hadith.py
# run the other ingest/*.py scripts you want (tafsir, etc.)
```

## 5. Set your secrets
```bash
cp /opt/al-wilayat/deploy/al-wilayat.env.example /etc/al-wilayat.env
nano /etc/al-wilayat.env        # fill in WILAYAT_SECRET and SMTP_* values
chmod 600 /etc/al-wilayat.env
```
Generate a secret with:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(48))"
```

## 6. Run it as a service (systemd)
```bash
chown -R www-data:www-data /opt/al-wilayat
cp /opt/al-wilayat/deploy/al-wilayat.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now al-wilayat
systemctl status al-wilayat        # should say "active (running)"
```
Test locally: `curl http://127.0.0.1:8000/api` should return JSON.

## 7. Put nginx in front
```bash
cp /opt/al-wilayat/deploy/nginx.conf /etc/nginx/sites-available/al-wilayat
nano /etc/nginx/sites-available/al-wilayat   # replace your-domain.com
ln -s /etc/nginx/sites-available/al-wilayat /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
```
Now visit `http://your-domain.com` (or `http://SERVER_IP`) — the app loads.

## 8. Add free HTTPS (with a domain)
```bash
apt -y install certbot python3-certbot-nginx
certbot --nginx -d your-domain.com -d www.your-domain.com
```
Certbot edits nginx and auto-renews. Your site is now **https://your-domain.com** 🎉

---

## Updating later
```bash
cd /opt/al-wilayat && git pull
backend/.venv/bin/pip install -r backend/requirements.txt
systemctl restart al-wilayat
```

## Backups
Your accounts live in `backend/app/data/users.db` — back this file up regularly.

## Troubleshooting
- Logs: `journalctl -u al-wilayat -f`
- Nginx errors: `tail -f /var/log/nginx/error.log`
- Port already in use: another process on 8000 — `systemctl restart al-wilayat`.
