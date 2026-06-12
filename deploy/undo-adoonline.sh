#!/bin/bash
# Annule deploy/fix-adoonline.sh — retire adoonline.online du serveur
# renova-conseil.com reste intact
#
# Usage (root, console DigitalOcean) :
#   curl -fsSL https://raw.githubusercontent.com/nlevis625-web/pop-direct/master/deploy/undo-adoonline.sh | bash
#
set -euo pipefail

NGINX_SITE="adoonline.online"

echo "=============================================="
echo " Annulation config adoonline.online"
echo " (renova-conseil.com non modifie)"
echo "=============================================="

if [ "$(id -u)" -ne 0 ]; then
  echo "Erreur : lancez en root"
  exit 1
fi

echo ""
echo "=== 1. Arreter popup-direct (PM2) ==="
if command -v pm2 >/dev/null 2>&1; then
  pm2 stop popup-direct 2>/dev/null || true
  pm2 delete popup-direct 2>/dev/null || true
  pm2 save 2>/dev/null || true
  echo "OK : popup-direct arrete"
else
  echo "PM2 absent — rien a arreter"
fi

echo ""
echo "=== 2. Retirer nginx adoonline ==="
rm -f "/etc/nginx/sites-enabled/${NGINX_SITE}.conf"
rm -f "/etc/nginx/sites-enabled/adoonline"*
nginx -t
systemctl reload nginx
echo "OK : config adoonline retiree de sites-enabled"

echo ""
echo "=== 3. Tests ==="
echo -n "renova HTTPS : "
curl -skI https://127.0.0.1 -H "Host: renova-conseil.com" | head -1

echo ""
echo "=============================================="
echo " TERMINE"
echo " adoonline.online ne pointe plus vers popup-direct"
echo " (peut afficher renova ou 404 selon nginx default)"
echo " renova-conseil.com : inchange"
echo ""
echo " Dossier /var/www/popup-direct conserve (supprimez manuellement si besoin)"
echo "=============================================="
