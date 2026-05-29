# NEXUS SUPREME v1.3 · REGLAS DEL EQUIPO MULTI-AI
## Documento maestro consolidado · v2.0 · 28 mayo 2026

> Síntesis de 6 evaluaciones independientes (ChatGPT, Codex, Gemini, Grok, Kimi, Kimi Code)
> más el complemento operativo de Kimi Swarm.
> Adopción inmediata en `deploy-v1.3`.

---

## 0. FILOSOFÍA NEXUS ÉTICA

Reglas absolutas, sin excepción:

1. No goteo de fixes — una auditoría = un dictamen completo.
2. No rediseñar por ego — si funciona, no se toca.
3. No alucinar — admitir "no tengo certeza" cuando aplique.
4. No declarar GO sin prueba real (curl, log, output verificable).
5. No tocar producción sin rollback definido.
6. No esconder errores ni minimizar riesgos.
7. No inflar complejidad por aparentar más trabajo.
8. Beneficio del proyecto y del usuario, siempre, primero.
9. Trabajo en equipo > ego individual de cualquier AI.
10. Transparencia total — toda decisión importante queda registrada.

---

## 1. CONSENSO TÉCNICO ADOPTADO

Estos puntos fueron confirmados por 5/6 evaluaciones independientes:

| Acuerdo | Origen |
|---|---|
| Claude Code es el ÚNICO que toca el VPS | unánime 6/6 |
| Una AI escribe, otra audita, otra ejecuta | unánime 6/6 |
| James decide en empates y comandos destructivos | unánime 6/6 |
| `deploy-v1.3` es la única rama de verdad | unánime 6/6 |
| Día 0 arranca con 3 AIs, no con 5–7 | mayoría 5/6 |
| Auditoría visual ≠ tests automatizados | mayoría 4/6 |
| Monitoreo 24/7 real lo hace Uptime Kuma, no una AI | Kimi (único, validado) |
| Validación automatizada antes del push es obligatoria | Kimi + ChatGPT |

---

## 2. EQUIPO Y CARRILES EXCLUSIVOS

```
┌───────────────────────────────────────────────────────────┐
│             JAMES (HUMANO) · Orquestador final            │
│    Rompe empates · Aprueba arquitectura · 60s gate        │
└─────────────────────────┬─────────────────────────────────┘
                          │
   ┌──────────────────────┼──────────────────────┐
   ▼                      ▼                      ▼
┌──────────┐         ┌──────────┐          ┌──────────┐
│  CODEX   │ ────────▶│   KIMI   │ ────────▶│  CLAUDE  │
│ (local)  │         │ (audita) │          │   CODE   │
│ genera + │         │ multi-   │          │  (VPS)   │
│ pre-     │         │ archivo  │          │ ejecuta  │
│ commit   │         │ + sec    │          │ deploy   │
└──────────┘         └──────────┘          └──────────┘
                                                  │
                          ┌───────────────────────┤
                          ▼                       ▼
                     ┌──────────┐           ┌──────────┐
                     │  GEMINI  │           │   GROK   │
                     │ logs +   │           │ research │
                     │ diag     │           │ + seg ext│
                     │ (si fail)│           │(si empate│
                     └──────────┘           └──────────┘

ASÍNCRONOS (no bloquean pipeline):
  · MANUS  → research comercial, propuestas, docs largas
  · CURSOR → microedición humana en IDE local
```

### Carriles exclusivos (NO se cruzan)

| AI | Dominio exclusivo | Acceso | NO toca |
|---|---|---|---|
| **Claude Code** | VPS · SSH · Docker · Deploy · Hotfixes | Root al VPS | Workflows n8n · prompts Dify |
| **Codex** | Repo local · scripts · YAML · JSON workflows · pre-commit | Git local | VPS · producción |
| **Kimi Code** | Auditoría multi-archivo · seguridad · drift detection | Read repo + VPS read-only | Editar código de producción |
| **Grok** | Investigación externa · segunda opinión · monitoreo competidores | Read repo | Producción · arquitectura |
| **Gemini CLI** | Logs · diagnóstico rápido · documentación | Read VPS logs | Decisiones técnicas críticas |
| **Manus** | Research comercial · propuestas · docs largas | Solo lectura | Código productivo |
| **Cursor+DeepSeek** | Edición inline rápida (humano-asistida) | Local IDE | Arquitectura · deploy |

