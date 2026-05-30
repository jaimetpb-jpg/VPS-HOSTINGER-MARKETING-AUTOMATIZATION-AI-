#!/usr/bin/env python3
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def envload():
    p=ROOT/'.env'
    d={}
    if not p.exists():
        return d
    for line in p.read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.strip().startswith('#') or '=' not in line:
            continue
        k,v=line.split('=',1); d[k.strip()]=v.strip()
    return d
E=envload()
def has_real(key):
    value=E.get(key,'')
    return bool(value) and all(marker not in value for marker in ['REEMPLAZAR','CAMBIAME','TU_INSTANCIA','TU_PROYECTO','tudominio.com'])
checks = [
    ('Rendered workflow exists', (ROOT/'n8n/workflows/nexus_lead_to_revenue_v1.rendered.json').exists()),
    ('Test payload exists', (ROOT/'n8n/workflows/test_payload.json').exists()),
    ('Dify prompt exists', (ROOT/'prompts/dify/lead_qualifier.md').exists()),
    ('Lead schema exists', (ROOT/'schemas/lead_intake.schema.json').exists()),
    ('.env exists', (ROOT/'.env').exists()),
    ('N8N API credentials configured', has_real('N8N_BASE_URL') and has_real('N8N_API_KEY')),
    ('Dify key configured', has_real('DIFY_LEAD_QUALIFIER_KEY')),
    ('Evolution API configured', has_real('EVOLUTION_BASE_URL') and has_real('EVOLUTION_API_KEY')),
    ('Operator WhatsApp configured', has_real('OPERATOR_WHATSAPP')),
    ('Production webhook configured', has_real('N8N_LEAD_WEBHOOK_URL')),
]
print('GO/NO GO REPORT')
failed = []
for name, ok in checks:
    print(('OK ' if ok else 'FAIL ') + name)
    if not ok:
        failed.append(name)
if failed:
    print('\nNO GO')
    print('Pending:', ', '.join(failed))
    raise SystemExit(1)
print('\nGO')
