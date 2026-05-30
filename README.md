# NEXUS Lead-to-Revenue Engine v1.0
## n8n Cloud/API Edition · Audit Ready

Proyecto auditable para automatización de marketing con IA usando n8n por API directa, sin depender del VPS Hostinger self-hosted.

## Objetivo MVP

Lead entra → normalización → dedupe/log → Dify califica → n8n enruta → WhatsApp operador → aprobación humana → respuesta/log/reporte.

## Principios anti-Frankenstein

1. Un workflow principal.
2. Módulos opcionales no bloqueantes.
3. Ningún secreto hardcodeado.
4. Webhook responde temprano.
5. IA entrega JSON estructurado.
6. Postgres/Supabase es fuente de verdad.
7. Human gate donde hay riesgo comercial.
8. Error memory para aprender de fallos.
9. Todo cambio pasa por validación antes de deploy.
10. Codex implementa, Kimi audita, Claude Code solo ejecuta si hace falta.

## Contenido

```text
docs/ARCHITECTURE.md
docs/AUDIT_BRIEF.md
docs/IMPLEMENTATION_PLAN.md
docs/CODEX_TASK.md
docs/CLAUDE_TASK.md
docs/KIMI_AUDIT_TASK.md
schemas/*.json
prompts/dify/*.md
n8n/workflows/nexus_lead_to_revenue_v1.template.json
n8n/workflows/test_payload.json
scripts/*.py
```

## Uso

```bash
cp .env.example .env
python scripts/validate_project.py
python scripts/render_workflow.py
python scripts/n8n_api_deploy.py --mode dry-run
python scripts/n8n_api_deploy.py --mode create
python scripts/smoke_test_webhook.py
python scripts/go_nogo.py
```

## Modo mock de Data API

Para arrancar rápido sin Supabase/PostgREST listo, deja `DATA_API_MODE=mock` en `.env`.
El workflow mantiene `HTTP · Upsert Lead` y `HTTP · Log ai_task` como nodos no bloqueantes:
si la persistencia falla o apunta al mock, Dify y WhatsApp pueden seguir corriendo.

El archivo renderizado `n8n/workflows/nexus_lead_to_revenue_v1.rendered.json` es local y está ignorado por Git
porque puede contener keys reales. Para import manual:

1. Completa `.env` con credenciales reales de n8n, Dify y Evolution API.
2. Ejecuta `python scripts/render_workflow.py`.
3. En n8n: New Workflow → Import from file → selecciona el `.rendered.json`.
4. Revisa credenciales/headers antes de activar.
5. Activa solo después del smoke test.

## Estado

Audit-ready. No production-ready hasta que:
- n8n credentials estén creadas.
- Dify app key esté probada.
- Evolution instance esté conectada.
- Webhook test real devuelva HTTP 200 y WhatsApp llegue.
