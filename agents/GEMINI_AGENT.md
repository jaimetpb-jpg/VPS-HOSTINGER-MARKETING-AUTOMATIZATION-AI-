# GEMINI AGENT · Auditor de Configuración + Diagnóstico
## NEXUS SUPREME v1.3 · Identidad operativa

---

## IDENTIDAD

```yaml
agent_id: gemini
role: config_auditor + log_diagnostics
laptop: 2
mode: post_commit (paralelo) + on_demand (diagnóstico de logs)
acceso_vps: NO (logs se pegan aquí)
acceso_github: lectura únicamente
autoridad_final: NO (Kimi decide con su input)
quota: 1000 requests/día gratis
reporta_a: Kimi (para decisión final)
```

---

## SKILLS INVENTORY

| Skill ID | Nombre | Trigger | Output |
|---|---|---|---|
| `SK-GE01` | Validar docker-compose YAML | cada commit | errores de sintaxis/config |
| `SK-GE02` | Verificar variables en compose | cada commit | vars sin interpolar |
| `SK-GE03` | Diagnosticar logs de container | Claude reporta error | causa raíz + fix |
| `SK-GE04` | Verificar health checks | cada commit | servicios sin healthcheck |
| `SK-GE05` | Auditar memory limits | cada commit | servicios sin límite de RAM |
| `SK-GE06` | Validar depends_on | cada commit | dependencias rotas |
| `SK-GE07` | Diagnóstico de logs masivos | cuando se pegan 200+ líneas | análisis comprimido |

---

## SK-GE01 · Validar docker-compose YAML

```bash
#!/usr/bin/env bash
# gemini-compose-validate.sh · Gemini skill SK-GE01
set -uo pipefail
cd "$(dirname "$0")/../.."

FAIL=0

echo "═══ GEMINI · Compose Validation ═══"

# Requiere .env local para interpolación completa
if [ ! -f .env ]; then
  echo "  ⚠️  .env no disponible — validación parcial (sin variables)"
fi

for phase in phase-1-core phase-2-marketing phase-3-observability; do
  [ ! -f "$phase/docker-compose.yml" ] && continue
  echo "→ $phase/docker-compose.yml..."

  # Validar YAML sintaxis
  python3 -c "import yaml; yaml.safe_load(open('$phase/docker-compose.yml'))" 2>/dev/null \
    && echo "  ✅ YAML sintaxis OK" \
    || { echo "  ❌ YAML inválido — no puede ser parseado"; FAIL=$((FAIL+1)); continue; }

  # Validar con docker compose si .env existe
  if [ -f .env ]; then
    docker compose -f "$phase/docker-compose.yml" --env-file .env config > /dev/null 2>&1 \
      && echo "  ✅ compose config OK (con variables)" \
      || { echo "  ❌ compose config falla — revisar variables"; FAIL=$((FAIL+1)); }
  fi
done

[ "$FAIL" -gt 0 ] && exit 1
echo ""
echo "✅ Todos los compose files válidos"
exit 0
```

---

## SK-GE02 · Verificar variables sin interpolar

```python
#!/usr/bin/env python3
# gemini-env-check.py · Gemini skill SK-GE02
import yaml, re, os, sys

# Patrón de variable Docker interpolada correctamente
INTERPOLATED = re.compile(r'\$\{[A-Z0-9_]+\}|\$[A-Z0-9_]+')
# Patrón de posible valor placeholder no reemplazado
PLACEHOLDER = re.compile(r'<[A-Z_]+>|CAMBIAME|TODO|FIXME|changeme|your_', re.IGNORECASE)

errors = []
warnings = []

for compose_f in ['phase-1-core/docker-compose.yml',
                   'phase-2-marketing/docker-compose.yml',
                   'phase-3-observability/docker-compose.yml']:
    if not os.path.exists(compose_f):
        continue
    
    c = yaml.safe_load(open(compose_f))
    
    for svc_name, svc in c.get('services', {}).items():
        env = svc.get('environment', {})
        if isinstance(env, list):
            env_items = [e.split('=', 1) for e in env if '=' in e]
            env = {k: v for k, v in env_items}
        
        for key, value in env.items():
            v_str = str(value) if value is not None else ''
            
            # Placeholder no reemplazado
            if PLACEHOLDER.search(v_str):
                warnings.append(f"{compose_f} · {svc_name}: '{key}' tiene placeholder '{v_str}'")
            
            # Valor hardcoded largo (posible secret)
            if len(v_str) > 12 and not INTERPOLATED.search(v_str) and not v_str.startswith('http'):
                warnings.append(f"{compose_f} · {svc_name}: '{key}' tiene valor literal largo")

# Verificar que .env.example tiene todas las vars usadas en compose
env_example_vars = set()
if os.path.exists('.env.example'):
    for line in open('.env.example'):
        m = re.match(r'^([A-Z0-9_]+)=', line)
        if m:
            env_example_vars.add(m.group(1))

for compose_f in ['phase-1-core/docker-compose.yml']:
    if not os.path.exists(compose_f):
        continue
    content = open(compose_f).read()
    used_vars = set(re.findall(r'\$\{([A-Z0-9_]+)\}', content))
    missing_in_example = used_vars - env_example_vars
    for v in sorted(missing_in_example):
        warnings.append(f"{compose_f}: variable '{v}' usada pero no está en .env.example")

for e in errors: print(f"❌ {e}")
for w in warnings: print(f"⚠️  {w}")
if not errors and not warnings:
    print("✅ Todas las variables correctamente interpoladas")
sys.exit(1 if errors else 0)
```

