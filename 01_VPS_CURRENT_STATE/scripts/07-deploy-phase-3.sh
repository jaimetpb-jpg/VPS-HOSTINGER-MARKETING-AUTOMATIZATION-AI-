#!/usr/bin/env bash
# NEXUS v1.3 · 07-deploy-phase-3.sh · Plausible + Beszel (Observabilidad)
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; source .env; set +a; }

echo "═══ NEXUS v1.3 · Deploy Fase 3 — Observabilidad ═══"

docker compose -f phase-3-observability/docker-compose.yml --env-file .env config > /tmp/p3.yml \
  && echo "✓ Compose Phase 3 válido" || { echo "✗ Error en compose Phase 3"; exit 1; }

docker compose -f phase-3-observability/docker-compose.yml --env-file .env up -d

echo "→ Verificando servicios..."
sleep 15
docker ps --filter "name=nexus-" --format "table {{.Names}}\t{{.Status}}" \
  | grep -E "plausible|beszel|clickhouse"

echo ""
echo "✅ FASE 3 DESPLEGADA"
echo "URLs:"
echo "  https://analytics.${DOMAIN} — Plausible CE"
echo ""
echo "Acción manual:"
echo "  1. Crear site ainexus.mx en Plausible"
echo "  2. Registrar Beszel agent en el dashboard"
echo "Siguiente: bash scripts/08-backup-restic.sh"
