#!/bin/bash
# Restauration complete serveur 159.89.50.166
# - renova-conseil.com (safepage PHP)
# - adoonline.online (+ adoonline.pics landing Node)
#
# Usage (root, console DigitalOcean) :
#   curl -fsSL https://raw.githubusercontent.com/nlevis625-web/pop-direct/master/deploy/restore-all.sh | bash
#
set -euo pipefail

echo "=============================================="
echo " RESTAURATION COMPLETE DU SERVEUR"
echo " $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "=============================================="

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur : lancez en root"
  exit 1
fi

RENOVA="/var/www/renova-conseil"
POPUP="/var/www/popup-direct"

echo ""
echo "=== 1/4 Packages ==="
export DEBIAN_FRONTEND=noninteractive
apt update -qq
apt install -y nginx php-fpm git certbot python3-certbot-nginx curl

if ! command -v node >/dev/null 2>&1 || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 18 ]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt install -y nodejs
fi
command -v pm2 >/dev/null 2>&1 || npm install -g pm2

PHP_SOCK=$(ls /var/run/php/*.sock | head -1)

echo ""
echo "=== 2/4 Site renova-conseil.com ==="
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/renova-conseil.com
if [ -d "$RENOVA/.git" ]; then
  git -C "$RENOVA" fetch origin master
  git -C "$RENOVA" reset --hard origin/master
else
  rm -rf "$RENOVA"
  git clone --branch master https://github.com/nlevis625-web/renova-conseil.git "$RENOVA"
fi
chown -R www-data:www-data "$RENOVA" 2>/dev/null || true
find "$RENOVA" -type d -exec chmod 755 {} \;
find "$RENOVA" -type f -exec chmod 644 {} \;

cat > /etc/nginx/sites-available/renova-conseil.conf << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name renova-conseil.com www.renova-conseil.com;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name renova-conseil.com www.renova-conseil.com;
    root ${RENOVA};
    index index.php index.html;
    ssl_certificate /etc/letsencrypt/live/renova-conseil.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/renova-conseil.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \\.php\$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:${PHP_SOCK}; }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/renova-conseil.conf /etc/nginx/sites-enabled/renova-conseil.conf

if [ -f /etc/letsencrypt/live/renova-conseil.com/fullchain.pem ]; then
  certbot install --cert-name renova-conseil.com 2>/dev/null || true
else
  certbot --nginx -d renova-conseil.com -d www.renova-conseil.com \
    --non-interactive --agree-tos -m contact@renova-conseil.com --redirect || true
fi

echo ""
echo "=== 3/4 Site adoonline.online ==="
if [ -d "$POPUP/.git" ]; then
  git -C "$POPUP" fetch origin master
  git -C "$POPUP" reset --hard origin/master
else
  git clone --branch master https://github.com/nlevis625-web/pop-direct.git "$POPUP"
fi
cd "$POPUP"
npm install
npm run build
pm2 startOrRestart ecosystem.config.cjs
pm2 save
pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true

cat > /etc/nginx/sites-available/adoonline.online.conf << 'NGINXEOF'
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

ln -sf /etc/nginx/sites-available/adoonline.online.conf /etc/nginx/sites-enabled/adoonline.online.conf

if ! certbot certificates 2>/dev/null | grep -q "Certificate Name: adoonline.online"; then
  certbot --nginx \
    -d adoonline.online -d www.adoonline.online \
    -d adoonline.pics -d www.adoonline.pics \
    --non-interactive --agree-tos -m contact@renova-conseil.com --redirect || true
else
  certbot install --cert-name adoonline.online 2>/dev/null || true
fi

echo ""
echo "=== 4/4 Reload services ==="
nginx -t
systemctl restart nginx
systemctl restart php*-fpm 2>/dev/null || systemctl restart php8.3-fpm 2>/dev/null || true

echo ""
echo "=== Tests ==="
echo -n "renova  : "
curl -skI https://127.0.0.1 -H "Host: renova-conseil.com" | head -1
echo -n "adoonline health : "
curl -fsS http://127.0.0.1:8080/health || echo FAIL
echo ""
echo -n "adoonline HTTPS  : "
curl -sk https://127.0.0.1/health -H "Host: adoonline.online" || echo FAIL
echo ""

echo "=============================================="
echo " TERMINE"
echo " https://renova-conseil.com/"
echo " https://adoonline.online/"
echo "=============================================="
