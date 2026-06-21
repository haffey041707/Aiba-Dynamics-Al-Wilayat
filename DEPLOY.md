# Deploying Al-Wilayat on your own server (VPS)

This publishes the app as its own website (e.g. `https://your-domain.com`) on a
small Ubuntu server. You'll run the FastAPI app with **systemd**, put **nginx**
in front of it, and add **free HTTPS** with certbot.

Plan: ~30–45 minutes. Cost: a $5/mo VPS + (optional) a domain name.

---

## ⚡ The easy way — one command

After you have an Ubuntu server (see **Provider quick-start** below), SSH in and run:

```bash
curl -fsSL https://raw.githubusercontent.com/haffey041707/Aiba-Dynamics-Al-Wilayat/main/deploy/setup.sh -o setup.sh
sudo bash setup.sh
```

That installs everything, downloads the content data, starts the app, and puts
nginx in front. When it finishes it prints your link (`http://YOUR_SERVER_IP`).

**With a domain + free HTTPS**, point the domain's DNS at your server first
(A records for `@` and `www`), then run:

```bash
sudo DOMAIN=your-domain.com LE_EMAIL=you@gmail.com bash setup.sh
```

→ Your site is live at **https://your-domain.com** 🎉

Options you can add before `bash setup.sh`:
- `WITH_TAFSIR=1` — also download the large (~131 MB) tafsir data.
- `SMTP_USER=… SMTP_PASS=…` — preset the Gmail app password for reset emails
  (otherwise edit `/etc/al-wilayat.env` afterwards and `systemctl restart al-wilayat`).

The script is **safe to re-run** — it updates the code and restarts the service.

---

## 🖱️ Provider quick-start (getting the server)

You just need an Ubuntu 22.04/24.04 server and its IP. Two popular options:

### Hetzner Cloud (cheapest, ~€4/mo)
1. Sign up at **console.hetzner.cloud** → **New Project**.
2. **Add Server** → Location: nearest to you → Image: **Ubuntu 24.04** →
   Type: **CX22** (2 vCPU / 4 GB) → under **SSH keys** add yours (or set a root
   password) → **Create & Buy now**.
3. Copy the server's **IPv4**. Connect: `ssh root@THAT_IP`.
4. Run the one command above.

### DigitalOcean (most popular, $6/mo)
1. Sign up at **cloud.digitalocean.com** → **Create → Droplets**.
2. Region: nearest → Image: **Ubuntu 24.04** → Size: **Basic / Regular, $6/mo
   (1 GB)** → Authentication: **SSH key** (recommended) → **Create Droplet**.
3. Copy the Droplet's **IP**. Connect: `ssh root@THAT_IP`.
4. Run the one command above.

> AWS Lightsail works too: create an **Ubuntu** instance, open ports **80** and
> **443** in its Networking tab, then SSH in and run the one command.

---

## Manual steps (if you prefer to do it yourself)

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