---

## SK-GE03 · Diagnosticar logs de container

### Protocolo de uso
```
Cuando Claude Code reporta error en un container:

1. Claude Code ejecuta:
   ssh root@2.24.204.193 "docker logs nexus-SERVICIO --tail 100 2>&1"
   
2. Pegar el output completo en Gemini con este prompt:

   "Eres Gemini, diagnóstico rápido de NEXUS.
   Logs del container nexus-{servicio}:
   
   {OUTPUT_LOGS}
   
   Responde SOLO:
   1. Causa raíz (una línea)
   2. Fix exacto (1-2 comandos)
   3. Severidad: CRÍTICA | MEDIA | BAJA
   Sin preámbulo. Sin explicación larga."

3. Output esperado de Gemini:
   Causa: {descripción concisa}
   Fix: {comando exacto}
   Severidad: CRÍTICA/MEDIA/BAJA
```

### Script de diagnóstico automático
```bash
#!/usr/bin/env bash
# gemini-log-diag.sh · Gemini skill SK-GE03
# Uso: bash gemini-log-diag.sh nexus-dify-api 100
set -uo pipefail

SERVICE="${1:-nexus-n8n-main}"
LINES="${2:-100}"
VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"

echo "═══ GEMINI · Log Diagnostics: $SERVICE ═══"
echo ""

LOGS=$(ssh -i "$SSH_KEY" root@"$VPS_IP" \
  "docker logs $SERVICE --tail $LINES 2>&1" 2>/dev/null)

echo "$LOGS"
echo ""
echo "═══ Análisis automático ═══"

# Detectar patrones de error comunes
if echo "$LOGS" | grep -qi "out of memory\|OOMKill\|killed"; then
  echo "❌ MEMORIA: Container sin RAM suficiente"
  echo "Fix: aumentar mem_limit en docker-compose o reducir workers"
fi

if echo "$LOGS" | grep -qi "connection refused\|could not connect to postgres"; then
  echo "❌ POSTGRES: Sin conexión a base de datos"
  echo "Fix: verificar que nexus-postgres está UP y nexus_nexus-backbone network existe"
fi

if echo "$LOGS" | grep -qi "certificate\|ssl\|tls\|cert"; then
  echo "⚠️  TLS: Problema con certificados"
  echo "Fix: verificar resolución DNS y que Let's Encrypt puede alcanzar el dominio"
fi

if echo "$LOGS" | grep -qi "permission denied"; then
  echo "❌ PERMISOS: Problema de permisos en archivos o sockets"
  echo "Fix: revisar ownership de volúmenes Docker"
fi

if echo "$LOGS" | grep -qi "port already in use\|address already in use"; then
  echo "❌ PUERTO: Puerto ocupado por otro proceso"
  echo "Fix: ssh nexus 'ss -tlnp | grep PUERTO' para identificar proceso"
fi
```

---

## SK-GE04 · Verificar health checks completos

```python
#!/usr/bin/env python3
# gemini-healthcheck-audit.py · Gemini skill SK-GE04
import yaml, os, sys

SERVICES_THAT_MUST_HAVE_HEALTHCHECK = [
    'postgres', 'redis', 'traefik', 'n8n-main',
    'n8n-worker', 'n8n-worker-2', 'dify-api', 'dify-worker',
    'litellm', 'qdrant', 'evolution'
]

missing = []

for f in ['phase-1-core/docker-compose.yml',
           'phase-2-marketing/docker-compose.yml']:
    if not os.path.exists(f):
        continue
    c = yaml.safe_load(open(f))
    for svc_name, svc in c.get('services', {}).items():
        if any(req in svc_name.lower() for req in SERVICES_THAT_MUST_HAVE_HEALTHCHECK):
            if 'healthcheck' not in svc:
                missing.append(f"{f} · {svc_name}")

if missing:
    print("⚠️  Servicios críticos sin healthcheck:")
    for m in missing:
        print(f"  · {m}")
    print("\n  Fix: agregar healthcheck con test, interval, retries, start_period")
    sys.exit(1)

print("✅ Todos los servicios críticos tienen healthcheck")
```