---

## 3. LÍNEA DE PRODUCCIÓN (flujo único oficial)

```
[1] CODEX (local)
     · genera/edita código
     · ejecuta pre-commit hooks AUTOMÁTICOS:
         - python -m json.tool workflows/*.json
         - bash -n scripts/*.sh
         - docker compose config --quiet
         - grep secrets (private keys, hardcoded passwords)
         - SQL syntax check (db-init/*.sql)
     · si PASS → commit + push deploy-v1.3
     · si FAIL → corrige y reintenta (no avanza)

           ↓

[2] KIMI (lee commit en GitHub)
     · audita diff completo
     · 14 checks de CHECKLIST_GATE.md
     · reporta SOLO ❌ con archivo:línea + fix
     · si todo OK → "✅ GATE APROBADO — GO para VPS"
     · si ❌ crítico → vuelve a Codex

           ↓

[3] JAMES (gate humano, máximo 60s)
     · si comando destructivo, DNS, secretos, datos → revisa
     · si workflow nuevo o cambio menor → aprobación rápida
     · sin respuesta en 5 min con verde de Kimi → aprueba por default

           ↓

[4] CLAUDE CODE (VPS via SSH)
     · git pull en /opt/nexus
     · docker compose config (validación pre-deploy)
     · ejecuta scripts/00-...-09-... en orden
     · valida cada fase con curl real (no asume éxito)
     · si fase falla → STOP, reporta logs

           ↓

[5] SMOKE TEST (scripts/99-smoke-test.sh)
     · curl HTTPS a todos los servicios
     · LiteLLM completion real (debe devolver "OK")
     · Postgres schema validado
     · Webhook lead-intake → 200 + lead en DB + WhatsApp recibido

           ↓
        ✅ MVP ACTIVO

ASÍNCRONOS (corren en paralelo, NO bloquean):
  · GEMINI: lee logs si Claude reporta error → causa raíz en segundos
  · GROK: investiga si Codex y Kimi se contradicen sin evidencia
  · MANUS: research comercial, propuestas en background
  · CURSOR: solo cuando James necesita editar manualmente
```

---

## 4. RESOLUCIÓN DE CONFLICTOS

Cuando dos AIs dan respuestas contradictorias, este es el orden de prioridad:

1. **Si es error de código** → Codex propone diff con validación local.
2. **Si es error de VPS** → Claude Code revisa logs y reporta.
3. **Si es inconsistencia multi-archivo** → Kimi audita y dictamina.
4. **Si es contradicción técnica con evidencia parcial** → Grok da segunda opinión.
5. **Si sigue bloqueado más de 10 minutos** → James decide.
6. **Si implica borrar datos, DNS, llaves, seguridad o arquitectura** → James decide SIEMPRE.

**Criterio de desempate técnico** (de ChatGPT, adoptado):
> Gana la opción que tenga (1) diff reproducible, (2) comando de validación, (3) rollback definido.
> Si ambas posiciones tienen evidencia igual de fuerte, gana lo más simple que conserve el MVP.

---

## 5. CUÁNDO INTERVIENE JAMES (gate humano obligatorio)

| Tipo | Acción |
|---|---|
| Comando destructivo (`rm`, `down -v`, `DROP`) | Aprobación explícita |
| Borrar volúmenes o datos | Aprobación explícita |
| Cambio de DNS | Solo James toca DNS |
| Cambio de llaves SSH | Solo James |
| Cambio de arquitectura grande | Discusión + James decide |
| Dos AIs contradictorias sin evidencia clara | James rompe empate |
| Riesgo de ban en WhatsApp o servicios externos | James valida |
| Declarar MVP listo para cliente real | James verifica end-to-end |

---

## 6. ARRANQUE — DÍA 0 (3 AIs activas, NO 6)

