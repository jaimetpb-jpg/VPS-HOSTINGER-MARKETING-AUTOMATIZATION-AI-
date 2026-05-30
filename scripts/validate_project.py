#!/usr/bin/env python3
from pathlib import Path
import json, sys
ROOT=Path(__file__).resolve().parents[1]; FAIL=[]
def fail(x): FAIL.append(x); print('FAIL:',x)
def ok(x): print('OK:',x)
for p in ROOT.rglob('*.json'):
    if p.name.endswith('.rendered.json'):
        continue
    try: json.loads(p.read_text(encoding='utf-8')); ok(f'JSON parse: {p.relative_to(ROOT)}')
    except Exception as e: fail(f'JSON parse failed {p}: {e}')
patterns=['BEGIN OPENSSH PRIVATE KEY','BEGIN RSA PRIVATE KEY','sk-ant-','sk-proj-','ghp_','xoxb-']
secret_scan_excludes={
    'validate_project.py',
    'pre-commit-validate.sh',
    'skills-runner.sh',
    'CHECKLIST_GATE.md',
    'CLAUDE_CODE_INSTRUCCIONES.md',
    'CODEX_INSTRUCCIONES.md',
    'KIMI_AGENT.md',
}
for p in ROOT.rglob('*'):
    if p.is_file() and p.name not in secret_scan_excludes and p.suffix.lower() in {'.py','.json','.md','.sh','.yml','.yaml','.example'}:
        t=p.read_text(encoding='utf-8', errors='ignore')
        for pat in patterns:
            if pat in t: fail(f'Potential secret pattern {pat} in {p.relative_to(ROOT)}')
wf=json.loads((ROOT/'n8n/workflows/nexus_lead_to_revenue_v1.template.json').read_text(encoding='utf-8'))
nodes={n['name']:n for n in wf.get('nodes',[])}
for src,conn in wf.get('connections',{}).items():
    if src not in nodes: fail(f'orphan source {src}')
    for lane in conn.get('main',[]):
        for tgt in lane:
            if tgt.get('node') not in nodes: fail(f'orphan target {tgt.get("node")}')
has_resp=any(n.get('type')=='n8n-nodes-base.respondToWebhook' for n in wf.get('nodes',[]))
for n in wf.get('nodes',[]):
    if n.get('type')=='n8n-nodes-base.webhook' and n.get('parameters',{}).get('responseMode')=='responseNode' and not has_resp:
        fail('webhook responseNode without Respond node')
    if n.get('name') in {'HTTP · Upsert Lead','HTTP · Log ai_task'} and n.get('onError') != 'continueRegularOutput':
        fail(f'{n.get("name")} must be non-blocking with onError=continueRegularOutput')
if FAIL:
    print('\nNO GO')
    sys.exit(1)
print('\nGO: project validation passed')
