# 🚀 Configuration DNS Cloudflare - À FAIRE MAINTENANT

**Durée estimée**: 5 minutes
**Propagation DNS**: 5-10 minutes

---

## Étape 1: Connexion Cloudflare

1. Ouvrir https://dash.cloudflare.com
2. Se connecter avec vos identifiants
3. Sélectionner le domaine: **studiomacrea.cloud**
4. Cliquer sur l'onglet **DNS** → **Records**

---

## Étape 2: Configurer max-api.studiomacrea.cloud

### Créer un nouvel enregistrement A

**Cliquer sur "Add record"**

| Champ | Valeur |
|-------|--------|
| Type | **A** |
| Name | **max-api** |
| IPv4 address | **51.159.170.20** |
| Proxy status | **✅ Proxied** (nuage orange) |
| TTL | **Auto** |

**Cliquer sur "Save"**

---

## Étape 3: Reconfigurer max.studiomacrea.cloud pour Vercel

### Option A: Si l'enregistrement existe déjà

1. Trouver l'enregistrement pour **max** ou **max.studiomacrea.cloud**
2. Cliquer sur **Edit**
3. Modifier:
   - **Type**: CNAME
   - **Target**: `cname.vercel-dns.com`
   - **Proxy status**: ✅ Proxied
4. **Save**

### Option B: Si aucun enregistrement n'existe

1. **Add record**
2. Configuration:
   - **Type**: CNAME
   - **Name**: **max**
   - **Target**: **cname.vercel-dns.com**
   - **Proxy status**: ✅ Proxied
   - **TTL**: Auto
3. **Save**

---

## Étape 4: Vérifier crm.studiomacrea.cloud

**Vérifier qu'il existe déjà** (devrait être OK ✅):

| Champ | Valeur attendue |
|-------|-----------------|
| Type | A |
| Name | crm |
| IPv4 address | 51.159.170.20 |
| Proxy status | ✅ Proxied |

Si absent, créer avec ces valeurs.

---

## Étape 5: Vérifier SSL/TLS Settings

1. Dans Cloudflare Dashboard
2. Onglet **SSL/TLS**
3. **Encryption mode**: Doit être **Full (strict)**

Si ce n'est pas le cas, sélectionner **Full (strict)** et sauvegarder.

---

## ✅ Récapitulatif des DNS

Après configuration, vous devriez avoir:

```
Type    Name        Target/Value            Proxy
────────────────────────────────────────────────────
A       max-api     51.159.170.20          ✅ Proxied
CNAME   max         cname.vercel-dns.com   ✅ Proxied
A       crm         51.159.170.20          ✅ Proxied
```

---

## 🧪 Test après propagation (5-10 min)

### Test 1: Vérifier la résolution DNS

Ouvrir PowerShell et exécuter:

```powershell
nslookup max-api.studiomacrea.cloud
```

**Résultat attendu**: Une ou plusieurs adresses IP Cloudflare (104.x.x.x ou 172.x.x.x)

### Test 2: Tester l'API Health

```powershell
curl -I https://max-api.studiomacrea.cloud/api/health
```

**Résultat attendu**:
```
HTTP/2 200
server: nginx
```

### Test 3: Vérifier le CRM

Ouvrir dans le navigateur:
```
https://crm.studiomacrea.cloud
```

**Résultat attendu**: Page de connexion EspoCRM

---

## ⚠️ Si problèmes

### Problème: "Could not resolve host"

**Cause**: DNS pas encore propagé

**Solution**: Attendre 5-10 minutes, puis réessayer

---

### Problème: "ERR_TOO_MANY_REDIRECTS" sur CRM

**Cause**: Double redirection HTTPS

**Solution rapide**:
1. Cloudflare → SSL/TLS
2. Changer de **Full (strict)** à **Full**
3. Attendre 1 minute
4. Réessayer

---

### Problème: Cloudflare montre "Error 521 Web server is down"

**Cause**: Nginx pas démarré ou certificat SSL manquant

**Solution**:
```bash
ssh root@51.159.170.20
cd /opt/max-infrastructure
docker compose ps
# Vérifier que nginx est "Up"

# Si problème SSL, vérifier:
ls -la nginx/ssl/
# Doit contenir cloudflare-origin-cert.pem et cloudflare-origin-key.pem
```

---

## 📞 Étapes suivantes après DNS OK

Une fois que `max-api.studiomacrea.cloud` répond:

1. ✅ **Générer certificat SSL Cloudflare Origin** (voir DEPLOYMENT_CHECKLIST.md section 2)
2. ✅ **Uploader le code MAX Backend** (section 3)
3. ✅ **Uploader custom EspoCRM** (section 4)
4. ✅ **Créer .env avec vrais secrets** (section 5)
5. ✅ **Générer API Key EspoCRM** (section 6)
6. ✅ **Déployer Frontend sur Vercel** (section 7)
7. ✅ **Configurer webhook Green-API** (section 8)

---

**Référence complète**: Voir [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)
