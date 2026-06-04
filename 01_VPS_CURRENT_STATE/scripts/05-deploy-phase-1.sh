#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# NEXUS v1.3 · 05 · Deploy FASE 1
# FIX v1.3: exit 1 si Dify no arranca (no más fallo silencioso)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; source .env; set +a; }

echo "═══════════════════════════════════════════════════════════"
echo "  NEXUS v1.3 · Deploy Fase 1 — Core AI"
echo "═══════════════════════════════════════════════════════════"

# Validar DBs
DB_COUNT=$(docker exec -e PGPASSWORD="${PG_ADMIN_PASS:-x}" nexus-postgres \
  psql -U "${PG_ADMIN_USER:-nexus_admin}" -d postgres -tAc \
  "SELECT count(*) FROM pg_database WHERE datname IN ('dify','n8n','litellm','nexus_core');" 2>/dev/null || echo "0")

if [ "$DB_COUNT" != "4" ]; then
  echo "⚠ Las DBs no están listas (encontradas: $DB_COUNT/4)"
  echo "  Ejecuta: bash scripts/04-init-databases.sh"
  exit 1
fi
echo "✓ DBs verificadas ($DB_COUNT/4)"

# Validar compose antes de levantar
echo ""
echo "→ Validando docker-compose.yml..."
docker compose -f phase-1-core/docker-compose.yml --env-file .env config > /tmp/phase1-rendered.yml 2>&1
if [ $? -ne 0 ]; then
  echo "✗ Error en docker-compose.yml. Revisar /tmp/phase1-rendered.yml"
  cat /tmp/phase1-rendered.yml | head -20
  exit 1
fi
echo "✓ Compose válido"

# Levantar
echo ""
echo "→ Levantando servicios de Fase 1..."
cd phase-1-core
docker compose --env-file ../.env up -d
cd ..

# Esperar Postgres healthcheck
echo ""
echo "→ Verificando Postgres..."
for i in {1..20}; do
  if docker exec nexus-postgres pg_isready -U "${PG_ADMIN_USER}" &>/dev/null; then
    echo "✓ Postgres responde"
    break
  fi
  sleep 3
  [ "$i" -eq 20 ] && { echo "✗ Postgres no responde"; exit 1; }
done

# Esperar Dify — con exit 1 real si falla (FIX v1.3)
echo ""
echo "→ Esperando Dify migrations (puede tardar 3-5 min en primer boot)..."
DIFY_READY=false
for i in {1..72}; do
  if docker logs nexus-dify-api 2>&1 | grep -q "Application startup complete"; then
    echo "✓ Dify listo en $((i*5))s"
    DIFY_READY=true
    break
  fi
  # Mostrar progreso cada 30s
  if [ $((i % 6)) -eq 0 ]; then
    echo "  ... $((i*5))s — $(docker logs nexus-dify-api 2>&1 | tail -1)"
  else
    echo -n "."
  fi
  sleep 5
done

if [ "$DIFY_READY" = false ]; then
  echo ""
  echo "✗ Dify NO arrancó después de 6 minutos."
  echo ""
  echo "→ Últimos 30 logs de nexus-dify-api:"
  docker logs nexus-dify-api --tail 30 2>&1
  echo ""
  echo "Causas comunes:"
  echo "  1. Migración de DB fallida → docker logs nexus-dify-api 2>&1 | grep -i 'error\|fail'"
  echo "  2. RAM insuficiente → free -h (necesita >2GB libres para Dify)"
  echo "  3. Postgres no accesible → docker exec nexus-postgres pg_isready"
  echo ""
  echo "Para reintentar: docker restart nexus-dify-api && bash scripts/05-deploy-phase-1.sh"
  exit 1
fi

# Esperar LiteLLM
echo ""
echo "→ Verificando LiteLLM..."
for i in {1..24}; do
  STATUS=$(curl -sk https://llm.${DOMAIN}/v1/models \
    -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
    -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
  if [ "$STATUS" = "200" ]; then
    echo "✓ LiteLLM OK (HTTP 200)"
    break
  fi
  sleep 5
  if [ "$i" -eq 24 ]; then
    echo ""
    echo "⚠ LiteLLM no respondió en 2 minutos."
    LITELLM_READY=false
  fi
done
if [ "${LITELLM_READY:-true}" = false ]; then
  echo "  → Logs: docker logs nexus-litellm --tail 20"
  echo "  ⚠ NO declarar Phase 1 completa hasta que LiteLLM completion responda."
fi

# Estado final
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ FASE 1 DESPLEGADA"
echo "═══════════════════════════════════════════════════════════"
docker ps --filter "name=nexus-" --format "table {{.Names}}\t{{.Status}}" | grep -v "^NAMES"
echo ""
FREE_RAM=$(free -h | awk '/^Mem:/ {print $7}')
DISK_FREE=$(df -h /opt | awk 'NR==2 {print $4}')
echo "  RAM disponible: $FREE_RAM | Disco /opt: $DISK_FREE"
echo ""
echo "URLs:"
echo "  https://traefik.${DOMAIN}   — Dashboard Traefik"
echo "  https://llm.${DOMAIN}       — LiteLLM API"
echo "  https://dify.${DOMAIN}      — Dify UI"
echo "  https://n8n.${DOMAIN}       — n8n UI"
echo "  https://status.${DOMAIN}    — Uptime Kuma"
echo ""
echo "Siguiente: bash scripts/06-deploy-phase-2.sh"
