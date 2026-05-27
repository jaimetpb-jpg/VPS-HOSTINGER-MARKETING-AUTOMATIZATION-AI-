#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# NEXUS v1.3 · 99 · Smoke Test end-to-end
# Valida que NEXUS esté completamente operativo
# ═══════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; source .env; set +a; }

PASS=0; FAIL=0; WARN=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠  $1"; WARN=$((WARN+1)); }

echo "═══════════════════════════════════════════════════════════"
echo "  NEXUS v1.3 · Smoke Test · $(date '+%Y-%m-%d %H:%M')"
echo "═══════════════════════════════════════════════════════════"

# Infra
echo ""; echo "── Infraestructura ──"
docker exec nexus-postgres pg_isready -U "${PG_ADMIN_USER}" &>/dev/null \
  && ok "Postgres responde" || fail "Postgres no responde"

redis-cli -h localhost -p 6379 -a "${REDIS_PASS}" ping 2>/dev/null | grep -q "PONG" \
  && ok "Redis ping OK" \
  || { docker exec nexus-redis redis-cli -a "${REDIS_PASS}" ping 2>/dev/null | grep -q "PONG" \
    && ok "Redis ping OK (via docker)" || fail "Redis no responde"; }

docker run --rm --network nexus-ai \
    curlimages/curl:8.10.1 -sf --max-time 5 \
    -H "api-key: ${QDRANT_KEY}" \
    "http://qdrant:6333/collections" &>/dev/null \
  && ok "Qdrant responde" || warn "Qdrant no accesible (red nexus-ai)"

# TLS y servicios web
echo ""; echo "── Servicios Web (TLS) ──"
for svc in "llm:LiteLLM" "dify:Dify" "n8n:n8n" "status:Uptime_Kuma"; do
  sub="${svc%%:*}"; name="${svc##*:}"
  code=$(curl -sk "https://${sub}.${DOMAIN}" -o /dev/null -w "%{http_code}" --max-time 10 2>/dev/null || echo "000")
  [ "$code" != "000" ] && [ "$code" != "502" ] && [ "$code" != "503" ] \
    && ok "$name (https://${sub}.${DOMAIN}) → HTTP $code" \
    || fail "$name (https://${sub}.${DOMAIN}) → HTTP $code"
done

# LiteLLM test real
echo ""; echo "── LiteLLM Chat Real ──"
LITELLM_RESP=$(curl -sk -X POST "https://llm.${DOMAIN}/v1/chat/completions" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"cheap-spanish","messages":[{"role":"user","content":"responde solo: OK"}],"max_tokens":5}' \
  --max-time 30 2>/dev/null || echo "error")

if echo "$LITELLM_RESP" | grep -q "choices"; then
  CONTENT=$(echo "$LITELLM_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['choices'][0]['message']['content'][:50])" 2>/dev/null || echo "parsed")
  ok "LiteLLM genera texto: '$CONTENT'"
elif echo "$LITELLM_RESP" | grep -q "error"; then
  fail "LiteLLM error: $(echo $LITELLM_RESP | head -c 200)"
else
  fail "LiteLLM no responde correctamente"
fi

# Fase 2 (opcional)
echo ""; echo "── Marketing Stack (Fase 2 — si desplegada) ──"
for svc in "wa:Evolution_API" "email:Listmonk" "postiz:Postiz"; do
  sub="${svc%%:*}"; name="${svc##*:}"
  code=$(curl -sk "https://${sub}.${DOMAIN}" -o /dev/null -w "%{http_code}" --max-time 8 2>/dev/null || echo "000")
  if [ "$code" = "000" ] || [ "$code" = "502" ]; then
    warn "$name no accesible (puede no estar desplegado)"
  else
    ok "$name HTTP $code"
  fi
done

# RAM y disco
echo ""; echo "── Recursos del sistema ──"
FREE_RAM_GB=$(free -g | awk '/^Mem:/ {print $7}')
DISK_FREE_GB=$(df -BG /opt | awk 'NR==2 {gsub("G","",$4); print $4}')

[ "${FREE_RAM_GB:-0}" -ge 4 ] && ok "RAM libre: ${FREE_RAM_GB}GB" || warn "RAM libre: ${FREE_RAM_GB}GB (considera reiniciar contenedores pesados)"
[ "${DISK_FREE_GB:-0}" -ge 20 ] && ok "Disco /opt libre: ${DISK_FREE_GB}GB" || warn "Disco /opt libre: ${DISK_FREE_GB}GB (considera limpiar)"

# Containers en Restarting
echo ""; echo "── Estado de containers ──"
RESTARTING=$(docker ps --filter "name=nexus-" --filter "status=restarting" --format "{{.Names}}" 2>/dev/null || echo "")
[ -z "$RESTARTING" ] && ok "Sin containers en Restarting" || fail "En Restarting: $RESTARTING"

EXITED=$(docker ps -a --filter "name=nexus-" --filter "status=exited" --format "{{.Names}}" 2>/dev/null || echo "")
[ -z "$EXITED" ] && ok "Sin containers exitados" || warn "Exitados: $EXITED"

# Resumen
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  RESULTADO: ✅ $PASS OK · ⚠ $WARN Warnings · ❌ $FAIL Fallos"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
