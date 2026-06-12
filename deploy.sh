#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "==> Installation"
npm install

echo "==> Build landing page"
npm run build

echo "==> Redemarrage serveur"
if command -v pm2 >/dev/null 2>&1; then
  pm2 startOrRestart ecosystem.config.cjs
  pm2 save
  echo "OK : pm2 status / pm2 logs popup-direct"
else
  echo "PM2 absent. Installez : npm install -g pm2"
  echo "Puis : pm2 start ecosystem.config.cjs"
fi

echo ""
echo "==> Domaines : adoonline.online + adoonline.pics"
echo "==> Nginx    : sudo cp nginx/adoonline.online.conf /etc/nginx/sites-available/"
echo "               sudo ln -sf /etc/nginx/sites-available/adoonline.online.conf /etc/nginx/sites-enabled/"
echo "               sudo nginx -t && sudo systemctl reload nginx"
echo "               sudo certbot --nginx -d adoonline.online -d www.adoonline.online -d adoonline.pics -d www.adoonline.pics"
echo "==> Test     : curl http://127.0.0.1:8080/health"
