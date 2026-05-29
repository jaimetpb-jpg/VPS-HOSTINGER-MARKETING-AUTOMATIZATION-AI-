# NEXUS SUPREME v1.3
## Automatización de Agencia de Marketing Digital con AI

> Sistema completo de automatización de marketing con AI y agentes autónomos.
> MVP: Lead → Dify califica → Postgres → WhatsApp → operador → log.

---

## Estado actual

- **Versión:** v1.3 (28 mayo 2026)
- **Branch productiva:** `deploy-v1.3`
- **VPS:** Hostinger KVM8 · 32GB RAM · 200GB SSD · Ubuntu 24
- **Dominio:** ainexus.mx (wildcard DNS)
- **Equipo Multi-AI:** 5 agentes activos (Codex, Kimi, Grok, Gemini, Claude Code)

---

## Stack tecnológico

```
Phase 1 — Core AI:
  Traefik v3.1 + Postgres 16 + PgBouncer + Redis 7.4 + Qdrant v1.12
  LiteLLM v1.52 + Dify 0.13.2 + n8n 1.70.0 (queue mode, main + 2 workers)
  Uptime Kuma

Phase 2 — Marketing:
  Evolution API v2.2 + Listmonk v4.1 + Postiz v2.11.5

Phase 3 — Observabilidad:
  Plausible CE v2.1 + Beszel 0.9.1 + Restic backups
```

---

## Estructura del repositorio

```
.
├── README.md                          ← este archivo
├── NEXUS_AI_TEAM_RULES.md             ← reglas del equipo Multi-AI
├── DECISIONES.md                      ← registro de decisiones técnicas
├── QUICKSTART.md                      ← arranque hora-por-hora
├── CHECKLIST_GATE.md                  ← gate pre-deploy
├── CLAUDE_CODE_INSTRUCCIONES.md       ← instrucciones VPS
├── CODEX_INSTRUCCIONES.md             ← instrucciones cirugía local
│
├── .env.example                       ← spec de variables (con markers)
├── .env.future.example                ← variables para fases futuras
├── .gitignore                         ← protección contra leaks
│
├── agents/                            ← definición de los 5 agentes AI
│   ├── CODEX_AGENT.md
│   ├── KIMI_AGENT.md                  ← auditor líder (GO/NO GO final)
│   ├── GROK_AGENT.md                  ← auditor de seguridad
│   ├── GEMINI_AGENT.md                ← auditor de configuración
│   └── CLAUDE_CODE_AGENT.md           ← ejecutor único del VPS
│
├── scripts/                           ← 14 scripts del deploy
│   ├── 00-prepare-vps.sh
│   ├── 01-generate-secrets.sh
│   ├── 02-validate-secrets.sh         ← REPARADO v1.3
│   ├── 03-deploy-postgres-first.sh
│   ├── 04-init-databases.sh
│   ├── 05-deploy-phase-1.sh
│   ├── 06-deploy-phase-2.sh
│   ├── 07-deploy-phase-3.sh
│   ├── 08-backup-restic.sh
│   ├── 09-export-credentials.sh
│   ├── 99-smoke-test.sh
│   ├── check-env-drift.sh
│   ├── preflight-hostinger.sh
│   ├── rollback-snapshot.sh
│   └── pre-commit-validate.sh         ← gate automático pre-push
│
├── skills/                            ← orquestador de skills
│   └── skills-runner.sh
│
├── configs/                           ← configs runtime (gitkeep)
│   └── .gitkeep
│
├── phase-1-core/
│   ├── docker-compose.yml
│   └── litellm-config.yaml
├── phase-2-marketing/
│   └── docker-compose.yml
├── phase-3-observability/
│   └── docker-compose.yml
│
├── db-init/
│   ├── 00-bootstrap.sql
│   └── 01-nexus-core-schema.sql
│
└── workflows/
    ├── n8n-lead-qualifier-v1.3.json
    ├── n8n-whatsapp-concierge-v1.3.json
    └── n8n-content-factory-v1.3.json
```

---

## Equipo Multi-AI

```
James (humano · orquestador final)
  │
  ├─ Codex      → genera código local + pre-commit
  │              ↓
  ├─ Kimi       → auditor LÍDER (GO/NO GO final)
  │   Grok      → auditor seguridad (paralelo)
  │   Gemini    → auditor config/logs (paralelo)
  │              ↓
  └─ Claude Code → único ejecutor del VPS

Backup (si falla 2x): Cursor + Antigravity + JetBrains
```

Ver `NEXUS_AI_TEAM_RULES.md` para reglas completas.

---

## Arranque rápido

Ver `QUICKSTART.md` para arranque hora-por-hora.

Resumen:
1. Codex genera/edita código → `pre-commit-validate.sh` → push
2. Kimi + Grok + Gemini auditan en paralelo
3. Kimi decide GO/NO GO
4. James aprueba (60s gate)
5. Claude Code ejecuta deploy en VPS
6. Smoke test real → MVP activo

---

## Fases del deploy

| Fase | Servicios | Script |
|---|---|---|
| 0 | Preparar VPS | `00-prepare-vps.sh` |
| 1 | Postgres + Redis + Qdrant + LiteLLM + Dify + n8n | `05-deploy-phase-1.sh` |
| 2 | Evolution + Listmonk + Postiz | `06-deploy-phase-2.sh` |
| 3 | Plausible + Beszel + backups | `07-deploy-phase-3.sh` |

---

## Documentación de soporte

- `NEXUS_AI_TEAM_RULES.md` — reglas del equipo
- `DECISIONES.md` — registro de decisiones técnicas
- `CHECKLIST_GATE.md` — gate de validación pre-deploy
- `CLAUDE_CODE_INSTRUCCIONES.md` — pasos en el VPS
- `CODEX_INSTRUCCIONES.md` — cirugía de código local
- `agents/*.md` — definición operativa de cada AI

---

*NEXUS SUPREME v1.3 · 28 mayo 2026*
