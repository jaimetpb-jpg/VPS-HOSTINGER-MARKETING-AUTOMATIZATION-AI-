# 🚀 NEXUS SUPREME v1.2 · Deploy Kit Endurecido

> **v1.1 → v1.2:** 10 bugs identificados por auditoría externa de Kimi, todos arreglados.
> Esta es la versión que **sobrevive un segundo deploy**.

---

## 🐛 BUGS ARREGLADOS DESDE v1.1

| # | Bug | Fix v1.2 |
|---|---|---|
| 1 | `init-dbs.sql` con `sed` no idempotente, frágil con caracteres especiales en passwords, solo corre 1 vez | **`scripts/04-init-databases.sh`** ejecuta SQL con bloques `DO $$ ... IF NOT EXISTS`, pasa passwords vía `psql -v` (no sed). Corre cuantas veces necesites |
| 2 | Modelos Anthropic `claude-sonnet-4-5` no existen → router roto día 1 | IDs verificados contra docs oficiales 2026: `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5-20251001` |
| 3 | Postiz en `:latest` mientras todo lo demás pinneado | Pinneado a `v2.21.7` (release estable abril 2026) |
| 4 | Dify Sandbox con `ENABLE_NETWORK: true` = vector de ataque (acceso a red interna desde código arbitrario) | **Sandbox eliminado** día 1. Code execution se reactiva semana 2 con `network: false` |
| 5 | HITL enviaba WhatsApp con link a `panel.${DOMAIN}` inexistente | **n8n Forms nativos** (n8n 1.30+). URL real: `https://n8n.${DOMAIN}/form/nexus-approval-form` |
| 6 | `prometheus.yml` con targets de exporters no desplegados → alertas falsas | Targets fantasma **comentados** hasta semana 2 con exporters reales |
| 7 | Puerto Beszel 45876 bloqueado por UFW | `00-prepare-vps.sh` abre 45876 **condicional** y solo desde localhost |
| 8 | `.env` con 40+ vars incluyendo semana 2-3 = ruido cognitivo | **Split**: `.env` (activo fases 1-3) + `.env.future` (semana 2+) |
| 9 | NocoBase como CRM día 2 = over-engineering (2h config manual) | **Tabla `leads` simple** en `nexus_core`, gestionada desde n8n. NocoBase entra semana 3 si justifica |
| 10 | Backup con staging en `/tmp` (tmpfs/RAM) → puede causar OOM | **Stdin pipe directo a restic**, sin archivos temporales |

### Bonus aceptado de Kimi (Opportunity K)
- **PgBouncer** (50 MB) agregado entre apps y Postgres. Con 10 apps × 25 conexiones = 250, fácil rebasar el límite default de Postgres (100). Pool de transacciones reduce esto a 25-50 conexiones reales al backend.

### Bonus aceptado de Kimi (Opportunity I)
- `01-generate-secrets.sh` ahora **genera el hash htpasswd automáticamente** y lo inyecta en `configs/traefik-basic-auth.yml`. Cero fricción manual.

---

## 📋 ORDEN CORRECTO DE DEPLOY

```bash
# 1. Preparar VPS (Docker, UFW, swap, redes Docker)
bash scripts/00-prepare-vps.sh

# 2. Generar secretos + htpasswd + dividir .env / .env.future
bash scripts/01-generate-secrets.sh
nano .env  # completar API keys

# 3. Validar API keys ANTES de levantar 13 containers
bash scripts/02-validate-secrets.sh

# 4. Levantar SOLO Postgres (necesario para init de DBs)
bash scripts/03-deploy-postgres-first.sh

# 5. Inicializar DBs/users idempotentemente
bash scripts/04-init-databases.sh

# 6. Levantar resto de fase 1 (Dify, n8n, LiteLLM, etc.)
bash scripts/05-deploy-phase-1.sh

# 7. Config manual Dify + n8n (~30 min)
# Ver docs/BOOTSTRAP_SEQUENCE.md

# 8. Fase 2 - Marketing
bash scripts/06-deploy-phase-2.sh

# 9. Fase 3 - Observabilidad
bash scripts/07-deploy-phase-3.sh

# 10. Backup cron diario (cuando hayas configurado .env.future con restic)
bash scripts/08-backup-restic.sh
```

---