Solo se activan tres AIs al inicio:

```
DÍA 0  → Codex + Kimi + Claude Code
DÍA 2+ → se suma Gemini (logs) y Grok (segunda opinión)
DÍA 7+ → se suma Manus (research) y Cursor (microedición)
```

**Razón:** menos AIs simultáneas en el mismo repo = menos colisiones Git, menos confusión de contexto, deploy más rápido. Confirmado por 5/6 evaluaciones.

---

## 7. PRE-COMMIT HOOKS (el gap que ninguna AI cubrió completamente)

**Problema detectado por Kimi Swarm:** auditoría visual no detecta bugs como `status='running'` vs `status='processing'`. La solución no son más auditores, son checks ejecutables.

**Implementación obligatoria:** ver `scripts/pre-commit-validate.sh`. Codex lo ejecuta antes de cada `git push`. Si algún check falla, el push se bloquea automáticamente.

**Cobertura del hook:**
- JSON workflows válidos
- Bash sin errores de sintaxis
- docker-compose config parseable con .env actual
- Sin private keys versionadas
- Sin secretos hardcoded en YAML
- SQL idempotente (sin DO $$ activo en bootstrap)
- Status fields con valores válidos (running/processing/done/error)
- DOMAIN en los 3 servicios n8n
- DIFY_CONCIERGE_KEY en main + worker(s)

---

## 8. MÉTRICAS DE ÉXITO

El equipo está funcionando bien si:

| Métrica | Target | Cómo se mide |
|---|---|---|
| Tiempo a primer deploy completo | < 6 horas | wallclock desde Fase 0 hasta MVP |
| Bugs en producción por semana | < 3 | issues GitHub con label `bug-prod` |
| Commits sin necesidad de rollback | > 80% | git log vs git revert ratio |
| Conflictos Git por semana | < 2 | merge conflicts en deploy-v1.3 |
| ZIPs/secretos versionados | 0 | gate Kimi pre-push |
| Pre-commit hooks ejecutados | 100% | log del hook en `.git/hooks/` |
| Reinicios de contexto AI | cada 6h | cada AI reinicia sesión + recarga CLAUDE.md |

---

## 9. COMUNICACIÓN INTER-AI

### Canales

- **GitHub (fuente única de verdad):** commits, PRs, issues
- **DECISIONES.md (en raíz del repo):** decisiones técnicas con timestamp + autor
- **WhatsApp al operador (OPERATOR_WHATSAPP):** alertas críticas vía Evolution API
- **n8n ai_task tabla:** log estructurado de toda actividad AI

### Formato de reporte estándar

```
[NEXUS-AI-{nombre}] {NIVEL}: {mensaje}

Status: [OK | WARNING | ERROR | BLOCKED]
AI: {nombre}
Task: {qué hizo}
Result: {resultado verificable}
Next: {siguiente paso}
Needs: {qué necesita de otra AI, o "nada"}
```

### Ejemplos

```
[NEXUS-AI-KIMI] OK: GATE APROBADO en commit 6e66e88
Task: Auditoría 14 checks
Result: 14/14 PASS
Next: Claude Code puede ejecutar deploy
Needs: nada

[NEXUS-AI-CLAUDE] ERROR: Phase 1 deploy falló
Task: docker compose up phase-1-core
Result: dify-api exited 1
Next: Gemini diagnostique logs
Needs: gemini -p "$(docker logs nexus-dify-api --tail 80)" "causa raíz"
```

---

## 10. PROTOCOLO DE EMERGENCIA

| Señal | Acción inmediata |
|---|---|
| RAM > 90% por 5+ min | Claude reinicia containers no críticos |
| 3+ containers caídos simultáneos | James interviene · revisar logs antes de tocar |
| LiteLLM error > 10 min | Gemini diagnostica · Codex propone fix |
| Postgres no acepta conexiones | STOP TODO · James + Claude revisan |
| Kimi reporta CRITICAL | Bloqueo automático de push · James decide |
| WhatsApp ban | STOP Evolution · Manus investiga causa raíz |

---