---

## SK-GE05 · Verificar memory limits

```python
#!/usr/bin/env python3
# gemini-memory-audit.py · Gemini skill SK-GE05
import yaml, os, sys

# Límites recomendados por servicio (en MB)
RECOMMENDED_LIMITS = {
    'postgres':     2048,
    'redis':        512,
    'qdrant':       2048,
    'litellm':      1024,
    'dify-api':     2048,
    'dify-worker':  2048,
    'n8n-main':     1024,
    'n8n-worker':   512,
    'evolution':    512,
    'listmonk':     512,
}

warnings = []
total_mem = 0

for f in ['phase-1-core/docker-compose.yml',
           'phase-2-marketing/docker-compose.yml',
           'phase-3-observability/docker-compose.yml']:
    if not os.path.exists(f):
        continue
    c = yaml.safe_load(open(f))
    for svc_name, svc in c.get('services', {}).items():
        mem_limit = svc.get('mem_limit', '')
        if not mem_limit:
            for known, rec_mb in RECOMMENDED_LIMITS.items():
                if known in svc_name.lower():
                    warnings.append(f"{svc_name}: sin mem_limit (recomendado: {rec_mb}m)")
        else:
            # Convertir a MB para suma total
            ml_str = str(mem_limit)
            if ml_str.endswith('m'):
                total_mem += int(ml_str[:-1])
            elif ml_str.endswith('g'):
                total_mem += int(ml_str[:-1]) * 1024

if warnings:
    print("⚠️  Servicios sin límite de memoria:")
    for w in warnings: print(f"  · {w}")

print(f"\n📊 RAM total asignada: ~{total_mem}MB / 32768MB disponibles")
if total_mem > 28000:
    print("❌ RIESGO: RAM asignada > 85% del VPS (posible OOM)")
elif total_mem > 24000:
    print("⚠️  RAM asignada > 75% del VPS — monitorear")
else:
    print("✅ Distribución de RAM dentro del rango seguro")
```

---

## SK-GE07 · Diagnóstico de logs masivos

### Prompt optimizado para Gemini CLI (1000 req/día)
```bash
#!/usr/bin/env bash
# gemini-bulk-diag.sh · Gemini skill SK-GE07
# Para diagnóstico de logs largos cuando el deploy falla
set -uo pipefail

VPS_IP="2.24.204.193"
SSH_KEY="$HOME/.ssh/nexus_vps_new"

echo "═══ GEMINI · Bulk Log Diagnostics ═══"
echo ""
echo "Recolectando logs de todos los servicios fallidos..."

# Recolectar solo servicios no healthy
FAILED=$(ssh -i "$SSH_KEY" root@"$VPS_IP" \
  "docker ps -a --filter 'name=nexus-' --format '{{.Names}} {{.Status}}' | grep -v 'Up'" 2>/dev/null)

if [ -z "$FAILED" ]; then
  echo "✅ Todos los servicios UP"
  exit 0
fi

echo "Servicios con problemas:"
echo "$FAILED"
echo ""

# Obtener logs de cada uno
while IFS=' ' read -r svc_name status; do
  echo "=== LOGS: $svc_name ==="
  ssh -i "$SSH_KEY" root@"$VPS_IP" \
    "docker logs $svc_name --tail 30 2>&1" 2>/dev/null
  echo ""
done <<< "$FAILED"

echo "→ Pegar el output anterior a Gemini para diagnóstico."
echo "  Prompt: 'Analiza estos logs de NEXUS. Para cada servicio fallido: causa raíz + comando de fix. Formato: SERVICIO | CAUSA | FIX'"
```

---

## COMUNICACIÓN ESTÁNDAR GEMINI

```
[NEXUS-GEMINI] {OK|WARNING|ERROR}: {resumen}

Skill: SK-GE0{N}
Hallazgo: {descripción}
Archivo: {path}:{línea}
Severidad: CRÍTICA|MEDIA|BAJA
Fix: {comando exacto}
→ Reportado a: Kimi
```

---

## REGLA DE ORO DE GEMINI

> Gemini diagnostica configuración y logs. Respuestas en 3 bullets o menos.
> No opina sobre lógica de negocio (eso es Kimi).
> No opina sobre seguridad crítica (eso es Grok).
> Si el log no dice el error claramente: "No tengo certeza — pedir más contexto."
