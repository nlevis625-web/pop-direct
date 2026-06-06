#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "==> Installation"
npm install

echo "==> Build"
npm run build

echo "==> Redemarrage serveur"
if command -v pm2 >/dev/null 2>&1; then
  pm2 startOrRestart ecosystem.config.cjs
  pm2 save
  echo "Serveur controle via: pm2 status / pm2 logs popup-direct"
else
  echo "PM2 non installe. Lancez: npm install -g pm2"
  echo "Puis: pm2 start ecosystem.config.cjs"
fi
