import json,sys,urllib.request,base64
from pathlib import Path
sys.stdout.reconfigure(encoding='utf8')
OUT=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局')
headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'}
def post(data):
 req=urllib.request.Request('http://127.0.0.1:27183/mcp',json.dumps(data).encode(),headers,method='POST')
 with urllib.request.urlopen(req,timeout=1800) as r:
  if r.headers.get('Mcp-Session-Id'):headers['Mcp-Session-Id']=r.headers['Mcp-Session-Id']
  raw=r.read().decode()
  if not raw:return None
  if raw.startswith(('event:','data:')):raw=next(x[5:].strip() for x in raw.splitlines() if x.startswith('data:'))
  return json.loads(raw)
post({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'r2c','version':'1'}}})
post({'jsonrpc':'2.0','method':'notifications/initialized'})
label=sys.argv[2] if sys.argv[1]=='discover' else (sys.argv[3] if sys.argv[1]=='read' else Path(sys.argv[1]).stem)
if sys.argv[1]=='discover':r=post({'jsonrpc':'2.0','id':2,'method':'tools/list'})
else:
 if sys.argv[1]=='read': name='fusion_mcp_read';args=json.loads(sys.argv[2])
 else:
  name='fusion_mcp_execute';source='\n'.join(Path(p).read_text(encoding='utf-8-sig') for p in sys.argv[2:]+[sys.argv[1]])
  args={'featureType':'script','object':{'script':source.encode('ascii','backslashreplace').decode('ascii')}}
 r=post({'jsonrpc':'2.0','id':2,'method':'tools/call','params':{'name':name,'arguments':args}})
(OUT/'evidence'/f'{label}_mcp.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf8')
def walk(v):
 if isinstance(v,dict):
  for k in ['base64Data','data']:
   if k in v and v.get('mimeType')=='image/png':
    (OUT/'evidence'/f'{label}.png').write_bytes(base64.b64decode(v[k]));v[k]='[image saved]'
  for w in v.values():walk(w)
 elif isinstance(v,list):
  for w in v:walk(w)
walk(r);print(json.dumps(r,ensure_ascii=False))

