# PROPUESTA FIX SASL PHASE 2 — generado 04-jun-2026

## HALLAZGO CRÍTICO — No es un sed problem, es un compose problem

pgbouncer.ini es **auto-generado al arrancar** por `edoburu/pgbouncer` a partir de `DATABASE_URL`.
El contenedor tiene **0 bind mounts** (confirmado: `docker inspect nexus-pgbouncer --Mounts = []`).
Si aplicamos solo el sed, el fix se pierde al próximo `docker restart nexus-pgbouncer`.

**FIX PERMANENTE requiere cambio en `phase-1-core/docker-compose.yml` + recreate de pgbouncer.**

---

## RIESGO PARA PHASE 1: CERO

n8n, dify y litellm conectan DIRECTO a `postgres:5432` (no via pgbouncer).
Evidencia en fase-1-core-docker-compose.yml:
```
DB_HOST: postgres              # dify-api, dify-worker
DB_POSTGRESDB_HOST: postgres   # n8n, n8n-worker, n8n-worker-2
DATABASE_URL: postgresql://...@postgres:5432/litellm  # litellm
```
Recrear solo `nexus-pgbouncer` NO interrumpe Phase 1.

---

## DIAGNÓSTICO CONFIRMADO

| Check | Resultado | Archivo evidencia |
|---|---|---|
| DBs evolution/listmonk/postiz existen | ✅ | 02_DIAGNOSTICO_SASL/01_dbs_existentes.txt |
| Roles con password | ✅ | 02_DIAGNOSTICO_SASL/02_roles_passwords.txt |
| Método SCRAM-SHA-256 | ✅ | 02_DIAGNOSTICO_SASL/03_password_method.txt |
| [databases] solo tiene `postgres` | ❌ CAUSA RAÍZ | 02_DIAGNOSTICO_SASL/04_pgbouncer_config.txt |
| evolution_app conecta directo a Postgres | ✅ (SELECT 1 = 1) | 02_DIAGNOSTICO_SASL/07_test_directo_sin_pgbouncer.txt |
| auth_query (nexus_admin lee pg_shadow) | ✅ | 02_DIAGNOSTICO_SASL/06_auth_query.txt |
| pgbouncer tiene 0 bind mounts | ❌ config es efímera | docker inspect en vivo |

---

## ESTADO DE userlist.txt — PROBLEMA #2: NO EXISTE

Contenido: `"nexus_admin" "432cfd732e763ebf2f5dbbae5f479a81"`

Formato: plaintext (32 chars hex = password real de nexus_admin, NO es MD5 hasheado con prefijo).
PgBouncer lo usa como plaintext para hacer SCRAM con Postgres → funciona correctamente.
`auth_query` contra `pg_shadow` confirmada operativa.

**Dictamen Problema #2: No tocar userlist.txt.**

---

## FIX PROPUESTO — 2 opciones

### OPCIÓN A — Inmediato pero efímero (sed + HUP)
Aplicar si necesitas Phase 2 funcionando AHORA y haces el fix permanente después.
Se pierde al próximo restart de nexus-pgbouncer.

```bash
# Paso A1 — Backup (correr ANTES del sed)
ssh nexus 'docker exec nexus-pgbouncer cp /etc/pgbouncer/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini.bak.$(date +%s) && ls /etc/pgbouncer/pgbouncer.ini.bak.*'

# Paso A2 — Aplicar sed (escribe a /tmp primero, copia solo si ok)
ssh nexus 'docker exec nexus-pgbouncer sh -c "sed '"'"'/^postgres = host=postgres port=5432 auth_user=nexus_admin$/a evolution = host=postgres port=5432 auth_user=nexus_admin\nlistmonk = host=postgres port=5432 auth_user=nexus_admin\npostiz = host=postgres port=5432 auth_user=nexus_admin'"'"' /etc/pgbouncer/pgbouncer.ini > /tmp/pgbouncer_new.ini && cp /tmp/pgbouncer_new.ini /etc/pgbouncer/pgbouncer.ini"'

# Paso A3 — Reload sin restart (HUP)
ssh nexus 'docker kill --signal=HUP nexus-pgbouncer'

# Paso A4 — Verificar que las 3 DBs aparecen en el config
ssh nexus 'docker exec nexus-pgbouncer cat /etc/pgbouncer/pgbouncer.ini | head -8'
```

### OPCIÓN B — Permanente (compose + recreate pgbouncer solamente)
Modifica `/opt/nexus/phase-1-core/docker-compose.yml` en el servicio `pgbouncer`,
reemplazando el bloque `environment` actual por:

