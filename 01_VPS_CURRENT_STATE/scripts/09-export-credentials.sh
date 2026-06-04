#!/usr/bin/env bash
# NEXUS v1.3 · 09-export-credentials.sh · Exportar credenciales para operadores
set -uo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; source .env; set +a; }

OUT="/opt/nexus-rollback/credentials-$(date +%F-%H%M%S).txt"
mkdir -p /opt/nexus-rollback
chmod 700 /opt/nexus-rollback

cat > "$OUT" << CREDS
═══════════════════════════════════════════════════════════
NEXUS SUPREME v1.3 · Credenciales de acceso
Generado: $(date '+%Y-%m-%d %H:%M:%S')
CONFIDENCIAL — No compartir
═══════════════════════════════════════════════════════════

DOMINIO: ${DOMAIN}

SERVICIOS WEB:
  LiteLLM:  https://llm.${DOMAIN}     key: ${LITELLM_MASTER_KEY}
  Dify:     https://dify.${DOMAIN}
  n8n:      https://n8n.${DOMAIN}
  Evolution:https://wa.${DOMAIN}      key: ${EVOLUTION_API_KEY}
  Listmonk: https://email.${DOMAIN}   user: ${LISTMONK_ADMIN_USER} pass: ${LISTMONK_ADMIN_PASS}
  Postiz:   https://postiz.${DOMAIN}
  Analytics:https://analytics.${DOMAIN}

BASE DE DATOS (postgres:5432):
  Admin:    ${PG_ADMIN_USER} / ${PG_ADMIN_PASS}
  nexus_core app: nexus_core_app / ${PG_NEXUS_CORE_PASS}

REDIS: pass=${REDIS_PASS}
QDRANT: key=${QDRANT_KEY}

OPERATOR_WHATSAPP: ${OPERATOR_WHATSAPP}
AINEXUS_INSTANCE:  ${AINEXUS_INSTANCE}
═══════════════════════════════════════════════════════════
CREDS

chmod 600 "$OUT"
echo "✅ Credenciales exportadas: $OUT"
echo "⚠  Archivo con permisos 600 — solo root puede leerlo"
