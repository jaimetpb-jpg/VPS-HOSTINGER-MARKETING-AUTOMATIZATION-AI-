#!/usr/bin/env python3
import argparse,json
from pathlib import Path
from urllib import request,error
ROOT=Path(__file__).resolve().parents[1]
def envload():
    d={}
    for line in (ROOT/'.env').read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.strip().startswith('#') or '=' not in line: continue
        k,v=line.split('=',1); d[k]=v
    return d
def http(method,url,key,payload=None):
    data=json.dumps(payload).encode() if payload is not None else None
    req=request.Request(url,data=data,method=method)
    req.add_header('Content-Type','application/json'); req.add_header('X-N8N-API-KEY',key)
    try:
        with request.urlopen(req,timeout=30) as r: return r.status,r.read().decode()
    except error.HTTPError as e: return e.code,e.read().decode(errors='ignore')
ap=argparse.ArgumentParser(); ap.add_argument('--mode',choices=['create','dry-run'],default='dry-run'); args=ap.parse_args()
E=envload(); base=E.get('N8N_BASE_URL','').rstrip('/'); key=E.get('N8N_API_KEY','')
wfpath=ROOT/'n8n/workflows/nexus_lead_to_revenue_v1.rendered.json'
if not wfpath.exists(): raise SystemExit('Run render_workflow.py first')
wf=json.loads(wfpath.read_text(encoding='utf-8'))
print('Workflow:',wf.get('name'),'Nodes:',len(wf.get('nodes',[])),'Mode:',args.mode)
if args.mode=='dry-run': raise SystemExit(0)
if not base or 'TU_INSTANCIA' in base or not key or key in {'REEMPLAZAR','CAMBIAME'}:
    raise SystemExit('Missing N8N_BASE_URL/N8N_API_KEY. Use manual import or fill .env before --mode create.')
status,body=http('POST',f'{base}/api/v1/workflows',key,wf)
print('HTTP',status); print(body[:2000])
if status>=300: raise SystemExit('n8n API create failed; use manual import or adjust payload')
