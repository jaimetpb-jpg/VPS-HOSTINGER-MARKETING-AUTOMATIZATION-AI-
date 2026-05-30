# Arquitectura · NEXUS Lead-to-Revenue Engine v1.0

## Capa 1 — Intake
Fuentes: Landing page form, WhatsApp inbound, manual lead entry, futuro Meta Leads/Typeform.

## Capa 2 — n8n Orchestration
n8n recibe el webhook y responde temprano para evitar timeouts.

```text
Webhook
→ Respond to Webhook inmediato
→ Normalize Lead
→ Upsert Lead
→ Dify Qualifier
→ Parse AI JSON
→ Store Score
→ Switch HOT/WARM/COLD
→ WhatsApp/Email/List
→ Log ai_task
```

## Capa 3 — Dify / AI
Dify no ejecuta acciones peligrosas. Solo clasifica, resume, redacta y devuelve JSON.

## Capa 4 — Data
Postgres/Supabase guarda leads, ai_task, consent, interaction_log y error_memory.

## Capa 5 — Human Gate
Aprobación humana obligatoria para respuesta directa a lead HOT, primer cold email, publicación social, propuesta comercial y acciones con costo/reputación.

## Diagrama

```text
[Lead Source]
     │
     ▼
[n8n Webhook] ⚡
     │
     ├──→ [Respond 200 immediately] 🛡
     │
     ▼
[Normalize + Validate]
     │
     ▼
[Postgres/Supabase Upsert Lead] 🛡
     │
     ▼
[Dify Lead Qualifier] ⚡
     │
     ▼
[Parse JSON Score]
     │
     ▼
[Store Score + ai_task]
     │
     ▼
[Switch HOT / WARM / COLD]
   ┌─┴─────────────┬────────────────┐
   ▼               ▼                ▼
[HOT]            [WARM]           [COLD]
WhatsApp         Draft            Nurture
Operator         Follow-up        Low priority
Human Gate       Optional Gate     No aggressive outreach
   │               │                │
   └───────┬───────┴───────┬────────┘
           ▼               ▼
       [Interaction Log + Error Memory]
           │
           ▼
       [Daily Report]
```
