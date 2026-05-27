#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# NEXUS v1.3 · rollback-snapshot.sh
# Guarda snapshot del estado antes de cada fase
# Uso: bash scripts/rollback-snapshot.sh <label>
# ═══════════════════════════════════════════════════════════════
set -uo pipefail
LABEL="${1:-snapshot}"
cd "$(dirname "$0")/.."
STAMP="$(date +%F-%H%M%S)"
OUT_DIR="/opt/nexus-rollback"
mkdir -p "$OUT_DIR"

echo "=== NEXUS snapshot: ${LABEL} @ ${STAMP} ==="

# .env
[ -f ".env" ] && cp .env "${OUT_DIR}/.env.${LABEL}.${STAMP}" \
  && echo "  ✓ .env → ${OUT_DIR}/.env.${LABEL}.${STAMP}"

# Estado Docker
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' \
  > "${OUT_DIR}/containers.${LABEL}.${STAMP}.txt" 2>/dev/null \
  && echo "  ✓ containers snapshot"

docker volume ls \
  > "${OUT_DIR}/volumes.${LABEL}.${STAMP}.txt" 2>/dev/null \
  && echo "  ✓ volumes snapshot"

docker network ls \
  > "${OUT_DIR}/networks.${LABEL}.${STAMP}.txt" 2>/dev/null \
  && echo "  ✓ networks snapshot"

# RAM y disco
{ free -h; df -h /opt 2>/dev/null || df -h /; } \
  > "${OUT_DIR}/resources.${LABEL}.${STAMP}.txt" 2>/dev/null \
  && echo "  ✓ resources snapshot"

echo ""
echo "Snapshot guardado en: ${OUT_DIR}/"
echo "Para ver todos: ls ${OUT_DIR}/"
echo ""
echo "Para rollback de containers:"
echo "  docker compose -f phase-1-core/docker-compose.yml --env-file .env down"
echo "  cp ${OUT_DIR}/.env.${LABEL}.${STAMP} .env"
echo "  docker compose -f phase-1-core/docker-compose.yml --env-file .env up -d"
