#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# M.A.X. Deploy Script avec Versioning
#
# Usage:
#   ./deploy.sh              # Deploy avec tag automatique
#   ./deploy.sh --no-tag     # Deploy sans créer de tag
#   ./deploy.sh --dry-run    # Affiche ce qui serait fait
# ═══════════════════════════════════════════════════════════════════

set -e

DEPLOY_DIR="/opt/max-infrastructure"
VERSIONS_FILE="${DEPLOY_DIR}/versions.json"
MAX_VERSIONS=5  # Garder les 5 dernières versions

# Arguments
DRY_RUN=false
NO_TAG=false
for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --no-tag) NO_TAG=true ;;
    esac
done

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

cd "$DEPLOY_DIR"

# ═══════════════════════════════════════════════════════════════════
# PRÉ-VÉRIFICATIONS
# ═══════════════════════════════════════════════════════════════════
log "═══════════════════════════════════════════════════"
log "🚀 M.A.X. Deploy"
log "═══════════════════════════════════════════════════"

if [ ! -f ".env" ]; then
    log "❌ ERROR: .env not found"
    exit 1
fi

# Git info
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)
GIT_COMMIT_FULL=$(git rev-parse HEAD)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
VERSION_TAG="${TIMESTAMP}_${GIT_COMMIT}"

log "📦 Branch: ${GIT_BRANCH}"
log "📦 Commit: ${GIT_COMMIT}"
log "📦 Version: ${VERSION_TAG}"

if [ "$DRY_RUN" = true ]; then
    log "🔍 DRY RUN - Aucune action"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════
# SAUVEGARDE VERSION ACTUELLE (avant deploy)
# ═══════════════════════════════════════════════════════════════════
log "💾 Sauvegarde version actuelle..."

CURRENT_VERSION=""
if docker images max-infrastructure-max-backend:current -q 2>/dev/null | grep -q .; then
    CURRENT_VERSION=$(docker inspect max-infrastructure-max-backend:current --format '{{index .Config.Labels "version"}}' 2>/dev/null || echo "")

    if [ -n "$CURRENT_VERSION" ] && [ "$NO_TAG" = false ]; then
        # Tag l'image actuelle comme previous
        docker tag max-infrastructure-max-backend:current "max-infrastructure-max-backend:previous" 2>/dev/null || true
        log "   Tagged current → previous"
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# GIT PULL
# ═══════════════════════════════════════════════════════════════════
log "📥 Git pull..."
git pull origin "$GIT_BRANCH"

# ═══════════════════════════════════════════════════════════════════
# BUILD & DEPLOY
# ═══════════════════════════════════════════════════════════════════
log "🔨 Building images..."

# Build avec label de version
docker compose build --build-arg VERSION="${VERSION_TAG}"

# Tag les nouvelles images
if [ "$NO_TAG" = false ]; then
    docker tag max-infrastructure-max-backend:latest "max-infrastructure-max-backend:${VERSION_TAG}"
    docker tag max-infrastructure-max-backend:latest "max-infrastructure-max-backend:current"

    # Ajouter label de version
    # Note: Les labels sont ajoutés pendant le build, pas après
fi

log "🔄 Stopping containers..."
docker compose down

log "🚀 Starting new version..."
docker compose up -d

# ═══════════════════════════════════════════════════════════════════
# HEALTH CHECK
# ═══════════════════════════════════════════════════════════════════
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
    log "❌ Health check failed! Rolling back..."
    ./scripts/rollback.sh --auto
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════
# ENREGISTRER LA VERSION
# ═══════════════════════════════════════════════════════════════════
if [ "$NO_TAG" = false ]; then
    # Créer/mettre à jour le fichier de versions
    NEW_VERSION="{\"tag\":\"${VERSION_TAG}\",\"commit\":\"${GIT_COMMIT_FULL}\",\"branch\":\"${GIT_BRANCH}\",\"timestamp\":\"$(date -Iseconds)\"}"

    if [ -f "$VERSIONS_FILE" ]; then
        # Ajouter au début et garder les N dernières
        jq --argjson new "$NEW_VERSION" \
           --argjson max "$MAX_VERSIONS" \
           '[$new] + . | .[:$max]' "$VERSIONS_FILE" > "${VERSIONS_FILE}.tmp"
        mv "${VERSIONS_FILE}.tmp" "$VERSIONS_FILE"
    else
        echo "[$NEW_VERSION]" > "$VERSIONS_FILE"
    fi

    log "📝 Version enregistrée: ${VERSION_TAG}"
fi

# ═══════════════════════════════════════════════════════════════════
# NETTOYAGE ANCIENNES IMAGES
# ═══════════════════════════════════════════════════════════════════
log "🧹 Nettoyage images orphelines..."
docker image prune -f 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════
# RÉSUMÉ
# ═══════════════════════════════════════════════════════════════════
log "═══════════════════════════════════════════════════"
log "✅ DEPLOY RÉUSSI"
log "   Version: ${VERSION_TAG}"
log "   Health:  OK"
log "═══════════════════════════════════════════════════"

docker compose ps
