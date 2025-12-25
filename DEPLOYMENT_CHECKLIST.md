# MAX MVP1 Production Deployment Checklist

**Date**: 2025-12-25
**Goal**: Deploy MAX AI Assistant to production with Frontend/Backend/CRM separation

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                       CLOUDFLARE                            │
│              SSL/TLS: Full (strict)                         │
│              WAF + DDoS Protection                          │
└───────────────────┬─────────────────────────────────────────┘
                    │
        ┌───────────┼───────────────┐
        │           │               │
        ▼           ▼               ▼
   max.studio  api.max.studio  crm.studio
   macrea.cloud   macrea.cloud    macrea.cloud
        │           │               │
        │           │               │
   ┌────┘      ┌────┴────────┐     │
   │           │  Scaleway   │     │
   │           │  51.159.    │     │
   │           │  170.20     │     │
   │           └──────┬──────┘     │
   │                  │            │
   ▼                  ▼            ▼
┌──────┐      ┌──────────────────────────┐
│Vercel│      │     Nginx (Docker)       │
│React │      │   SSL Termination        │
│SPA   │      └─────────┬────────────────┘
└──────┘                │
                   ┌────┴────┐
                   │         │
                   ▼         ▼
          ┌──────────┐  ┌─────────┐
          │MAX       │  │EspoCRM  │
          │Backend   │  │PHP      │
          │Node:3005 │  │:80      │
          └────┬─────┘  └────┬────┘
               │             │
               └──────┬──────┘
                      ▼
              ┌──────────────┐
              │  MariaDB     │
              │  :3306       │
              └──────────────┘
