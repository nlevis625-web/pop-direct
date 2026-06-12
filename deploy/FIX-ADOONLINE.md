# Reparation adoonline.online

## Probleme

`adoonline.online` et `renova-conseil.com` pointent vers la meme IP (`159.89.50.166`).
Lors du deploiement Renova, la config nginx `adoonline*` a ete supprimee.
Resultat : le domaine affiche le site Renova Solaire au lieu de la landing popup.

## Solution

Lancer `deploy/fix-adoonline.sh` sur le Droplet DigitalOcean.

## Etapes

### 1. Ouvrir la console DigitalOcean

DigitalOcean → Droplets → serveur `159.89.50.166` → **Access** → **Launch Droplet Console**

### 2. Lancer le script (root)

**Option A — depuis GitHub (apres push) :**

```bash
curl -fsSL https://raw.githubusercontent.com/nlevis625-web/pop-direct/master/deploy/fix-adoonline.sh | bash
```

**Option B — copier-coller le script localement :**

```bash
cd /var/www
git clone https://github.com/nlevis625-web/pop-direct.git popup-direct
bash /var/www/popup-direct/deploy/fix-adoonline.sh
```

### 3. Verifier

```bash
curl -s https://adoonline.online/health
# Attendu : ok

curl -sI https://renova-conseil.com/ | head -1
# Attendu : HTTP/2 200
```

Dans le navigateur : https://adoonline.online/

### 4. Cloudflare (si utilise)

Purge le cache DNS/page puis recharge avec `Ctrl+Shift+R`.

## Ce que le script fait

1. Verifie que `renova-conseil.conf` reste actif
2. Installe Node.js 20 + PM2 si necessaire
3. Clone/met a jour `pop-direct` dans `/var/www/popup-direct`
4. Build + demarrage PM2 sur le port 8080
5. Ajoute la config nginx `adoonline.online` (proxy vers 8080)
6. Genere le certificat SSL Let's Encrypt
7. Teste les deux domaines

## Ce que le script ne fait PAS

- Ne supprime pas la config `renova-conseil`
- Ne modifie pas le DNS (deja correct vers 159.89.50.166)
