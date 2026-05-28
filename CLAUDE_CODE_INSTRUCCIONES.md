# NEXUS SUPREME v1.3 · INSTRUCCIONES PARA CLAUDE CODE
## ⚠️ Este ZIP es overlay quirúrgico. Aplicar sobre el repo completo antes de usarlo.

---

## Contexto
- **VPS:** root@2.24.204.193 · Hostinger KVM8 · 32GB RAM · 200GB SSD
- **SSH:** `ssh nexus` → `~/.ssh/nexus_vps_new`
- **Repo:** `github.com/jaimetpb-jpg/VPS-HOSTINGER-MARKETING-AUTOMATIZATION-AI-`  **Rama:** `deploy-v1.3`
- **Path VPS:** `/opt/nexus` · **Dominio:** `ainexus.mx`
- **MVP:** Lead → Dify → Postgres → WhatsApp → Aprobación → Log

## Stack
```
Phase 1: Traefik + Postgres + PgBouncer + Redis + Qdrant + LiteLLM + Dify + n8n (main+2workers) + Uptime Kuma
Phase 2: Evolution API + Listmonk + Postiz v2.11.5
Phase 3: Plausible CE + Beszel
```

## Reglas no negociables
1. Comando destructivo (rm, down -v, DROP): mostrar y esperar confirmación.
2. `docker compose config` antes de levantar cada fase. Si falla → PARAR.
3. Servicio falla → PARAR. No avanzar de fase.
4. No declarar éxito sin LiteLLM completion real (choices/OK).
5. No exportar `ANTHROPIC_API_KEY` en el shell.
6. No cambiar DNS desde VPS.
7. Postiz y Content Factory NO bloquean MVP.
8. PgBouncer fallback: servicios ya apuntan a postgres:5432 Day 1.
9. LE staging: descomentar la línea `caserver` en Traefik si vas a reiniciar múltiples veces el mismo día.
10. Al finalizar cada fase: `docker ps`, `free -h`, `df -h /opt`, errores pendientes.

---

## FASE 0 · Precheck básico VPS (sin depender del repo)

```bash
ssh nexus "hostname && whoami && free -h && df -h /opt || df -h /"
ssh nexus "ss -tlnp | grep -E ':80|:443' || echo 'PUERTOS LIBRES'"
ssh nexus "systemctl stop apache2 nginx 2>/dev/null || true && systemctl disable apache2 nginx 2>/dev/null || true"
dig +short "*.ainexus.mx" @1.1.1.1
# STOP si no responde 2.24.204.193
```

---

## FASE 1 · Instalar dependencias y clonar repo

```bash
ssh nexus "apt-get update && apt-get install -y git curl jq dnsutils"

# Si /opt/nexus NO existe:
ssh nexus "cd /opt && git clone https://github.com/jaimetpb-jpg/VPS-HOSTINGER-MARKETING-AUTOMATIZATION-AI-.git nexus && cd nexus && git checkout deploy-v1.3"

# Si ya existe:
ssh nexus "cd /opt/nexus && git fetch --all && git checkout deploy-v1.3 && git pull origin deploy-v1.3"

ssh nexus "chmod +x /opt/nexus/scripts/*.sh"

# Verificar sin private keys
ssh nexus "grep -rn --include='*.sh' --include='*.sql' --include='*.yml' --include='*.json' 'BEGIN OPENSSH PRIVATE KEY' /opt/nexus && echo 'ERROR: PRIVATE KEY' || echo 'OK'"

# Preflight (ahora sí, con el repo clonado)
ssh nexus "cd /opt/nexus && bash scripts/preflight-hostinger.sh"
# STOP si: RAM < 16GB · Disco < 50GB · DNS no apunta al VPS
```

---

## FASE 2 · Secrets y .env

```bash
ssh nexus "cd /opt/nexus && bash scripts/01-generate-secrets.sh"
ssh nexus "nano /opt/nexus/.env"
```

