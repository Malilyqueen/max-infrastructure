#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# M.A.X. Rollback Script - Retour à la version précédente
#
# Usage:
#   ./rollback.sh              # Rollback interactif (choix de version)
#   ./rollback.sh --auto       # Rollback automatique vers N-1
#   ./rollback.sh --list       # Lister les versions disponibles
#   ./rollback.sh <version>    # Rollback vers une version spécifique
# ═══════════════════════════════════════════════════════════════════

set -e

DEPLOY_DIR="/opt/max-infrastructure"
VERSIONS_FILE="${DEPLOY_DIR}/versions.json"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

cd "$DEPLOY_DIR"

# ═══════════════════════════════════════════════════════════════════
# LISTER LES VERSIONS
# ═══════════════════════════════════════════════════════════════════
if [ "$1" = "--list" ]; then
    echo "═══════════════════════════════════════════════════"
    echo "📋 Versions disponibles:"
    echo "═══════════════════════════════════════════════════"

    if [ -f "$VERSIONS_FILE" ]; then
        jq -r '.[] | "  \(.tag) - \(.branch) - \(.timestamp)"' "$VERSIONS_FILE"
    else
        echo "  Aucune version enregistrée"
    fi

    echo ""
    echo "📋 Images Docker disponibles:"
    docker images "max-infrastructure-max-backend" --format "  {{.Tag}} - {{.CreatedAt}}" | head -10
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════
# DÉTERMINER LA VERSION CIBLE
# ═══════════════════════════════════════════════════════════════════
TARGET_VERSION=""

if [ "$1" = "--auto" ]; then
    # Rollback automatique vers l'image "previous"
    if docker images max-infrastructure-max-backend:previous -q 2>/dev/null | grep -q .; then
        TARGET_VERSION="previous"
        log "🔄 Rollback automatique vers: previous"
    else
        log "❌ Aucune version 'previous' disponible"
        exit 1
    fi
elif [ -n "$1" ]; then
    # Version spécifiée
    TARGET_VERSION="$1"
    if ! docker images "max-infrastructure-max-backend:${TARGET_VERSION}" -q 2>/dev/null | grep -q .; then
        log "❌ Version non trouvée: ${TARGET_VERSION}"
        log "   Utilisez --list pour voir les versions disponibles"
        exit 1
    fi
else
    # Interactif
    echo "═══════════════════════════════════════════════════"
    echo "📋 Versions disponibles:"
    echo "═══════════════════════════════════════════════════"
    echo "  [0] previous (N-1)"

    i=1
    if [ -f "$VERSIONS_FILE" ]; then
        while IFS= read -r version; do
            echo "  [$i] $version"
            ((i++))
        done < <(jq -r '.[].tag' "$VERSIONS_FILE" | head -5)
    fi

    echo ""
    read -p "Choisir une version (0-$((i-1))) ou entrer un tag: " CHOICE

    if [ "$CHOICE" = "0" ]; then
        TARGET_VERSION="previous"
    elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -lt "$i" ]; then
        TARGET_VERSION=$(jq -r ".[$((CHOICE-1))].tag" "$VERSIONS_FILE")
    else
        TARGET_VERSION="$CHOICE"
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# CONFIRMATION (sauf --auto)
# ═══════════════════════════════════════════════════════════════════
if [ "$1" != "--auto" ]; then
    echo ""
    echo "⚠️  ROLLBACK vers: ${TARGET_VERSION}"
    echo ""
    read -p "Confirmer ? (oui/non): " CONFIRM

    if [ "$CONFIRM" != "oui" ]; then
        log "Rollback annulé."
        exit 0
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# ROLLBACK
# ═══════════════════════════════════════════════════════════════════
log "═══════════════════════════════════════════════════"
log "🔄 ROLLBACK vers: ${TARGET_VERSION}"
log "═══════════════════════════════════════════════════"

# Sauvegarder la version actuelle comme "failed" (pour analyse)
if docker images max-infrastructure-max-backend:current -q 2>/dev/null | grep -q .; then
    docker tag max-infrastructure-max-backend:current "max-infrastructure-max-backend:failed_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
fi

# Tag la version cible comme "current"
docker tag "max-infrastructure-max-backend:${TARGET_VERSION}" "max-infrastructure-max-backend:current"

# Restart avec la nouvelle image
log "🔄 Restart containers..."
docker compose down
docker compose up -d

# Health check
log "🩺 Health check..."
sleep 10

HEALTH_OK=false
for i in {1..6}; do
    if curl -sf http://localhost:3005/api/health > /dev/null 2>&1; then
        HEALTH_OK=true
        break
    fi
    log "   Attempt $i/6 - waiting..."
    sleep 5
done

if [ "$HEALTH_OK" = false ]; then
    log "❌ Health check failed après rollback!"
    log "   Intervention manuelle requise"
    docker compose logs --tail 50 max-backend
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════
# RÉSUMÉ
# ═══════════════════════════════════════════════════════════════════
log "═══════════════════════════════════════════════════"
log "✅ ROLLBACK RÉUSSI"
log "   Version: ${TARGET_VERSION}"
log "   Health:  OK"
log "═══════════════════════════════════════════════════"

docker compose ps
