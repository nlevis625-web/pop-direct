#!/bin/bash
# Repare TOUT : renova-conseil.com + adoonline.online (SSL + nginx + PM2)
set -euo pipefail
RENOVA="/var/www/renova-conseil"
POPUP="/var/www/popup-direct"
export DEBIAN_FRONTEND=noninteractive

apt update -qq
apt install -y nginx php-fpm git certbot python3-certbot-nginx curl
command -v node >/dev/null || { curl -fsSL https://deb.nodesource.com/setup_20.x | bash -; apt install -y nodejs; }
command -v pm2 >/dev/null || npm install -g pm2
PHP_SOCK=$(ls /var/run/php/*.sock | head -1)

# --- Renova safepage ---
rm -rf "$RENOVA"
git clone --branch master https://github.com/nlevis625-web/renova-conseil.git "$RENOVA"
chown -R www-data:www-data "$RENOVA" 2>/dev/null || true

# --- Popup landing ---
rm -rf "$POPUP"
git clone --branch master https://github.com/nlevis625-web/pop-direct.git "$POPUP"
cd "$POPUP" && npm install && npm run build
pm2 delete popup-direct 2>/dev/null || true
pm2 start ecosystem.config.cjs
pm2 save

# --- Nginx ---
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/*

cat > /etc/nginx/sites-available/renova-conseil.conf << EOF
server {
    listen 80; listen [::]:80;
    server_name renova-conseil.com www.renova-conseil.com;
    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { return 301 https://\$host\$request_uri; }
}
server {
    listen 443 ssl; listen [::]:443 ssl;
    server_name renova-conseil.com www.renova-conseil.com;
    root ${RENOVA}; index index.php index.html;
    ssl_certificate /etc/letsencrypt/live/renova-conseil.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/renova-conseil.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \\.php\$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:${PHP_SOCK}; }
}
EOF

cat > /etc/nginx/sites-available/adoonline.online.conf << 'EOF'
server {
    listen 80; listen [::]:80;
    server_name adoonline.online www.adoonline.online adoonline.pics www.adoonline.pics;
    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { return 301 https://$host$request_uri; }
}
server {
    listen 443 ssl; listen [::]:443 ssl;
    server_name adoonline.online www.adoonline.online adoonline.pics www.adoonline.pics;
    ssl_certificate /etc/letsencrypt/live/adoonline.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/adoonline.online/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/renova-conseil.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/adoonline.online.conf /etc/nginx/sites-enabled/

# --- SSL ---
certbot certonly --webroot -w /var/www/html \
  -d renova-conseil.com -d www.renova-conseil.com \
  --non-interactive --agree-tos -m contact@renova-conseil.com \
  --keep-until-expiring --expand 2>/dev/null || \
certbot certonly --nginx -d renova-conseil.com -d www.renova-conseil.com \
  --non-interactive --agree-tos -m contact@renova-conseil.com || true

certbot certonly --webroot -w /var/www/html \
  -d adoonline.online -d www.adoonline.online -d adoonline.pics -d www.adoonline.pics \
  --non-interactive --agree-tos -m contact@renova-conseil.com \
  --keep-until-expiring --expand 2>/dev/null || \
certbot certonly --nginx \
  -d adoonline.online -d www.adoonline.online -d adoonline.pics -d www.adoonline.pics \
  --non-interactive --agree-tos -m contact@renova-conseil.com || true

nginx -t
systemctl restart nginx
systemctl restart php*-fpm 2>/dev/null || true

echo "=== TESTS ==="
echo -n "renova  : "; curl -skI https://127.0.0.1/ -H "Host: renova-conseil.com" | head -1
echo -n "health  : "; curl -fsS http://127.0.0.1:8080/health; echo
echo -n "adoonline: "; curl -sk https://127.0.0.1/health -H "Host: adoonline.online"; echo
echo "TERMINE"
