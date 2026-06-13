#!/bin/bash
set -euo pipefail
RENOVA="/var/www/renova-conseil"
POPUP="/var/www/popup-direct"
PHP_SOCK=$(ls /var/run/php/*.sock | head -1)
cd "$POPUP" && npm install && npm run build
pm2 startOrRestart ecosystem.config.cjs || pm2 start ecosystem.config.cjs
pm2 save
cat > /etc/nginx/sites-available/renova-conseil.conf << EOF
server {
    listen 80; listen [::]:80;
    server_name renova-conseil.com www.renova-conseil.com;
    return 301 https://\$host\$request_uri;
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
    return 301 https://$host$request_uri;
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
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
ln -sf /etc/nginx/sites-available/renova-conseil.conf /etc/nginx/sites-enabled/
ln -sf /etc/nginx/sites-available/adoonline.online.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
[ ! -f /etc/letsencrypt/live/renova-conseil.com/fullchain.pem ] && certbot certonly --nginx -d renova-conseil.com -d www.renova-conseil.com --non-interactive --agree-tos -m contact@renova-conseil.com || true
[ ! -f /etc/letsencrypt/live/adoonline.online/fullchain.pem ] && certbot certonly --nginx -d adoonline.online -d www.adoonline.online -d adoonline.pics -d www.adoonline.pics --non-interactive --agree-tos -m contact@renova-conseil.com || true
nginx -t && systemctl reload nginx
echo "OK renova:" $(curl -skI https://127.0.0.1/ -H "Host: renova-conseil.com" | head -1)
echo "OK adoonline:" $(curl -sk https://127.0.0.1/health -H "Host: adoonline.online")
