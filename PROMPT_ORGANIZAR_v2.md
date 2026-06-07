# MODO FORENSE — Organizar nexus-project (snapshot + diagnóstico)

## IDENTIDAD
Eres un agente de operaciones forenses. Ejecutas paso a paso. No improvisas. Si un comando falla, escribes `[ERROR: <mensaje exacto>]` en el archivo destino y pasas al siguiente paso. Nunca inventas contenido.

## OBJETIVO
Organizar `C:\Users\Dell\nexus-project` en la rama `forensic-state-2026-06-03` con:
1. `01_VPS_CURRENT_STATE/` — snapshot real del VPS (solo lectura)
2. `02_DIAGNOSTICO_SASL/` — evidencia del diagnóstico SASL Phase 2
3. `03_PENDING_FIXES/` — fixes documentados listos para aplicar
4. `README_PROJECT_STATE.md` — tabla de estado actual

## REGLAS ABSOLUTAS
- Solo lectura del VPS. No restart, no DROP, no rm, no down.
- No `git push` hasta mi GO explícito.
- Si un paso falla tras 3 intentos, escribir `[ERROR: ...]` y continuar.
- No commitear secretos reales. El `.env` solo se baja redactado.

## PRECONDICIONES (verificar antes de empezar)
1. `C:\Users\Dell\nexus-project` existe y es repo git.
2. `ssh nexus` responde sin password.
3. Estamos en rama `forensic-state-2026-06-03` (crear si no existe).

═══════════════════════════════════════════════════════════════
EJECUTAR EN ESTE ORDEN — NO SALTAR PASOS
═══════════════════════════════════════════════════════════════

### FASE 1 — Preparación local (PowerShell)
```powershell
Set-Location C:\Users\Dell\nexus-project

# Verificar/crear rama (compatible con PowerShell 5.1 y 7+)
git checkout forensic-state-2026-06-03 2>$null
if ($LASTEXITCODE -ne 0) { git checkout -b forensic-state-2026-06-03 }

# Crear carpetas
$folders = @("01_VPS_CURRENT_STATE","02_DIAGNOSTICO_SASL","03_PENDING_FIXES")
foreach ($f in $folders) { if (!(Test-Path $f)) { New-Item -ItemType Directory -Path $f -Force | Out-Null } }

Write-Host "[OK] Fase 1 completada. Rama: $(git branch --show-current)"
```

### FASE 2 — Snapshot del VPS (comandos SSH individuales)
Ejecutar cada comando. Si falla, escribir `[ERROR: ...]` en el archivo destino.

**2.1 Crear estructura temporal en VPS:**
```powershell
ssh nexus 'mkdir -p /tmp/nexus-snapshot/{scripts,compose,logs}'
```

**2.2 Copiar scripts reales:**
```powershell
ssh nexus 'cp -r /opt/nexus/scripts/. /tmp/nexus-snapshot/scripts/ 2>/dev/null || echo MISSING > /tmp/nexus-snapshot/scripts/_MISSING'
```

**2.3 Copiar docker-compose de cada fase:**
```powershell
ssh nexus 'cat /opt/nexus/phase-1-core/docker-compose.yml 2>/dev/null || echo "[NO EXISTE]"' > 01_VPS_CURRENT_STATE\phase-1-core-docker-compose.yml
ssh nexus 'cat /opt/nexus/phase-2-marketing/docker-compose.yml 2>/dev/null || echo "[NO EXISTE]"' > 01_VPS_CURRENT_STATE\phase-2-marketing-docker-compose.yml
ssh nexus 'cat /opt/nexus/phase-3-observability/docker-compose.yml 2>/dev/null || echo "[NO EXISTE]"' > 01_VPS_CURRENT_STATE\phase-3-observability-docker-compose.yml
```

**2.4 .env REDACTADO (nombres + longitud, NUNCA valores):**
```powershell
ssh nexus 'awk -F= "/^[A-Z]/{v=\$1; sub(/^[^=]*=/,\"\"); print v\"=<\"length(\$0)\" chars>\"} !/^[A-Z]/{print}" /opt/nexus/.env' > 01_VPS_CURRENT_STATE\env_redacted.txt
```

