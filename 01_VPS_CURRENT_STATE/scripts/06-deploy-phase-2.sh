#!/usr/bin/env bash
# NEXUS v1.3 · 06-deploy-phase-2.sh · Evolution + Listmonk + Postiz
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; source .env; set +a; }

echo "═══ NEXUS v1.3 · Deploy Fase 2 — Marketing ═══"

# Validar Phase 1 activa
docker ps --filter "name=nexus-n8n" --filter "status=running" --format "{{.Names}}" \
  | grep -q "nexus-n8n" || { echo "✗ Phase 1 no está corriendo. Ejecuta 05-deploy-phase-1.sh primero"; exit 1; }

# Validar compose
docker compose -f phase-2-marketing/docker-compose.yml --env-file .env config > /tmp/p2.yml \
  && echo "✓ Compose Phase 2 válido" || { echo "✗ Error en compose Phase 2"; exit 1; }

docker compose -f phase-2-marketing/docker-compose.yml --env-file .env up -d

echo "→ Verificando servicios..."
for svc in nexus-evolution nexus-listmonk nexus-postiz; do
  for i in {1..20}; do
    docker ps --filter "name=${svc}" --filter "status=running" --format "{{.Names}}" \
      | grep -q "$svc" && { echo "  ✓ $svc"; break; }
    sleep 5
    [ "$i" -eq 20 ] && echo "  ⚠ $svc no está running (verificar logs)"
  done
done

echo ""
echo "✅ FASE 2 DESPLEGADA"
docker ps --filter "name=nexus-" --format "table {{.Names}}\t{{.Status}}" | grep -E "evolution|listmonk|postiz"
echo ""
echo "URLs:"
echo "  https://wa.${DOMAIN}      — Evolution API"
echo "  https://email.${DOMAIN}   — Listmonk"
echo "  https://postiz.${DOMAIN}  — Postiz"
echo ""
echo "Acción manual requerida:"
echo "  1. Crear instancia WhatsApp en Evolution API"
echo "  2. Escanear QR con WhatsApp Business"
echo "  3. Configurar SMTP en Listmonk"
