# 🚀 MAX Production - Démarrage Rapide

**⏱️ Temps total**: ~45 minutes
**📍 Vous êtes ici**: Serveur configuré ✅, DNS à faire

---

## ⚡ Action Immédiate - DNS Cloudflare (5 min)

### Ouvrir Cloudflare Dashboard

1. https://dash.cloudflare.com
2. Domaine: **studiomacrea.cloud**
3. Onglet **DNS** → **Records**

### Ajouter: max-api.studiomacrea.cloud

**Cliquer "Add record"**:

- Type: **A**
- Name: **max-api**
- IPv4: **51.159.170.20**
- Proxy: **✅ ON** (nuage orange)
- TTL: **Auto**

**Save**

### Modifier: max.studiomacrea.cloud

**Trouver l'enregistrement existant** et modifier:

- Type: **CNAME**
- Name: **max**
- Target: **cname.vercel-dns.com**
- Proxy: **✅ ON**
- TTL: **Auto**

**Save**

### Test (attendre 5-10 min)

```powershell
nslookup max-api.studiomacrea.cloud
```

Si OK (IP Cloudflare visible), tester l'API:

```powershell
curl -I https://max-api.studiomacrea.cloud/api/health
```

**Attendu**: Erreur 502 ou 503 (c'est normal, certificat SSL manquant)
**Important**: Pas d'erreur DNS "Could not resolve host"

---

## 📜 Suite du Déploiement

Une fois le DNS configuré, suivre dans l'ordre:

### 1. SSL Cloudflare Origin (5 min)

[Voir DEPLOYMENT_CHECKLIST.md section 2](./DEPLOYMENT_CHECKLIST.md#2-cloudflare-ssl-origin-certificate)

### 2. Upload Code Backend (10 min)

```powershell
scp -r d:\Macrea\CRM\max_backend\* root@51.159.170.20:/opt/max-infrastructure/max-backend/
```

### 3. Upload Custom EspoCRM (5 min)

```powershell
scp -r "d:\Macrea\xampp\htdocs\espocrm\custom\*" root@51.159.170.20:/opt/max-infrastructure/espocrm/custom/
```

### 4. Créer .env Production (10 min)

```bash
ssh root@51.159.170.20
cd /opt/max-infrastructure
cp .env.example .env
nano .env
# Copier les valeurs de votre .env local
# Générer nouveaux mots de passe pour MYSQL et ESPO
docker compose restart max-backend espocrm
```

### 5. EspoCRM API Key (5 min)

- Login: https://crm.studiomacrea.cloud
- User → Preferences → API User → Enable → Generate Key
- Ajouter dans `.env` sur serveur: `ESPO_API_KEY=...`
- `docker compose restart max-backend`

### 6. Déployer Frontend Vercel (10 min)

```powershell
cd d:\Macrea\CRM\max_frontend
vercel --prod
vercel domains add max.studiomacrea.cloud
```

### 7. Green-API Webhook (2 min)

- https://console.green-api.com
- Instance 7105440259
- Webhook: `https://max-api.studiomacrea.cloud/webhooks/greenapi`

---

## ✅ État Actuel Infrastructure

**Serveur Scaleway** (51.159.170.20):

```
✅ Nginx: Running (Port 80, 443)
✅ MAX Backend: Healthy (Port 3005)
✅ EspoCRM: Healthy (Port 8080)
✅ MariaDB: Healthy (Internal 3306)
```

**Configuration**:

```
✅ Nginx vhosts: max-api + crm (corrigés)
✅ Frontend .env.production: Prêt
✅ Documentation complète: 4 fichiers MD
✅ Git commits: 3 commits (infrastructure ready)
```

---

## 📚 Documentation Complète

| Document | Usage |
|----------|-------|
| [STATUS.md](./STATUS.md) | État actuel détaillé |
| [DNS_CONFIG_NOW.md](./DNS_CONFIG_NOW.md) | Guide DNS étape par étape |
| [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) | Guide complet 9 étapes |
| [README.md](./README.md) | Infrastructure overview |

---

## 🎯 URLs Finales

| Service | URL |
|---------|-----|
| Frontend | https://max.studiomacrea.cloud |
| API | https://max-api.studiomacrea.cloud |
| CRM | https://crm.studiomacrea.cloud ✅ |
| Health | https://max-api.studiomacrea.cloud/api/health |

---

## 🆘 Support

### DNS ne se propage pas

**Vérifier**: Cloudflare Dashboard → DNS Records
**Attendre**: 5-10 minutes maximum
**Test**: `nslookup max-api.studiomacrea.cloud`

### Error 502 Bad Gateway

**Cause**: Certificat SSL manquant ou backend pas démarré
**Fix**: Suivre section 2 du DEPLOYMENT_CHECKLIST.md

### Error 521 Web Server Down

**Cause**: Nginx pas accessible
**Fix**:
```bash
ssh root@51.159.170.20
docker compose ps
docker compose restart nginx
```

---

**Prochaine action**: Configurer DNS Cloudflare maintenant 👆