**2.5 Exportar workflows n8n:**
```powershell
ssh nexus 'docker exec nexus-n8n n8n export:workflow --all --pretty --output=/home/node/.n8n/_export.json 2>/dev/null && docker cp nexus-n8n:/home/node/.n8n/_export.json /tmp/nexus-snapshot/n8n_workflows.json 2>/dev/null || echo "[ERROR: n8n export fallo]" > /tmp/nexus-snapshot/n8n_workflows.json'
```

**2.6 Estado de contenedores:**
```powershell
ssh nexus 'docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"' > 01_VPS_CURRENT_STATE\docker_ps.txt
```

**2.7 Logs de Phase 2 + DB (FIX: comillas simples por fuera para no interpolar $c en PowerShell):**
```powershell
ssh nexus 'for c in nexus-evolution nexus-listmonk nexus-postiz nexus-pgbouncer nexus-postgres; do echo "===== $c ====="; docker logs $c --tail 50 2>&1; echo; done' > 01_VPS_CURRENT_STATE\phase2_and_db_logs.txt
```

**2.8 Git diff VPS vs origin:**
```powershell
ssh nexus 'cd /opt/nexus && git fetch origin >/dev/null 2>&1 || true; echo "== branch =="; git branch -vv; echo "== status =="; git status; echo "== diff vs origin/deploy-v1.3 =="; git diff origin/deploy-v1.3' > 01_VPS_CURRENT_STATE\git_diff_vps_vs_origin.txt
```

**2.9 Empaquetar y traer snapshot:**
```powershell
ssh nexus 'tar czf /tmp/nexus-snapshot.tar.gz -C /tmp nexus-snapshot'
scp nexus:/tmp/nexus-snapshot.tar.gz 01_VPS_CURRENT_STATE\nexus-snapshot.tar.gz
# Extraer contenido del tarball en la carpeta
if (Test-Path 01_VPS_CURRENT_STATE\nexus-snapshot.tar.gz) {
    tar xzf 01_VPS_CURRENT_STATE\nexus-snapshot.tar.gz -C 01_VPS_CURRENT_STATE --strip-components=1
}
```

