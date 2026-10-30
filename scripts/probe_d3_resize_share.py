"""Factor display resampling arithmetic without changing any bit or cycle."""
from pathlib import Path
import hashlib,json,shutil
base=Path('E:/2026FPGA/.codex_tmp/d3_shared_font_source_r20_20261030/project')
out=Path('E:/2026FPGA/.codex_tmp/d3_resize_share_source_r22_20261030')
assert not out.exists();shutil.copytree(base,out/'project')
p=out/'project/user_source/hdl_source/rgb_resize_2_3.v';raw=p.read_bytes();s=raw.decode().replace('\r\n','\n')
old='''   sum=heavy_a?({2'b0,a}+{1'b0,a,1'b0}+{2'b0,b}):
                ({2'b0,a}+{2'b0,b}+{1'b0,b,1'b0});'''
new='''   // 3*a+b or a+3*b = (a+b)+2*(heavy_a ? a : b).
   // Full 10-bit sum (maximum 1020); unchanged truncation to bits[9:2].
   sum=({2'b0,a}+{2'b0,b})+{1'b0,(heavy_a ? a : b),1'b0};'''
assert s.count(old)==1;s=s.replace(old,new);p.write_bytes(s.encode())
sha=lambda b:hashlib.sha256(b).hexdigest()
(out/'PROVENANCE.json').write_text(json.dumps({'production_modified':False,'base':str(base),'before_sha256':sha(raw),'after_sha256':sha(p.read_bytes()),'scope':'Equivalent full-precision display bilinear blend; pixels, schedule, RAM, cancel and counters unchanged.'},indent=2)+'\n')
print(out)
