# FIX SASL PHASE 2 — Plan quirúrgico (solo lectura hasta mi GO)

## IDENTIDAD
Eres un agente de operaciones forenses. NO ejecutas nada destructivo sin mi GO explícito. Solo lectura y propuesta. Si un comando de lectura falla, reportas el error exacto.

## REGLAS ABSOLUTAS
- NUNCA sobrescribir un archivo de config en vivo con `cat >` o heredoc.
- NUNCA hacer reload/HUP/restart sin mi GO explícito.
- Siempre backup antes de tocar.
- Solo lectura en este prompt. NO aplicar cambios todavía.

## OBJETIVO
Diagnosticar y proponer el fix exacto para el SASL fail de Phase 2 (evolution/listmonk/postiz), sin poner en riesgo Phase 1 (n8n, dify, litellm pasan por pgbouncer:6432).

═══════════════════════════════════════════════════════════════
EJECUTAR EN ESTE ORDEN — SOLO LECTURA HASTA MI GO
═══════════════════════════════════════════════════════════════

### PASO 1 — Backup de pgbouncer.ini (preventivo)
```powershell
ssh nexus 'docker exec nexus-pgbouncer cp /etc/pgbouncer/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini.bak.$(date +%s) && ls -la /etc/pgbouncer/pgbouncer.ini.bak.*'
```
Reportar: ¿se creó el backup? ¿Ruta exacta?

### PASO 2 — Leer config actual (ya tenemos 04_pgbouncer_config.txt, pero verificar en vivo)
```powershell
ssh nexus 'docker exec nexus-pgbouncer cat /etc/pgbouncer/pgbouncer.ini'
```
Guardar output en un archivo temporal local: `pgbouncer_ini_vivo.txt`

### PASO 3 — Leer userlist.txt completo
```powershell
ssh nexus 'docker exec nexus-pgbouncer cat /etc/pgbouncer/userlist.txt'
```
Guardar output en: `userlist_vivo.txt`

### PASO 4 — Análisis y propuesta (NO tocar nada todavía)

Con base en los archivos leídos, responder EXACTAMENTE:

**4a) ¿Cuál es el sed exacto que agrega evolution/listmonk/postiz al [databases] sin tocar el resto?**

El sed debe:
- Insertar DESPUÉS de la línea `postgres = host=postgres port=5432 auth_user=nexus_admin`
- Agregar exactamente estas 3 líneas:
  ```
  evolution = host=postgres port=5432 auth_user=nexus_admin
  listmonk = host=postgres port=5432 auth_user=nexus_admin
  postiz = host=postgres port=5432 auth_user=nexus_admin
  ```
- NO modificar ninguna otra línea del archivo

Proponer el comando sed completo y mostrar qué haría (dry-run con `sed -n` o similar).

**4b) ¿El hash de nexus_admin en userlist.txt empieza con `SCRAM-SHA-256$...` o es MD5 plano?**

Si es SCRAM-SHA-256: reportar "Problema #2 no existe, no tocar userlist.txt"
Si es MD5 plano o sin prefijo: reportar "Problema #2 existe, necesita regeneración" y proponer:
```sql
ALTER USER nexus_admin WITH ENCRYPTED PASSWORD '<misma_password>';
```
Luego copiar el nuevo hash de pg_shadow a userlist.txt.

**4c) ¿Rollback exacto si algo sale mal?**

Proponer:
```bash
ssh nexus "docker exec nexus-pgbouncer cp /etc/pgbouncer/pgbouncer.ini.bak.<TIMESTAMP> /etc/pgbouncer/pgbouncer.ini"
ssh nexus "docker kill --signal=HUP nexus-pgbouncer"
```

### PASO 5 — Reporte de propuesta (NO ejecutar)

Generar un archivo `PROPUESTA_FIX_SASL.md` con:
- El sed exacto propuesto
- El estado de userlist.txt
- El rollback exacto
- Mi dictamen: ¿es seguro aplicar? ¿Hay riesgo para Phase 1?

═══════════════════════════════════════════════════════════════
REPORTE FINAL OBLIGATORIO
═══════════════════════════════════════════════════════════════
Al terminar, reportar EXACTAMENTE:
1. ¿Se creó el backup de pgbouncer.ini? ¿Ruta?
2. ¿Cuántas líneas tiene pgbouncer.ini en vivo?
3. ¿Cuál es el contenido exacto de la sección [databases]?
4. ¿El hash de nexus_admin en userlist.txt es SCRAM-SHA-256 o MD5?
5. El sed propuesto (comando completo)
6. El rollback propuesto (comando completo)
7. Dictamen: ¿es seguro aplicar? ¿Hay riesgo para Phase 1?

⛔ NO aplicar el sed todavía. NO hacer HUP. NO tocar userlist.txt.
⛔ Esperar mi GO explícito para ejecutar el paso 4a y el HUP.
