#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# NEXUS v1.3 · skills-runner.sh
# Orquestador de skills de agentes
# Uso: bash skills/skills-runner.sh <agente> <skill>
# ════════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.."

AGENT="${1:-help}"
SKILL="${2:-help}"

VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"

usage() {
cat << 'EOF'
NEXUS Skills Runner v1.3

Uso: bash skills/skills-runner.sh <agente> <skill> [args]

CODEX (generación de código):
  codex  pre-commit              Ejecutar validación antes de push
  codex  commit  "mensaje"       Commit atómico con validación previa

KIMI (auditoría líder):
  kimi   audit                   Auditoría completa del repo
  kimi   workflows               Validar lógica de workflows n8n
  kimi   security                Auditoría de seguridad
  kimi   env-drift               Detectar drift de variables .env

GROK (seguridad):
  grok   secrets                 Escanear secrets expuestos
  grok   docker                  Auditoría de seguridad Docker
  grok   ports                   Verificar puertos expuestos
  grok   traefik                 Auditar configuración Traefik

GEMINI (configuración):
  gemini compose                 Validar docker-compose YAML
  gemini env-vars                Verificar variables sin interpolar
  gemini healthchecks            Verificar health checks
  gemini memory                  Auditar límites de memoria
  gemini logs  <servicio>        Diagnosticar logs de container

CLAUDE (VPS):
  claude preflight               Precheck del VPS
  claude sync                    Sincronizar repo en VPS
  claude validate                Validar compose en VPS
  claude deploy  <fase>          Deploy fase (1|2|3|all)
  claude smoke                   Smoke test real
  claude rollback <snapshot>     Rollback a snapshot
  claude diagnose                Diagnóstico completo VPS

PIPELINE (flujo completo):
  pipeline  audit                Correr 3 auditores en paralelo
  pipeline  gate                 Verificar gate completo
  pipeline  deploy               Deploy completo con gates

EOF
  exit 0
}

# ─── CODEX SKILLS ───
codex_pre_commit() {
  echo "═══ CODEX · Pre-commit validation ═══"
  bash scripts/pre-commit-validate.sh
}

codex_commit() {
  local msg="${1:-}"
  [ -z "$msg" ] && { echo "Uso: codex commit 'mensaje'"; exit 1; }
  codex_pre_commit || exit 1
  git add -A
  git commit -m "$msg"
  git push origin deploy-v1.3
  echo "✅ Push exitoso → deploy-v1.3"
}

