#!/usr/bin/env bash
# NEXUS v1.3 · 01-generate-secrets.sh · Generar secretos y .env
# NO sobreescribe .env existente sin confirmación
set -euo pipefail
cd "$(dirname "$0")/.."

gen32()  { openssl rand -hex 16; }
gen64()  { openssl rand -hex 32; }
gen48()  { openssl rand -base64 36 | tr -d '=+/' | head -c 48; }
genkey() { openssl rand -base64 32 | tr -d '=+/'; }

echo "═══════════════════════════════════════════════════════════"
echo "  NEXUS v1.3 · Generador de secretos"
echo "═══════════════════════════════════════════════════════════"

if [ -f .env ]; then
  echo "⚠ Ya existe un archivo .env"
  echo -n "¿Sobrescribir? [s/N]: "
  read -r CONFIRM
  [[ "$CONFIRM" =~ ^[sS]$ ]] || { echo "Abortado."; exit 0; }
  cp .env ".env.backup.$(date +%F-%H%M%S)"
  echo "✓ Backup en .env.backup.*"
fi

echo "→ Generando secretos..."

cat > .env << ENVEOF
# ════════════════════════════════════════════════════════════
# NEXUS SUPREME v1.3 · .env generado por 01-generate-secrets.sh
# Generado: $(date '+%Y-%m-%d %H:%M:%S')
# ════════════════════════════════════════════════════════════

# ─── DOMINIO (EDITAR) ───
DOMAIN=ainexus.mx
ACME_EMAIL=james@ainexus.com.mx
TZ=America/Mexico_City

# ─── OPERADOR (EDITAR) ───
OPERATOR_WHATSAPP=521XXXXXXXXXX
AINEXUS_INSTANCE=ainexus-main

# ─── API KEYS (EDITAR) ───
DEEPSEEK_API_KEY=sk-CAMBIAME
ANTHROPIC_API_KEY=OPCIONAL
OPENAI_API_KEY=OPCIONAL
GEMINI_API_KEY=OPCIONAL

# ─── SMTP (EDITAR) ───
SMTP_HOST=smtp.resend.com
SMTP_PORT=587
SMTP_USER=resend
SMTP_PASS=re_CAMBIAME
SMTP_FROM=noreply@ainexus.mx

# ─── DIFY KEYS (completar después de configurar Dify UI) ───
DIFY_API_KEY=CAMBIAME
DIFY_LEAD_QUALIFIER_KEY=CAMBIAME
DIFY_CONCIERGE_KEY=CAMBIAME
POSTIZ_API_KEY=CAMBIAME

# ─── POSTGRES ───────────────────────────────────────────────
PG_ADMIN_USER=nexus_admin
PG_ADMIN_PASS=$(gen32)
PG_DIFY_PASS=$(gen32)
PG_N8N_PASS=$(gen32)
PG_LITELLM_PASS=$(gen32)
PG_NEXUS_CORE_PASS=$(gen32)
PG_LISTMONK_PASS=$(gen32)
PG_POSTIZ_PASS=$(gen32)
PG_EVOLUTION_PASS=$(gen32)
PG_PLAUSIBLE_PASS=$(gen32)

# ─── REDIS ──────────────────────────────────────────────────
REDIS_PASS=$(gen32)

# ─── QDRANT ─────────────────────────────────────────────────
QDRANT_KEY=$(gen32)

# ─── SERVICIOS ──────────────────────────────────────────────
DIFY_SECRET_KEY=$(gen48)
LITELLM_MASTER_KEY=sk-nexus-$(gen32)
LITELLM_UI_PASSWORD=$(gen32)
N8N_ENCRYPTION_KEY=$(gen32)
N8N_USER_MGMT_JWT_SECRET=$(gen64)
EVOLUTION_API_KEY=$(gen32)
LISTMONK_ADMIN_USER=admin
LISTMONK_ADMIN_PASS=$(gen32)
POSTIZ_JWT_SECRET=$(gen64)
PLAUSIBLE_SECRET_KEY=$(gen64)
PLAUSIBLE_TOTP_KEY=$(gen48)
BESZEL_AGENT_KEY=$(gen32)
ENVEOF

# ─── htpasswd para Traefik dashboard ───
if command -v htpasswd &>/dev/null; then
  mkdir -p configs
  TRAEFIK_PASS=$(gen32)
  HASHED=$(htpasswd -nbB admin "$TRAEFIK_PASS")
  cat > configs/traefik-basic-auth.yml << TRAEFIKEOF
http:
  middlewares:
    traefik-auth:
      basicAuth:
        users:
          - "${HASHED}"
TRAEFIKEOF
  echo "  Traefik admin pass: $TRAEFIK_PASS" >> .env.credentials-readme.txt
  echo "✓ configs/traefik-basic-auth.yml generado"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ .env generado"
echo "  ⚠  EDITAR ahora:"
echo "     DOMAIN · ACME_EMAIL · OPERATOR_WHATSAPP"
echo "     DEEPSEEK_API_KEY · SMTP_PASS"
echo "═══════════════════════════════════════════════════════════"
echo "Siguiente: nano .env  →  bash scripts/02-validate-secrets.sh"
