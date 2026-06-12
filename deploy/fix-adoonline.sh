#!/bin/bash
# Remet adoonline.online en ligne sur le Droplet 159.89.50.166
# sans toucher a renova-conseil.com
#
# Usage (console DigitalOcean, en root) :
#   curl -fsSL https://raw.githubusercontent.com/nlevis625-web/pop-direct/master/deploy/fix-adoonline.sh | bash
# ou :
#   bash deploy/fix-adoonline.sh
#
set -euo pipefail

APP_DIR="/var/www/popup-direct"
REPO="https://github.com/nlevis625-web/pop-direct.git"
NGINX_SITE="adoonline.online"
CERT_EMAIL="${CERT_EMAIL:-contact@renova-conseil.com}"
DOMAINS=(
  "adoonline.online"
  "www.adoonline.online"
  "adoonline.pics"
  "www.adoonline.pics"
)

echo "=============================================="
echo " Reparation adoonline.online (+ adoonline.pics)"
echo " Serveur : $(hostname -I 2>/dev/null | awk '{print $1}')"
echo "=============================================="

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur : lancez ce script en root (sudo bash deploy/fix-adoonline.sh)"
  exit 1
fi

echo ""
echo "=== 1. Verifier que renova-conseil reste intact ==="
if [ ! -f /etc/nginx/sites-enabled/renova-conseil.conf ] && \
   [ ! -L /etc/nginx/sites-enabled/renova-conseil.conf ]; then
  echo "ATTENTION : renova-conseil.conf absent de sites-enabled."
  echo "Le script continue, mais verifiez renova-conseil.com apres coup."
else
  echo "OK : renova-conseil.conf present"
fi

echo ""
echo "=== 2. Installer Node.js 20 + PM2 (si absent) ==="
export DEBIAN_FRONTEND=noninteractive
apt update -qq
apt install -y curl git nginx certbot python3-certbot-nginx

if ! command -v node >/dev/null 2>&1 || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 18 ]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt install -y nodejs
fi

if ! command -v pm2 >/dev/null 2>&1; then
  npm install -g pm2
fi

echo "Node $(node -v) | npm $(npm -v) | pm2 $(pm2 -v)"

echo ""
echo "=== 3. Deployer popup-direct ==="
mkdir -p "$(dirname "$APP_DIR")"
if [ -d "$APP_DIR/.git" ]; then
  echo "Mise a jour du depot existant..."
  git -C "$APP_DIR" fetch origin master
  git -C "$APP_DIR" reset --hard origin/master
else
  echo "Clone du depot..."
  rm -rf "$APP_DIR"
  git clone --branch master "$REPO" "$APP_DIR"
fi

cd "$APP_DIR"
npm install
npm run build

if [ ! -f "$APP_DIR/public/index.html" ]; then
  echo "Erreur : build echoue (public/index.html absent)"
  exit 1
fi

echo ""
echo "=== 4. Demarrer l'app Node sur le port 8080 ==="
pm2 startOrRestart ecosystem.config.cjs
pm2 save
pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true

sleep 2
HEALTH="$(curl -fsS http://127.0.0.1:8080/health || true)"
if [ "$HEALTH" != "ok" ]; then
  echo "Erreur : /health sur le port 8080 ne repond pas 'ok' (recu: '$HEALTH')"
  pm2 logs popup-direct --lines 30 --nostream || true
  exit 1
fi
echo "OK : Node ecoute sur http://127.0.0.1:8080/health"

echo ""
echo "=== 5. Configurer Nginx pour adoonline (sans supprimer renova) ==="
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

cat > "/etc/nginx/sites-available/${NGINX_SITE}.conf" <<'NGINXEOF'
server {
    listen 80;
    listen [::]:80;
    server_name adoonline.online www.adoonline.online adoonline.pics www.adoonline.pics;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXEOF

ln -sf "/etc/nginx/sites-available/${NGINX_SITE}.conf" "/etc/nginx/sites-enabled/${NGINX_SITE}.conf"
nginx -t
systemctl reload nginx

echo ""
echo "=== 6. Certificat SSL Let's Encrypt ==="
CERT_ARGS=()
for d in "${DOMAINS[@]}"; do
  CERT_ARGS+=("-d" "$d")
done

if certbot certificates 2>/dev/null | grep -q "Certificate Name: ${NGINX_SITE}"; then
  certbot renew --quiet || true
  certbot install --cert-name "${NGINX_SITE}" || true
else
  certbot --nginx "${CERT_ARGS[@]}" \
    --non-interactive --agree-tos -m "$CERT_EMAIL" --redirect || \
  certbot --nginx "${CERT_ARGS[@]}" \
    --non-interactive --agree-tos -m "$CERT_EMAIL"
fi

nginx -t
systemctl reload nginx

echo ""
echo "=== 7. Tests finaux ==="
echo -n "adoonline HTTP  : "
curl -sI http://127.0.0.1 -H "Host: adoonline.online" | head -1

echo -n "adoonline HTTPS : "
curl -skI https://127.0.0.1 -H "Host: adoonline.online" | head -1

echo -n "adoonline body  : "
curl -sk https://127.0.0.1/health -H "Host: adoonline.online" | tr -d '\n'
echo ""

echo -n "renova HTTPS    : "
curl -skI https://127.0.0.1 -H "Host: renova-conseil.com" | head -1

echo ""
echo "=============================================="
echo " TERMINE"
echo " Landing : https://adoonline.online/"
echo " Renova  : https://renova-conseil.com/ (inchange)"
echo ""
echo " Si Cloudflare est actif : purge le cache puis Ctrl+Shift+R."
echo "=============================================="
