# CHECKLIST — Rotación de llaves expuestas (antes de cliente real)

Expuestas en logs/chat (consta en transcripts):
- [ ] LITELLM_MASTER_KEY (regenerar en /opt/nexus/.env y reiniciar litellm)
- [ ] N8N_ENCRYPTION_KEY (⚠️ rotar invalida credenciales guardadas → re-importar)
- [ ] PG_NEXUS_CORE_PASS, PG_N8N_PASS, PG_DIFY_PASS (ALTER USER en Postgres + actualizar .env)
- [ ] DEEPSEEK_API_KEY (regenerar en panel DeepSeek)
- [ ] SMTP_PASS Resend (regenerar en Resend)
- [ ] Hostinger API token (regenerar en hPanel API)
- [ ] DIFY_LEAD_QUALIFIER_KEY, DIFY_CONCIERGE_KEY (regenerar en Dify → API Access)

Aplicar DESPUÉS de los fixes de Phase 2, no antes (porque cambiar passwords ahora puede romper cosas que estás depurando).
