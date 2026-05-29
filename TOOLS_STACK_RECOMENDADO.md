# NEXUS SUPREME v1.3 · TOOLS & STACK RECOMENDADO
## Herramientas, Apps, Conectores e Integraciones · Selección definitiva

---

## FILOSOFÍA DE SELECCIÓN

> "La mejor herramienta es la que ya está en producción funcionando."  
> Prioridad: self-hosted > cloud gratuito > cloud de pago mínimo  
> Regla: si se puede hacer con lo que ya está en el stack, NO se agrega nada nuevo

---

## STACK PRINCIPAL (ya configurado en NEXUS v1.3)

| Categoría | Herramienta | Por qué esta |
|---|---|---|
| Reverse Proxy / SSL | **Traefik v3** | Auto SSL, dashboard, zero-config routing |
| Base de datos | **Postgres 16 + PgBouncer** | Confiable, pool de conexiones, SQL completo |
| Cache / Queue | **Redis 7** | n8n jobs, sesiones, rate limiting |
| Vector DB | **Qdrant** | Memoria semántica para AI agents |
| AI Router | **LiteLLM** | Un endpoint, múltiples modelos, costo control |
| AI Platform | **Dify** | UI para crear apps AI sin código |
| Automation | **n8n (1 main + 2 workers)** | Workflows visuales, self-hosted, webhooks |
| WhatsApp | **Evolution API v2** | WhatsApp Business sin pagar Meta API |
| Email Marketing | **Listmonk** | Listas, campañas, self-hosted, SMTP |
| Social Media | **Postiz v2.11.5** | Multi-plataforma, scheduling |
| Analytics | **Plausible CE** | Privacy-first, GDPR, sin cookies |
| VPS Monitor | **Beszel** | Métricas del servidor en tiempo real |
| Container Logs | **Dozzle** | Ver logs de Docker desde browser |
| Uptime | **Uptime Kuma** | Alertas de caída de servicios |
| Backup | **Restic** | Backup incremental cifrado a S3/Backblaze |

---

## INTEGRACIONES EXTERNAS RECOMENDADAS (fuera del VPS)

### Comunicación
| Tool | Plan | Para qué |
|---|---|---|
| **WhatsApp Business** | Gratis (número real) | Canal principal de comunicación con leads |
| **Resend** | Free (3k emails/mes) | SMTP para Listmonk, confiable, entregable |
| **Twilio** (opcional) | Pay-as-go | SMS backup si WhatsApp falla |

### DNS y Dominio
| Tool | Plan | Para qué |
|---|---|---|
| **Cloudflare** | Free | DNS para ainexus.mx, DDoS protection, orange cloud |
| **Hostinger** | Ya tienes | VPS KVM8, DNS secundario |

### AI / LLM (sin API, con planes de suscripción)
| Tool | Plan | Para qué en el equipo |
|---|---|---|
| **Claude.ai** | Pro/Team | Claude Code CLI — implementa todo en VPS |
| **ChatGPT** / **Codex** | Plus | QA de workflows, validación de JSON |
| **Gemini Advanced** | Google One AI | Research, documentación técnica |
| **Grok** | X Premium | Intel de mercado, contenido con contexto real |
| **Kimi** | Free/Plus | Auditoría de código, contexto largo |
| **DeepSeek** | API barata | Motor LLM dentro del stack (LiteLLM → DeepSeek) |

### Captura de Leads (entrada al funnel)
| Tool | Plan | Por qué |
|---|---|---|
| **Tally.so** | Free (ilimitado) | Formularios bonitos, webhook nativo a n8n |
| **n8n Forms** | Ya incluido | HITL y aprobaciones internas |
| **Cal.com** | Free | Agendar demos, integra con n8n |

### Almacenamiento y Backup
| Tool | Plan | Para qué |
|---|---|---|
| **Backblaze B2** | Free 10GB | Restic backup destino |
| **Cloudflare R2** | Free 10GB/mes | Alternativa a S3, sin egress fees |

### Monitoreo Externo
| Tool | Plan | Para qué |
|---|---|---|
| **BetterUptime** | Free | Alertas de uptime externas (fuera del VPS) |
| **Sentry** | Free 5k errors | Error tracking en Dify/n8n |

