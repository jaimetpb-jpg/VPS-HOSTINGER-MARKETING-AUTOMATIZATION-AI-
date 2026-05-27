# ✅ CHECKLIST DE GATE — Revisión Humana/Kimi/Grok ANTES de push

> Ejecutar estos comandos en el repo después de aplicar el overlay.
> TODOS deben pasar en verde antes de dar GO a Claude Code.

## Comandos de validación (copiar y ejecutar)

```bash
cd ~/nexus-project  # o donde tengas el repo

# 1. JSON workflows válidos
find workflows -name "*.json" -print0 | xargs -0 -I{} python3 -m json.tool "{}" > /dev/null \
  && echo "✅ JSON OK" || echo "❌ JSON BROKEN"

# 2. Scripts bash sin errores de sintaxis
bash -n scripts/*.sh && echo "✅ Scripts OK" || echo "❌ Script syntax error"

# 3. Sin SSH keys privadas
grep -rn --include="*.sh" --include="*.sql" --include="*.yml" --include="*.yaml" --include="*.json" "BEGIN OPENSSH PRIVATE KEY" . \
  && echo "❌ PRIVATE KEY EXPOSED" || echo "✅ Sin private keys"

# 4. Sin NocoBase fantasma en workflows
grep -rn "NocoBase · Save lead" workflows \
  && echo "❌ NOCOBASE GHOST" || echo "✅ Sin NocoBase"

# 5. n8n-worker tiene vars de negocio (necesita 2 ocurrencias: main+worker)
COUNT=$(grep -c "OPERATOR_WHATSAPP" phase-1-core/docker-compose.yml)
[ "$COUNT" -ge 2 ] && echo "✅ n8n-worker env vars OK ($COUNT)" || echo "❌ n8n-worker MISSING vars"

# 6. Bootstrap SQL sin DO $$ para roles
grep -n "^[[:space:]]*DO \$\$" db-init/00-bootstrap.sql \
  && echo "❌ DO blocks activos" || echo "✅ SQL sin DO blocks activos" 

# 7. Todos los workflows tienen Respond to Webhook cuando usan responseNode
python3 - << 'PYEOF'
import json, os
for f in os.listdir('workflows'):
    if not f.endswith('.json'): continue
    with open(f'workflows/{f}') as fp: wf = json.load(fp)
    webhook_mode = None
    has_respond = False
    for n in wf['nodes']:
        if n['type'] == 'n8n-nodes-base.webhook':
            webhook_mode = n['parameters'].get('responseMode')
        if n['type'] == 'n8n-nodes-base.respondToWebhook':
            has_respond = True
    if webhook_mode == 'responseNode' and not has_respond:
        print(f"❌ {f}: responseNode sin Respond node")
    else:
        print(f"✅ {f}: webhook OK")
PYEOF

# 8. Docker Compose YAML válido
docker compose -f phase-1-core/docker-compose.yml --env-file .env config > /dev/null 2>&1 \
  && echo "✅ Phase-1 YAML OK" || echo "❌ Phase-1 YAML ERROR (necesita .env)"
```

## Gate de autorización

```
[ ] Todos los checks verdes
[ ] Kimi revisó los workflows JSON (conexiones coherentes)
[ ] Grok verificó el bootstrap SQL (sintaxis PostgreSQL)
[ ] James aprobó el CLAUDE.md y las reglas de Claude Code

→ APROBADO: git add -A && git commit -m "fix: v1.3 final surgery" && git push origin deploy-v1.3
→ RECHAZADO: reportar qué falló al canal de trabajo
```

# 3-service n8n DOMAIN check
python3 -c "
import yaml
c = yaml.safe_load(open('phase-1-core/docker-compose.yml'))
errors = [s for s in ['n8n-main','n8n-worker','n8n-worker-2'] if 'DOMAIN' not in c['services'][s].get('environment',{})]
print('❌ DOMAIN falta en: '+str(errors)) if errors else print('✅ DOMAIN en 3 servicios n8n OK')
"
