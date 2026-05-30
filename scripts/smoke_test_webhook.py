#!/usr/bin/env python3
from pathlib import Path
import json
from urllib import request,error
ROOT=Path(__file__).resolve().parents[1]
def envload():
    d={}
    p=ROOT/'.env'
    if not p.exists():
        return d
    for line in p.read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.strip().startswith('#') or '=' not in line: continue
        k,v=line.split('=',1); d[k]=v
    return d
E=envload(); url=E.get('N8N_LEAD_WEBHOOK_URL','')
if not url or 'TU_INSTANCIA' in url: raise SystemExit('N8N_LEAD_WEBHOOK_URL missing')
payload=json.loads((ROOT/'n8n/workflows/test_payload.json').read_text(encoding='utf-8'))
req=request.Request(url,data=json.dumps(payload).encode(),method='POST')
req.add_header('Content-Type','application/json')
try:
    with request.urlopen(req,timeout=30) as r:
        body=r.read().decode(errors='ignore'); print('HTTP',r.status); print(body[:2000])
        if r.status>=300: raise SystemExit('Smoke failed')
except error.HTTPError as e:
    print('HTTP',e.code); print(e.read().decode(errors='ignore')); raise SystemExit('Smoke failed')
