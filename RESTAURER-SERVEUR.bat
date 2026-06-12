@echo off
chcp 65001 >nul
title Restauration serveur complete

set "CMD=curl -fsSL https://raw.githubusercontent.com/nlevis625-web/pop-direct/master/deploy/restore-all.sh | bash"

echo.
echo  Commande copiee dans le presse-papier :
echo.
echo   %CMD%
echo.
powershell -NoProfile -Command "Set-Clipboard -Value '%CMD%'"
start "" "https://cloud.digitalocean.com/droplets?search=159.89.50.166"
echo  Console DigitalOcean ^> Access ^> Launch Console ^> Coller ^> Entree
pause
