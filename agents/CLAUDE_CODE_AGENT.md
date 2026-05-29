# CLAUDE CODE AGENT · Ejecutor VPS
## NEXUS SUPREME v1.3 · Identidad operativa

---

## IDENTIDAD

```yaml
agent_id: claude_code
role: vps_executor
laptop: 1
mode: post_gate (después de GO de Kimi + James)
acceso_vps: SI — root SSH completo
acceso_github: SI (git pull en VPS)
autoridad_final: NO en código · SI en operaciones de VPS
nunca_hace: editar código local (eso es Codex)
```

---

## SKILLS INVENTORY

| Skill ID | Nombre | Trigger | Output |
|---|---|---|---|
| `SK-CC01` | Preflight VPS | inicio de deploy | estado del VPS |
| `SK-CC02` | Sincronizar repo | antes de cada fase | deploy-v1.3 en VPS |
| `SK-CC03` | Validar compose antes de deploy | antes de cada fase | PASS / FAIL |
| `SK-CC04` | Deploy fase a fase | GO de Kimi + James | servicios UP |
| `SK-CC05` | Smoke test real | post-deploy | validación con curl real |
| `SK-CC06` | Rollback a snapshot | si deploy falla | restaurar estado anterior |
| `SK-CC07` | Diagnóstico en vivo | si fase falla | logs + causa raíz |
| `SK-CC08` | Configuración manual Dify/n8n | después de Phase 1 | servicios configurados |

---

## SK-CC01 · Preflight VPS

```bash
#!/usr/bin/env bash
# cc-preflight.sh · Claude Code skill SK-CC01
# Ejecutar ANTES de cualquier deploy
set -uo pipefail

VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"

echo "═══ CLAUDE CODE · VPS Preflight ═══"

FAIL=0

# 1. Conectividad SSH
echo "→ SSH conectividad..."
ssh -i "$SSH_KEY" -o ConnectTimeout=10 root@"$VPS_IP" "echo OK" 2>/dev/null \
  && echo "  ✅ SSH OK" || { echo "  ❌ SSH falla"; exit 1; }

# 2. RAM disponible
echo "→ RAM..."
RAM_FREE=$(ssh -i "$SSH_KEY" root@"$VPS_IP" "free -m | awk '/^Mem:/{print \$7}'")
if [ "${RAM_FREE:-0}" -lt 4096 ]; then
  echo "  ⚠️  RAM libre: ${RAM_FREE}MB — bajo (mínimo recomendado: 4GB)"
else
  echo "  ✅ RAM libre: ${RAM_FREE}MB"
fi

# 3. Disco disponible en /opt
echo "→ Disco /opt..."
DISK_FREE=$(ssh -i "$SSH_KEY" root@"$VPS_IP" "df -m /opt | awk 'NR==2{print \$4}'")
if [ "${DISK_FREE:-0}" -lt 20480 ]; then
  echo "  ❌ Disco libre: ${DISK_FREE}MB — insuficiente (mínimo: 20GB)"; FAIL=$((FAIL+1))
else
  echo "  ✅ Disco libre: ${DISK_FREE}MB"
fi

# 4. DNS wildcard
echo "→ DNS wildcard ainexus.mx..."
DNS_RESULT=$(dig +short "test-nexus.ainexus.mx" @1.1.1.1 2>/dev/null | tail -1)
if [ "$DNS_RESULT" = "2.24.204.193" ]; then
  echo "  ✅ DNS wildcard → $DNS_RESULT"
else
  echo "  ❌ DNS falla: resuelve '$DNS_RESULT' (esperado: 2.24.204.193)"; FAIL=$((FAIL+1))
fi

# 5. Puertos 80/443 libres
echo "→ Puertos 80/443..."
PORTS=$(ssh -i "$SSH_KEY" root@"$VPS_IP" \
  "ss -tlnp | grep -E ':80 |:443 ' | grep -v docker || echo 'LIBRES'")
echo "  $PORTS"

# 6. Docker disponible
echo "→ Docker..."
DOCKER_VER=$(ssh -i "$SSH_KEY" root@"$VPS_IP" "docker --version 2>/dev/null")
[ -n "$DOCKER_VER" ] && echo "  ✅ $DOCKER_VER" || { echo "  ❌ Docker no instalado"; FAIL=$((FAIL+1)); }

echo ""
[ "$FAIL" -gt 0 ] && echo "❌ Preflight FAIL — $FAIL problemas. STOP." && exit 1
echo "✅ Preflight OK — listo para deploy"
exit 0
```

---

## SK-CC02 · Sincronizar repo en VPS

