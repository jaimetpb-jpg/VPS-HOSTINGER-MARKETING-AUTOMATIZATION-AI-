#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# NEXUS v1.3 · 02 · Validar secretos ANTES de deploy
# FIX v1.3: providers opcionales = warnings (no exit 1)
#           solo DeepSeek es obligatorio para MVP
# ═══════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; source .env; set +a; } || { echo "✗ Falta .env"; exit 1; }

PASS=0; FAIL=0; WARN=0
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠  $1 (opcional)"; WARN=$((WARN+1)); }

echo "═══════════════════════════════════════════════════════════"
echo "  NEXUS v1.3 · Validación de secretos pre-deploy"
echo "═══════════════════════════════════════════════════════════"

# ─── 1. Placeholders sin reemplazar ───
echo ""
echo "→ Verificando placeholders..."
PLACEHOLDERS=$(grep -E "CAMBIAME|REEMPLAZAR|<GENERADO_|<GENERAR_" .env | grep -v "^#" || true)
if [ -z "$PLACEHOLDERS" ]; then
  ok "Sin placeholders críticos"
else
  # Solo falla si hay placeholders en vars obligatorias
  CRITICAL=$(echo "$PLACEHOLDERS" | grep -E "DEEPSEEK_API_KEY|SMTP_PASS|PG_ADMIN_PASS|DOMAIN|OPERATOR" || true)
  if [ -n "$CRITICAL" ]; then
    fail "Placeholders en variables obligatorias:"
    echo "$CRITICAL" | head -5
  else
    warn "Hay placeholders en vars opcionales (ok para MVP):"
    echo "$PLACEHOLDERS" | head -3
  fi
fi

# ─── 2. DeepSeek API (OBLIGATORIO) ───
echo ""
echo "→ DeepSeek API (REQUERIDO para MVP)..."
DS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  https://api.deepseek.com/v1/models \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY:-}" 2>/dev/null || echo "000")
case "$DS_CODE" in
  200) ok "DeepSeek API OK — modelos cheap-spanish/cheap-coder activos" ;;
  401) fail "DeepSeek API key inválida (401) — OBLIGATORIA" ;;
  *)   fail "DeepSeek API no responde (HTTP $DS_CODE) — OBLIGATORIA" ;;
esac

# ─── 3. Anthropic API (OPCIONAL) ───
echo ""
echo "→ Anthropic API (opcional — modelos creative-*)..."
if [ -n "${ANTHROPIC_API_KEY:-}" ] && [[ "${ANTHROPIC_API_KEY}" != *"CAMBIAME"* ]]; then
  ANT_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    https://api.anthropic.com/v1/messages \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}' 2>/dev/null || echo "000")
  case "$ANT_CODE" in
    200) ok "Anthropic API OK — claude-* activos" ;;
    401) warn "Anthropic API key inválida — modelos claude-* desactivados en LiteLLM" ;;
    *)   warn "Anthropic API no responde (HTTP $ANT_CODE)" ;;
  esac
else
  warn "Anthropic API key no configurada — modelos claude-* desactivados en LiteLLM"
fi

# ─── 4. OpenAI API (OPCIONAL) ───
echo ""
echo "→ OpenAI API (opcional — modelos strategy/agent-pm)..."
if [ -n "${OPENAI_API_KEY:-}" ] && [[ "${OPENAI_API_KEY}" != *"CAMBIAME"* ]]; then
  OAI_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    https://api.openai.com/v1/models \
    -H "Authorization: Bearer ${OPENAI_API_KEY}" 2>/dev/null || echo "000")
  case "$OAI_CODE" in
    200) ok "OpenAI API OK — gpt-* activos" ;;
    401) warn "OpenAI API key inválida — modelos gpt-* desactivados" ;;
    *)   warn "OpenAI API no responde (HTTP $OAI_CODE)" ;;
  esac
else
  warn "OpenAI API key no configurada — modelos gpt-* desactivados"
fi

# ─── 5. Gemini API (OPCIONAL) ───
echo ""
echo "→ Gemini API (opcional — long-research)..."
if [ -n "${GEMINI_API_KEY:-}" ] && [[ "${GEMINI_API_KEY}" != *"CAMBIAME"* ]]; then
  GEM_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}" 2>/dev/null || echo "000")
  case "$GEM_CODE" in
    200) ok "Gemini API OK" ;;
    *)   warn "Gemini API no responde (HTTP $GEM_CODE)" ;;
  esac
else
  warn "Gemini API key no configurada — long-research desactivado"
fi

# ─── 6. SMTP ───
echo ""
echo "→ SMTP (Resend)..."
if [[ "${SMTP_PASS:-}" == "CAMBIAME" ]] || [ -z "${SMTP_PASS:-}" ]; then
  fail "SMTP_PASS no configurada — emails no funcionarán"
else
  ok "SMTP_PASS configurada (validación SMTP solo en deploy)"
fi

# ─── 7. DNS wildcard ───
echo ""
echo "→ DNS wildcard *.${DOMAIN:-ainexus.mx}..."
TEST_SUBDOMAIN="test-$$"
TEST_IP=$(dig +short "${TEST_SUBDOMAIN}.${DOMAIN:-ainexus.mx}" @1.1.1.1 2>/dev/null | tail -1 || echo "")
DOMAIN_IP=$(dig +short "${DOMAIN:-ainexus.mx}" @1.1.1.1 2>/dev/null | tail -1 || echo "")
VPS_IP="2.24.204.193"

if [ "$TEST_IP" = "$VPS_IP" ]; then
  ok "Wildcard DNS *.${DOMAIN} apunta a $VPS_IP ✓"
elif [ "$DOMAIN_IP" = "$VPS_IP" ]; then
  fail "Root domain ${DOMAIN} OK, pero wildcard *.${DOMAIN} NO apunta al VPS. Traefik subdominios fallarán. Configura A record: *.${DOMAIN} → $VPS_IP"
else
  fail "DNS no resuelve a $VPS_IP. Actual: ${DOMAIN_IP:-sin respuesta}. Configura wildcard A record."
fi

# ─── 8. Longitud de secretos críticos ───
echo ""
echo "→ Longitud de secretos críticos..."
for var in LITELLM_MASTER_KEY DIFY_SECRET_KEY N8N_ENCRYPTION_KEY PG_ADMIN_PASS; do
  val="${!var:-}"
  if [ ${#val} -lt 24 ]; then
    fail "$var demasiado corto (${#val} chars) — ejecuta 01-generate-secrets.sh"
  else
    ok "$var OK (${#val} chars)"
  fi
done

# ─── 9. Variables de negocio para n8n ───
echo ""
echo "→ Variables de negocio para workflows n8n..."
for var in OPERATOR_WHATSAPP EVOLUTION_API_KEY; do
  val="${!var:-}"
  if [ -z "$val" ] || [[ "$val" == *"CAMBIAME"* ]] || [[ "$val" == *"XXXXXXXXXX"* ]]; then
    warn "$var pendiente de configurar (workflows de WhatsApp no funcionarán hasta completar)"
  else
    ok "$var configurada"
  fi
done

# ─── Resumen ───
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  RESULTADO: ✅ $PASS · ⚠ $WARN warnings · ❌ $FAIL fallos"
echo "═══════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ $FAIL FALLOS CRÍTICOS — resolver antes de deployar"
  echo "   (los warnings se pueden resolver después del primer deploy)"
  exit 1
else
  echo ""
  echo "✅ Listo para deployar fase 1"
  [ "$WARN" -gt 0 ] && echo "   ($WARN warnings — completar API keys opcionales para funcionalidad completa)"
  echo ""
  exit 0
fi