## 11. REINICIO DE SESIONES (anti-context-decay)

Hallazgo de Kimi y Gemini: después de ~100k tokens todas las AIs pierden precisión y empiezan a alucinar.

**Protocolo obligatorio:**
- Cada 6 horas: reiniciar sesión de cada AI activa.
- Al reiniciar: recargar `CLAUDE.md` + último estado del repo.
- No usar la misma sesión para más de 6 horas seguidas en deploys.

---

## 12. STACK DE MONITOREO REAL (NO AI)

Hallazgo de Kimi: "monitoreo 24/7 con AIs" es humo si no hay agentes autónomos. La solución real es infraestructura.

| Herramienta | Función | Estado |
|---|---|---|
| **Uptime Kuma** | Heartbeat de URLs cada 1 min | Ya en Phase 1 |
| **Beszel** | RAM, disco, CPU del VPS | Ya en Phase 3 |
| **n8n cron** | Reportes diarios al operador | Workflow `n8n-daily-report` |
| **Evolution API webhook** | Alertas a WhatsApp | Vía n8n |
| **Plausible CE** | Analytics sin AI | Ya en Phase 3 |

**Las AIs entran solo cuando algún sensor de los anteriores dispara alerta.**

---

## 13. ROADMAP DE FASES (orden de menor riesgo, mayor velocidad)

```
Fase 0  → Repo limpio + scripts versionados + gate verde ✅ COMPLETADO
Fase 1  → Core AI estable (Postgres + LiteLLM + Dify + n8n)
Fase 2  → WhatsApp + Lead Intake + HITL (PRIMER VALOR)
Fase 3  → Calificación inteligente + Nurturing
Fase 4  → Canales de salida (Listmonk + Postiz)
Fase 5  → Observabilidad + backups + hardening
Fase 6  → Expansión (multi-tenant, más agentes, NocoBase si justifica)
```

---

## 14. DOCUMENTOS REFERENCIADOS

| Documento | Propósito |
|---|---|
| `CLAUDE_CODE_INSTRUCCIONES.md` (original) | Instrucciones de deploy en VPS |
| `CODEX_INSTRUCCIONES.md` (original) | Instrucciones de cirugía local |
| `ai_instructions/CLAUDE_CODE_IMPROVED.md` | Versión mejorada (Kimi Swarm) |
| `ai_instructions/CODEX_IMPROVED.md` | Versión mejorada (Kimi Swarm) |
| `ai_instructions/KIMI_INSTRUCTIONS.md` | Rol de Kimi como auditor |
| `ai_instructions/GROK_INSTRUCTIONS.md` | Rol de Grok (activación Día 2+) |
| `ai_instructions/GEMINI_INSTRUCTIONS.md` | Rol de Gemini (activación Día 2+) |
| `docs/NEXUS_MULTI_AI_STRATEGY.md` | Estrategia operacional completa |
| `scripts/pre-commit-validate.sh` | Hook automático pre-push |
| `CHECKLIST_GATE.md` | 14 checks que Kimi corre antes de cada push |
| `DECISIONES.md` | Registro vivo de decisiones técnicas |

---

## 15. RESPUESTA A "¿QUIÉN GANA?"

> Gana el sistema que mejor coopera. No es competencia de ego, es una línea de producción.

| AI | Fortaleza única verificada |
|---|---|
| Claude Code | Ejecución multi-paso en VPS con SSH real |
| Codex | Cirugía local + commits atómicos rápidos |
| Kimi Code | Contexto multi-archivo (única que detectó `running` vs `processing`) |
| Grok | Investigación externa y segunda opinión |
| Gemini CLI | Logs y diagnóstico rápido (1000 req/día gratis) |
| Manus | Tareas largas asíncronas sin supervisión |
| Cursor+DeepSeek | Microedición humana asistida |

**James gana cuando todas trabajan sin batidero.**

---

*v2.0 · 28 mayo 2026 · Consolidado por Claude tras evaluación de 6 AIs + complemento Kimi Swarm*
*Documento vivo: cualquier modificación requiere PR + aprobación de James*
