#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# M.A.X. Database Restore Script
#
# Usage:
#   ./restore.sh espocrm_20260101_120000.sql.gz
#   ./restore.sh --latest              # Restaure le dernier backup
#   ./restore.sh --list                # Liste les backups disponibles
#   ./restore.sh --from-s3 <filename>  # Télécharge depuis S3 puis restore
# ═══════════════════════════════════════════════════════════════════

set -e

BACKUP_DIR="/opt/max-infrastructure/backups"

# Scaleway S3 (optionnel)
S3_ENDPOINT="${SCW_S3_ENDPOINT:-https://s3.fr-par.scw.cloud}"
S3_BUCKET="${SCW_S3_BUCKET:-max-backups}"
S3_ACCESS_KEY="${SCW_ACCESS_KEY}"
S3_SECRET_KEY="${SCW_SECRET_KEY}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ═══════════════════════════════════════════════════════════════════
# COMMANDES
# ═══════════════════════════════════════════════════════════════════

# Lister les backups
if [ "$1" = "--list" ]; then
    echo "═══════════════════════════════════════════════════"
    echo "📋 Backups locaux disponibles:"
    echo "═══════════════════════════════════════════════════"
    ls -lhtr "$BACKUP_DIR"/espocrm_*.sql.gz 2>/dev/null || echo "Aucun backup local"

    if [ -n "$S3_ACCESS_KEY" ]; then
        echo ""
        echo "═══════════════════════════════════════════════════"
        echo "☁️  Backups S3 disponibles:"
        echo "═══════════════════════════════════════════════════"
        export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
        export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
        aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://${S3_BUCKET}/backups/" 2>/dev/null | grep "espocrm_.*sql.gz" || echo "Aucun backup S3"
    fi
    exit 0
fi

# Dernier backup
if [ "$1" = "--latest" ]; then
    BACKUP_FILE=$(ls -t "$BACKUP_DIR"/espocrm_*.sql.gz 2>/dev/null | head -1)
    if [ -z "$BACKUP_FILE" ]; then
        log "❌ Aucun backup trouvé dans $BACKUP_DIR"
        exit 1
    fi
    log "📦 Utilisation du dernier backup: $(basename "$BACKUP_FILE")"
elif [ "$1" = "--from-s3" ]; then
    # Télécharger depuis S3
    if [ -z "$2" ]; then
        log "❌ Usage: $0 --from-s3 <filename>"
        exit 1
    fi
    if [ -z "$S3_ACCESS_KEY" ]; then
        log "❌ S3 non configuré (SCW_ACCESS_KEY manquant)"
        exit 1
    fi

    export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"

    log "⬇️  Téléchargement depuis S3: $2"
    aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://${S3_BUCKET}/backups/$2" "${BACKUP_DIR}/$2"
    BACKUP_FILE="${BACKUP_DIR}/$2"
else
    # Fichier spécifié
    if [ -z "$1" ]; then
        echo "Usage: $0 <backup_file.sql.gz>"
        echo "       $0 --latest"
        echo "       $0 --list"
        echo "       $0 --from-s3 <filename>"
        exit 1
    fi

    if [ -f "$1" ]; then
        BACKUP_FILE="$1"
    elif [ -f "${BACKUP_DIR}/$1" ]; then
        BACKUP_FILE="${BACKUP_DIR}/$1"
    else
        log "❌ Fichier non trouvé: $1"
        exit 1
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# CONFIRMATION
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "⚠️  ATTENTION: Cette opération va ÉCRASER la base de données actuelle!"
echo ""
echo "   Fichier: $(basename "$BACKUP_FILE")"
echo "   Taille:  $(du -h "$BACKUP_FILE" | cut -f1)"
echo "   Date:    $(stat -c %y "$BACKUP_FILE" 2>/dev/null || stat -f %Sm "$BACKUP_FILE")"
echo ""
read -p "Continuer ? (oui/non): " CONFIRM

if [ "$CONFIRM" != "oui" ]; then
    log "Restauration annulée."
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════
# BACKUP AVANT RESTORE (sécurité)
# ═══════════════════════════════════════════════════════════════════
log "🔄 Création backup de sécurité avant restore..."
PRE_RESTORE_FILE="${BACKUP_DIR}/pre_restore_$(date +%Y%m%d_%H%M%S).sql.gz"

docker exec mariadb mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" \
    --single-transaction espocrm 2>/dev/null | gzip > "$PRE_RESTORE_FILE"

log "✅ Backup de sécurité: $(basename "$PRE_RESTORE_FILE")"

# ═══════════════════════════════════════════════════════════════════
# RESTORE
# ═══════════════════════════════════════════════════════════════════
log "📥 Restauration en cours..."

# Décompresser et importer
gunzip -c "$BACKUP_FILE" | docker exec -i mariadb mysql -u root -p"${MYSQL_ROOT_PASSWORD}" espocrm

log "✅ Restauration terminée!"

# ═══════════════════════════════════════════════════════════════════
# POST-RESTORE
# ═══════════════════════════════════════════════════════════════════
log "🔄 Rebuild EspoCRM cache..."
docker exec espocrm php bin/command rebuild

log ""
log "═══════════════════════════════════════════════════"
log "✅ RESTORE TERMINÉ AVEC SUCCÈS"
log "   Source: $(basename "$BACKUP_FILE")"
log "   Backup sécurité: $(basename "$PRE_RESTORE_FILE")"
log "═══════════════════════════════════════════════════"
