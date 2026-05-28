# NEXUS SUPREME v1.3 · INSTRUCCIONES PARA CODEX
## ⚠️ Este ZIP es overlay quirúrgico v1.3. Aplicar sobre el repo completo VPS-HOSTINGER-MARKETING-AUTOMATIZATION-AI-. NO es bundle standalone.

---

## Contexto
- **Repo:** `github.com/jaimetpb-jpg/VPS-HOSTINGER-MARKETING-AUTOMATIZATION-AI-`
- **Rama:** `deploy-v1.3`
- **MVP:** Lead → Dify → Postgres → WhatsApp → Aprobación → Log
- **Dominio:** ainexus.mx

## Stack activo
```
Phase 1: Traefik + Postgres + PgBouncer + Redis + Qdrant + LiteLLM + Dify + n8n (main + 2 workers) + Uptime Kuma
Phase 2: Evolution API + Listmonk + Postiz v2.11.5 (pre-Temporal)
Phase 3: Plausible CE + Beszel
```

## Fixes ya aplicados en este ZIP (NO retocar)
| # | Fix | Archivo |
|---|---|---|
| 1 | DOMAIN + DIFY_CONCIERGE_KEY en n8n-main, worker y worker-2 | `phase-1-core/docker-compose.yml` |
| 2 | n8n HA: worker-2 agregado | `phase-1-core/docker-compose.yml` |
| 3 | postgres:5432 directo Day 1 (n8n, Dify, LiteLLM) | `phase-1-core/docker-compose.yml` |
| 4 | LE staging comentado en Traefik | `phase-1-core/docker-compose.yml` |
| 5 | Volúmenes con name: nexus_XXX | Todos los composes |
| 6 | bootstrap.sql → SELECT format()\gexec, sin DO $$ para roles | `db-init/00-bootstrap.sql` |
| 7 | Schema nexus_core (tenants, ai_task, leads, tutor_corrections) | `db-init/01-nexus-core-schema.sql` |
| 8 | Respond to Webhook en todos los workflows | Todos los workflows |
| 9 | Lead Qualifier: Respond early + NocoBase eliminado | `workflows/n8n-lead-qualifier-v1.3.json` |
| 10 | Content Factory: formTrigger → Wait node | `workflows/n8n-content-factory-v1.3.json` |
| 11 | Headers Dify con = prefix | Lead qualifier + Concierge |
| 12 | Credenciales Postgres unificadas: nexus-pg-core | Todos los workflows |
| 13 | validate-secrets: DeepSeek obligatorio, resto warnings | `scripts/02-validate-secrets.sh` |
| 14 | validate-secrets detecta `<GENERADO_POR_SCRIPT>` | `scripts/02-validate-secrets.sh` |
| 15 | check-env-drift: regex `^[A-Z0-9_]+=.*` | `scripts/check-env-drift.sh` |
| 16 | Restic init automático | `scripts/08-backup-restic.sh` |
| 17 | Dify exit 1 real si no arranca | `scripts/05-deploy-phase-1.sh` |
| 18 | Qdrant smoke test via Docker network nexus-ai | `scripts/99-smoke-test.sh` |
| 19 | CHECKLIST_GATE.md sin falsos positivos | `CHECKLIST_GATE.md` |

---

## Tarea de Codex: QA + workflows nuevos

### PASO 1 — Validación completa (ejecutar primero, TODOS deben ser verde)

```bash
find workflows -name "*.json" -print0 | xargs -0 -I{} python3 -m json.tool "{}" > /dev/null && echo "✅ JSON OK"
bash -n scripts/*.sh && echo "✅ Scripts OK"
grep -rn --include="*.sh" --include="*.sql" --include="*.yml" --include="*.json" "BEGIN OPENSSH PRIVATE KEY" . && echo "❌ PRIVATE KEY" || echo "✅ Sin private keys"
grep -rn "NocoBase · Save lead" workflows && echo "❌ NOCOBASE" || echo "✅ Sin NocoBase"
grep -n "^[[:space:]]*DO \$\$" db-init/00-bootstrap.sql && echo "❌ DO activo" || echo "✅ SQL OK"
python3 -c "
import yaml; c = yaml.safe_load(open('phase-1-core/docker-compose.yml'))
errors = [svc for svc in ['n8n-main','n8n-worker','n8n-worker-2'] if 'DOMAIN' not in c['services'][svc].get('environment',{})]
print('❌ DOMAIN falta en:',errors) if errors else print('✅ DOMAIN en los 3 servicios n8n')
"
grep -c "DIFY_CONCIERGE_KEY" phase-1-core/docker-compose.yml | xargs -I{} sh -c 'test {} -ge 2 && echo "✅ CONCIERGE OK" || echo "❌ CONCIERGE FALTA"'
python3 - << 'PYEOF'
import json, os
errors = []
for f in os.listdir('workflows'):
    if not f.endswith('.json'): continue
    wf = json.load(open(f'workflows/{f}'))
    nodes = {n['name'] for n in wf['nodes']}
    for src, conn in wf['connections'].items():
        if src not in nodes: errors.append(f"{f}: orphan src '{src}'")
        for ts in conn.get('main',[]): 
            for t in ts:
                if t['node'] not in nodes: errors.append(f"{f}: orphan tgt '{t['node']}'")
    for n in wf['nodes']:
        if n['type'] == 'n8n-nodes-base.webhook':
            mode = n['parameters'].get('responseMode','')
            has_respond = any(x['type']=='n8n-nodes-base.respondToWebhook' for x in wf['nodes'])
            if mode == 'responseNode' and not has_respond:
                errors.append(f"{f}: responseNode sin Respond node")
[print(f"❌ {e}") for e in errors]
print("✅ Workflows OK" if not errors else f"❌ {len(errors)} errores")
PYEOF
```

### PASO 2 — Crear workflows nuevos (solo si validación verde)

**Reporte Diario:**
```
Crear: workflows/n8n-daily-report-v1.3.json
Trigger: Cron 0 8 * * * (8am México)
→ Query nexus_core.leads WHERE created_at > NOW()-INTERVAL '24h' GROUP BY tenant_id
→ Code: construir texto del reporte
→ HTTP POST Evolution API enviar WhatsApp a $env.OPERATOR_WHATSAPP
→ INSERT ai_task(workflow_name='daily_report', status='done')
Credencial: Nexus Postgres Core (id: nexus-pg-core)
```

**Alerta Competidores:**
```
Crear: workflows/n8n-competitor-alert-v1.3.json
Trigger: Cron 0 7 * * 1,4
→ Query tenants activos
→ HTTP GET URLs de competidores
→ HTTP POST LiteLLM cheap-spanish: analizar cambios, JSON {score, cambios, resumen}
→ IF score > 60: WhatsApp al operador via Evolution
→ INSERT ai_task(workflow_name='competitor_alert')
```

### PASO 3 — Commit

```bash
git add -A
git commit -m "feat: v1.3 QA final + new workflows + HA n8n"
git push origin deploy-v1.3
```

## Content Factory — Fase 2.5 (no productivo hasta primer cliente)
## Reglas absolutas: NO SSH · NO VPS · NO agregar servicios · Diff completo en una sola respuesta