```bash
#!/usr/bin/env bash
# cc-sync-repo.sh · Claude Code skill SK-CC02
set -uo pipefail

VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"
NEXUS_PATH="/opt/nexus"
BRANCH="deploy-v1.3"
REPO="https://github.com/jaimetpb-jpg/VPS-HOSTINGER-MARKETING-AUTOMATIZATION-AI-.git"

echo "═══ CLAUDE CODE · Repo Sync ═══"

ssh -i "$SSH_KEY" root@"$VPS_IP" << ENDSSH
set -euo pipefail

if [ ! -d "$NEXUS_PATH/.git" ]; then
  echo "→ Clonando repo por primera vez..."
  cd /opt
  git clone "$REPO" nexus
  cd nexus
  git checkout "$BRANCH"
else
  echo "→ Actualizando repo existente..."
  cd "$NEXUS_PATH"
  git fetch --all
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
fi

echo "✅ Repo en commit: \$(git rev-parse --short HEAD)"
echo "✅ Archivos: \$(find . -name '*.sh' | wc -l) scripts, \$(find workflows -name '*.json' 2>/dev/null | wc -l) workflows"
ENDSSH

echo ""
echo "✅ Repo sincronizado en VPS"
```

---

## SK-CC03 · Validar compose antes de deploy

```bash
#!/usr/bin/env bash
# cc-validate-compose.sh · Claude Code skill SK-CC03
set -uo pipefail

VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"

echo "═══ CLAUDE CODE · Pre-deploy Compose Validation ═══"

FAIL=0

ssh -i "$SSH_KEY" root@"$VPS_IP" << 'ENDSSH'
set -uo pipefail
cd /opt/nexus

[ ! -f .env ] && { echo "❌ .env no existe — ejecutar 01-generate-secrets.sh"; exit 1; }

for phase in phase-1-core phase-2-marketing phase-3-observability; do
  [ ! -f "$phase/docker-compose.yml" ] && continue
  echo "→ Validando $phase..."
  docker compose -f "$phase/docker-compose.yml" --env-file .env config > /tmp/validate-$phase.yml 2>&1 \
    && echo "  ✅ $phase: compose válido" \
    || { echo "  ❌ $phase: compose INVÁLIDO — revisar antes de continuar"; cat /tmp/validate-$phase.yml; exit 1; }
done
ENDSSH

[ $? -ne 0 ] && FAIL=$((FAIL+1))

[ "$FAIL" -gt 0 ] && echo "❌ Compose inválido — NO ejecutar deploy" && exit 1
echo "✅ Compose válido — OK para deploy"
```

---

## SK-CC04 · Deploy fase a fase

```bash
#!/usr/bin/env bash
# cc-deploy.sh · Claude Code skill SK-CC04
# Uso: bash cc-deploy.sh [1|2|3|all]
set -uo pipefail

VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"
PHASE="${1:-1}"

echo "═══ CLAUDE CODE · Deploy Phase $PHASE ═══"

deploy_phase() {
  local phase=$1
  local script="0${phase}-deploy-phase-${phase}.sh"
  
  echo "→ Tomando snapshot pre-phase${phase}..."
  ssh -i "$SSH_KEY" root@"$VPS_IP" \
    "cd /opt/nexus && bash scripts/rollback-snapshot.sh pre-phase${phase}"
  
  echo "→ Ejecutando $script..."
  ssh -i "$SSH_KEY" root@"$VPS_IP" \
    "cd /opt/nexus && bash scripts/${script}"
  
  local exit_code=$?
  
  if [ $exit_code -ne 0 ]; then
    echo "❌ Phase $phase FALLÓ (exit $exit_code)"
    echo "→ Ejecutar diagnóstico: bash cc-diagnose.sh"
    echo "→ Para rollback: bash cc-rollback.sh pre-phase${phase}"
    exit 1
  fi
  
  echo "✅ Phase $phase completada"
}

case "$PHASE" in
  "1")
    # Preparar VPS
    ssh -i "$SSH_KEY" root@"$VPS_IP" "cd /opt/nexus && bash scripts/00-prepare-vps.sh"
    # Secrets
    ssh -i "$SSH_KEY" root@"$VPS_IP" "cd /opt/nexus && bash scripts/01-generate-secrets.sh"
    echo "⏸  Editar .env en el VPS con API keys reales antes de continuar"
    echo "   ssh root@$VPS_IP 'nano /opt/nexus/.env'"
    read -p "¿.env editado? [s/N]: " confirm
    [[ "$confirm" =~ ^[sS]$ ]] || { echo "Abortado."; exit 0; }
    # Validar secrets
    ssh -i "$SSH_KEY" root@"$VPS_IP" "cd /opt/nexus && bash scripts/02-validate-secrets.sh"
    # Postgres first
    ssh -i "$SSH_KEY" root@"$VPS_IP" "cd /opt/nexus && bash scripts/03-deploy-postgres-first.sh"
    # Init databases
    ssh -i "$SSH_KEY" root@"$VPS_IP" "cd /opt/nexus && bash scripts/04-init-databases.sh"
    # Phase 1 completa
    deploy_phase 1
    ;;
  "2")
    deploy_phase 2
    ;;
  "3")
    deploy_phase 3
    ;;
  "all")
    for p in 1 2 3; do deploy_phase "$p"; done
    ;;
esac
```

