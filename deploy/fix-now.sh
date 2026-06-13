#!/bin/bash
set -e
RENOVA="/var/www/renova-conseil"
POPUP="/var/www/popup-direct"
PHP_SOCK=$(ls /var/run/php/*.sock | head -1)

# 1. Retirer hoax — remettre la vraie safepage Renova
rm -rf "$RENOVA"
git clone https://github.com/nlevis625-web/renova-conseil.git "$RENOVA"

# 2. Landing adoonline (port 8080)
cd "$POPUP" && git pull origin master && npm install && npm run build
pm2 restart popup-direct 2>/dev/null || pm2 start ecosystem.config.cjs
pm2 save

# 3. Nginx propre (1 certificat par domaine)
rm -f /etc/nginx/sites-enabled/*
cat > /etc/nginx/sites-available/renova.conf << EOF
server {
    listen 443 ssl; listen [::]:443 ssl;
    server_name renova-conseil.com www.renova-conseil.com;
    root $RENOVA; index index.php index.html;
    ssl_certificate /etc/letsencrypt/live/renova-conseil.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/renova-conseil.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \\.php\$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:$PHP_SOCK; }
}
server {
    listen 80; listen [::]:80;
    server_name renova-conseil.com www.renova-conseil.com;
    return 301 https://\$host\$request_uri;
}
EOF
cat > /etc/nginx/sites-available/adoonline.conf << 'EOF'
server {
    listen 443 ssl; listen [::]:443 ssl;
    server_name adoonline.online www.adoonline.online adoonline.pics www.adoonline.pics;
    ssl_certificate /etc/letsencrypt/live/adoonline.online/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/adoonline.online/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
server {
    listen 80; listen [::]:80;
    server_name adoonline.online www.adoonline.online adoonline.pics www.adoonline.pics;
    return 301 https://$host$request_uri;
}
EOF
ln -sf /etc/nginx/sites-available/renova.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/adoonline.conf /etc/nginx/sites-enabled/
certbot install --cert-name renova-conseil.com 2>/dev/null || certbot --nginx -d renova-conseil.com -d www.renova-conseil.com --non-interactive --agree-tos -m contact@renova-conseil.com || true
certbot install --cert-name adoonline.online 2>/dev/null || certbot --nginx -d adoonline.online -d www.adoonline.online -d adoonline.pics -d www.adoonline.pics --non-interactive --agree-tos -m contact@renova-conseil.com || true
nginx -t && systemctl reload nginx
echo "renova:" $(curl -sk https://127.0.0.1/ -H "Host: renova-conseil.com" | head -c 80)
echo "health:" $(curl -sk https://127.0.0.1/health -H "Host: adoonline.online")
echo "TERMINE"
