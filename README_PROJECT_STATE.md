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
