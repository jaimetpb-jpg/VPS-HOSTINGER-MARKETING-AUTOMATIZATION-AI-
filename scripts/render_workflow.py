#!/usr/bin/env python3
from pathlib import Path
import json, re
ROOT=Path(__file__).resolve().parents[1]
def envload():
    p=ROOT/'.env'
    if not p.exists(): raise SystemExit('Missing .env')
    d={}
    for line in p.read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.strip().startswith('#') or '=' not in line: continue
        k,v=line.split('=',1); d[k.strip()]=v.strip()
    return d
E=envload(); data=(ROOT/'n8n/workflows/nexus_lead_to_revenue_v1.template.json').read_text(encoding='utf-8')
defaults={
    'WORKFLOW_NAME':'NEXUS Lead-to-Revenue Engine v1.0',
    'DEFAULT_TENANT_ID':'ainexus',
    'DIFY_BASE_URL':'https://api.dify.ai/v1',
    'EVOLUTION_INSTANCE':'ainexus-main',
    'DATA_API_MODE':'mock',
    'DATA_API_BASE_URL':'https://example.invalid/mock-data-api',
    'DATA_API_KEY':'MOCK_DATA_API_KEY',
    'DATA_API_LEADS_TABLE':'leads',
    'DATA_API_TASKS_TABLE':'ai_task',
}
required=['WORKFLOW_NAME','DEFAULT_TENANT_ID','DIFY_BASE_URL','DIFY_LEAD_QUALIFIER_KEY','EVOLUTION_BASE_URL','EVOLUTION_API_KEY','EVOLUTION_INSTANCE','OPERATOR_WHATSAPP','DATA_API_BASE_URL','DATA_API_KEY','DATA_API_LEADS_TABLE','DATA_API_TASKS_TABLE']
warnings=[]
for k,v in defaults.items():
    if not E.get(k) or E[k] in ['REEMPLAZAR','CAMBIAME']:
        E[k]=v
mode=E.get('DATA_API_MODE','mock').lower()
if mode == 'mock':
    E['DATA_API_BASE_URL']='https://example.invalid/mock-data-api'
    E['DATA_API_KEY']='MOCK_DATA_API_KEY'
for k in required:
    if not E.get(k) or E[k] in ['REEMPLAZAR','CAMBIAME']:
        safe=f'REPLACE_{k}'
        E[k]=safe
        warnings.append(k)
for k,v in E.items(): data=data.replace(f'__{k}__', v)
unresolved=sorted(set(re.findall(r'__[A-Z0-9_]+__', data)))
if unresolved: raise SystemExit(f'Unresolved placeholders: {unresolved}')
parsed=json.loads(data)
out=ROOT/'n8n/workflows/nexus_lead_to_revenue_v1.rendered.json'
out.write_text(json.dumps(parsed,indent=2,ensure_ascii=False),encoding='utf-8')
print('Rendered workflow:', out)
if mode == 'mock':
    print('DATA_API_MODE=mock: Data API nodes are non-blocking and use a non-routable mock endpoint.')
if warnings:
    print('WARNING: rendered workflow still contains replacement placeholders for:', ', '.join(warnings))
    print('Do not import/activate in production until these values are replaced in .env or n8n credentials.')