# ─── KIMI SKILLS ───
kimi_audit() {
  echo "═══ KIMI · Full Audit ═══"
  local PASS=0; local FAIL=0

  # JSON
  find workflows -name "*.json" -print0 2>/dev/null | \
    xargs -0 -I{} python3 -m json.tool "{}" > /dev/null 2>&1 \
    && { echo "  ✅ JSON OK"; PASS=$((PASS+1)); } \
    || { echo "  ❌ JSON inválido"; FAIL=$((FAIL+1)); }

  # Bash
  bash -n scripts/*.sh 2>/dev/null \
    && { echo "  ✅ Scripts OK"; PASS=$((PASS+1)); } \
    || { echo "  ❌ Script error"; FAIL=$((FAIL+1)); }

  # Secrets
  grep -rn --include="*.sh" --include="*.sql" \
    --include="*.yml" --include="*.json" \
    "BEGIN OPENSSH PRIVATE KEY" . 2>/dev/null \
    && { echo "  ❌ Private key!"; FAIL=$((FAIL+1)); } \
    || { echo "  ✅ Sin private keys"; PASS=$((PASS+1)); }

  # NocoBase
  grep -rn "NocoBase · Save lead" workflows 2>/dev/null \
    && { echo "  ❌ NocoBase"; FAIL=$((FAIL+1)); } \
    || { echo "  ✅ Sin NocoBase"; PASS=$((PASS+1)); }

  # DOMAIN en n8n
  python3 -c "
import yaml,sys
c=yaml.safe_load(open('phase-1-core/docker-compose.yml'))
m=[s for s in ['n8n-main','n8n-worker','n8n-worker-2'] if 'DOMAIN' not in c['services'].get(s,{}).get('environment',{})]
print('  ❌ DOMAIN falta:',m) if m else print('  ✅ DOMAIN OK')
sys.exit(1 if m else 0)" \
    && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

  echo ""
  echo "═══ Kimi: ✅ $PASS · ❌ $FAIL ═══"
  [ "$FAIL" -gt 0 ] && echo "❌ NO GO — $FAIL fallos" && exit 1
  echo "✅ GATE APROBADO — GO para VPS"
}

kimi_workflows() {
  echo "═══ KIMI · Workflow Logic Validation ═══"
  python3 agents/skills/validate-workflows.py
}

kimi_security() {
  echo "═══ KIMI · Security Audit ═══"
  bash agents/skills/grok-secrets-scan.sh
}

kimi_env_drift() {
  echo "═══ KIMI · Env Drift Detection ═══"
  bash agents/skills/env-drift.sh
}

# ─── GROK SKILLS ───
grok_secrets()  { bash agents/skills/grok-secrets-scan.sh; }
grok_docker()   { bash agents/skills/grok-docker-security.sh; }
grok_ports()    { bash agents/skills/grok-ports-audit.sh; }
grok_traefik()  { bash agents/skills/grok-traefik-audit.sh; }

# ─── GEMINI SKILLS ───
gemini_compose()      { bash agents/skills/gemini-compose-validate.sh; }
gemini_env_vars()     { python3 agents/skills/gemini-env-check.py; }
gemini_healthchecks() { python3 agents/skills/gemini-healthcheck-audit.py; }
gemini_memory()       { python3 agents/skills/gemini-memory-audit.py; }
gemini_logs()         {
  local svc="${1:-nexus-n8n-main}"
  bash agents/skills/gemini-log-diag.sh "$svc"
}

# ─── CLAUDE CODE SKILLS ───
claude_preflight() { bash agents/skills/cc-preflight.sh; }
claude_sync()      { bash agents/skills/cc-sync-repo.sh; }
claude_validate()  { bash agents/skills/cc-validate-compose.sh; }
claude_deploy()    {
  local phase="${1:-1}"
  bash agents/skills/cc-deploy.sh "$phase"
}
claude_smoke()     { bash agents/skills/cc-smoke-test.sh; }
claude_rollback()  {
  local snap="${1:-}"
  bash agents/skills/cc-rollback.sh "$snap"
}
claude_diagnose()  { bash agents/skills/cc-diagnose.sh; }

# ─── PIPELINE COMPLETO ───
pipeline_audit() {
  echo "═══ PIPELINE · 3 Auditores en Paralelo ═══"
  echo ""

  # Correr los 3 en paralelo y capturar resultados
  grok_secrets   > /tmp/grok-result.txt   2>&1 &
  GROK_PID=$!
  gemini_compose > /tmp/gemini-result.txt 2>&1 &
  GEMINI_PID=$!
  kimi_audit     > /tmp/kimi-result.txt   2>&1 &
  KIMI_PID=$!

  # Esperar a que terminen
  wait $GROK_PID;   GROK_EXIT=$?
  wait $GEMINI_PID; GEMINI_EXIT=$?
  wait $KIMI_PID;   KIMI_EXIT=$?

  echo "─── Resultado Grok ───"
  cat /tmp/grok-result.txt

  echo "─── Resultado Gemini ───"
  cat /tmp/gemini-result.txt

  echo "─── Resultado Kimi (LÍDER) ───"
  cat /tmp/kimi-result.txt

  echo ""
  echo "═══ Veredicto Final (Kimi) ═══"
  if [ $GROK_EXIT -ne 0 ] || [ $GEMINI_EXIT -ne 0 ] || [ $KIMI_EXIT -ne 0 ]; then
    echo "❌ NO GO — uno o más auditores reportaron fallos"
    echo "  Grok: $([ $GROK_EXIT -eq 0 ] && echo OK || echo FAIL)"
    echo "  Gemini: $([ $GEMINI_EXIT -eq 0 ] && echo OK || echo FAIL)"
    echo "  Kimi: $([ $KIMI_EXIT -eq 0 ] && echo OK || echo FAIL)"
    exit 1
  fi
  echo "✅ GATE APROBADO — GO para VPS"
}

pipeline_gate() {
  pipeline_audit
}

pipeline_deploy() {
  echo "═══ PIPELINE · Deploy Completo ═══"
  echo ""
  echo "Paso 1: Gate de auditoría..."
  pipeline_audit || exit 1
  echo ""
  echo "Paso 2: Aprobación de James (60s)..."
  read -t 60 -p "¿Aprobar deploy? [s/N]: " confirm || confirm=""
  [[ "$confirm" =~ ^[sS]$ ]] || { echo "Abortado por James."; exit 0; }
  echo ""
  echo "Paso 3: Claude Code al VPS..."
  claude_preflight || exit 1
  claude_sync      || exit 1
  claude_validate  || exit 1
  claude_deploy 1  || exit 1
  echo ""
  echo "⏸  Configurar Dify + n8n manualmente (ver SK-CC08)"
  read -p "¿Configuración completada? [s/N]: " dify_done
  [[ "$dify_done" =~ ^[sS]$ ]] || { echo "Deploy pausado. Continuar con: claude deploy 2"; exit 0; }
  claude_deploy 2  || exit 1
  claude_deploy 3  || exit 1
  claude_smoke     || exit 1
  echo ""
  echo "✅ DEPLOY COMPLETO — MVP activo en ainexus.mx"
}

# ─── ROUTER ───
case "$AGENT" in
  codex)
    case "$SKILL" in
      pre-commit) codex_pre_commit ;;
      commit)     codex_commit "${3:-}" ;;
      *)          echo "Skills Codex: pre-commit, commit"; exit 1 ;;
    esac ;;
  kimi)
    case "$SKILL" in
      audit)      kimi_audit ;;
      workflows)  kimi_workflows ;;
      security)   kimi_security ;;
      env-drift)  kimi_env_drift ;;
      *)          echo "Skills Kimi: audit, workflows, security, env-drift"; exit 1 ;;
    esac ;;
  grok)
    case "$SKILL" in
      secrets)    grok_secrets ;;
      docker)     grok_docker ;;
      ports)      grok_ports ;;
      traefik)    grok_traefik ;;
      *)          echo "Skills Grok: secrets, docker, ports, traefik"; exit 1 ;;
    esac ;;
  gemini)
    case "$SKILL" in
      compose)      gemini_compose ;;
      env-vars)     gemini_env_vars ;;
      healthchecks) gemini_healthchecks ;;
      memory)       gemini_memory ;;
      logs)         gemini_logs "${3:-nexus-n8n-main}" ;;
      *)            echo "Skills Gemini: compose, env-vars, healthchecks, memory, logs"; exit 1 ;;
    esac ;;
  claude)
    case "$SKILL" in
      preflight)  claude_preflight ;;
      sync)       claude_sync ;;
      validate)   claude_validate ;;
      deploy)     claude_deploy "${3:-1}" ;;
      smoke)      claude_smoke ;;
      rollback)   claude_rollback "${3:-}" ;;
      diagnose)   claude_diagnose ;;
      *)          echo "Skills Claude: preflight, sync, validate, deploy, smoke, rollback, diagnose"; exit 1 ;;
    esac ;;
  pipeline)
    case "$SKILL" in
      audit)      pipeline_audit ;;
      gate)       pipeline_gate ;;
      deploy)     pipeline_deploy ;;
      *)          echo "Pipeline: audit, gate, deploy"; exit 1 ;;
    esac ;;
  *)
    usage ;;
esac