**2.10 Manifest:**
```powershell
$manifest = "NEXUS VPS SNAPSHOT — $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n"
Get-ChildItem -Recurse 01_VPS_CURRENT_STATE | Select-Object FullName, Length | ForEach-Object { $manifest += "$($_.FullName) | $($_.Length)`n" }
$manifest | Out-File -Encoding utf8 01_VPS_CURRENT_STATE\_MANIFEST.txt
```

### FASE 3 — Diagnóstico SASL Phase 2 (solo lectura)
Ejecutar cada comando. Guardar TODO output en `02_DIAGNOSTICO_SASL/`.

**3.1 Crear carpeta temporal en VPS:**
```powershell
ssh nexus 'mkdir -p /tmp/sasl-diag'
```

**3.2 DBs existentes (FIX: comillas simples por fuera para que PowerShell no interpole $POSTGRES_PASSWORD):**
```powershell
ssh nexus 'source /opt/nexus/.env && docker exec -e PGPASSWORD=$POSTGRES_PASSWORD nexus-postgres psql -U nexus_admin -d postgres -c "\\l" 2>&1 | grep -iE "evolution|listmonk|postiz|nexus_core|dify|n8n|litellm" || echo "[NINGUNA DB DE PHASE 2]"' > 02_DIAGNOSTICO_SASL\01_dbs_existentes.txt
```

**3.3 Roles y passwords:**
```powershell
ssh nexus 'source /opt/nexus/.env && docker exec -e PGPASSWORD=$POSTGRES_PASSWORD nexus-postgres psql -U nexus_admin -d postgres -c "SELECT rolname, rolcanlogin, (rolpassword IS NOT NULL) AS has_pw FROM pg_authid WHERE rolname IN ('"'"'evolution_app'"'"','"'"'listmonk_app'"'"','"'"'postiz_app'"'"','"'"'nexus_admin'"'"') ORDER BY rolname;"' > 02_DIAGNOSTICO_SASL\02_roles_passwords.txt
```

**3.4 Método de password (scram vs md5):**
```powershell
ssh nexus 'source /opt/nexus/.env && docker exec -e PGPASSWORD=$POSTGRES_PASSWORD nexus-postgres psql -U nexus_admin -d postgres -c "SELECT rolname, LEFT(rolpassword,11) AS pw_prefix FROM pg_authid WHERE rolname IN ('"'"'evolution_app'"'"','"'"'listmonk_app'"'"','"'"'postiz_app'"'"');"' > 02_DIAGNOSTICO_SASL\03_password_method.txt
```

**3.5 Config PgBouncer:**
```powershell
ssh nexus 'docker exec nexus-pgbouncer sh -c "cat /etc/pgbouncer/pgbouncer.ini; echo ---USERLIST---; cat /etc/pgbouncer/userlist.txt"' > 02_DIAGNOSTICO_SASL\04_pgbouncer_config.txt
```

**3.6 Bootstrap scripts contemplan Phase 2?**
```powershell
ssh nexus 'grep -rniE "evolution|listmonk|postiz" /opt/nexus/scripts/04-init-databases.sh /opt/nexus/scripts/06-deploy-phase-2.sh 2>&1 | head -40' > 02_DIAGNOSTICO_SASL\05_bootstrap_phase2.txt
```

**3.7 auth_query (nexus_admin lee pg_shadow?):**
```powershell
ssh nexus 'source /opt/nexus/.env && docker exec -e PGPASSWORD=$POSTGRES_PASSWORD nexus-postgres psql -U nexus_admin -d postgres -c "SELECT usename FROM pg_shadow LIMIT 1;" 2>&1' > 02_DIAGNOSTICO_SASL\06_auth_query.txt
```

**3.8 Test DIRECTO a Postgres sin pgbouncer (password real del compose evolution):**
```powershell
ssh nexus 'docker exec nexus-postgres bash -c "PGPASSWORD=e45915d536ff1c93a5233102ed099ee6 psql -h 127.0.0.1 -p 5432 -U evolution_app -d evolution -c \"SELECT 1;\"" 2>&1 || echo "[FALLA DIRECTA A POSTGRES]"' > 02_DIAGNOSTICO_SASL\07_test_directo_sin_pgbouncer.txt
```

**3.9 Empaquetar diagnóstico:**
```powershell
ssh nexus 'tar czf /tmp/sasl-diag.tar.gz -C /tmp sasl-diag'
scp nexus:/tmp/sasl-diag.tar.gz 02_DIAGNOSTICO_SASL\sasl-diag.tar.gz
```

### FASE 4 — Fixes pendientes (generar localmente)
Crear estos archivos con contenido exacto:

**4.1 `03_PENDING_FIXES/HEALTHCHECK_WORKERS_FIX.md`**
```markdown
# FIX P3 — Healthcheck de n8n workers (cosmético)

Causa: el healthcheck `wget http://localhost:5678/healthz` apunta al puerto del n8n main; el worker no expone HTTP → Connection refused × 13.926 (falso negativo).

## Fix (Opción A — la oficial de n8n)
En `phase-1-core/docker-compose.yml`, dentro de los servicios `n8n-worker` y `n8n-worker-2`, agregar al bloque `environment`:

```yaml
QUEUE_HEALTH_CHECK_ACTIVE: "true"
```

Con esto el worker levanta su propio /healthz en :5678 y el healthcheck existente pasa sin cambios.

## NO RECREAR contenedores solo por esto
Es P3. Aplicar este cambio JUNTO con el siguiente recreate (idealmente el del fix de Phase 2 SASL) para un solo `docker compose up -d --no-deps n8n-worker n8n-worker-2`.
```

**4.2 `03_PENDING_FIXES/ROTATE_KEYS_CHECKLIST.md`**
```markdown
# CHECKLIST — Rotación de llaves expuestas (antes de cliente real)

