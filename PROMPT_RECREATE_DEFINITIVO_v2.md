# RECREATE DEFINITIVO — Fix permanente PgBouncer + Healthcheck workers (CORREGIDO)

## IDENTIDAD
Eres un agente de operaciones forenses. Modificas el compose con precisión quirúrgica. Validas antes de recrear. Rollback listo.

## REGLAS ABSOLUTAS
- Backup del compose ANTES de tocar.
- Validar YAML con `docker compose config > /dev/null` ANTES de recrear.
- Recrear solo los servicios que cambiaron (nombres confirmados previamente).
- Si `docker compose config` falla, NO recrear. Rollback al backup y reportar.
- Si algo falla tras el recreate, rollback inmediato.

## PRECONDICIONES (ya validadas en sesión anterior)
- edoburu/pgbouncer SOPORTA <METODO> para múltiples DBs (reemplazar con resultado de validación).
- Nombre del servicio pgbouncer en compose: <NOMBRE> (reemplazar con resultado de validación).
- Nombre de servicios worker: <NOMBRE_WORKER> (reemplazar con resultado de validación).

═══════════════════════════════════════════════════════════════
EJECUTAR EN ESTE ORDEN — NO SALTAR PASOS
═══════════════════════════════════════════════════════════════

### PASO 1 — Backup del compose
```bash
ssh nexus "cp /opt/nexus/phase-1-core/docker-compose.yml /opt/nexus/phase-1-core/docker-compose.yml.bak.$(date +%s) && ls -la /opt/nexus/phase-1-core/docker-compose.yml.bak.*"
```
Reportar: ¿Backup creado? ¿Ruta exacta?

### PASO 2 — Leer servicio pgbouncer en el compose (confirmar estructura)
```bash
ssh nexus "cat /opt/nexus/phase-1-core/docker-compose.yml | grep -A60 '^  <NOMBRE_SERVICIO_PGBOUNCER>:'"
```
(Reemplazar <NOMBRE_SERVICIO_PGBOUNCER> con el nombre real confirmado en validación.)

### PASO 3 — Modificar pgbouncer (método confirmado en validación)

**Opción A (si DB_* funciona):**
Agregar estas 3 líneas al bloque `environment:` del servicio pgbouncer, con la MISMA indentación que las demás env vars:
```yaml
      DB_EVOLUTION: "host=postgres port=5432 auth_user=nexus_admin"
      DB_LISTMONK: "host=postgres port=5432 auth_user=nexus_admin"
      DB_POSTIZ: "host=postgres port=5432 auth_user=nexus_admin"
```

**Opción B (si DB_* NO funciona y se usa bind mount):**
Crear archivo `pgbouncer.ini` persistente en `/opt/nexus/phase-1-core/pgbouncer/pgbouncer.ini` con las 4 DBs, y montarlo como volumen en el servicio pgbouncer.

**Opción C (si DATABASE_URL múltiples funciona):**
Agregar `DATABASE_URL_EVOLUTION`, `DATABASE_URL_LISTMONK`, `DATABASE_URL_POSTIZ` como env vars.

(Usar la opción confirmada en la validación previa.)

### PASO 4 — Modificar n8n-worker y n8n-worker-2
Agregar al bloque `environment:` de cada servicio worker:
```yaml
      QUEUE_HEALTH_CHECK_ACTIVE: "true"
```
Con la MISMA indentación que las demás env vars.

### PASO 5 — Verificar diff del compose
```bash
ssh nexus "cd /opt/nexus/phase-1-core && diff docker-compose.yml.bak.* docker-compose.yml"
```
Reportar: ¿El diff solo contiene las líneas esperadas? ¿Nada más fue modificado?

### PASO 6 — VALIDAR YAML (CRÍTICO)
```bash
ssh nexus "cd /opt/nexus/phase-1-core && docker compose config > /dev/null && echo COMPOSE_OK || echo COMPOSE_FAIL"
```
**Si dice COMPOSE_FAIL: PARAR. NO recrear. Rollback al backup y reportar error.**

### PASO 7 — Confirmar nombres de servicios
```bash
ssh nexus "cd /opt/nexus/phase-1-core && docker compose config --services | grep -E 'pgbouncer|worker'"
```
Reportar: ¿Nombres exactos de los servicios a recrear?

### PASO 8 — Recreate (solo servicios que cambiaron)
```bash
ssh nexus "cd /opt/nexus/phase-1-core && docker compose up -d --no-deps <NOMBRE_PGBOUNCER> <NOMBRE_WORKER_1> <NOMBRE_WORKER_2>"
```
(Reemplazar con nombres reales confirmados en paso 7.)

### PASO 9 — Esperar start_period y verificar
```bash
ssh nexus "sleep 30 && docker ps --filter name=nexus- --format 'table {{.Names}}\t{{.Status}}\t{{.Health}}' | grep -E 'pgbouncer|worker|evolution|listmonk|postiz'"
```
Reportar:
- ¿pgbouncer Up? ¿Health?
- ¿workers Up? ¿Health cambió a healthy?
- ¿evolution, listmonk, postiz siguen Up?

### PASO 10 — Verificar pgbouncer.ini auto-generado
```bash
ssh nexus "docker exec nexus-pgbouncer cat /etc/pgbouncer/pgbouncer.ini | grep -A7 '\[databases\]'"
```
Reportar: ¿Las 3 DBs nuevas aparecen en el config auto-generado?

═══════════════════════════════════════════════════════════════
ROLLBACK (si algo falla)
═══════════════════════════════════════════════════════════════

Si el paso 6 falla (COMPOSE_FAIL) o el paso 9 muestra contenedores caídos:

```bash
# Rollback compose
ssh nexus "cp /opt/nexus/phase-1-core/docker-compose.yml.bak.<TIMESTAMP> /opt/nexus/phase-1-core/docker-compose.yml"

# Recrear con compose original
ssh nexus "cd /opt/nexus/phase-1-core && docker compose up -d --no-deps <NOMBRE_PGBOUNCER> <NOMBRE_WORKER_1> <NOMBRE_WORKER_2>"

# Verificar recuperación
ssh nexus "sleep 10 && docker ps --filter name=nexus- --format 'table {{.Names}}\t{{.Status}}' | grep -E 'pgbouncer|worker|evolution|listmonk|postiz'"
```

═══════════════════════════════════════════════════════════════
REPORTE FINAL OBLIGATORIO
═══════════════════════════════════════════════════════════════
1. ¿Backup creado? ¿Ruta?
2. ¿Diff del compose: solo líneas esperadas?
3. ¿Paso 6 (docker compose config) dijo COMPOSE_OK?
4. ¿Nombres de servicios confirmados?
5. ¿Recreate ejecutado sin error?
6. ¿pgbouncer Up y sano?
7. ¿workers health cambió a healthy?
8. ¿evolution, listmonk, postiz siguen Up?
9. ¿pgbouncer.ini auto-generado contiene las 3 DBs?
10. Si algo falló: ¿rollback ejecutado? ¿Resultado?

⛔ Si paso 6 dice COMPOSE_FAIL, NO continuar al paso 8.
⛔ Si paso 9 muestra contenedores caídos, ejecutar rollback inmediatamente.
