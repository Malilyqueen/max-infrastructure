# README – Connexion UI M.A.X. ↔ Macréa CRM (EspoCRM)

## Prérequis

- Backend Node/Express (port 3005) : `D:\Macrea\CRMACREA\ia_admin_api`
- Frontend Vite/React (port 5173) : `D:\Macrea\CRMACREA\ia-admin-ui`
- EspoCRM local sur `http://127.0.0.1:8081`
- n8n (optionnel) sur `http://127.0.0.1:5678`

## Étape 0 — Dépendances & Env

### Backend (ia_admin_api)

```bash
npm i express cors node-fetch@3
```

### Frontend (ia-admin-ui)

```bash
npm i
```

Créer/éditer `.env` côté frontend :

```
VITE_API_BASE=http://127.0.0.1:3005
```

## Étape 1 — Logging global (6: Logs & Traces)

Fichier : `ia_admin_api/server.js` (haut du fichier)

```javascript
process.on('unhandledRejection', (reason)=> console.error('[FATAL] UnhandledRejection:', reason));
process.on('uncaughtException', (err)=> { console.error('[FATAL] UncaughtException:', err); process.exit(1); });
process.on('SIGINT', ()=> { console.log('[EXIT] SIGINT'); process.exit(0); });
process.on('SIGTERM', ()=> { console.log('[EXIT] SIGTERM'); process.exit(0); });
```

## Étape 2 — Middleware headers + CORS

Fichier : `ia_admin_api/middleware/headers.js` (NOUVEAU)

```javascript
module.exports = function headers(req,res,next){
  req.ctx = {
    tenant:  req.header('X-Tenant')  || 'damath',
    role:    req.header('X-Role')    || 'admin',
    preview: (req.header('X-Preview')||'true') === 'true'
  };
  res.setHeader('X-Tenant', req.ctx.tenant);
  res.setHeader('X-Role', req.ctx.role);
  res.setHeader('X-Preview', String(req.ctx.preview));
  next();
};
```

Fichier : `ia_admin_api/server.js` (ajouter)

```javascript
const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());
app.use(require('./middleware/headers'));
```

## Étape 3 — Endpoints baseline (7)

### 3.1 Resolve Tenant (badge en ligne)

Fichier : `ia_admin_api/routes/status.js` (NOUVEAU)

```javascript
const router = require('express').Router();
router.get('/resolve-tenant', (req,res)=> {
  res.json({ ok:true, tenant:req.ctx.tenant, role:req.ctx.role, preview:req.ctx.preview });
});
router.get('/__espo-status', (req,res)=> res.json({ ok:true, base:'http://127.0.0.1:8081', sample:1 }));
module.exports = router;
```

Fichier : `ia_admin_api/server.js`

```javascript
app.use('/api', require('./routes/status'));
```

### 3.2 Reporting (KPIs + activity)

Fichier : `ia_admin_api/routes/reporting.js` (NOUVEAU)

```javascript
const r = require('express').Router();
r.get('/reporting', (req,res)=>{
  res.json({
    ok:true,
    kpis:{ leads:42, hot:7, tasksRunning:2 },
    activity:[{ts:Date.now(), actor:'MAX', event:'preview.check', tenant:req.ctx.tenant }]
  });
});
module.exports = r;
```

Fichier : `ia_admin_api/server.js`

```javascript
app.use('/api', require('./routes/reporting'));
```

### 3.3 Espace M.A.X. (Chat + Execution Log)

Fichier : `ia_admin_api/routes/ask.js` (NOUVEAU)

```javascript
const router = require('express').Router();
const executionLog = [];
router.post('/ask', async (req,res)=>{
  const entry = { id:Date.now().toString(), ts:Date.now(), type:'ask', payload:req.body, status:'done' };
  executionLog.push(entry);
  res.json({ ok:true, answer:"OK", logId:entry.id });
});
router.get('/execution-log', (req,res)=> res.json({ ok:true, list:executionLog.slice(-100) }));
module.exports = router;
```

Fichier : `ia_admin_api/server.js`

```javascript
app.use('/api', require('./routes/ask'));
```

### 3.4 Extensions pilotées par rôle/preview (pas de labels en dur)

Fichier : `ia_admin_api/routes/menu.js` (NOUVEAU)

```javascript
const router = require('express').Router();
router.get('/menu', (req,res)=>{
  const base = ['dashboard','automation','max','crm'];
  const extensions = ['logistique','ecommerce','coaching'];
  res.json({
    ok:true,
    tabs: base,
    extensions: (req.ctx.role==='admin' || req.ctx.preview) ? extensions : []
  });
});
module.exports = router;
```

Fichier : `ia_admin_api/server.js`

```javascript
app.use('/api', require('./routes/menu'));
```