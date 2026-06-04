#!/usr/bin/env bash
# NEXUS v1.3 · 03-deploy-postgres-first.sh · Levantar solo Postgres
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; source .env; set +a; }

echo "═══ NEXUS v1.3 · Postgres First ═══"

# Validar que .env tiene PG_ADMIN_PASS
[ -z "${PG_ADMIN_PASS:-}" ] && { echo "✗ Falta PG_ADMIN_PASS en .env"; exit 1; }

# Levantar solo postgres y pgbouncer
docker compose -f phase-1-core/docker-compose.yml --env-file .env \
  up -d postgres pgbouncer

echo "→ Esperando Postgres healthcheck..."
for i in {1..30}; do
  docker exec nexus-postgres pg_isready -U "${PG_ADMIN_USER:-nexus_admin}" &>/dev/null \
    && { echo "✓ Postgres listo en $((i*3))s"; break; }
  sleep 3
  [ "$i" -eq 30 ] && { echo "✗ Postgres no arrancó"; docker logs nexus-postgres --tail 20; exit 1; }
done

echo "✅ Postgres corriendo"
echo "Siguiente: bash scripts/04-init-databases.sh"
