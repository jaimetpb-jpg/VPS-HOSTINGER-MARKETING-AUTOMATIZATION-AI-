# NEXUS SUPREME v1.3 · QUICKSTART OPERATIVO
## Arranque real desde 0 hasta MVP en producción

---

## 0. ESTADO ACTUAL (28 mayo 2026)

- ✅ Repo limpio en GitHub deploy-v1.3 (commit `6e66e88`)
- ✅ 14 checks de gate aprobados por Kimi y Grok
- ✅ Reglas del equipo Multi-AI consolidadas en `NEXUS_AI_TEAM_RULES.md`
- ✅ Pre-commit hooks listos en `scripts/pre-commit-validate.sh`
- ⏳ Primer deploy en VPS: PENDIENTE
- ⏳ MVP Lead → WhatsApp: PENDIENTE

---

## 1. ARRANQUE — DÍA 0 (3 AIs activas)

> Lección aprendida: activar 6 AIs simultáneas el Día 0 genera batidero.
> Confirmado por 5 de 6 evaluaciones independientes.

### Setup (15 min)

**Laptop 1 (principal):**
```bash
cd ~/nexus-project
git pull origin deploy-v1.3

# Verificar SSH al VPS
ssh root@2.24.204.193 -i ~/.ssh/nexus_vps_new "hostname"
# Si responde → continuar.
# Si error → revisar ruta de la llave SSH primero.
```

**Laptop 2 (auditoría):**
```bash
cd ~/nexus-project
git pull origin deploy-v1.3
# Mantener Kimi Code activo con el repo como contexto.
```

---

## 2. PIPELINE DEL DÍA 0 — hora por hora

### Hora 0:00 — Codex limpia repo local
**AI activa:** Codex en Laptop 1.

```bash
# Codex ejecuta pre-commit validation antes de cualquier push:
bash scripts/pre-commit-validate.sh

# Si todo verde → continúa.
# Si rojo → corrige y reintenta.
```

**Gate de salida:** ✅ 12/12 checks verdes en pre-commit.

---

### Hora 0:30 — Kimi audita commit en GitHub
**AI activa:** Kimi Code en Laptop 2 con repo como contexto.

Prompt para Kimi:
```
Audita el último commit en rama deploy-v1.3.
Verifica los 14 checks de CHECKLIST_GATE.md.
Reporta SOLO ❌ con archivo:línea + fix.
Si todo OK → "✅ GATE APROBADO — GO para VPS"
```

**Gate de salida:** Kimi responde "GATE APROBADO".

---

### Hora 1:00 — Claude Code ejecuta deploy en VPS
**AI activa:** Claude Code en Laptop 1 con SSH al VPS.

Prompt para Claude Code:
```
Lee CLAUDE_CODE_INSTRUCCIONES.md y ejecuta Fase 0 → Fase 1 → Fase 2.
SSH: ssh root@2.24.204.193 -i ~/.ssh/nexus_vps_new
Path VPS: /opt/nexus · Branch: deploy-v1.3

Reporta output completo de cada comando.
STOP si DNS no es 2.24.204.193, si preflight falla, o si Phase 1 no levanta.
```

**Gates intermedios:**
- Fase 0 verde → continúa
- Fase 1 verde + LiteLLM completion real "OK" → continúa
- Si algo rojo → STOP, reporta logs.

**Gate de salida:** Phase 1 con todos los containers UP + LiteLLM funcionando.

---

### Hora 3:00 — Configuración manual de James (Dify + n8n)

Tareas que James hace en la UI (no las AIs):
1. **Dify UI** (`https://dify.ainexus.mx`):
   - Settings → Model Provider → OpenAI compatible: `http://litellm:4000/v1` + `LITELLM_MASTER_KEY`
   - Crear app "Lead Qualifier" → copiar API key → guardar como `DIFY_LEAD_QUALIFIER_KEY`
   - Crear app "WhatsApp Concierge" → copiar API key → `DIFY_CONCIERGE_KEY`

2. Editar `.env` con las 2 keys de Dify:
   ```bash
   ssh root@2.24.204.193 "nano /opt/nexus/.env"
   ```

3. Reiniciar n8n:
   ```bash
   ssh root@2.24.204.193 "cd /opt/nexus/phase-1-core && docker compose --env-file ../.env up -d n8n-main n8n-worker n8n-worker-2"
   ```

4. **n8n UI** (`https://n8n.ainexus.mx`):
   - Credentials → New Postgres: `id: nexus-pg-core`
   - Importar `n8n-lead-qualifier-v1.3.json` → activar
   - Importar `n8n-whatsapp-concierge-v1.3.json` → activar

**Gate de salida:** ambos workflows activos en n8n.

---

### Hora 4:00 — Claude Code ejecuta Phase 2 (Marketing)

Prompt:
```
Ejecuta Fase 2 (Evolution + Listmonk + Postiz).
Después: ssh root@2.24.204.193 "source /opt/nexus/.env && curl -sk -X POST https://wa.ainexus.mx/instance/create -H 'apikey: '$EVOLUTION_API_KEY -H 'Content-Type: application/json' -d '{\"instanceName\":\"ainexus-main\",\"qrcode\":true}'"

Reporta QR para que James lo escanee con WhatsApp Business.
```

