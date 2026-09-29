import urllib.request,json,sys,base64
from pathlib import Path
sys.stdout.reconfigure(encoding='utf8')
url='http://127.0.0.1:27183/mcp';headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'}
def post(data):
 req=urllib.request.Request(url,json.dumps(data).encode(),headers,method='POST')
 with urllib.request.urlopen(req,timeout=300) as r:
  sid=r.headers.get('Mcp-Session-Id')
  if sid:headers['Mcp-Session-Id']=sid
  raw=r.read().decode()
  if not raw:return None
  if raw.startswith('event:') or raw.startswith('data:'):
   raw=next(line[5:].strip() for line in raw.splitlines() if line.startswith('data:'))
  return json.loads(raw)
print('Initialize',flush=True)
print(post({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'r2-direct','version':'1'}}}),flush=True)
post({'jsonrpc':'2.0','method':'notifications/initialized'})
if sys.argv[1]=='schema':params={'name':'fusion_mcp_read','arguments':{'queryType':'activeDocument'}}
else:
 source='\n'.join(Path(p).read_text(encoding='utf8') for p in sys.argv[3:])+ '\n'+Path(sys.argv[1]).read_text(encoding='utf8')
 source=source.replace('ensure_ascii=False','ensure_ascii=True').encode('ascii','backslashreplace').decode('ascii')
 params={'name':'fusion_mcp_execute','arguments':{'featureType':'script','object':{'script':source}}}
print('Calling tool',flush=True)
result=post({'jsonrpc':'2.0','id':2,'method':'tools/call','params':params})
Path(sys.argv[2]).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(result,ensure_ascii=False),flush=True)