Expuestas en logs/chat (consta en transcripts):
- [ ] LITELLM_MASTER_KEY (regenerar en /opt/nexus/.env y reiniciar litellm)
- [ ] N8N_ENCRYPTION_KEY (⚠️ rotar invalida credenciales guardadas → re-importar)
- [ ] PG_NEXUS_CORE_PASS, PG_N8N_PASS, PG_DIFY_PASS (ALTER USER en Postgres + actualizar .env)
- [ ] DEEPSEEK_API_KEY (regenerar en panel DeepSeek)
- [ ] SMTP_PASS Resend (regenerar en Resend)
- [ ] Hostinger API token (regenerar en hPanel API)
- [ ] DIFY_LEAD_QUALIFIER_KEY, DIFY_CONCIERGE_KEY (regenerar en Dify → API Access)

Aplicar DESPUÉS de los fixes de Phase 2, no antes (porque cambiar passwords ahora puede romper cosas que estás depurando).
```

### FASE 5 — README principal
Crear `README_PROJECT_STATE.md` en la raíz:

```markdown
# nexus-project — Estado del proyecto (snapshot 03-jun-2026)

Esta rama (`forensic-state-2026-06-03`) NO toca deploy-v1.3.

## Estructura
| Carpeta | Qué contiene |
|---|---|
| `01_VPS_CURRENT_STATE/` | Snapshot REAL del VPS (scripts, composes, .env redactado, workflows n8n, logs, git diff) |
| `02_DIAGNOSTICO_SASL/` | Evidencia del diagnóstico SASL Phase 2 (7 archivos de evidencia) |
| `03_PENDING_FIXES/` | Fixes sin aplicar (healthcheck workers, rotación llaves) |

## Estado real (al 03-jun)
| Componente | Estado |
|---|---|
| Phase 1 core | ✅ sano (Up 5 días) |
| Lead Qualifier | ✅ GO (COLD/WARM/HOT en DB) |
| Workers "unhealthy" | ✅ falso negativo — fix P3 listo en 03_PENDING_FIXES/ |
| Phase 2 (Evo/List/Postiz) | 🔴 CRASH-LOOP por SASL — evidencia en 02_DIAGNOSTICO_SASL/ |
| Backups | 🔴 cero |
| Llaves expuestas | 🔴 sin rotar |
| Carga VPS | 🟠 ~70 contenedores (mayoría ajenos a NEXUS, instalados el 16-may) |

## Siguiente paso lógico
1. Analizar evidencia en `02_DIAGNOSTICO_SASL/`.
2. Decidir fix SASL.
3. Aplicar fix + healthcheck workers en MISMO recreate.
4. Luego TLS Phase 2 → QR WhatsApp → SMTP → Evolution credential en n8n.
5. Backups Restic.
6. Rotación de llaves.
```

### FASE 6 — Commit (sin push)
```powershell
Set-Location C:\Users\Dell\nexus-project
git add 01_VPS_CURRENT_STATE 02_DIAGNOSTICO_SASL 03_PENDING_FIXES README_PROJECT_STATE.md
git status
git commit -m "docs(forense): snapshot VPS + diagnostico SASL + fixes pendientes (03-jun)"
Write-Host "[OK] Commit realizado en rama: $(git branch --show-current)"
Write-Host "[INFO] NO hacer git push. Esperar GO manual."
```

═══════════════════════════════════════════════════════════════
REPORTE FINAL OBLIGATORIO
═══════════════════════════════════════════════════════════════
Al terminar, reportar EXACTAMENTE:
1. ¿Cuántos archivos se commitearon?
2. Tabla: archivo | tamaño (bytes) | ¿vacío o error?
3. ¿Qué pasos de Fase 2 o 3 fallaron y por qué?
4. Confirmar rama activa es `forensic-state-2026-06-03` y NO `deploy-v1.3`
5. **DICTAMEN SASL:** ¿Es (A) DBs/usuarios no existen, (B) password mismatch, (C) pgbouncer mal configurado, o (D) otra? Cita el archivo de evidencia que lo prueba. NO inventes.
6. Esperar mi GO para `git push origin forensic-state-2026-06-03`