---

## CONECTORES / WEBHOOKS CRÍTICOS

```
[Tally Form] ──webhook──→ n8n /webhook/lead-intake
[n8n]        ──HTTP──────→ Dify /v1/chat-messages (Lead Qualifier)
[Dify]       ──responde──→ n8n (JSON con clasificación)
[n8n]        ──HTTP──────→ Evolution API /message/sendText
[Evolution]  ──WhatsApp──→ OPERATOR_WHATSAPP
[n8n Forms]  ──aprobación→ n8n continúa workflow
[n8n]        ──INSERT─────→ Postgres nexus_core.leads
[n8n]        ──INSERT─────→ Postgres nexus_core.ai_task
[Plausible]  ──pixel──────→ Landing page ainexus.mx (analytics)
[Listmonk]   ──SMTP──────→ Resend → bandeja del lead
[Postiz]     ──API────────→ LinkedIn / Instagram / X
```

---

## HERRAMIENTAS DE DESARROLLO (para el equipo Multi-AI)

| Tool | Quién lo usa | Para qué |
|---|---|---|
| **GitHub** | Todos | Fuente de verdad, PRs, Issues, CI |
| **GitHub Issues** | Kimi (bugs), todos | Tracking de tareas y bugs |
| **GitHub Projects** | Claude Code | Kanban del sprint |
| **Claude Code CLI** | Claude Code | SSH, git, deploy, debug |

---

## HERRAMIENTAS QUE NO RECOMENDAMOS (y por qué)

| Tool | Por qué NO |
|---|---|
| **Zapier / Make.com** | Ya tenemos n8n self-hosted, duplica costos y funcionalidad |
| **HubSpot / Salesforce** | Over-engineering para MVP, Postgres + n8n hace lo mismo |
| **Vercel / Netlify** | VPS ya tiene Traefik, no necesitamos otro hosting |
| **AWS SES** | Resend es más simple y confiable para este volumen |
| **Docker Swarm / K8s** | VPS single-node no lo necesita, compose es suficiente |
| **MongoDB** | Ya tenemos Postgres, no agregar otra DB sin razón |
| **Firebase** | Vendor lock-in, Postgres hace lo mismo self-hosted |
| **NocoBase CRM (ahora)** | Tabla leads en Postgres es suficiente para MVP |

---

## FLUJO COMPLETO DE DATOS

```
ENTRADA:
Landing ainexus.mx → Tally Form → webhook → n8n
                                              │
                                              ▼
CALIFICACIÓN:                          Dify Lead Qualifier
                                       (LiteLLM → DeepSeek)
                                              │
                                              ▼
DECISIÓN:                              Score + sector + urgencia
                                              │
                              ┌───────────────┼───────────────┐
                              ▼               ▼               ▼
                         Score ALTO      Score MEDIO     Score BAJO
                              │               │               │
                              ▼               ▼               ▼
ACCIÓN:                  WhatsApp      Email Listmonk   Log + nurture
                      (Evolution API) (Resend SMTP)    (Postgres)
                              │
                              ▼
HITL:                  n8n Form → Jaime aprueba/rechaza
                              │
                              ▼
REGISTRO:              Postgres nexus_core.leads + ai_task
                              │
                              ▼
ANALYTICS:             Plausible + n8n Daily Report → WhatsApp
```

---

## EXPANSIÓN FASE 2 (cuando el MVP esté estable)

| Herramienta | Cuándo agregar | Para qué |
|---|---|---|
| **NocoBase** | Semana 3, primer cliente | CRM visual, no técnico |
| **Dify Sandbox** | Semana 2, con network:false | Code execution en AI apps |
| **Temporal.io** | Semana 4, si Postiz falla | Orquestación de workflows complejos |
| **OpenTelemetry** | Mes 2 | Traces distribuidos entre servicios |
| **Grafana + Loki** | Mes 2 | Logs centralizados, dashboards custom |
| **Keycloak / Authentik** | Mes 3 | SSO para clientes multi-tenant |

---

*NEXUS SUPREME v1.3 · Tools Stack · Mayo 2026*
