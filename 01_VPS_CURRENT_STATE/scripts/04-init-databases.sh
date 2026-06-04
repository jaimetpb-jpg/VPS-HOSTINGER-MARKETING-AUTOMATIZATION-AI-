#!/usr/bin/env bash
# NEXUS v1.3 · 04-init-databases.sh · Crear DBs y usuarios (idempotente)
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; source .env; set +a; }

echo "═══ NEXUS v1.3 · Init Databases ═══"

docker exec nexus-postgres pg_isready -U "${PG_ADMIN_USER}" &>/dev/null   || { echo "✗ Postgres no está corriendo. Ejecuta 03-deploy-postgres-first.sh"; exit 1; }

echo "→ Creando usuarios y bases de datos..."
docker exec -i -e PGPASSWORD="${PG_ADMIN_PASS}" nexus-postgres psql -U "${PG_ADMIN_USER}" -d postgres   -v pg_dify_pass="${PG_DIFY_PASS}"   -v pg_n8n_pass="${PG_N8N_PASS}"   -v pg_litellm_pass="${PG_LITELLM_PASS}"   -v pg_nexus_core_pass="${PG_NEXUS_CORE_PASS}"   -v pg_listmonk_pass="${PG_LISTMONK_PASS}"   -v pg_postiz_pass="${PG_POSTIZ_PASS}"   -v pg_evolution_pass="${PG_EVOLUTION_PASS}"   -v pg_plausible_pass="${PG_PLAUSIBLE_PASS}"   < db-init/00-bootstrap.sql
echo "✓ Usuarios y DBs creados"

echo "→ Aplicando schema nexus_core..."
docker exec -i -e PGPASSWORD="${PG_ADMIN_PASS}" nexus-postgres psql -U "${PG_ADMIN_USER}" -d nexus_core   < db-init/01-nexus-core-schema.sql
echo "✓ Schema nexus_core OK"

echo "→ Verificando tablas nexus_core..."
TABLES=$(docker exec -e PGPASSWORD="${PG_ADMIN_PASS}" nexus-postgres psql -U "${PG_ADMIN_USER}" -d nexus_core -tAc "\dt" | cut -d'|' -f2 | tr -d ' ')
for t in tenants ai_task leads tutor_corrections; do
  echo "$TABLES" | grep -q "^${t}$"     && echo "  ✓ $t" || { echo "  ✗ $t FALTA"; exit 1; }
done

echo "✅ Bases de datos inicializadas"
echo "Siguiente: bash scripts/05-deploy-phase-1.sh"
