"""Extract both actual ID-RAM read ports for high-address/clear/collision tests."""
from pathlib import Path
import argparse,hashlib,json,re
r=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--source',type=Path,required=True);x=a.parse_args()
h=x.source/'user_source/hdl_source';out=r/'tests/dual_stop_d3/extracted_d3_id_ram.sv'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
parts=[]
for name,mod in [('classified_pocket_counter','reference_id_ram'),('observed_classified_pocket_counter','candidate_id_ram')]:
 s=(h/(name+'.v')).read_text()
 decl=re.search(r'reg \[8:0\] empty_ids\[0:MAX_TOTAL-1\];',s)[0]
 block=s.split(' // RAM contents are run-length bounded; never reset or expose stale addresses.',1)[1].split(' always @(posedge clk or negedge rst_n)',1)[0]
 block=block.replace("  ledger_data<=ledger_address<total ? ledger[ledger_address] : 6'd0;\n",'')
 extra=''
 if 'empty_id_raw' in block:
  extra=re.search(r" reg \[8:0\] empty_id_raw;reg empty_id_valid;\n assign empty_id=empty_id_valid \? empty_id_raw : 9'd0;",s)[0]
 assert "empty_ids[empty_total]<=total+1'b1;empty_total<=empty_total+1'b1;" in s
 parts.append('module '+mod+' #(parameter MAX_TOTAL=300)(input wire clk,wr,input wire [8:0] empty_address,empty_total,total,output '+('wire' if extra else 'reg')+' [8:0] empty_id);\n '+decl+'\n'+extra+'\n'+block+" always @(posedge clk)if(wr)empty_ids[empty_total]<=total+1'b1;\nendmodule\n")
out.write_text('\n'.join(parts))
(r/'docs/D3_ID_RAM_PORT_EXTRACTION.json').write_text(json.dumps({'source':str(x.source),'inputs':{name+'.v':sha(h/(name+'.v')) for name in ['classified_pocket_counter','observed_classified_pocket_counter']},'fixture_sha256':sha(out),'scope':'Actual source read blocks and unmodified RAM write expression; external count/address stimulus supplements full original-counter public-output comparisons.'},indent=2)+'\n')
print(out)
