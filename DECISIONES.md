# NEXUS v1.3 · REGISTRO DE DECISIONES TÉCNICAS

> Archivo vivo. Cada decisión técnica importante se registra aquí.
> Formato: fecha · autor · tema · decisión · justificación.
> Las AIs deben consultar esto antes de proponer cambios estructurales.

---

## 2026-05-28 · Consolidación equipo Multi-AI v2.0

**Autor:** James (consolidación basada en evaluación de 6 AIs + Kimi Swarm)

**Decisión:** Adoptar pipeline `Codex → Kimi → James → Claude Code` como flujo único oficial.

**Justificación:**
- 5 de 6 evaluaciones independientes coincidieron en este orden.
- Empezar Día 0 con 6 AIs simultáneas genera colisiones Git y confusión de contexto.
- Codex aporta validación local automatizada (pre-commit hooks).
- Kimi aporta auditoría multi-archivo con contexto largo.
- Claude Code es el único con SSH funcional al VPS.

**Implementación:** ver `NEXUS_AI_TEAM_RULES.md` v2.0.

---

## 2026-05-28 · Pre-commit hooks obligatorios

**Autor:** James (basado en hallazgo de Kimi Swarm)

**Decisión:** Todo `git push` a `deploy-v1.3` debe pasar `scripts/pre-commit-validate.sh` antes de ser aceptado.

**Justificación:**
- Kimi Swarm detectó que la auditoría visual no captura bugs estructurales (ej: `status='running'` vs `'processing'`).
- 3 auditores AI (Kimi, Codex, Grok) pasaron el bug por alto. Solo el check ejecutable lo detectó.
- La validación automatizada es más confiable y reproducible que opiniones de AI.

**Implementación:** `scripts/pre-commit-validate.sh` con 12 checks ejecutables.

---

## 2026-05-28 · Monitoreo 24/7 con stack, no con AI

**Autor:** James (basado en evaluación Kimi)

**Decisión:** El monitoreo continuo lo hace Uptime Kuma + Beszel + n8n cron, no una AI en loop.

**Justificación:**
- Kimi identificó correctamente que "monitoreo 24/7 con AI" es retórica vacía: ninguna AI tiene agente autónomo real.
- Uptime Kuma con webhook a Evolution API → WhatsApp es la solución técnicamente correcta.
- Las AIs entran solo cuando un sensor del stack dispara alerta.

**Implementación:** ya en Phase 1 (Uptime Kuma) + Phase 3 (Beszel).

---

## 2026-05-28 · Día 0 con 3 AIs, no con 6

**Autor:** James (consenso 5/6 evaluaciones)

**Decisión:** Solo Codex, Kimi y Claude Code están activas en el deploy inicial.

**Justificación:**
- Más AIs simultáneas en el mismo repo = más conflictos Git.
- Gemini y Grok aportan valor pero generan ruido si no hay logs reales que diagnosticar.
- Manus y Cursor son apoyo, no parte del pipeline crítico.

**Implementación:**
- Día 0: Codex + Kimi + Claude Code
- Día 2+: + Gemini (logs) + Grok (segunda opinión)
- Día 7+: + Manus (research comercial) + Cursor (microedición humana)

---

## 2026-05-28 · Reglas éticas NEXUS

**Autor:** James (validación moral del proyecto)

**Decisión:** 10 reglas absolutas (ver sección 0 de `NEXUS_AI_TEAM_RULES.md`).

**Justificación:**
- Trabajo en equipo > ego de cualquier AI individual.
- Beneficio del proyecto y del usuario sobre velocidad o reputación.
- Transparencia total: toda decisión queda registrada.

---

## TEMPLATE PARA NUEVAS DECISIONES

```markdown
## YYYY-MM-DD · Título corto

**Autor:** Quién propone (AI o James)

**Decisión:** Qué se decidió en 1-2 oraciones.

**Justificación:**
- Razón técnica 1
- Razón técnica 2
- Evidencia o referencia

**Implementación:** Archivo, script o sección donde se aplica.
```