```

---

## ✅ Completed Steps

- [x] Docker infrastructure created locally
- [x] Git repository initialized (`max-infrastructure`)
- [x] Scaleway server provisioned (Ubuntu 22.04)
- [x] Docker Compose stack deployed on Scaleway
- [x] Nginx reverse proxy configured
- [x] EspoCRM container running and healthy
- [x] MAX Backend container running and healthy
- [x] MariaDB container running and healthy
- [x] crm.studiomacrea.cloud DNS configured and working
- [x] Nginx configuration fixed (api.max domain)
- [x] Frontend .env.production created

---

## 🔄 Remaining Steps

### 1. Cloudflare DNS Configuration

**Action Required**: Configure DNS in Cloudflare Dashboard

#### A. Add api.max.studiomacrea.cloud

1. Login to Cloudflare Dashboard
2. Select domain: `studiomacrea.cloud`
3. Go to DNS → Records → Add record
4. Configuration:
   - **Type**: A
   - **Name**: `api.max` (or `api.max.studiomacrea.cloud`)
   - **IPv4 address**: `51.159.170.20`
   - **Proxy status**: ✅ Proxied (orange cloud)
   - **TTL**: Auto

#### B. Reconfigure max.studiomacrea.cloud

**Current Status**: Currently pointing to Cloudflare Tunnel
**Required Change**: Point to Vercel

**Steps**:
1. Remove existing CNAME record for `max.studiomacrea.cloud`
2. Add new CNAME record:
   - **Type**: CNAME
   - **Name**: `max`
   - **Target**: `cname.vercel-dns.com`
   - **Proxy status**: ✅ Proxied (orange cloud)
   - **TTL**: Auto

#### C. Verify crm.studiomacrea.cloud

**Current Status**: Already working ✅

**Verify Config**:
- **Type**: A
- **Name**: `crm`
- **IPv4 address**: `51.159.170.20`
- **Proxy status**: ✅ Proxied

**Test**: https://crm.studiomacrea.cloud (should load EspoCRM)

---

### 2. Cloudflare SSL Origin Certificate

**Why Needed**: Secure connection between Cloudflare and Nginx

**Steps**:

1. **Generate Certificate**:
   - Cloudflare Dashboard → SSL/TLS → Origin Server
   - Click "Create Certificate"
   - **Options**:
     - Private key type: RSA (2048)
     - Hostnames: `*.studiomacrea.cloud, studiomacrea.cloud`
     - Validity: 15 years
   - Click "Create"

2. **Download Files**:
   - Copy "Origin Certificate" → save as `cloudflare-origin-cert.pem`
   - Copy "Private Key" → save as `cloudflare-origin-key.pem`

3. **Upload to Server**:
   ```powershell
   # From local machine
   scp cloudflare-origin-cert.pem root@51.159.170.20:/opt/max-infrastructure/nginx/ssl/
   scp cloudflare-origin-key.pem root@51.159.170.20:/opt/max-infrastructure/nginx/ssl/
   ```

4. **Set Permissions**:
   ```bash
   ssh root@51.159.170.20
   chmod 600 /opt/max-infrastructure/nginx/ssl/*.pem
   ```

5. **Restart Nginx**:
   ```bash
   cd /opt/max-infrastructure
   docker compose restart nginx
   ```

---

### 3. Upload MAX Backend Code

**Current Status**: Backend container running with placeholder code
**Required**: Upload actual MAX code from local development

**Steps**:

```powershell
# From d:\Macrea\CRM directory
scp -r max_backend\* root@51.159.170.20:/opt/max-infrastructure/max-backend/
```

**Verify Upload**:
```bash
ssh root@51.159.170.20 "ls -la /opt/max-infrastructure/max-backend/"
```

**Restart Backend**:
```bash
ssh root@51.159.170.20 "cd /opt/max-infrastructure && docker compose restart max-backend"
```

---

### 4. Upload EspoCRM Custom Files

**Current Status**: EspoCRM running with base installation
**Required**: Upload custom fields and configurations

**Steps**:

```powershell
# From d:\Macrea\CRM directory
scp -r "d:\Macrea\xampp\htdocs\espocrm\custom\*" root@51.159.170.20:/opt/max-infrastructure/espocrm/custom/
```

**Rebuild EspoCRM**:
```bash
ssh root@51.159.170.20
cd /opt/max-infrastructure
docker exec espocrm php command.php rebuild
docker exec espocrm php command.php clear-cache
```

---

### 5. Configure Production Environment Variables

**Current Status**: .env.example exists with placeholders
**Required**: Create .env with real secrets

**Steps**:

```bash
ssh root@51.159.170.20
cd /opt/max-infrastructure
cp .env.example .env
nano .env
```

**Required Values**:

```env
# Supabase (from existing local .env)
SUPABASE_URL=https://xxxxxxxxxxxxxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# OpenAI (from existing local .env)
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Green-API (from existing local .env)
GREENAPI_INSTANCE_ID=7105440259
GREENAPI_API_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxx

# Database (generate new strong passwords)
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
ESPO_DB_PASSWORD=$(openssl rand -base64 32)

# EspoCRM Admin (set your preferred password)
ESPO_USERNAME=admin
ESPO_PASSWORD=YourSecurePassword123!

# JWT Secret (generate new)
JWT_SECRET=$(openssl rand -base64 32)

# Will be filled after EspoCRM API key generation
ESPO_API_KEY=
```

**Save and Secure**:
```bash
chmod 600 .env
```

**Restart All Services**:
```bash
docker compose down
docker compose up -d
```

---

### 6. Generate EspoCRM API Key

**Current Status**: EspoCRM running without API key
**Required**: API key for MAX Backend to communicate with CRM

**Steps**:

1. **Login to EspoCRM**:
   - URL: https://crm.studiomacrea.cloud
   - Username: `admin`
   - Password: (from .env ESPO_PASSWORD)

2. **Create API User**:
   - Click on your username (top-right)
   - Preferences
   - Scroll to "API User"
   - Check "Is API User"
   - Click "Save"

3. **Generate API Key**:
   - After saving, a new section "API Key" appears
   - Click "Generate API Key"
   - Copy the key (it won't be shown again!)

4. **Update .env**:
   ```bash
   ssh root@51.159.170.20
   cd /opt/max-infrastructure
   nano .env
   # Add: ESPO_API_KEY=paste_your_key_here
   ```

5. **Restart MAX Backend**:
   ```bash
   docker compose restart max-backend
   ```

---

### 7. Deploy Frontend to Vercel

**Current Status**: .env.production created locally
**Required**: Deploy to Vercel and connect max.studiomacrea.cloud

**Steps**:

```powershell
# From d:\Macrea\CRM\max_frontend
cd d:\Macrea\CRM\max_frontend

# Login to Vercel (if not already)
vercel login

# Deploy to production
vercel --prod

# Add custom domain
vercel domains add max.studiomacrea.cloud

# Set environment variables in Vercel Dashboard
# OR via CLI:
vercel env add VITE_API_BASE production
# When prompted, enter: https://api.max.studiomacrea.cloud

vercel env add VITE_API_URL production
# When prompted, enter: https://api.max.studiomacrea.cloud

vercel env add VITE_X_TENANT production
# When prompted, enter: macrea

vercel env add VITE_X_ROLE production
# When prompted, enter: admin

vercel env add VITE_X_PREVIEW production
# When prompted, enter: false

vercel env add VITE_FLAG_USE_MOCKS production
# When prompted, enter: false
```

**Redeploy with Environment Variables**:
```powershell
vercel --prod
```

---

### 8. Configure Green-API Webhook

**Current Status**: Green-API instance active but webhook not configured
**Required**: Point webhook to production API

**Steps**:

1. **Login to Green-API Dashboard**:
   - URL: https://console.green-api.com
   - Instance: 7105440259

2. **Configure Webhook**:
   - Settings → Webhooks
   - **Webhook URL**: `https://api.max.studiomacrea.cloud/webhooks/greenapi`
   - **Events**: Check "incomingMessageReceived"
   - Save

3. **Test Webhook**:
   ```powershell
   # Send test message to your WhatsApp
   # Check logs
   ssh root@51.159.170.20 "cd /opt/max-infrastructure && docker compose logs -f max-backend"
   ```

---

### 9. Push Infrastructure to GitHub

**Current Status**: Git repository initialized locally
**Required**: Push to GitHub for version control

**Steps**:

```powershell
# From d:\Macrea\CRM\max-infrastructure
cd d:\Macrea\CRM\max-infrastructure

# Verify .env is ignored
git status
# Should NOT show .env file

# Commit all files
git add .
git commit -m "init: MAX infrastructure Scaleway Docker"

# Push to GitHub
git remote add origin https://github.com/Malilyqueen/max-infrastructure.git
git branch -M main
git push -u origin main
```

---

## 🧪 Testing & Verification

### Test 1: API Health Check

**After DNS propagation** (5-10 minutes):

```bash
curl -I https://api.max.studiomacrea.cloud/api/health
```

**Expected**: `HTTP/2 200`

---

### Test 2: Frontend Loading

**URL**: https://max.studiomacrea.cloud

**Expected**: MAX UI loads correctly

**Check**:
- Browser console: No CORS errors
- Network tab: API calls to `https://api.max.studiomacrea.cloud`

---

### Test 3: EspoCRM Access

**URL**: https://crm.studiomacrea.cloud

**Expected**: EspoCRM login page

**Login**: admin / (your password)

---

### Test 4: WhatsApp Integration

1. Send WhatsApp message to your Green-API number
2. Check logs:
   ```bash
   ssh root@51.159.170.20 "cd /opt/max-infrastructure && docker compose logs -f max-backend | grep greenapi"
   ```
3. Verify webhook received

---

## 🔒 Security Checklist

- [ ] `.env` file has chmod 600
- [ ] `.env` is in `.gitignore`
- [ ] SSL certificates are valid (Cloudflare Origin)
- [ ] Cloudflare proxy enabled (orange cloud) for all DNS
- [ ] Strong passwords generated with `openssl rand -base64 32`
- [ ] Database not exposed to internet (only internal Docker network)
- [ ] Nginx rate limiting active (`limit_req` zones)
- [ ] HSTS header configured (`Strict-Transport-Security`)

---

## 📊 Monitoring

### View Logs

```bash
# All services
docker compose logs -f

# MAX Backend only
docker compose logs -f max-backend

# EspoCRM only
docker compose logs -f espocrm

# Nginx only
docker compose logs -f nginx
```

### Check Service Health

```bash
docker compose ps
```

All should show `(healthy)` status.

---

## 🔄 Maintenance Commands

### Update MAX Backend Code

```powershell
# From local machine
scp -r d:\Macrea\CRM\max_backend\* root@51.159.170.20:/opt/max-infrastructure/max-backend/
ssh root@51.159.170.20 "cd /opt/max-infrastructure && docker compose restart max-backend"
```

### Update Frontend

```powershell
cd d:\Macrea\CRM\max_frontend
vercel --prod
```

### Backup Database

```bash
ssh root@51.159.170.20
cd /opt/max-infrastructure
./scripts/backup.sh
```

### Restore from Backup

```bash
# Find backup
ls -lh /opt/max-infrastructure/backups/

# Restore database
gunzip < backups/espocrm_20251225_120000.sql.gz | docker exec -i mariadb mysql -u root -p${MYSQL_ROOT_PASSWORD} espocrm
```

### Rebuild Everything

```bash
ssh root@51.159.170.20
cd /opt/max-infrastructure
docker compose down
docker compose build --no-cache
docker compose up -d
```

---

## 🆘 Troubleshooting

### Issue: "Could not resolve host: api.max.studiomacrea.cloud"

**Cause**: DNS not configured or not propagated yet

**Fix**:
1. Check Cloudflare DNS records
2. Wait 5-10 minutes for propagation
3. Test with `nslookup api.max.studiomacrea.cloud`

---

### Issue: "ERR_TOO_MANY_REDIRECTS" on crm.studiomacrea.cloud

**Cause**: Double HTTPS redirect (Cloudflare + Nginx)

**Fix Option 1** (Cloudflare):
1. Cloudflare Dashboard → SSL/TLS
2. Change from "Full (strict)" to "Full"

**Fix Option 2** (Nginx):
1. Edit `/opt/max-infrastructure/nginx/conf.d/crm.conf`
2. Remove HTTP→HTTPS redirect section (lines 16-19)
3. Restart nginx: `docker compose restart nginx`

---

### Issue: Backend not connecting to Supabase

**Check**:
```bash
ssh root@51.159.170.20
cd /opt/max-infrastructure
docker compose logs max-backend | grep -i supabase
```

**Fix**: Verify `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` in `.env`

---

### Issue: EspoCRM shows white screen

**Fix**:
```bash
docker exec espocrm php command.php rebuild
docker exec espocrm php command.php clear-cache
docker compose restart espocrm
```

---

## 📝 Important URLs

| Service | URL | Status |
|---------|-----|--------|
| Frontend MAX | https://max.studiomacrea.cloud | ⏳ Pending Vercel deploy |
| Backend API | https://api.max.studiomacrea.cloud | ⏳ Pending DNS config |
| EspoCRM | https://crm.studiomacrea.cloud | ✅ Working |
| API Health | https://api.max.studiomacrea.cloud/api/health | ⏳ Pending DNS config |
| Green-API Webhook | https://api.max.studiomacrea.cloud/webhooks/greenapi | ⏳ Pending DNS config |

---

## 🎯 Next Immediate Action

**Priority 1**: Configure Cloudflare DNS for `api.max.studiomacrea.cloud`

1. Login to Cloudflare
2. Add A record: `api.max` → `51.159.170.20` (proxied)
3. Wait 5-10 minutes
4. Test: `curl -I https://api.max.studiomacrea.cloud/api/health`

Once DNS works, proceed with steps 2-9 in order.

---

**Last Updated**: 2025-12-25 16:41 UTC
**Infrastructure Version**: 1.0.0
**Server IP**: 51.159.170.20
