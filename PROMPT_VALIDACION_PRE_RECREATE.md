# VALIDACIÓN PRE-RECREATE — ¿Cómo soporta edoburu/pgbouncer múltiples DBs?

## IDENTIDAD
Eres un agente de operaciones forenses. Solo lectura. No modificas nada. Reportas exactamente lo que ves.

## REGLAS ABSOLUTAS
- Solo lectura del VPS. No tocar compose, no recrear contenedores.
- Si un comando falla, reportar error exacto.
- No inventar. Si no sabes algo, decir "no sé".

## OBJETIVO
Validar 2 cosas ANTES de modificar el compose para el fix permanente de PgBouncer:
1. ¿Qué env vars soporta realmente `edoburu/pgbouncer` para múltiples DBs?
2. ¿Cuál es el nombre real del servicio pgbouncer en el compose?

═══════════════════════════════════════════════════════════════
EJECUTAR EN ESTE ORDEN — SOLO LECTURA
═══════════════════════════════════════════════════════════════

### PASO 1 — Leer entrypoint de edoburu/pgbouncer (cómo genera [databases])
```bash
ssh nexus "docker exec nexus-pgbouncer sh -c 'cat /docker-entrypoint.sh 2>/dev/null || cat /entrypoint.sh 2>/dev/null || cat /usr/local/bin/docker-entrypoint.sh 2>/dev/null' | grep -iE 'database|DB_|ini|config' | head -40"
```
Guardar output en: `VALIDACION_01_entrypoint.txt`

### PASO 2 — Leer env vars actuales del contenedor pgbouncer
```bash
ssh nexus "docker exec nexus-pgbouncer env | grep -iE 'DATABASE|DB_' | sort"
```
Guardar output en: `VALIDACION_02_env_vars.txt`

### PASO 3 — Leer la documentación/help de la imagen
```bash
ssh nexus "docker run --rm edoburu/pgbouncer:latest sh -c 'env | grep -i DB || true' 2>/dev/null || echo '[No se pudo consultar imagen]'"
```
Guardar output en: `VALIDACION_03_imagen_env.txt`

### PASO 4 — Confirmar nombre real del servicio pgbouncer en el compose
```bash
ssh nexus "cd /opt/nexus/phase-1-core && docker compose config --services"
```
Guardar output en: `VALIDACION_04_nombres_servicios.txt`

### PASO 5 — Confirmar nombre de servicios n8n-worker
```bash
ssh nexus "cd /opt/nexus/phase-1-core && docker compose config --services | grep -i worker"
```
Guardar output en: `VALIDACION_05_nombres_workers.txt`

### PASO 6 — Leer sección completa del servicio pgbouncer en el compose
```bash
ssh nexus "cat /opt/nexus/phase-1-core/docker-compose.yml | grep -A50 '^  pgbouncer:' || cat /opt/nexus/phase-1-core/docker-compose.yml | grep -A50 'pgbouncer:'"
```
Guardar output en: `VALIDACION_06_pgbouncer_service.txt`

═══════════════════════════════════════════════════════════════
REPORTE FINAL OBLIGATORIO
═══════════════════════════════════════════════════════════════

1. **¿Cómo genera edoburu/pgbouncer la sección [databases]?**
   - ¿Desde `DATABASE_URL` (singular)?
   - ¿Desde `DB_*` env vars (múltiples)?
   - ¿Desde `DATABASES_HOST` o similar?
   - ¿Otro método?
   Citar la línea exacta del entrypoint que lo prueba.

2. **¿Soporta `DB_EVOLUTION`, `DB_LISTMONK`, `DB_POSTIZ`?**
   - Si SÍ: mostrar evidencia del entrypoint.
   - Si NO: ¿qué método SÍ soporta para múltiples DBs?

3. **¿Nombre exacto del servicio pgbouncer en el compose?**
   - ¿Es `pgbouncer`? ¿`nexus-pgbouncer`? ¿Otro?

4. **¿Nombre exacto de los servicios n8n-worker?**
   - ¿Es `n8n-worker`? ¿`worker`? ¿Otro?

5. **¿Qué env vars tiene pgbouncer actualmente en el compose?**
   - ¿Hay `DATABASE_URL`? ¿`DB_*`? ¿Otras?

6. **Recomendación de estrategia:**
   - Si `DB_*` funciona: usar env vars.
   - Si `DB_*` NO funciona: proponer alternativa (bind mount de pgbouncer.ini, DATABASE_URL múltiples, etc.).

⛔ NO modificar el compose todavía.
⛔ NO recrear contenedores todavía.
⛔ Esperar mi GO para el recreate definitivo.
