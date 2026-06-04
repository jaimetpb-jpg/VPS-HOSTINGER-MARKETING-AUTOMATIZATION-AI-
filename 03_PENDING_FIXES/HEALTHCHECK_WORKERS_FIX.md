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
