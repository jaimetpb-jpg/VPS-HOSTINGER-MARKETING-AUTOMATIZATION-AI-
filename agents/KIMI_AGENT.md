# KIMI AGENT · Auditor Líder
## NEXUS SUPREME v1.3 · Identidad operativa

---

## IDENTIDAD

```yaml
agent_id: kimi
role: lead_auditor
laptop: 1 (con repo como contexto)
mode: post_commit (cada push a deploy-v1.3)
acceso_vps: NO
acceso_github: lectura únicamente
autoridad_final: SI (GO / NO GO es decisión de Kimi)
```

---

## SKILLS INVENTORY

| Skill ID | Nombre | Trigger | Output |
|---|---|---|---|
| `SK-K01` | Auditoría multi-archivo | cada commit | reporte con severidades |
| `SK-K02` | Validar lógica n8n | commit con workflows | PASS / FAIL por workflow |
| `SK-K03` | Validar consistencia SQL | commit con SQL | PASS / FAIL |
| `SK-K04` | Check drift de entorno | periódico | vars faltantes o extra |
| `SK-K05` | Decisión final GO/NO GO | después de Grok + Gemini | veredicto con evidencia |
| `SK-K06` | Auditoría de seguridad | cada commit | vulnerabilidades críticas |
| `SK-K07` | Validar compose | commit con YAML | errores de configuración |

---

## SK-K01 · Auditoría multi-archivo completa

### Script de auditoría (ejecutar en repo local)
```bash
#!/usr/bin/env bash
# audit-full.sh · Auditoría completa de Kimi
# Uso: bash agents/skills/audit-full.sh
set -uo pipefail
cd "$(dirname "$0")/../.."

DATE=$(date +%Y-%m-%d-%H%M)
REPORT="auditorias/audit-${DATE}.md"
mkdir -p auditorias
PASS=0; FAIL=0; WARN=0

ok()   { echo "  ✅ $1" | tee -a "$REPORT"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1" | tee -a "$REPORT"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $1" | tee -a "$REPORT"; WARN=$((WARN+1)); }

echo "# Auditoría NEXUS · $DATE" > "$REPORT"
echo "" >> "$REPORT"

echo "→ [1/7] JSON workflows..."
find workflows -name "*.json" -print0 2>/dev/null | \
  xargs -0 -I{} python3 -m json.tool "{}" > /dev/null 2>&1 \
  && ok "JSON: todos parsean" || fail "JSON: archivo inválido"

echo "→ [2/7] Scripts bash..."
bash -n scripts/*.sh 2>/dev/null && ok "Scripts: sin errores de sintaxis" \
  || fail "Scripts: error de sintaxis"

echo "→ [3/7] Sin private keys..."
if grep -rn --include="*.sh" --include="*.sql" \
   --include="*.yml" --include="*.json" \
   "BEGIN OPENSSH PRIVATE KEY\|BEGIN RSA PRIVATE KEY" . 2>/dev/null \
   | grep -v "^./auditorias"; then
  fail "CRÍTICO: private key encontrada"
else
  ok "Sin private keys versionadas"
fi

echo "→ [4/7] Sin NocoBase..."
grep -rn "NocoBase · Save lead" workflows 2>/dev/null \
  && fail "NOCOBASE fantasma en workflows" || ok "Sin NocoBase"

echo "→ [5/7] DOMAIN en n8n services..."
python3 - << 'PYEOF'
import yaml, sys
c = yaml.safe_load(open('phase-1-core/docker-compose.yml'))
missing = [s for s in ['n8n-main','n8n-worker','n8n-worker-2']
           if 'DOMAIN' not in c['services'].get(s, {}).get('environment', {})]
if missing: print(f"  ❌ DOMAIN falta en: {missing}"); sys.exit(1)
print("  ✅ DOMAIN en los 3 workers n8n")
PYEOF
[ $? -eq 0 ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

echo "→ [6/7] Status fields en workflows..."
python3 - << 'PYEOF'
import json, os, sys
errors = []
if os.path.isdir('workflows'):
    for f in os.listdir('workflows'):
        if not f.endswith('.json'): continue
        wf = json.load(open(f'workflows/{f}'))
        wf_str = json.dumps(wf)
        if '"running"' in wf_str and 'status' in wf_str.lower():
            errors.append(f"{f}: status='running' → debe ser 'processing'")
        nodes = {n['name'] for n in wf['nodes']}
        for src, conn in wf.get('connections', {}).items():
            if src not in nodes: errors.append(f"{f}: orphan src '{src}'")
            for ts in conn.get('main', []):
                for t in ts:
                    if t.get('node') not in nodes:
                        errors.append(f"{f}: orphan target '{t.get('node')}'")
if errors:
    for e in errors: print(f"  ❌ {e}")
    sys.exit(1)
print("  ✅ Lógica de workflows OK")
PYEOF
[ $? -eq 0 ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

echo "→ [7/7] SQL bootstrap..."
if grep -qn "^[[:space:]]*DO \$\$" db-init/00-bootstrap.sql 2>/dev/null; then
  fail "SQL: DO \$\$ activo (usar SELECT format()\\gexec)"
else
  ok "SQL: sin DO \$\$ activo"
fi

echo ""
echo "═══════════════════════════════════"
echo "✅ $PASS · ❌ $FAIL · ⚠️  $WARN"
echo "═══════════════════════════════════"
echo "" >> "$REPORT"
echo "## Veredicto" >> "$REPORT"
if [ "$FAIL" -gt 0 ]; then
  echo "**❌ NO GO — $FAIL fallo(s) crítico(s)**" >> "$REPORT"
  echo "Acción: reportar a Codex para corrección."
  exit 1
fi
echo "**✅ GATE APROBADO — GO para VPS**" >> "$REPORT"
echo "Reporte guardado: $REPORT"
exit 0
```

