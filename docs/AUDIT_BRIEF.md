# Audit Brief para Kimi/Grok/Codex

## Objetivo
Determinar si este proyecto puede pasar a implementación n8n API sin introducir riesgos de seguridad, bugs silenciosos o complejidad Frankenstein.

## Preguntas de auditoría
1. ¿El workflow responde temprano al webhook?
2. ¿Hay secretos hardcodeados?
3. ¿Hay nodos sin conexión?
4. ¿Hay acciones automáticas de alto riesgo sin human gate?
5. ¿El output AI está validado como JSON?
6. ¿Los errores se guardan o notifican?
7. ¿El proyecto depende de servicios no declarados?
8. ¿El workflow puede importarse a n8n sin credenciales reales?
9. ¿El diseño permite crecer sin mezclar demasiadas funciones?
10. ¿Qué debe quedarse para Fase 2?

## Criterio GO
GO solo si validate_project.py pasa, no hay secretos, el workflow renderiza, el webhook test funciona, Dify responde y WhatsApp llega.
