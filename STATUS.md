# 🎯 MAX Production - État Actuel

**Date**: 2025-12-25 16:52 UTC
**Version**: 1.0.1 (correction domaine)

---

## ✅ Correction Appliquée

**Problème**: Cloudflare n'accepte pas `api.max.studiomacrea.cloud` (sous-sous-domaine)
**Solution**: Utilisation de `max-api.studiomacrea.cloud` à la place

### Changements effectués:

1. ✅ Nginx vhost corrigé sur serveur Scaleway
2. ✅ Nginx redémarré
3. ✅ Frontend `.env.production` mis à jour
4. ✅ Documentation complète mise à jour (3 fichiers MD)
5. ✅ Docker Compose sur serveur mis à jour (`MAX_BASE_URL`)
6. ✅ MAX Backend redémarré
7. ✅ Changements committés sur Git

---

## 🏗️ Architecture Finale

```
┌─────────────────────────────────────────────────┐
│              CLOUDFLARE DNS                     │
│           SSL/TLS: Full (strict)                │
└───────────┬─────────────────────────────────────┘
            │
     ┌──────┼──────┐
     │      │      │
     ▼      ▼      ▼
   max    max-api  crm
   .studio .studio .studio
   macrea  macrea  macrea
   .cloud  .cloud  .cloud
     │      │      │
     │      │      │
     ▼      ▼      ▼
  Vercel  Nginx   Nginx
   React  Proxy   Proxy
           │      │
           ▼      ▼
         MAX    EspoCRM
       Backend   PHP
      Node:3005  :80
```

---

## 📋 Configuration DNS à Faire

### Dans Cloudflare Dashboard

**Domaine**: studiomacrea.cloud

#### 1. max-api.studiomacrea.cloud (NOUVEAU)

```
Type:     A
Name:     max-api
Target:   51.159.170.20
Proxy:    ✅ ON (orange cloud)
TTL:      Auto
```

#### 2. max.studiomacrea.cloud (MODIFIER)

**Ancien**: CNAME → Cloudflare Tunnel
**Nouveau**:
```
Type:     CNAME
Name:     max
Target:   cname.vercel-dns.com
Proxy:    ✅ ON (orange cloud)
TTL:      Auto
```

#### 3. crm.studiomacrea.cloud (OK)

```
Type:     A
Name:     crm
Target:   51.159.170.20
Proxy:    ✅ ON (orange cloud)
TTL:      Auto
```

---

## 🔧 URLs de Production

| Service | URL | Backend Port |
|---------|-----|--------------|
| Frontend MAX | https://max.studiomacrea.cloud | - |
| API Backend | https://max-api.studiomacrea.cloud | 3005 |
| EspoCRM | https://crm.studiomacrea.cloud | 8080 |
| Health Check | https://max-api.studiomacrea.cloud/api/health | 3005 |
| Green-API Webhook | https://max-api.studiomacrea.cloud/webhooks/greenapi | 3005 |

---

## 🧪 Tests à Effectuer (après DNS)

### 1. Résolution DNS

```powershell
nslookup max-api.studiomacrea.cloud
```

**Attendu**: IP Cloudflare (104.x ou 172.x)

### 2. API Health

```powershell
curl -I https://max-api.studiomacrea.cloud/api/health
```

**Attendu**: `HTTP/2 200`

### 3. Frontend Vercel

Navigateur: `https://max.studiomacrea.cloud`

**Attendu**: Interface MAX charge

### 4. CRM

Navigateur: `https://crm.studiomacrea.cloud`

**Attendu**: Login EspoCRM (déjà fonctionnel ✅)

---

## 📦 État des Services Scaleway

**Serveur**: 51.159.170.20

```bash
docker compose ps
```

| Service | Status | Health | Port |
|---------|--------|--------|------|
| nginx | Up | - | 80, 443 |
| max-backend | Up | ✅ Healthy | 3005 |
| espocrm | Up | ✅ Healthy | 8080 |
| mariadb | Up | ✅ Healthy | 3306 |

---

## 🔐 Variables d'Environnement

### Frontend (Vercel)

Déjà configurées dans [.env.production](d:\Macrea\CRM\max_frontend\.env.production):

```env
VITE_API_BASE=https://max-api.studiomacrea.cloud
VITE_API_URL=https://max-api.studiomacrea.cloud
VITE_X_TENANT=macrea
VITE_X_ROLE=admin
VITE_X_PREVIEW=false
VITE_FLAG_USE_MOCKS=false
```

### Backend (Scaleway Docker)

