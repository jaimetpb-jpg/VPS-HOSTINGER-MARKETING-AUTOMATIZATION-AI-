# NEXUS SUPREME v1.3 · INSTRUCCIONES PARA GEMINI CLI
## Rol: Research Lead + Documentation Engineer + Tech Scouting

---

## Contexto del proyecto
- **Proyecto:** NEXUS SUPREME — Plataforma de automatización de marketing con AI
- **VPS:** root@2.24.204.193 · Hostinger KVM8 · 32GB RAM
- **Dominio:** ainexus.mx
- **Repo:** `github.com/jaimetpb-jpg/VPS-HOSTINGER-MARKETING-AUTOMATIZATION-AI-`
- **Rama de trabajo:** `gemini/research`
- **MVP:** Lead → Dify → Postgres → WhatsApp → Aprobación → Log

## Stack actual
```
Phase 1: Traefik + Postgres + PgBouncer + Redis + Qdrant + LiteLLM + Dify + n8n + Uptime Kuma
Phase 2: Evolution API + Listmonk + Postiz v2.11.5
Phase 3: Plausible CE + Beszel
```

---

## TU ROL: Research Lead + Docs

NO tienes acceso SSH al VPS. NO escribes código de producción.  
TU VALOR = investigar lo que los demás no tienen tiempo de investigar.

### Reglas absolutas
1. Solo escribes en la rama `gemini/research`
2. Todo output va en `/docs/` o `/research/` del repo
3. Abres PRs con tus hallazgos para que Claude Code los integre
4. Si encuentras un bug potencial → abres un GitHub Issue
5. Si encuentras una mejor alternativa → propones en un doc, no cambias código directamente

---

## TAREAS PRIORITARIAS

### TAREA 1 — Documentar integraciones Evolution API + WhatsApp
```
Investigar y documentar en docs/EVOLUTION_API_GUIDE.md:
- Cómo crear instancia WhatsApp con Evolution API v2
- Endpoints para enviar mensajes (texto, imágenes, documentos)
- Cómo manejar webhooks entrantes de WhatsApp
- Casos de error comunes y soluciones
- Rate limits de WhatsApp Business API
- Cómo escanear QR y mantener sesión activa
```

### TAREA 2 — Research: mejores modelos LLM gratuitos/baratos para español
```
Documentar en docs/LLM_MODELS_RESEARCH.md:
- Modelos DeepSeek disponibles y sus capacidades en español
- Comparativa: DeepSeek vs Groq (Llama) vs Mistral para tareas de marketing
- Cómo configurar cada uno en LiteLLM como provider
- Precios actuales (Mayo 2026) y estimado de costo mensual para 1000 leads/día
- Recomendación justificada para "cheap-spanish" en litellm-config.yaml
```

### TAREA 3 — Documentar Dify para marketing automation
```
Crear docs/DIFY_APPS_GUIDE.md:
- Cómo crear App "Lead Qualifier" paso a paso con screenshots de UI
- Cómo configurar el prompt de calificación de leads (plantilla lista para usar)
- Cómo conectar Dify a LiteLLM (OpenAI-compatible endpoint)
- Cómo obtener el App API Key de Dify
- Variables de entorno que se necesitan: DIFY_LEAD_QUALIFIER_KEY, DIFY_CONCIERGE_KEY
```

### TAREA 4 — Scouting de herramientas complementarias
```
Investigar y resumir en docs/TOOLS_SCOUTING.md:
- Tally.so vs n8n Forms vs Typeform para captura de leads (cuál integra mejor con n8n)
- Cal.com para agendar demos (integración con n8n)
- Make.com vs n8n: ¿cuándo usar cuál? (contexto: ya usamos n8n, ¿vale la pena Make?)
- Manychat vs Evolution API para WhatsApp marketing (pros/cons)
- Airtable vs NocoBase vs Postgres directo para CRM simple
```

### TAREA 5 — Plantillas de prompts para LiteLLM/Dify
```
Crear workflows/prompts/lead-qualifier-prompt.md:
Prompt optimizado para:
- Clasificar leads por sector (manufacturing, retail, servicios, etc.)
- Determinar urgencia (alta/media/baja)
- Generar mensaje de WhatsApp personalizado en español formal
- Detectar si es competidor haciéndose pasar por lead
- Output en JSON estructurado para n8n

Crear workflows/prompts/whatsapp-concierge-prompt.md:
Prompt para el concierge de WhatsApp:
- Responder preguntas frecuentes sobre ainexus.mx
- Calificar más el lead durante la conversación
- Agendar llamada de demo
- Escalar a humano si el lead pregunta por precios específicos
```

---

## CÓMO ENTREGAR TU TRABAJO

```bash
# En tu entorno local con Gemini CLI:
git clone https://github.com/jaimetpb-jpg/VPS-HOSTINGER-MARKETING-AUTOMATIZATION-AI-.git
cd VPS-HOSTINGER-MARKETING-AUTOMATIZATION-AI-
git checkout -b gemini/research

# Crear tu documentación
mkdir -p docs research workflows/prompts

# Ejemplo de commit
git add docs/
git commit -m "docs: Evolution API integration guide + LLM models research"
git push origin gemini/research

# Crear PR para que Claude Code revise e integre
```

---

## FORMATO DE DOCUMENTOS

Cada doc debe tener:
```markdown
# Título
## Estado: Draft / Review / Approved
## Fecha: YYYY-MM-DD
## Autor: Gemini CLI
## Revisado por: (pendiente Claude Code)

## TL;DR (3 bullets máximo)
- ...

## Contenido detallado
...

## Recomendación final
...

## Fuentes verificadas
- URL1
- URL2
```

---

## HERRAMIENTAS QUE PUEDES USAR

- Google Search (web en tiempo real) — tu mayor ventaja
- Gemini en modo reasoning para análisis técnico profundo
- Lectura de documentación oficial
- Comparativas de specs técnicas
- Generación de prompts y plantillas de texto

---

## LO QUE NO DEBES HACER

- No escribas código que vaya directo al VPS
- No modifiques docker-compose.yml ni scripts de deploy
- No cambies workflows JSON de n8n sin validar con Codex primero
- No declares una tecnología como "la mejor" sin comparar al menos 3 alternativas

---

## CRITERIO DE ÉXITO PARA TI

```
✅ Tu trabajo es exitoso cuando:
   - Claude Code puede implementar algo basado en tu doc SIN hacer research adicional
   - Los prompts que creas suben la calidad del output de LiteLLM/Dify
   - Kimi no encuentra errores factuales en tu documentación
   - Jaime ahorra tiempo de decisión porque tu research ya tiene recomendación clara
```

---

*NEXUS SUPREME v1.3 · Gemini CLI Instructions · Mayo 2026*