---

## SK-CC05 · Smoke test real

```bash
#!/usr/bin/env bash
# cc-smoke-test.sh · Claude Code skill SK-CC05
# REGLA: Sin curl real = No hay GO. Nunca asumir que funciona.
set -uo pipefail

VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"

echo "═══ CLAUDE CODE · Smoke Test Real ═══"
FAIL=0

ssh -i "$SSH_KEY" root@"$VPS_IP" << 'ENDSSH'
set -uo pipefail
cd /opt/nexus
source .env 2>/dev/null || true

check_url() {
  local url="$1"
  local expected="${2:-200}"
  local code
  code=$(curl -sk -o /dev/null -w "%{http_code}" "$url" --max-time 10)
  if [ "$code" = "$expected" ]; then
    echo "  ✅ $url → $code"
    return 0
  else
    echo "  ❌ $url → $code (esperado: $expected)"
    return 1
  fi
}

FAIL=0

echo "→ URLs de servicios..."
check_url "https://dify.ainexus.mx" "200" || FAIL=$((FAIL+1))
check_url "https://n8n.ainexus.mx" "200" || FAIL=$((FAIL+1))
check_url "https://llm.ainexus.mx/health" "200" || FAIL=$((FAIL+1))
check_url "https://uptime.ainexus.mx" "200" || FAIL=$((FAIL+1))

echo "→ LiteLLM completion real..."
LITELLM_RESPONSE=$(curl -sk -X POST "https://llm.ainexus.mx/v1/chat/completions" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"cheap-spanish","messages":[{"role":"user","content":"responde solo: OK"}],"max_tokens":5}' \
  --max-time 30)
if echo "$LITELLM_RESPONSE" | grep -q "choices"; then
  echo "  ✅ LiteLLM completion OK"
else
  echo "  ❌ LiteLLM completion FALLA: $LITELLM_RESPONSE"
  FAIL=$((FAIL+1))
fi

echo "→ Postgres schema..."
TABLES=$(docker exec nexus-postgres \
  psql -U nexus_core_app -d nexus_core -tAc "\dt" 2>/dev/null | wc -l)
if [ "${TABLES:-0}" -ge 4 ]; then
  echo "  ✅ Postgres: schema OK ($TABLES tablas)"
else
  echo "  ❌ Postgres: schema incompleto ($TABLES tablas, esperado >= 4)"
  FAIL=$((FAIL+1))
fi

echo "→ Test MVP end-to-end..."
MVP_RESPONSE=$(curl -sk -X POST "https://n8n.ainexus.mx/webhook/lead-intake" \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Test Smoke","empresa":"NEXUS QA","telefono":"521XXXXXXXXXX","sector":"test"}' \
  --max-time 30)
if echo "$MVP_RESPONSE" | grep -q '"ok"'; then
  echo "  ✅ MVP webhook → 200 OK"
else
  echo "  ⚠️  MVP webhook: $MVP_RESPONSE (verificar Dify keys configuradas)"
fi

echo ""
[ "$FAIL" -gt 0 ] && echo "❌ $FAIL tests fallaron" && exit 1
echo "✅ Smoke test completo — MVP operativo"
ENDSSH
```

---

## SK-CC06 · Rollback a snapshot

