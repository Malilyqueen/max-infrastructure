#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# M.A.X. Database Backup Script
# Dump MariaDB + Upload Scaleway Object Storage + Rotation 7 jours
#
# Usage:
#   ./backup.sh              # Backup complet
#   ./backup.sh --db-only    # Backup DB uniquement
#   ./backup.sh --no-s3      # Sans upload S3
# ═══════════════════════════════════════════════════════════════════

set -e

# Configuration
BACKUP_DIR="/opt/max-infrastructure/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${BACKUP_DIR}/backup.log"
RETENTION_DAYS=7

# Scaleway Object Storage (optionnel - configurer dans .env)
S3_ENDPOINT="${SCW_S3_ENDPOINT:-https://s3.fr-par.scw.cloud}"
S3_BUCKET="${SCW_S3_BUCKET:-max-backups}"
S3_ACCESS_KEY="${SCW_ACCESS_KEY}"
S3_SECRET_KEY="${SCW_SECRET_KEY}"

# Arguments
DB_ONLY=false
NO_S3=false
for arg in "$@"; do
    case $arg in
        --db-only) DB_ONLY=true ;;
        --no-s3) NO_S3=true ;;
    esac
done

# Fonctions de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_success() {
    log "✅ $1"
}

log_error() {
    log "❌ $1"
    # Envoyer alerte si configuré
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -s -X POST "$ALERT_WEBHOOK" -H "Content-Type: application/json" \
            -d "{\"text\":\"🚨 BACKUP FAILED: $1\"}" || true
    fi
}

# Créer le dossier de backup
mkdir -p "$BACKUP_DIR"

log "════════════════════════════════════════════════════"
log "🔄 Démarrage backup M.A.X. - $(date)"
log "════════════════════════════════════════════════════"

# ═══════════════════════════════════════════════════════════════════
# ÉTAPE 1: Dump MariaDB (EspoCRM)
# ═══════════════════════════════════════════════════════════════════
log "📦 Étape 1: Dump MariaDB..."

DB_BACKUP_FILE="espocrm_${TIMESTAMP}.sql.gz"

if docker exec mariadb mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" \
    --single-transaction \
    --routines \
    --triggers \
    --quick \
    espocrm 2>> "$LOG_FILE" | gzip > "${BACKUP_DIR}/${DB_BACKUP_FILE}"; then

    DB_SIZE=$(du -h "${BACKUP_DIR}/${DB_BACKUP_FILE}" | cut -f1)
    log_success "DB dump créé: ${DB_BACKUP_FILE} (${DB_SIZE})"
else
    log_error "Échec dump MariaDB!"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════
# ÉTAPE 2: Backup volumes Docker (si pas --db-only)
# ═══════════════════════════════════════════════════════════════════
if [ "$DB_ONLY" = false ]; then
    log "📁 Étape 2: Backup volumes Docker..."

    # EspoCRM data
    ESPO_BACKUP_FILE="espocrm_data_${TIMESTAMP}.tar.gz"
    if docker run --rm -v espocrm-data:/data -v "${BACKUP_DIR}:/backup" alpine \
        tar czf "/backup/${ESPO_BACKUP_FILE}" /data 2>> "$LOG_FILE"; then
        ESPO_SIZE=$(du -h "${BACKUP_DIR}/${ESPO_BACKUP_FILE}" | cut -f1)
        log_success "EspoCRM data: ${ESPO_BACKUP_FILE} (${ESPO_SIZE})"
    else
        log_error "Échec backup EspoCRM data"
    fi

    # MAX data (conversations, logs)
    MAX_BACKUP_FILE="max_data_${TIMESTAMP}.tar.gz"
    if docker run --rm \
        -v max-conversations:/conversations \
        -v max-logs:/logs \
        -v max-data:/data \
        -v "${BACKUP_DIR}:/backup" alpine \
        tar czf "/backup/${MAX_BACKUP_FILE}" /conversations /logs /data 2>> "$LOG_FILE"; then
        MAX_SIZE=$(du -h "${BACKUP_DIR}/${MAX_BACKUP_FILE}" | cut -f1)
        log_success "MAX data: ${MAX_BACKUP_FILE} (${MAX_SIZE})"
    else
        log_error "Échec backup MAX data"
    fi