**Gate de salida:** Evolution API up + QR escaneado + instancia activa.

---

### Hora 4:30 — Test MVP end-to-end

```bash
curl -sk -X POST https://n8n.ainexus.mx/webhook/lead-intake \
  -H 'Content-Type: application/json' \
  -d '{"nombre":"Test","empresa":"ACME","telefono":"521XXXXXXXXXX","sector":"manufacturing"}'
```

**Validaciones del MVP:**
- ✅ HTTP 200 con `{"ok":true}`
- ✅ Lead en Postgres: `docker exec nexus-postgres psql -U nexus_core_app -d nexus_core -c "SELECT * FROM leads ORDER BY created_at DESC LIMIT 1;"`
- ✅ WhatsApp llega a `OPERATOR_WHATSAPP`

**Si las 3 validaciones pasan → 🎉 MVP ACTIVO.**

---

## 3. ARRANQUE — DÍA 2 (sumar Gemini + Grok)

Solo cuando MVP esté estable 24h sin caídas:

### Gemini CLI (Laptop 2)
**Rol:** diagnóstico rápido de logs. Activación bajo demanda.

```bash
# Cuando Claude reporte un error en un container:
gemini -p "$(ssh root@2.24.204.193 'docker logs nexus-SERVICIO --tail 80 2>&1')" \
  "Causa raíz + fix exacto en 3 bullets. Sin preámbulo."
```

### Grok CLI (Laptop 2)
**Rol:** segunda opinión cuando Codex y Kimi se contradicen sin evidencia.

```bash
# Cuando hay empate técnico:
grok "Codex dice X, Kimi dice Y, evidencia: [pegar diff]. Tu veredicto técnico con justificación. Sin asumir lealtad."
```

---

## 4. ARRANQUE — DÍA 7 (sumar Manus + Cursor)

Solo cuando hay primer cliente real en onboarding:

### Manus
**Rol:** research comercial asíncrono. NO toca código.

Tareas asignadas:
- Research de competidores en Torreón/Monterrey
- Onboarding del primer cliente (propuesta + SOW)
- Pruebas A/B de prompts de Dify Lead Qualifier

### Cursor + DeepSeek
**Rol:** edición inline rápida en local. Solo cuando James edita manualmente.

---

## 5. COMANDOS DE EMERGENCIA

```bash
# Estado completo del sistema:
ssh root@2.24.204.193 "docker ps --filter 'name=nexus-' --format 'table {{.Names}}\t{{.Status}}'"

# RAM y disco:
ssh root@2.24.204.193 "free -h && df -h /opt"

# Logs de un servicio:
ssh root@2.24.204.193 "docker logs nexus-SERVICIO --tail 50"

# LiteLLM completion test:
ssh root@2.24.204.193 "source /opt/nexus/.env && curl -sk -X POST https://llm.ainexus.mx/v1/chat/completions -H 'Authorization: Bearer '\$LITELLM_MASTER_KEY -H 'Content-Type: application/json' -d '{\"model\":\"cheap-spanish\",\"messages\":[{\"role\":\"user\",\"content\":\"OK\"}]}'"

# Reiniciar un servicio:
ssh root@2.24.204.193 "docker restart nexus-SERVICIO"

# Ver snapshots de rollback:
ssh root@2.24.204.193 "ls /opt/nexus-rollback/"
```

---

## 6. SEÑALES DE ALERTA — cuándo James interviene

🚨 **Inmediato:**
- RAM > 90% por más de 5 min
- 3+ containers caídos simultáneos
- LiteLLM error > 10 min
- Kimi reporta "CRITICAL"
- WhatsApp ban risk

⚠️ **Revisar pronto:**
- RAM > 85%
- Disco > 85%
- Un container caído
- Latencia API > 5s

ℹ️ **Informativo (no intervenir):**
- Reportes periódicos de Grok
- Optimizaciones propuestas por Gemini
- Auditorías de Kimi (PASS)
- Smoke tests verdes

---

## 7. CHECKPOINTS DIARIOS

Cada día James verifica:

```
[ ] Containers UP: docker ps · 100% running
[ ] RAM libre > 25%
[ ] Disco /opt libre > 30%
[ ] LiteLLM completion: OK
[ ] URLs respondiendo 200: dify, n8n, llm
[ ] Lead test funcionando end-to-end
[ ] Errores pendientes en GitHub Issues: 0 críticos
[ ] Próxima acción definida
```

---

## 8. ROADMAP A 30 DÍAS

```
Semana 1 (Día 1-7)   → MVP estable + primer lead real procesado
Semana 2 (Día 8-14)  → Backups Restic + multi-tenant básico
Semana 3 (Día 15-21) → Content Factory + Postiz productivos
Semana 4 (Día 22-30) → Primer cliente externo facturando
```

---

*QUICKSTART v2.0 · 28 mayo 2026 · Trabajo en equipo > ego individual*