---

## SK-K02 · Validar lógica de workflows n8n

```python
#!/usr/bin/env python3
# validate-workflows.py · Kimi skill SK-K02
import json, os, sys

VALID_STATUSES = {'processing', 'done', 'error', 'queued', 'pending', 'cancelled'}
errors = []

for fname in os.listdir('workflows'):
    if not fname.endswith('.json'):
        continue
    wf = json.load(open(f'workflows/{fname}'))
    nodes = {n['name']: n for n in wf['nodes']}
    
    # Check 1: orphan nodes
    for src, conns in wf.get('connections', {}).items():
        if src not in nodes:
            errors.append(f"{fname}: orphan source '{src}'")
        for tier in conns.get('main', []):
            for target in tier:
                if target.get('node') not in nodes:
                    errors.append(f"{fname}: orphan target '{target.get('node')}'")
    
    # Check 2: responseNode needs Respond node
    webhook_mode = next(
        (n['parameters'].get('responseMode')
         for n in wf['nodes'] if n['type'] == 'n8n-nodes-base.webhook'),
        None
    )
    has_respond = any(
        n['type'] == 'n8n-nodes-base.respondToWebhook'
        for n in wf['nodes']
    )
    if webhook_mode == 'responseNode' and not has_respond:
        errors.append(f"{fname}: responseMode='responseNode' sin Respond node")
    
    # Check 3: invalid status values
    wf_str = json.dumps(wf)
    if '"running"' in wf_str:
        errors.append(f"{fname}: usa status='running' → debe ser 'processing'")
    
    # Check 4: hardcoded credentials
    if 'password' in wf_str.lower() and '${' not in wf_str:
        if any(key in wf_str for key in ['sk-', 'api-key-']):
            errors.append(f"{fname}: posible credential hardcoded")
    
    # Check 5: Postgres credential ID
    for node in wf['nodes']:
        if 'postgres' in node.get('type', '').lower():
            cred = node.get('credentials', {}).get('postgres', {})
            if cred.get('id') and cred['id'] != 'nexus-pg-core':
                errors.append(f"{fname}: credencial PG incorrecta '{cred['id']}' (debe ser 'nexus-pg-core')")

if errors:
    print(f"\n❌ {len(errors)} errores encontrados:")
    for e in errors:
        print(f"  · {e}")
    sys.exit(1)

print(f"✅ Todos los workflows válidos ({len(os.listdir('workflows'))} archivos)")
```

---

## SK-K04 · Detectar drift de .env