```yaml
    environment:
      DATABASE_URL: postgres://${PG_ADMIN_USER}:${PG_ADMIN_PASS}@postgres:5432/postgres
      DATABASE_EVOLUTION_URL: postgres://${PG_ADMIN_USER}:${PG_ADMIN_PASS}@postgres:5432/evolution
      DATABASE_LISTMONK_URL: postgres://${PG_ADMIN_USER}:${PG_ADMIN_PASS}@postgres:5432/listmonk
      DATABASE_POSTIZ_URL: postgres://${PG_ADMIN_USER}:${PG_ADMIN_PASS}@postgres:5432/postiz
      POOL_MODE: transaction
      MAX_CLIENT_CONN: 1000
      DEFAULT_POOL_SIZE: 25
      RESERVE_POOL_SIZE: 5
      AUTH_TYPE: scram-sha-256
      AUTH_USER: ${PG_ADMIN_USER}
      ADMIN_USERS: ${PG_ADMIN_USER}
      LISTEN_PORT: 6432
      SERVER_TLS_SSLMODE: disable
```

NOTA: `DATABASE_*_URL` es el patrón soportado por `edoburu/pgbouncer` para múltiples bases.
Si la imagen no lo soporta, fallback a Opción C (bind mount).

Luego:
```bash
ssh nexus 'cd /opt/nexus && docker compose -f phase-1-core/docker-compose.yml --env-file .env up -d --no-deps pgbouncer'
```

### OPCIÓN C — Permanente garantizado (bind mount de config)
Si Opción B no funciona, este método es infalible:

```bash
# 1. Crear config completa en VPS
ssh nexus 'cat > /opt/nexus/pgbouncer-override.ini << '"'"'EOF'"'"'
[databases]
postgres = host=postgres port=5432 auth_user=nexus_admin
evolution = host=postgres port=5432 auth_user=nexus_admin
listmonk = host=postgres port=5432 auth_user=nexus_admin
postiz = host=postgres port=5432 auth_user=nexus_admin
[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
unix_socket_dir =
user = postgres
auth_file = /etc/pgbouncer/userlist.txt
auth_type = scram-sha-256
auth_user = nexus_admin
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
reserve_pool_size = 5
ignore_startup_parameters = extra_float_digits
admin_users = nexus_admin
server_tls_sslmode = disable
EOF'

# 2. Agregar volumen en compose (pgbouncer service, sección volumes):
#    - ./pgbouncer-override.ini:/etc/pgbouncer/pgbouncer.ini:ro

# 3. Recrear solo pgbouncer
ssh nexus 'cd /opt/nexus && docker compose -f phase-1-core/docker-compose.yml --env-file .env up -d --no-deps pgbouncer'
```

---

## ROLLBACK EXACTO (para cualquier opción)

```bash
# Usar el timestamp del backup creado en Paso A1
TIMESTAMP=<el número devuelto por date +%s en el backup>

# Opción A (sed efímero) — restaurar y recargar
ssh nexus "docker exec nexus-pgbouncer cp /etc/pgbouncer/pgbouncer.ini.bak.${TIMESTAMP} /etc/pgbouncer/pgbouncer.ini"
ssh nexus "docker kill --signal=HUP nexus-pgbouncer"

# Opción B/C (compose) — simplemente recrear sin el cambio
ssh nexus 'cd /opt/nexus && git checkout phase-1-core/docker-compose.yml && docker compose -f phase-1-core/docker-compose.yml --env-file .env up -d --no-deps pgbouncer'
```

---

## DICTAMEN FINAL

**¿Es seguro aplicar?** SÍ, con condición.

- **Opción A**: segura para aplicar ahora. Phase 1 no se interrumpe (cero dependencia de pgbouncer).
  Riesgo: bajo. El HUP hace reload en caliente sin cortar conexiones activas.
- **Opción B**: requiere verificar que `edoburu/pgbouncer` soporte `DATABASE_*_URL`. Si no,
  el contenedor arranca pero solo tendrá `postgres` en [databases] igual que ahora.
  Verificar con: `docker exec nexus-pgbouncer cat /etc/pgbouncer/pgbouncer.ini | head -8`
- **Opción C**: garantizada, independiente de la imagen. Mínimo riesgo.

**Recomendación**: Opción A ahora (para desbloquear Phase 2) + Opción B o C después
para hacer permanente el fix en el mismo recreate donde aplicas QUEUE_HEALTH_CHECK_ACTIVE.

**Phase 1 en cualquier caso: INTOCABLE.**