**Mínimo obligatorio:**
```env
DOMAIN=ainexus.mx
ACME_EMAIL=james@ainexus.com.mx
TZ=America/Mexico_City
OPERATOR_WHATSAPP=521XXXXXXXXXX
DEEPSEEK_API_KEY=sk-...
AINEXUS_INSTANCE=ainexus-main
SMTP_HOST=smtp.resend.com
SMTP_PORT=587
SMTP_USER=resend
SMTP_PASS=re_...
```

```bash
ssh nexus "cd /opt/nexus && bash scripts/check-env-drift.sh"
ssh nexus "cd /opt/nexus && bash scripts/02-validate-secrets.sh"
# STOP si DeepSeek, DOMAIN o SMTP_PASS fallan.
```

---

## FASE 3 · Validar Compose

```bash
ssh nexus "cd /opt/nexus && docker compose -f phase-1-core/docker-compose.yml --env-file .env config > /tmp/p1.yml && echo 'Phase 1: OK' || echo 'Phase 1: ERROR'"
# STOP si Phase 1 falla.
```

---

## FASE 4 · Deploy Core AI

```bash
ssh nexus "cd /opt/nexus && bash scripts/rollback-snapshot.sh pre-phase1"
ssh nexus "cd /opt/nexus && bash scripts/00-prepare-vps.sh"
ssh nexus "cd /opt/nexus && bash scripts/03-deploy-postgres-first.sh"
ssh nexus "cd /opt/nexus && bash scripts/04-init-databases.sh"

# Verificar schema nexus_core ANTES de levantar n8n
ssh nexus "source /opt/nexus/.env && docker exec -e PGPASSWORD=\$PG_NEXUS_CORE_PASS nexus-postgres \
  psql -U nexus_core_app -d nexus_core -c '\dt'"
# Deben existir: tenants, ai_task, leads, tutor_corrections
# Si NO existen, ejecutar:
# ssh nexus "source /opt/nexus/.env && docker exec -e PGPASSWORD=\$PG_NEXUS_CORE_PASS nexus-postgres \
#   psql -U nexus_core_app -d nexus_core -f /opt/nexus/db-init/01-nexus-core-schema.sql"

ssh nexus "cd /opt/nexus && bash scripts/05-deploy-phase-1.sh"
# Este script hace exit 1 si Dify no arranca en 6 min.
```

**Validación real — STOP si LiteLLM falla:**
```bash
ssh nexus "docker ps --filter 'name=nexus-' --format 'table {{.Names}}\t{{.Status}}'"
ssh nexus "free -h && df -h /opt"
ssh nexus "source /opt/nexus/.env && curl -sk -X POST https://llm.ainexus.mx/v1/chat/completions \
  -H 'Authorization: Bearer '\$LITELLM_MASTER_KEY \
  -H 'Content-Type: application/json' \
  -d '{\"model\":\"cheap-spanish\",\"messages\":[{\"role\":\"user\",\"content\":\"responde solo: OK\"}],\"max_tokens\":5}'"
# Debe devolver choices con "OK"

ssh nexus "curl -sk -o /dev/null -w '%{http_code}' https://dify.ainexus.mx"   # 200
ssh nexus "curl -sk -o /dev/null -w '%{http_code}' https://n8n.ainexus.mx"    # 200
```

---

## FASE 5 · Configuración manual Dify + n8n

**En Dify** (`https://dify.ainexus.mx`):
1. Settings → Model Providers → OpenAI-compatible → Base URL: `http://litellm:4000/v1` · API Key: `LITELLM_MASTER_KEY`
2. Crear App "Lead Qualifier" → copiar API key → `DIFY_LEAD_QUALIFIER_KEY`
3. Crear App "WhatsApp Concierge" → copiar API key → `DIFY_CONCIERGE_KEY`
4. Content Factory queda Fase 2.5 — no crear ahora