## 📦 ESTRUCTURA v1.2

```
nexus-supreme-v1.2/
├── README.md
├── .env.example                       # con vars activas + future commented
├── phase-1-core/
│   ├── docker-compose.yml             # SIN dify-sandbox, CON pgbouncer
│   └── litellm-config.yaml            # modelos Anthropic REALES
├── phase-2-marketing/
│   └── docker-compose.yml             # SIN NocoBase, Postiz v2.21.7
├── phase-3-observability/
│   └── docker-compose.yml
├── db-init/                            # NUEVO en v1.2
│   ├── 00-bootstrap.sql               # DO $$ IF NOT EXISTS, idempotente
│   └── 01-nexus-core.sql              # tenants + ai_task + leads
├── scripts/
│   ├── 00-prepare-vps.sh              # abre 45876 condicional
│   ├── 01-generate-secrets.sh         # genera htpasswd automático
│   ├── 02-validate-secrets.sh         # test API keys
│   ├── 03-deploy-postgres-first.sh    # NUEVO: solo postgres standalone
│   ├── 04-init-databases.sh           # NUEVO: psql -v, idempotente
│   ├── 05-deploy-phase-1.sh           # resto de fase 1
│   ├── 06-deploy-phase-2.sh
│   ├── 07-deploy-phase-3.sh
│   ├── 08-backup-restic.sh            # stdin pipe, sin staging
│   └── 09-export-credentials.sh
├── configs/
│   ├── traefik-basic-auth.yml         # auto-generado en step 01
│   └── prometheus.yml                 # phantom targets COMENTADOS
├── workflows/
│   ├── n8n-content-factory-v1.2.json  # con n8n Forms (HITL real)
│   ├── n8n-lead-qualifier-v1.2.json   # sin NocoBase, sin panel fantasma
│   └── n8n-whatsapp-concierge-v1.2.json
└── docs/
    ├── BOOTSTRAP_SEQUENCE.md
    ├── ARCHITECTURE.md
    ├── HITL_GUIDE.md
    ├── HONEST_LIMITATIONS.md
    └── TROUBLESHOOTING.md
```

---

## 🎯 RAM ESTIMADA POR FASE

| Fase | Servicios | RAM |
|---|---|---|
| 1 (día 1) | Traefik + Postgres + PgBouncer + Redis + Qdrant + LiteLLM + Dify(api/worker/web) + n8n(main/worker) + Uptime Kuma | **~11 GB** |
| 2 (día 2) | + Evolution + Listmonk + Postiz | **+3 GB** = 14 GB |
| 3 (día 3) | + Plausible + Beszel + Dozzle | **+1.5 GB** = 15.5 GB |

VPS 32 GB → headroom 16 GB para crecimiento.

**Cambio vs v1.1:**
- `-NocoBase` (~700 MB)
- `-Dify Sandbox` (~100 MB)
- `+PgBouncer` (~50 MB)
- Neto: -750 MB

---

## ✅ DIFERENCIAS CLAVE CON v1.1

| Aspecto | v1.1 | v1.2 |
|---|---|---|
| Modelos Anthropic en LiteLLM | ❌ Strings inexistentes | ✅ IDs verificados mayo 2026 |
| Init de DBs | ⚠ Funciona 1 vez (sed + initdb.d) | ✅ Idempotente, redeploys seguros |
| HITL | 🚫 Link a panel fantasma | ✅ n8n Forms reales |
| Dify Sandbox | ⚠ Expuesto con red | ✅ Eliminado fase 1 |
| Postiz pin | `:latest` (impredecible) | `v2.21.7` |
| Backup OOM risk | ⚠ Staging en /tmp tmpfs | ✅ Stdin pipe, sin staging |
| Postgres pool | ❌ Sin PgBouncer | ✅ PgBouncer (1000→25 conn) |
| `.env` | Monolítico 40+ vars | Split activo/future |
| Prometheus | ⚠ Targets fantasma | ✅ Comentados hasta sem 2 |
| UFW + Beszel | ⚠ Puerto bloqueado | ✅ Apertura condicional |
| NocoBase CRM día 2 | ⚠ 2h setup manual | ✅ Tabla `leads` simple |

---

*v1.2 · Endurecida · Cada bug del audit cerrado con código · Mayo 2026*
