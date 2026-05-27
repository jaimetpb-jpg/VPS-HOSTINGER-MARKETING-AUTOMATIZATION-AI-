# NEXUS SUPREME v1.3 · Instrucciones para Claude Code

## Contexto del proyecto
- **Producto:** Agencia de marketing digital con AI y agentes autónomos
- **VPS:** root@2.24.204.193 (Hostinger KVM8, 32GB RAM, 200GB SSD)
- **Repo:** github.com/jaimetpb-jpg/VPS-HOSTINGER-MARKETING-AUTOMATIZATION-AI-
- **Rama activa:** `deploy-v1.3`
- **Dominio:** verificar con `dig +short "*.ainexus.mx"` → debe ser 2.24.204.193
- **Path VPS:** `/opt/nexus`
- **SSH alias:** `nexus` (configurado en ~/.ssh/config)

## Stack completo
```
Traefik v3.1       → Reverse proxy + TLS automático
Postgres 16        → Base de datos principal (9 DBs separadas por app)
PgBouncer 1.23     → Pool de conexiones (usar postgres:5432 directo si falla)
Redis 7.4          → Cache + colas n8n
Qdrant v1.12       → Vector store (Dify lo usa para RAG)
LiteLLM v1.52      → Router de modelos AI (DeepSeek obligatorio, resto opcional)
Dify 0.13.2        → Hub de agentes y apps AI
n8n 1.70.0         → Orquestador de workflows (QUEUE mode, 2 workers)
Evolution API v2.2 → WhatsApp Business API
Listmonk v4.1      → Email marketing
Postiz v2.11.5     → Publicación social (pre-Temporal, actualizar cuando haya revenue)
Plausible CE v2.1  → Analytics web privado
Beszel 0.9.1       → Monitoreo de VPS
```

## REGLAS ESTRICTAS — No negociables

1. **Antes de cualquier comando destructivo** (rm, docker volume rm, DROP DATABASE): mostrar el comando y pedir confirmación explícita.
2. **Antes de levantar cada fase**: ejecutar `docker compose config` y confirmar que es válido.
3. **Si un servicio falla**: PARAR. No avanzar a la siguiente fase sin resolver.
4. **Postiz NO es bloqueador del MVP** — si falla, documentar y continuar.
5. **PgBouncer fallback**: si falla conexión, usar `postgres:5432` directamente.
6. **No exportar ANTHROPIC_API_KEY en el shell** — Claude Code usa `claude login`.
7. **Al finalizar cada fase**: mostrar `docker ps`, `free -h`, `df -h /opt`.

## Secuencia de deploy (Día 0 ya completado en local)

```bash
# DÍA 1 — Core AI
ssh nexus "systemctl stop apache2 nginx 2>/dev/null; ss -tlnp | grep ':80\|:443' || echo OK"
ssh nexus "cd /opt/nexus && git pull origin deploy-v1.3"
ssh nexus "cd /opt/nexus && docker compose -f phase-1-core/docker-compose.yml --env-file .env config > /tmp/p1.yml && echo COMPOSE OK"
ssh nexus "cd /opt/nexus && bash scripts/00-prepare-vps.sh"
ssh nexus "cd /opt/nexus && bash scripts/01-generate-secrets.sh"
# → Completar .env manualmente (DEEPSEEK_API_KEY, SMTP, OPERATOR_WHATSAPP)
ssh nexus "cd /opt/nexus && bash scripts/check-env-drift.sh"
ssh nexus "cd /opt/nexus && bash scripts/02-validate-secrets.sh"
ssh nexus "cd /opt/nexus && bash scripts/03-deploy-postgres-first.sh"
ssh nexus "cd /opt/nexus && bash scripts/04-init-databases.sh"
ssh nexus "cd /opt/nexus && bash scripts/05-deploy-phase-1.sh"

# DÍA 2 — Marketing
ssh nexus "cd /opt/nexus && docker compose -f phase-2-marketing/docker-compose.yml --env-file .env config > /tmp/p2.yml && echo OK"
ssh nexus "cd /opt/nexus && bash scripts/06-deploy-phase-2.sh"

# DÍA 3 — Observabilidad + Backup
ssh nexus "cd /opt/nexus && bash scripts/07-deploy-phase-3.sh"
ssh nexus "cd /opt/nexus && bash scripts/08-backup-restic.sh"
ssh nexus "cd /opt/nexus && bash scripts/99-smoke-test.sh"
```

## Comandos de emergencia

```bash
# Estado rápido
ssh nexus "docker ps --filter 'name=nexus-' --format 'table {{.Names}}\t{{.Status}}'"

# Logs de cualquier servicio
ssh nexus "docker logs nexus-SERVICIO --tail 50 --follow"

# RAM + top consumers
ssh nexus "free -h && docker stats --no-stream --format 'table {{.Container}}\t{{.MemUsage}}' | sort -k2 -r | head -10"

# Reiniciar servicio caído
ssh nexus "docker restart nexus-SERVICIO"

# Bajar fase sin borrar datos
ssh nexus "cd /opt/nexus && docker compose -f phase-1-core/docker-compose.yml --env-file .env down"

# Test LiteLLM real
ssh nexus "source /opt/nexus/.env && curl -sk -X POST https://llm.ainexus.mx/v1/chat/completions -H 'Authorization: Bearer '\$LITELLM_MASTER_KEY -H 'Content-Type: application/json' -d '{\"model\":\"cheap-spanish\",\"messages\":[{\"role\":\"user\",\"content\":\"responde: OK\"}],\"max_tokens\":5}'"

# Ver logs en vivo (tunnel para Dozzle)
ssh -L 8888:localhost:8888 nexus &  # → abrir http://localhost:8888
```

## Políticas de API keys

```
DESARROLLO (WSL2):
  claude login → Max subscription (NO API key)
  Cursor → DEEPSEEK_API_KEY (solo para autocompletado local)

PRODUCCIÓN (LiteLLM en VPS):
  DEEPSEEK_API_KEY  → OBLIGATORIO (cheap-spanish, cheap-coder)
  ANTHROPIC_API_KEY → OPCIONAL   (creative-*, claude-*)
  OPENAI_API_KEY    → OPCIONAL   (strategy-*, agent-pm)
  GEMINI_API_KEY    → OPCIONAL   (long-research-*)
```

## MVP del producto

```
Lead entra (webhook) → Dify califica → Postgres guarda → n8n orquesta
→ WhatsApp al operador (con link de aprobación único)
→ Operador aprueba/rechaza → log en Postgres
→ Seguimiento automatizado (WARM/COLD drip)

Precio: USD $500-1,500/mes por cliente
```