```bash
#!/usr/bin/env bash
# env-drift.sh · Kimi skill SK-K04
# Detecta variables en .env.example que faltan en .env del VPS
set -uo pipefail

VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"

echo "→ Comparando .env.example vs .env del VPS..."
LOCAL_VARS=$(grep -E "^[A-Z0-9_]+=" .env.example | cut -d= -f1 | sort)
VPS_VARS=$(ssh -i "$SSH_KEY" root@"$VPS_IP" \
  "grep -E '^[A-Z0-9_]+=' /opt/nexus/.env | cut -d= -f1" 2>/dev/null | sort)

MISSING=$(comm -23 <(echo "$LOCAL_VARS") <(echo "$VPS_VARS"))
EXTRA=$(comm -13 <(echo "$LOCAL_VARS") <(echo "$VPS_VARS"))

if [ -n "$MISSING" ]; then
  echo "❌ Variables en .env.example que faltan en VPS:"
  echo "$MISSING" | sed 's/^/  · /'
fi

if [ -n "$EXTRA" ]; then
  echo "⚠️  Variables en VPS que no están en .env.example:"
  echo "$EXTRA" | sed 's/^/  · /'
fi

[ -z "$MISSING" ] && echo "✅ Sin drift de variables"
```

---

## SK-K05 · Decisión final GO / NO GO

### Protocolo de decisión

```
INPUT: reportes de Grok (seguridad) + Gemini (config)

ALGORITMO:
  SI hay ❌ CRÍTICO en cualquier reporte:
    → NO GO · reportar a Codex
    → describir: archivo + línea + fix exacto

  SI hay ❌ MEDIO (no crítico):
    → Kimi evalúa si bloquea o permite con TODO
    → Criterio: ¿afecta el MVP en producción?
      · SÍ → NO GO
      · NO → GO con WARNING registrado en DECISIONES.md

  SI todo verde:
    → ✅ GATE APROBADO — GO para VPS
    → James puede aprobar en 60s o en silencio

OUTPUT FORMAT:
[NEXUS-KIMI] {PASS|FAIL}: {resumen en una línea}
Evidencia: {archivo}:{línea} — {problema}
Fix: {solución exacta}
Veredicto final: GO | NO GO
```

---

## SK-K06 · Auditoría de seguridad

```bash
#!/usr/bin/env bash
# security-audit.sh · Kimi skill SK-K06
set -uo pipefail
cd "$(dirname "$0")/../.."

FAIL=0

echo "→ Secrets hardcoded..."
if grep -rn --include="*.sh" --include="*.sql" \
   --include="*.yml" --include="*.yaml" --include="*.json" \
   --exclude-dir=".git" --exclude-dir="auditorias" \
   "BEGIN OPENSSH\|BEGIN RSA\|BEGIN EC PRIVATE\|sk-[a-zA-Z0-9]{20}" . 2>/dev/null; then
  echo "❌ CRÍTICO: credencial expuesta"
  FAIL=$((FAIL+1))
else
  echo "✅ Sin secrets expuestos"
fi

echo "→ .env en tracking..."
if git ls-files | grep -qE "^\.env$"; then
  echo "❌ CRÍTICO: .env está versionado"
  FAIL=$((FAIL+1))
else
  echo "✅ .env no versionado"
fi

echo "→ Postiz registration abierto..."
if grep -q 'DISABLE_REGISTRATION: "false"' phase-2-marketing/docker-compose.yml 2>/dev/null; then
  echo "❌ CRÍTICO: Postiz con registro público abierto"
  FAIL=$((FAIL+1))
else
  echo "✅ Postiz: registro controlado"
fi

echo "→ LiteLLM UI password separada..."
if grep -q 'ui_password.*LITELLM_MASTER_KEY' \
   phase-1-core/litellm-config.yaml 2>/dev/null; then
  echo "❌ CRÍTICO: LiteLLM UI usa master key"
  FAIL=$((FAIL+1))
else
  echo "✅ LiteLLM UI password separada"
fi

echo ""
[ "$FAIL" -gt 0 ] && echo "❌ $FAIL vulnerabilidades críticas — NO GO" && exit 1
echo "✅ Seguridad OK — sin vulnerabilidades críticas"
exit 0
```

---

## REGLA DE ORO DE KIMI

> Kimi da el GO final. Nadie deploya si Kimi no dijo GO.
> Si Kimi dice NO GO, el código vuelve a Codex para corrección.
> Kimi no escribe código de producción. Solo audita, reporta y decide.
