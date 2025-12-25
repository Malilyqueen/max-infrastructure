# MAX Infrastructure - Scaleway Deployment

Production Docker infrastructure for MAX AI Assistant + EspoCRM.

**Server**: Scaleway Ubuntu 22.04
**SSL**: Cloudflare Full (strict) + Origin Certificate
**Services**: MAX Backend (3005), EspoCRM, MariaDB, Nginx

---

## Quick Deploy

```bash
# On Scaleway server
cd /opt
git clone https://github.com/Malilyqueen/max-infrastructure.git
cd max-infrastructure

# Create .env from .env.example
cp .env.example .env
nano .env  # Fill with real values

# Upload SSL certificates (from local)
scp cloudflare-origin-cert.pem root@51.159.170.20:/opt/max-infrastructure/nginx/ssl/
scp cloudflare-origin-key.pem root@51.159.170.20:/opt/max-infrastructure/nginx/ssl/

# Copy MAX backend code (from local)
scp -r d:\Macrea\CRM\max_backend\* root@51.159.170.20:/opt/max-infrastructure/max-backend/

# Copy EspoCRM custom (from local)
scp -r "d:\Macrea\xampp\htdocs\espocrm\custom\*" root@51.159.170.20:/opt/max-infrastructure/espocrm/custom/

# Set permissions
chmod 600 .env
chmod 600 nginx/ssl/*.pem
chmod +x scripts/*.sh

# Build and start
docker compose up -d --build

# Check status
docker compose ps
docker compose logs -f max-backend
```

---

## Services

- **MAX Backend**: `http://localhost:3005` → `https://max-api.studiomacrea.cloud`
- **EspoCRM**: `http://localhost:8080` → `https://crm.studiomacrea.cloud`
- **MariaDB**: Internal only (:3306)
- **Nginx**: Reverse proxy with HTTPS (:80, :443)

---

## Environment Variables

Required in `.env`:

```env
SUPABASE_URL=https://...
SUPABASE_SERVICE_KEY=...
OPENAI_API_KEY=sk-proj-...
GREENAPI_INSTANCE_ID=...
GREENAPI_API_TOKEN=...
MYSQL_ROOT_PASSWORD=...
ESPO_DB_PASSWORD=...
ESPO_USERNAME=admin
ESPO_PASSWORD=...
JWT_SECRET=...
```

---

## Post-Deploy

1. **Generate EspoCRM API Key**:
   - Login: https://crm.studiomacrea.cloud
   - User → Preferences → API User → Create
   - Update `.env`: `ESPO_API_KEY=...`
   - Restart: `docker compose restart max-backend`

2. **Configure Green-API Webhook**:
   - URL: `https://max-api.studiomacrea.cloud/webhooks/greenapi`

3. **Rebuild EspoCRM**:
   ```bash
   docker exec espocrm php command.php rebuild
   docker exec espocrm php command.php clear-cache
   ```

---

## Maintenance

```bash
# Update deployment
cd /opt/max-infrastructure
./scripts/deploy.sh

# View logs
docker compose logs -f max-backend

# Backup
./scripts/backup.sh

# Restart service
docker compose restart max-backend
```

---

## Architecture

```
Cloudflare (SSL/WAF)
    ↓
Nginx (Reverse Proxy)
    ↓
┌───────────┬──────────┐
MAX Backend  EspoCRM   MariaDB
(Node:3005)  (PHP:80)  (:3306)
    ↓
Supabase (External)
```

---

## DNS Configuration

Cloudflare DNS → Proxied:
- `max-api.studiomacrea.cloud` → `51.159.170.20`
- `crm.studiomacrea.cloud` → `51.159.170.20`

SSL/TLS: **Full (strict)**

---

## License

Proprietary - Macrea CRM
