#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# NEXUS v1.3 · 02-validate-secrets.sh
# Validar secretos y .env antes del deploy
# REPARADO 28-may-2026 · Fix Kimi C1 (regex corrupto + DS_CODE undefined)
# ════════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "❌ .env no existe. Ejecutar 01-generate-secrets.sh primero."
  exit 1
fi

set -a
source .env
set +a

PASS=0; FAIL=0; WARN=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN+1)); }

echo "═══════════════════════════════════════════════════════════"
echo "  NEXUS v1.3 · Validate Secrets"
echo "═══════════════════════════════════════════════════════════"

# ─── 1. Placeholders sin reemplazar ───
echo "→ [1/8] Placeholders sin reemplazar..."
PLACEHOLDERS=$(grep -E "CAMBIAME|REEMPLAZAR|<GENERADO_|<GENERAR_" .env | grep -v "^#" || true)
if [ -n "$PLACEHOLDERS" ]; then
  fail "Hay placeholders sin reemplazar:"
  echo "$PLACEHOLDERS" | sed 's/^/      /'
else
  ok "Sin placeholders pendientes"
fi

# ─── 2. DeepSeek API key (mandatorio) ───
echo "→ [2/8] DeepSeek API key..."
if [ -z "${DEEPSEEK_API_KEY:-}" ] || [ "${DEEPSEEK_API_KEY}" = "sk-CAMBIAME" ]; then
  fail "DEEPSEEK_API_KEY no configurada (obligatoria para MVP)"
else
  DS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    https://api.deepseek.com/v1/models \
    -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" 2>/dev/null || echo "000")
  case "$DS_CODE" in
    200) ok "DeepSeek API: válida (HTTP 200)" ;;
    401) fail "DeepSeek API: key inválida (HTTP 401)" ;;
    000) warn "DeepSeek API: no se pudo verificar (timeout/sin red)" ;;
    *)   warn "DeepSeek API: respuesta inesperada (HTTP $DS_CODE)" ;;
  esac
fi

# ─── 3. API keys opcionales (warning si faltan) ───
echo "→ [3/8] API keys opcionales..."
for key in ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY; do
  val="${!key:-}"
  if [ -z "$val" ] || [ "$val" = "OPCIONAL" ]; then
    warn "$key sin configurar (opcional)"
  else
    ok "$key configurada"
  fi
done

# ─── 4. DOMAIN ───
echo "→ [4/8] DOMAIN..."
if [ -z "${DOMAIN:-}" ]; then
  fail "DOMAIN no configurado"
else
  ok "DOMAIN: $DOMAIN"
fi

# ─── 5. SMTP_PASS ───
echo "→ [5/8] SMTP credentials..."
if [ -z "${SMTP_PASS:-}" ] || [ "${SMTP_PASS}" = "re_CAMBIAME" ]; then
  fail "SMTP_PASS no configurada (obligatoria para Listmonk)"
else
  ok "SMTP_PASS configurada"
fi

# ─── 6. OPERATOR_WHATSAPP ───
echo "→ [6/8] OPERATOR_WHATSAPP..."
if [[ "${OPERATOR_WHATSAPP:-}" =~ ^521[0-9]{10}$ ]]; then
  ok "OPERATOR_WHATSAPP: formato válido (521XXXXXXXXXX)"
else
  fail "OPERATOR_WHATSAPP inválido (debe ser 521 + 10 dígitos)"
fi

# ─── 7. Postgres passwords presentes ───
echo "→ [7/8] Postgres passwords generadas..."
for var in PG_ADMIN_PASS PG_DIFY_PASS PG_N8N_PASS PG_LITELLM_PASS PG_NEXUS_CORE_PASS; do
  if [ -z "${!var:-}" ]; then
    fail "$var no generada (correr 01-generate-secrets.sh)"
  fi
done
[ "$FAIL" -eq 0 ] && ok "Todas las passwords de Postgres presentes"

# ─── 8. Longitud mínima de secretos críticos ───
echo "→ [8/8] Longitud de secretos críticos (>=24 chars)..."
SHORT=0
for var in LITELLM_MASTER_KEY N8N_ENCRYPTION_KEY DIFY_SECRET_KEY EVOLUTION_API_KEY; do
  val="${!var:-}"
  if [ "${#val}" -lt 24 ]; then
    fail "$var muy corto (${#val} chars, mínimo 24)"
    SHORT=$((SHORT+1))
  fi
done
[ "$SHORT" -eq 0 ] && ok "Todos los secretos críticos con longitud OK"

# ─── Resumen ───
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ $PASS · ❌ $FAIL · ⚠️  $WARN"
echo "═══════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo "❌ Validación FALLÓ — corregir antes de continuar"
  exit 1
fi

echo "✅ Validación OK — listo para deploy"
exit 0