Variables dans `/opt/max-infrastructure/.env` (à créer):

```env
SUPABASE_URL=<from_local_.env>
SUPABASE_SERVICE_KEY=<from_local_.env>
OPENAI_API_KEY=<from_local_.env>
GREENAPI_INSTANCE_ID=7105440259
GREENAPI_API_TOKEN=<from_local_.env>
MYSQL_ROOT_PASSWORD=<generate_new>
ESPO_DB_PASSWORD=<generate_new>
ESPO_USERNAME=admin
ESPO_PASSWORD=<set_secure_password>
JWT_SECRET=<generate_new>
ESPO_API_KEY=<generate_after_espo_setup>
```

---

## 📝 Checklist Déploiement

### Phase 1: DNS (5 min)

- [ ] Cloudflare → Add A record `max-api` → 51.159.170.20
- [ ] Cloudflare → Modify `max` to CNAME → cname.vercel-dns.com
- [ ] Attendre 5-10 min propagation
- [ ] Test: `curl -I https://max-api.studiomacrea.cloud/api/health`

### Phase 2: SSL (5 min)

- [ ] Cloudflare → SSL/TLS → Origin Server → Create Certificate
- [ ] Télécharger les 2 fichiers .pem
- [ ] Upload au serveur:
  ```powershell
  scp cloudflare-origin-cert.pem root@51.159.170.20:/opt/max-infrastructure/nginx/ssl/
  scp cloudflare-origin-key.pem root@51.159.170.20:/opt/max-infrastructure/nginx/ssl/
  ```
- [ ] SSH: `chmod 600 /opt/max-infrastructure/nginx/ssl/*.pem`
- [ ] SSH: `docker compose restart nginx`

### Phase 3: Backend Code (10 min)

- [ ] Upload code MAX:
  ```powershell
  scp -r d:\Macrea\CRM\max_backend\* root@51.159.170.20:/opt/max-infrastructure/max-backend/
  ```
- [ ] Upload custom EspoCRM:
  ```powershell
  scp -r "d:\Macrea\xampp\htdocs\espocrm\custom\*" root@51.159.170.20:/opt/max-infrastructure/espocrm/custom/
  ```
- [ ] SSH: Créer `.env` avec secrets
- [ ] SSH: `docker compose restart max-backend espocrm`
- [ ] SSH: `docker exec espocrm php command.php rebuild`

### Phase 4: EspoCRM API (5 min)

- [ ] Login https://crm.studiomacrea.cloud
- [ ] User → Preferences → API User → Enable
- [ ] Generate API Key
- [ ] Copier la clé
- [ ] SSH: Ajouter `ESPO_API_KEY=...` dans `.env`
- [ ] SSH: `docker compose restart max-backend`

### Phase 5: Frontend Vercel (10 min)

- [ ] Local: `cd d:\Macrea\CRM\max_frontend`
- [ ] `vercel login`
- [ ] `vercel --prod`
- [ ] `vercel domains add max.studiomacrea.cloud`
- [ ] Ajouter env vars dans Vercel Dashboard ou via CLI
- [ ] Redeploy: `vercel --prod`

### Phase 6: Green-API (2 min)

- [ ] Login https://console.green-api.com (instance 7105440259)
- [ ] Settings → Webhooks
- [ ] URL: `https://max-api.studiomacrea.cloud/webhooks/greenapi`
- [ ] Save

### Phase 7: Tests Finaux (5 min)

- [ ] Test API: `curl https://max-api.studiomacrea.cloud/api/health`
- [ ] Test Frontend: Ouvrir https://max.studiomacrea.cloud
- [ ] Test CRM: Ouvrir https://crm.studiomacrea.cloud
- [ ] Test WhatsApp: Envoyer message
- [ ] Vérifier logs: `docker compose logs -f max-backend`

---

## 🔗 Documentation

- **Guide complet**: [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)
- **Guide DNS rapide**: [DNS_CONFIG_NOW.md](./DNS_CONFIG_NOW.md)
- **README infrastructure**: [README.md](./README.md)

---

## 🚨 Actions Immédiates

**Priorité 1**: Configurer DNS Cloudflare pour `max-api.studiomacrea.cloud`

Suivre le guide: [DNS_CONFIG_NOW.md](./DNS_CONFIG_NOW.md)

---

**Last Update**: 2025-12-25 16:52 UTC
**Git Commits**:
- d11ae2d: docs: Add production deployment guides
- d300a08: fix: Use max-api instead of api.max (Cloudflare subdomain limitation)
