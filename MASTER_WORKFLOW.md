# NEXUS SUPREME · MASTER WORKFLOW · Multi-AI Team
## La estrategia más efectiva para arrancar rápido, sin errores, expandiéndose

---

## PRINCIPIO RECTOR

> GitHub = fuente de verdad única.  
> Claude Code = integrador final y operador del VPS.  
> Cada AI trabaja en su carril. Nadie toca el carril del otro.  
> El humano (Jaime) interviene solo en decisiones de arquitectura, conflictos de criterio, y aprobaciones de PR a `main`.

---

## 1. ESTRUCTURA DE RAMAS

```
main                    ← producción (solo merge desde deploy-v1.3 via PR aprobado por Jaime)
deploy-v1.3             ← rama de integración principal (Claude Code hace merge aquí)
  ├── codex/qa          ← Codex: validación QA + nuevos workflows
  ├── kimi/audit        ← Kimi: auditoría de bugs + docs
  ├── gemini/research   ← Gemini CLI: investigación + README + docs técnicas
  └── grok/intel        ← Grok: contenido marketing + inteligencia competidora
```

**Regla de oro:** Nadie escribe directo a `deploy-v1.3`. Cada AI commitea en su rama. Claude Code hace el merge después de revisar.

---

## 2. SPRINTS DE 24 HORAS (ciclo continuo, 2 laptops 24/7)

```
┌─────────────────────────────────────────────────────────────┐
│  HORA 00-02  │ PLANNING                                      │
│              │ Jaime define prioridades del día              │
│              │ Claude Code crea issues en GitHub             │
│              │ Cada AI recibe su brief                       │
├─────────────────────────────────────────────────────────────┤
│  HORA 02-18  │ EJECUCIÓN PARALELA                            │
│              │ Claude Code → VPS: deploy, scripts, debug     │
│              │ Codex       → QA: validación, workflows       │
│              │ Kimi        → Audit: bugs, seguridad, docs    │
│              │ Gemini CLI  → Research: docs, alternativas    │
│              │ Grok        → Intel: tendencias, competencia  │
├─────────────────────────────────────────────────────────────┤
│  HORA 18-20  │ INTEGRACIÓN (Claude Code)                     │
│              │ Revisar PRs de cada AI                        │
│              │ Merge en deploy-v1.3                          │
│              │ Correr smoke tests en VPS                     │
├─────────────────────────────────────────────────────────────┤
│  HORA 20-22  │ VALIDACIÓN + DEPLOY                           │
│              │ Jaime revisa resultados                       │
│              │ Si OK → merge a main                          │
│              │ Si error → Jaime interviene                   │
├─────────────────────────────────────────────────────────────┤
│  HORA 22-24  │ MONITORING + NEXT SPRINT                      │
│              │ Uptime Kuma + Beszel: alertas activas         │
│              │ n8n daily report via WhatsApp                 │
│              │ Preparar brief para sprint siguiente          │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. CRITERIOS DE PARADA (stop antes de avanzar)

Cualquier AI o Jaime puede activar STOP si:

1. `docker compose config` falla → STOP, no deployar
2. LiteLLM no devuelve `choices` con OK → STOP fase 4
3. Servicio critical DOWN (postgres, n8n, traefik) → STOP, diagnosticar
4. Merge conflict entre ramas → Jaime decide qué código gana
5. Comando destructivo (rm -rf, DROP TABLE, down -v) → mostrar y esperar confirmación de Jaime
6. Dos AIs en desacuerdo técnico → Jaime como árbitro

---

## 4. ASIGNACIÓN DE LAPTOPS

### Laptop A (Principal - Claude Code en el frente)
- Claude Code CLI ejecutando tareas de VPS/GitHub
- Terminal SSH activa a `ssh nexus`
- Monitoreo de containers: `docker stats`, Beszel, Dozzle
- Prioridad: deploy, debug, integración de código

### Laptop B (QA + Research paralelo)
- Codex: validando JSONs, scripts, workflows nuevos
- Kimi: auditando código antes de merge
- Gemini CLI: research de integraciones, docs
- Grok: inteligencia de mercado, contenido

---

## 5. FLUJO DE COMUNICACIÓN ENTRE AIs

```
[Gemini CLI] ──research──→ crea docs en gemini/research → PR → Claude Code revisa → merge
[Kimi]       ──audit──────→ abre GitHub Issues con bugs → Claude Code los cierra con fix
[Codex]      ──QA/workflows→ crea JSON en codex/qa     → PR → Claude Code valida e importa
[Grok]       ──intel/content→ crea briefs en grok/intel → Claude Code los conecta a Dify/n8n
[Claude Code] ──INTEGRA TODO──→ deploy-v1.3 → main
```

---

## 6. FASES DEL PROYECTO (estado actual y progresión)

```
FASE 0 · DONE (ayer)
  ✅ SSH configurado: ssh nexus → root@2.24.204.193
  ✅ GitHub repo vinculado
  ✅ NEXUS SUPREME v1.3 listo para deploy
  ✅ Instrucciones Claude Code y Codex creadas

FASE 1 · HOY (Día 1)
  🎯 Deploy Core Stack en VPS
  🎯 MVP funcional: Lead → Dify → Postgres → WhatsApp → Aprobación
  🎯 Test end-to-end del flujo principal
  🎯 Uptime Kuma monitoreando

FASE 2 · DÍA 2
  🎯 Evolution API (WhatsApp Business conectado)
  🎯 Listmonk (email marketing)
  🎯 Postiz v2.11.5 (social media scheduling)
  🎯 QR WhatsApp escaneado y verificado

FASE 3 · DÍA 3
  🎯 Plausible CE (analytics)
  🎯 Beszel (monitoreo VPS)
  🎯 Backup Restic configurado
  🎯 Smoke tests completos

FASE 2.5 · SEMANA 2
  🎯 Content Factory activada
  🎯 NocoBase CRM (si se justifica)
  🎯 Dify Sandbox con network:false
  🎯 Primeros leads reales fluyendo

EXPANSIÓN · SEMANA 3+
  🎯 Multi-tenant (múltiples clientes)
  🎯 Dashboards Plausible para clientes
  🎯 Automatización de onboarding
  🎯 ROI tracking por campaña
```

---

## 7. CÓDIGO MORAL Y ÉTICO DEL EQUIPO

1. **Beneficio del usuario primero** — cada decisión técnica sirve al objetivo de negocio de Jaime
2. **No ocultar errores** — si algo falla, reportar con diagnóstico completo, no silenciar
3. **Mínimo viable primero** — feature simple que funciona > feature compleja que falla
4. **Datos seguros** — nunca exponer keys, credentials, o datos de leads en logs o repos
5. **Reversibilidad** — siempre crear snapshot antes de cambio destructivo
6. **Trabajo en equipo** — el output de una AI alimenta a otra, no se duplica trabajo
7. **Humano en el loop** — Jaime tiene la última palabra en arquitectura y producción

---

## 8. MÉTRICAS DE ÉXITO (MVP)

```
✅ MVP logrado cuando:
   - curl al webhook devuelve HTTP 200 {"ok":true}
   - Lead aparece en nexus_core.leads en Postgres
   - WhatsApp llega a OPERATOR_WHATSAPP en < 30 segundos
   - n8n Forms de aprobación funcionan
   - Uptime Kuma muestra todos los servicios en verde
   - LiteLLM completa request con choices/OK
```

---

*NEXUS SUPREME v1.3 · Master Workflow · Multi-AI Team · Mayo 2026*
*Jaime Tamayo · ainexus.mx · jaimetpb@gmail.com*