**Actualizar `.env` y reiniciar n8n:**
```bash
ssh nexus "nano /opt/nexus/.env"
# Completar: DIFY_LEAD_QUALIFIER_KEY=app-... y DIFY_CONCIERGE_KEY=app-...

ssh nexus "cd /opt/nexus/phase-1-core && docker compose --env-file ../.env up -d n8n-main n8n-worker n8n-worker-2"
```

**En n8n** (`https://n8n.ainexus.mx`):
1. Settings → Credentials → New Postgres: `id: nexus-pg-core` · host=postgres · port=5432 · db=nexus_core · user=nexus_core_app
2. Importar: `n8n-lead-qualifier-v1.3.json` → activar
3. Importar: `n8n-whatsapp-concierge-v1.3.json` → activar
4. NO importar Content Factory como productivo

---

## FASE 6 · Deploy Marketing

```bash
ssh nexus "cd /opt/nexus && docker compose -f phase-2-marketing/docker-compose.yml --env-file .env config > /tmp/p2.yml && echo OK"
ssh nexus "cd /opt/nexus && bash scripts/rollback-snapshot.sh pre-phase2"
ssh nexus "cd /opt/nexus && bash scripts/06-deploy-phase-2.sh"

# Crear instancia WhatsApp
ssh nexus "source /opt/nexus/.env && curl -sk -X POST https://wa.ainexus.mx/instance/create \
  -H 'apikey: '\$EVOLUTION_API_KEY \
  -H 'Content-Type: application/json' \
  -d '{\"instanceName\":\"ainexus-main\",\"qrcode\":true}'"
# Escanear QR desde WhatsApp Business
```

**Test MVP — criterio de éxito absoluto:**
```bash
ssh nexus "curl -sk -X POST https://n8n.ainexus.mx/webhook/lead-intake \
  -H 'Content-Type: application/json' \
  -d '{\"nombre\":\"Test Lead\",\"empresa\":\"ACME\",\"telefono\":\"521XXXXXXXXXX\",\"sector\":\"manufacturing\"}'"
# ✅ HTTP 200 {"ok":true}
# ✅ Lead en Postgres: docker exec nexus-postgres psql -U nexus_core_app -d nexus_core -c "SELECT * FROM leads ORDER BY created_at DESC LIMIT 1;"
# ✅ WhatsApp llega a OPERATOR_WHATSAPP
```

---

## FASE 7 · Observabilidad + Backup

```bash
ssh nexus "cd /opt/nexus && bash scripts/rollback-snapshot.sh pre-phase3"
ssh nexus "cd /opt/nexus && bash scripts/07-deploy-phase-3.sh"
ssh nexus "cd /opt/nexus && bash scripts/08-backup-restic.sh"  # requiere RESTIC_* en .env
ssh nexus "cd /opt/nexus && bash scripts/99-smoke-test.sh"
```

---

## Comandos de emergencia

```bash
# Estado
ssh nexus "docker ps --filter 'name=nexus-' --format 'table {{.Names}}\t{{.Status}}'"

# Logs
ssh nexus "docker logs nexus-SERVICIO --tail 50"

# RAM
ssh nexus "free -h && docker stats --no-stream --format 'table {{.Container}}\t{{.MemUsage}}' | sort -k2 -r | head -8"

# Reiniciar
ssh nexus "docker restart nexus-SERVICIO"

# Bajar fase sin borrar datos
ssh nexus "cd /opt/nexus && docker compose -f phase-1-core/docker-compose.yml --env-file .env down"

# Ver snapshots de rollback
ssh nexus "ls /opt/nexus-rollback/"
```

---

## Reporte obligatorio al finalizar cada fase

```
FASE X:
- Containers UP: 
- RAM libre:
- Disco /opt libre:
- LiteLLM completion: OK/FAIL
- URLs OK:
- Errores pendientes:
- Próxima acción:
```

---

*NEXUS SUPREME v1.3 · Claude Code Instructions · GO · Mayo 2026*