```bash
#!/usr/bin/env bash
# cc-rollback.sh · Claude Code skill SK-CC06
# Uso: bash cc-rollback.sh pre-phase1
set -uo pipefail

VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"
SNAPSHOT="${1:-}"

[ -z "$SNAPSHOT" ] && {
  echo "Uso: bash cc-rollback.sh <snapshot-name>"
  echo "Snapshots disponibles:"
  ssh -i "$SSH_KEY" root@"$VPS_IP" "ls /opt/nexus-rollback/" 2>/dev/null
  exit 1
}

echo "⚠️  ROLLBACK a snapshot: $SNAPSHOT"
read -p "¿Confirmar rollback? Esto detiene servicios y restaura estado. [s/N]: " confirm
[[ "$confirm" =~ ^[sS]$ ]] || { echo "Abortado."; exit 0; }

ssh -i "$SSH_KEY" root@"$VPS_IP" << ENDSSH
set -euo pipefail
cd /opt/nexus

SNAP_DIR="/opt/nexus-rollback/${SNAPSHOT}"
[ ! -d "\$SNAP_DIR" ] && echo "❌ Snapshot no existe: \$SNAP_DIR" && exit 1

echo "→ Deteniendo servicios..."
docker compose -f phase-1-core/docker-compose.yml --env-file .env down 2>/dev/null || true

echo "→ Restaurando .env..."
cp "\$SNAP_DIR/.env" /opt/nexus/.env

echo "→ Restaurando configuración..."
[ -f "\$SNAP_DIR/docker_state.txt" ] && cat "\$SNAP_DIR/docker_state.txt"

echo "→ Reiniciando con estado restaurado..."
docker compose -f phase-1-core/docker-compose.yml --env-file .env up -d

echo "✅ Rollback completado a: $SNAPSHOT"
ENDSSH
```

---

## SK-CC07 · Diagnóstico en vivo

```bash
#!/usr/bin/env bash
# cc-diagnose.sh · Claude Code skill SK-CC07
# Recolecta estado completo del VPS para diagnóstico
set -uo pipefail

VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"

echo "═══ CLAUDE CODE · Live Diagnostics ═══"

ssh -i "$SSH_KEY" root@"$VPS_IP" << 'ENDSSH'
echo "=== CONTAINERS ==="
docker ps -a --filter "name=nexus-" --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"

echo ""
echo "=== RAM Y DISCO ==="
free -h
df -h /opt

echo ""
echo "=== CONTAINERS CON PROBLEMAS ==="
docker ps -a --filter "name=nexus-" --filter "status=exited" \
  --format "{{.Names}}" | while read svc; do
  echo "--- $svc (últimas 20 líneas) ---"
  docker logs "$svc" --tail 20 2>&1
  echo ""
done

echo ""
echo "=== REDES DOCKER ==="
docker network ls | grep nexus

echo ""
echo "=== VOLÚMENES DOCKER ==="
docker volume ls | grep nexus
ENDSSH

echo ""
echo "→ Pegar el output anterior a Gemini para diagnóstico automatizado."
```

---

## SK-CC08 · Configuración manual Dify + n8n

### Checklist de configuración post-Phase1
```
DIFY (https://dify.ainexus.mx):
  [ ] Settings → Model Providers → Add:
        Type: OpenAI-compatible
        Base URL: http://litellm:4000/v1
        API Key: ${LITELLM_MASTER_KEY}
        Model: deepseek/deepseek-chat (alias cheap-spanish)

  [ ] Apps → Create → "Lead Qualifier":
        Type: Chatflow
        Usar prompt desde: prompts/lead-qualifier.md
        → Copiar API key → guardar como DIFY_LEAD_QUALIFIER_KEY

  [ ] Apps → Create → "WhatsApp Concierge":
        Type: Agent
        Usar prompt desde: prompts/whatsapp-concierge.md
        → Copiar API key → guardar como DIFY_CONCIERGE_KEY

  [ ] Editar .env con ambas keys:
        ssh root@2.24.204.193 "nano /opt/nexus/.env"

  [ ] Reiniciar n8n:
        cd /opt/nexus/phase-1-core
        docker compose --env-file ../.env up -d n8n-main n8n-worker n8n-worker-2

n8n (https://n8n.ainexus.mx):
  [ ] Settings → Credentials → New:
        Type: PostgreSQL
        Host: postgres · Port: 5432
        DB: nexus_core · User: nexus_core_app
        Password: ${PG_NEXUS_CORE_PASS}
        ID: nexus-pg-core (EXACTO)

  [ ] Import → workflows/n8n-lead-qualifier-v1.3.json → Activar
  [ ] Import → workflows/n8n-whatsapp-concierge-v1.3.json → Activar
  [ ] NO importar content-factory como productivo aún
```

---

## REGLA DE ORO DE CLAUDE CODE

> Claude Code ejecuta en el VPS. Nunca edita código local.
> Si necesita un cambio de código → pide a Codex → espera gate de Kimi → ejecuta.
> Sin smoke test real con curl → no hay GO.
> Comando destructivo (rm, down -v, DROP) → siempre confirmación de James.
