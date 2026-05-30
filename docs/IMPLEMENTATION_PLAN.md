# Implementation Plan

## Fase 0 — Preparación
1. Crear n8n API key.
2. Crear Dify App "Lead Qualifier".
3. Crear Evolution instance.
4. Crear Supabase/Neon Postgres o endpoint REST equivalente.
5. Llenar `.env`.

## Fase 1 — Validación local
```bash
python scripts/validate_project.py
python scripts/render_workflow.py
```

## Fase 2 — Deploy a n8n por API
```bash
python scripts/n8n_api_deploy.py --mode create
```

Si el API create falla por formato interno de n8n, importar el JSON renderizado manualmente desde la UI. El artefacto sigue siendo usable porque n8n guarda workflows como JSON.

## Fase 3 — Configuración manual
Revisar nodos HTTP Request, configurar credenciales, confirmar URL del webhook y activar workflow.

## Fase 4 — Smoke Test
```bash
python scripts/smoke_test_webhook.py
python scripts/go_nogo.py
```

## Fase 5 — Expansión
Daily Report, Competitor Watch, RAG Concierge, Website Intelligence, Content Approval + Postiz.