else
    log "⏭️  Étape 2: Skip volumes (--db-only)"
fi

# ═══════════════════════════════════════════════════════════════════
# ÉTAPE 3: Upload vers Scaleway S3 (si configuré)
# ═══════════════════════════════════════════════════════════════════
if [ "$NO_S3" = false ] && [ -n "$S3_ACCESS_KEY" ] && [ -n "$S3_SECRET_KEY" ]; then
    log "☁️  Étape 3: Upload vers Scaleway S3..."

    export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"

    # Upload DB
    if aws --endpoint-url "$S3_ENDPOINT" s3 cp \
        "${BACKUP_DIR}/${DB_BACKUP_FILE}" \
        "s3://${S3_BUCKET}/backups/${DB_BACKUP_FILE}" 2>> "$LOG_FILE"; then
        log_success "S3 upload DB: s3://${S3_BUCKET}/backups/${DB_BACKUP_FILE}"
    else
        log_error "Échec upload S3 DB"
    fi

    # Upload volumes (si pas --db-only)
    if [ "$DB_ONLY" = false ]; then
        aws --endpoint-url "$S3_ENDPOINT" s3 cp \
            "${BACKUP_DIR}/${ESPO_BACKUP_FILE}" \
            "s3://${S3_BUCKET}/backups/${ESPO_BACKUP_FILE}" 2>> "$LOG_FILE" || true
        aws --endpoint-url "$S3_ENDPOINT" s3 cp \
            "${BACKUP_DIR}/${MAX_BACKUP_FILE}" \
            "s3://${S3_BUCKET}/backups/${MAX_BACKUP_FILE}" 2>> "$LOG_FILE" || true
        log_success "S3 upload volumes terminé"
    fi
else
    log "⏭️  Étape 3: Skip S3 (non configuré ou --no-s3)"
fi

# ═══════════════════════════════════════════════════════════════════
# ÉTAPE 4: Rotation des backups (7 jours)
# ═══════════════════════════════════════════════════════════════════
log "🔄 Étape 4: Rotation backups locaux (> ${RETENTION_DAYS} jours)..."

DELETED=$(find "$BACKUP_DIR" -name "*.gz" -mtime +$RETENTION_DAYS -delete -print | wc -l)
log "   Supprimé: $DELETED fichier(s)"

# Rotation S3 (si configuré)
if [ -n "$S3_ACCESS_KEY" ] && [ -n "$S3_SECRET_KEY" ]; then
    CUTOFF_DATE=$(date -d "-${RETENTION_DAYS} days" +%Y%m%d 2>/dev/null || date -v-${RETENTION_DAYS}d +%Y%m%d 2>/dev/null || echo "")
    if [ -n "$CUTOFF_DATE" ]; then
        log "   Rotation S3 (fichiers avant $CUTOFF_DATE)..."
        # Note: Pour une rotation S3 complète, configurer les lifecycle policies sur Scaleway
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# RÉSUMÉ
# ═══════════════════════════════════════════════════════════════════
log "════════════════════════════════════════════════════"
log_success "BACKUP TERMINÉ"
log "  DB:     ${DB_BACKUP_FILE} (${DB_SIZE})"
[ "$DB_ONLY" = false ] && log "  Espo:   ${ESPO_BACKUP_FILE} (${ESPO_SIZE:-N/A})"
[ "$DB_ONLY" = false ] && log "  MAX:    ${MAX_BACKUP_FILE} (${MAX_SIZE:-N/A})"
log "════════════════════════════════════════════════════"

# Fichier status pour monitoring
cat > "${BACKUP_DIR}/last_backup.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "db_file": "${DB_BACKUP_FILE}",
  "db_size": "${DB_SIZE}",
  "status": "success"
}
EOF

# Lister les backups
ls -lh "$BACKUP_DIR"/*.gz 2>/dev/null | tail -10
