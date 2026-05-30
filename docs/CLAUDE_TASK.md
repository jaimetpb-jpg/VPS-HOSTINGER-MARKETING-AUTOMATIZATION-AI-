# Tarea para Claude Code

Solo usar si hay que ejecutar comandos en entorno real.

Reglas:
1. No tocar producción sin GO.
2. No cambiar DNS.
3. No borrar workflows existentes.
4. No crear credenciales con secretos en texto plano dentro de workflow.
5. No activar workflow hasta pasar smoke test.

Comandos:
```bash
python scripts/validate_project.py
python scripts/render_workflow.py
python scripts/n8n_api_deploy.py --mode create
python scripts/smoke_test_webhook.py
python scripts/go_nogo.py
```
