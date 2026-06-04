#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# NEXUS v1.3 · pre-commit-validate.sh
# Hook automático ejecutable ANTES de cada git push
# ════════════════════════════════════════════════════════════════
#
# CONTEXTO: Kimi Swarm detectó que la auditoría visual no captura
# bugs como `status: "running"` cuando debe ser `"processing"`.
# La solución es validación EJECUTABLE, no más auditores.
#
# INSTALACIÓN:
#   ln -s ../../scripts/pre-commit-validate.sh .git/hooks/pre-push
#   chmod +x scripts/pre-commit-validate.sh .git/hooks/pre-push
#
# USO MANUAL:
#   bash scripts/pre-commit-validate.sh
#
# COMPORTAMIENTO:
#   - exit 0 → push permitido
#   - exit 1 → push bloqueado, muestra qué falló
# ════════════════════════════════════════════════════════════════

set -uo pipefail
cd "$(dirname "$0")/.."

PYTHON_BIN="python3"
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c "import sys" >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

PASS=0
FAIL=0
WARNINGS=0

ok()    { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail()  { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn()  { echo "  ⚠️  $1"; WARNINGS=$((WARNINGS+1)); }

echo "═══════════════════════════════════════════════════════════"
echo "  NEXUS v1.3 · Pre-Commit Validation Gate"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ─── 1. JSON workflows válidos ───
echo "→ Validando workflows JSON..."
if find workflows -name "*.json" -print0 2>/dev/null | \
   xargs -0 -I{} "$PYTHON_BIN" -m json.tool "{}" > /dev/null 2>&1; then
  ok "JSON workflows: parsean correctamente"
else
  fail "JSON workflow inválido — revisar workflows/*.json"
fi

# ─── 2. Bash sintaxis ───
echo "→ Validando scripts bash..."
if bash -n scripts/*.sh 2>/dev/null; then
  ok "Scripts bash: sin errores de sintaxis"
else
  fail "Script bash con error — corre 'bash -n scripts/*.sh' para ver cuál"
fi

# ─── 3. docker-compose config ───
echo "→ Validando docker-compose..."
if [ -f .env ]; then
  for phase in phase-1-core phase-2-marketing phase-3-observability; do
    if [ -f "$phase/docker-compose.yml" ]; then
      if docker compose -f "$phase/docker-compose.yml" --env-file .env config > /dev/null 2>&1; then
        ok "$phase: compose válido"
      else
        fail "$phase: compose inválido (correr 'docker compose config' para detalle)"
      fi
    fi
  done
else
  warn ".env no existe localmente — compose validation skipped (ejecutar 01-generate-secrets.sh primero)"
fi

# ─── 4. Sin private keys versionadas ───
echo "→ Buscando SSH/RSA private keys..."
if grep -rn --include="*.sh" --include="*.sql" --include="*.yml" \
   --include="*.yaml" --include="*.json" --include="*.env*" \
   --exclude-dir=.git \
   --exclude="pre-commit-validate.sh" \
   --exclude="skills-runner.sh" \
   "BEGIN OPENSSH PRIVATE KEY\|BEGIN RSA PRIVATE KEY\|BEGIN EC PRIVATE KEY\|BEGIN DSA PRIVATE KEY\|BEGIN PGP PRIVATE KEY" \
   . 2>/dev/null | grep -v "^./README.md" | grep -v "^./CHECKLIST_GATE.md"; then
  fail "PRIVATE KEY detectada — NO commitear"
else
  ok "Sin private keys versionadas"
fi

# ─── 5. Sin contraseñas hardcoded en YAML ───
echo "→ Buscando passwords hardcoded en compose..."
if grep -rnE --include="*.yml" --include="*.yaml" \
   "(password|secret|api_key)[[:space:]]*:[[:space:]]*['\"]?[a-zA-Z0-9]{8,}['\"]?[[:space:]]*$" \
   phase-1-core/ phase-2-marketing/ phase-3-observability/ 2>/dev/null | \
   grep -v "\${" | grep -v "CAMBIAME" | grep -v "<GENERADO"; then
  warn "Posible password hardcoded — verificar manualmente"
else
  ok "Sin passwords hardcoded en YAML"
fi

# ─── 6. Bootstrap SQL sin DO $$ activo ───
echo "→ Validando SQL bootstrap..."
if [ -f db-init/00-bootstrap.sql ]; then
  if grep -qn "^[[:space:]]*DO \$\$" db-init/00-bootstrap.sql 2>/dev/null; then
    fail "db-init/00-bootstrap.sql: bloque DO \$\$ activo (usar SELECT format()\\gexec)"
  else
    ok "SQL bootstrap: sin DO \$\$ activo"
  fi
fi

# ─── 7. Status fields con valores válidos en workflows ───
echo "→ Validando status fields en workflows n8n..."
INVALID_STATUS=$("$PYTHON_BIN" - << 'PYEOF' 2>/dev/null
import json, os, sys
valid_statuses = {'processing', 'done', 'error', 'queued', 'pending', 'cancelled'}
errors = []
for f in os.listdir('workflows') if os.path.isdir('workflows') else []:
    if not f.endswith('.json'): continue
    try:
        wf = json.load(open(f'workflows/{f}', encoding='utf-8'))
        wf_str = json.dumps(wf).lower()
        # Detectar bug específico que Kimi Swarm encontró:
        if "'status': 'running'" in wf_str or '"status":"running"' in wf_str.replace(' ',''):
            errors.append(f"workflows/{f}: status='running' no es valor válido (usar 'processing')")
    except Exception as e:
        errors.append(f"workflows/{f}: parse error {e}")
for e in errors: print(e)
sys.exit(1 if errors else 0)
PYEOF
)
if [ -z "$INVALID_STATUS" ]; then
  ok "Status fields: todos los valores son válidos"
else
  fail "Status fields inválidos:"
  echo "$INVALID_STATUS" | sed 's/^/      /'
fi

# ─── 8. DOMAIN en los 3 servicios n8n ───
echo "→ Validando DOMAIN en n8n services..."
DOMAIN_CHECK=$("$PYTHON_BIN" - << 'PYEOF' 2>/dev/null
import yaml, sys
try:
    c = yaml.safe_load(open('phase-1-core/docker-compose.yml', encoding='utf-8'))
    missing = []
    for svc in ['n8n-main', 'n8n-worker', 'n8n-worker-2']:
        if svc in c.get('services', {}):
            if 'DOMAIN' not in c['services'][svc].get('environment', {}):
                missing.append(svc)
    if missing:
        print(f"Falta DOMAIN en: {missing}")
        sys.exit(1)
except FileNotFoundError:
    pass
PYEOF
)
if [ -z "$DOMAIN_CHECK" ]; then
  ok "DOMAIN: presente en n8n-main, worker, worker-2"
else
  fail "$DOMAIN_CHECK"
fi

# ─── 9. DIFY_CONCIERGE_KEY en main + worker(s) ───
echo "→ Validando DIFY_CONCIERGE_KEY..."
if [ -f phase-1-core/docker-compose.yml ]; then
  CONCIERGE_COUNT=$(grep -c "DIFY_CONCIERGE_KEY" phase-1-core/docker-compose.yml 2>/dev/null || echo "0")
  if [ "$CONCIERGE_COUNT" -ge 2 ]; then
    ok "DIFY_CONCIERGE_KEY: $CONCIERGE_COUNT ocurrencias (mínimo 2)"
  else
    fail "DIFY_CONCIERGE_KEY: solo $CONCIERGE_COUNT ocurrencias (necesita 2+)"
  fi
fi

# ─── 10. Sin NocoBase fantasma ───
echo "→ Verificando ausencia de NocoBase..."
if grep -rn "NocoBase · Save lead\|nocobase" workflows/ 2>/dev/null | grep -qv "// NocoBase removed"; then
  fail "Referencia a NocoBase encontrada en workflows/"
else
  ok "Sin referencias a NocoBase"
fi

# ─── 11. Workflows con responseMode='responseNode' deben tener Respond node ───
echo "→ Validando Respond to Webhook nodes..."
RESPOND_CHECK=$("$PYTHON_BIN" - << 'PYEOF' 2>/dev/null
import json, os, sys
errors = []
if os.path.isdir('workflows'):
    for f in os.listdir('workflows'):
        if not f.endswith('.json'): continue
        wf = json.load(open(f'workflows/{f}', encoding='utf-8'))
        webhook_mode = None
        has_respond = False
        for n in wf.get('nodes', []):
            if n.get('type') == 'n8n-nodes-base.webhook':
                webhook_mode = n.get('parameters', {}).get('responseMode')
            if n.get('type') == 'n8n-nodes-base.respondToWebhook':
                has_respond = True
        if webhook_mode == 'responseNode' and not has_respond:
            errors.append(f"workflows/{f}: responseMode='responseNode' pero falta Respond node")
for e in errors: print(e)
sys.exit(1 if errors else 0)
PYEOF
)
if [ -z "$RESPOND_CHECK" ]; then
  ok "Webhooks: responseMode coherente con Respond nodes"
else
  fail "$RESPOND_CHECK"
fi

# ─── 12. .gitignore cubre archivos sensibles ───
echo "→ Validando .gitignore..."
if [ -f .gitignore ]; then
  for pattern in "*.zip" ".env" ".env.backup*" ".env.credentials-readme.txt"; do
    if grep -Fxq "${pattern}" .gitignore 2>/dev/null; then
      ok ".gitignore cubre: ${pattern}"
    else
      warn ".gitignore NO cubre: ${pattern}"
    fi
  done
else
  fail ".gitignore no existe"
fi

# ─── Resumen ───
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  RESUMEN: ✅ $PASS · ❌ $FAIL · ⚠️  $WARNINGS"
echo "═══════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ PUSH BLOQUEADO — corregir $FAIL fallo(s) antes de continuar."
  echo "   Para reintentar después de corregir: git push"
  exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
  echo ""
  echo "⚠️  Push permitido con $WARNINGS warning(s)."
  echo "   Revisar advertencias arriba — no son bloqueadores pero merecen atención."
fi

echo ""
echo "✅ TODOS LOS CHECKS PASARON — push autorizado."
exit 0
