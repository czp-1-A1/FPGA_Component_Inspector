"""Create one isolated Slice optimization candidate; never edit production RTL."""
from pathlib import Path
import argparse, hashlib, json, shutil, re

a=argparse.ArgumentParser()
a.add_argument('--base',type=Path,required=True)
a.add_argument('--out',type=Path,required=True)
a.add_argument('--stage',choices=['ram','labels','flags'],required=True)
x=a.parse_args()
assert not x.out.exists()
shutil.copytree(x.base,x.out/'project')
h=x.out/'project/user_source/hdl_source'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
name='compact_inspector_osd.v' if x.stage=='labels' else 'observed_classified_pocket_counter.v'
p=h/name;before=sha(p);s=p.read_text()
if x.stage=='ram':
    old='input wire [8:0] empty_address,output reg [8:0] empty_id,'
    assert s.count(old)==1
    s=s.replace(old,old.replace('output reg','output wire'),1)
    declaration='(* ram_style="bram" *) reg [8:0] empty_ids[0:MAX_TOTAL-1];'
    assert s.count(declaration)==1
    s=s.replace(declaration,'(* ram_style="bram_20k(fast)" *) reg [8:0] empty_ids[0:MAX_TOTAL-1];\n reg [8:0] empty_id_raw;reg empty_id_valid;\n assign empty_id=empty_id_valid ? empty_id_raw : 9\'d0;',1)
    old="  empty_id<=empty_address<empty_total ? empty_ids[empty_address] : 9'd0;"
    assert s.count(old)==1
    s=s.replace(old,'  empty_id_raw<=empty_ids[empty_address];\n  empty_id_valid<=empty_address<empty_total;',1)
elif x.stage=='labels':
    anchor='reg formatting,feeding,write_valid,ready;'
    assert s.count(anchor)==1
    s=s.replace(anchor,anchor+'''
// One shared geometry calculator runs in the existing frame preparation time.
// Data comes only from the atomic snapshot; ready masks all four writes.
reg [2:0] label_prepare;
reg [10:0] label_left[0:3],label_right[0:3],label_bottom[0:3];
reg [9:0] label_top[0:3];reg [3:0] label_prefix;
wire [75:0] prep_ob=obs[label_prepare[1:0]*76+:76];
wire [8:0] prep_id=DUAL_REGION_COUNT && label_prepare[1] ?
 record2[94+label_prepare[1:0]*9+:9] : record[94+label_prepare[1:0]*9+:9];
wire prep_prefix=page_s && (DUAL_REGION_COUNT && label_prepare[1] ? show2 : show) && prep_id!=0;
wire [10:0] prep_left=prep_ob[41:31]>WIDTH-112 ? WIDTH-112 : prep_ob[41:31];
wire [9:0] prep_top=!label_prepare[0] ? (prep_ob[19:10]>=108 ? prep_ob[19:10]-28 : 80) :
 (prep_ob[9:0]<HEIGHT-124 ? prep_ob[9:0]+4 : HEIGHT-120);
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)label_prepare<=4;
 else if(start)label_prepare<=0;
 else if(label_prepare<4)begin
  label_left[label_prepare[1:0]]<=prep_left;
  label_right[label_prepare[1:0]]<=prep_left+(prep_prefix ? 11'd112 : 11'd72);
  label_top[label_prepare[1:0]]<=prep_top;
  label_bottom[label_prepare[1:0]]<={1'b0,prep_top}+11'd24;
  label_prefix[label_prepare[1:0]]<=prep_prefix;
  label_prepare<=label_prepare+1'b1;
 end
end
''',1)
    old='''    prefix=page_s && (DUAL_REGION_COUNT && t>=2 ? show2 : show) && id!=0;
    lx=ob[41:31]>WIDTH-112 ? WIDTH-112 : ob[41:31];
    ly=t%2==0 ? (ob[19:10]>=108 ? ob[19:10]-28 : 80) : (ob[9:0]<HEIGHT-124 ? ob[9:0]+4 : HEIGHT-120);
    rx=lx+(prefix ? 112 : 72);
    if(x>=lx && x<rx && y>=ly && y<ly+24)begin label_hit=1;label_slot=t;end'''
    assert s.count(old)==1
    s=s.replace(old,'''    if(x>=label_left[t] && x<label_right[t] && y>=label_top[t] && y<label_bottom[t])begin label_hit=1;label_slot=t;end''',1)
    old='''   prefix=page_s && (DUAL_REGION_COUNT && label_slot[1] ? show2 : show) && id!=0;
   lx=ob[41:31]>WIDTH-112 ? WIDTH-112 : ob[41:31];
   ly=!label_slot[0] ? (ob[19:10]>=108 ? ob[19:10]-28 : 80) : (ob[9:0]<HEIGHT-124 ? ob[9:0]+4 : HEIGHT-120);'''
    assert s.count(old)==1
    s=s.replace(old,'''   prefix=label_prefix[label_slot];
   lx=label_left[label_slot];ly=label_top[label_slot];''',1)
else:
    anchor=' wire [4:0] mi=mapping[oi[OI_BITS-1:0]][4:0];'
    assert s.count(anchor)==1
    s=s.replace(anchor,anchor+'''
 // All single-bit flag writes are in ASSIGN/APPLY/EMIT/CHECK/SKIP.
 // Select their common slot once; all existing enables and NBA order remain.
 wire [4:0] flag_write_slot=phase==ASSIGN ? (matches==1 ? found[4:0] : free_slot[4:0]) :
  phase==APPLY ? mi : phase==EMIT ? event_slot : si[4:0];''',1)
    pattern=r'(valid_tracks|used|armed|quarantined|cross_pending)\[(found\[4:0\]|free_slot\[4:0\]|si\[4:0\]|mi|event_slot|emit_track)\](?=<=)'
    s,n=re.subn(pattern,r'\1[flag_write_slot]',s)
    assert n==22,n
p.write_bytes(s.encode())
scopes={'ram':'Same-clock RAM data and validity split; unchanged original FSM, write path, capacity, IDs, reset-visible output and read latency.','labels':'Shared label geometry computation across four existing preparation clocks; snapshot, ready, pixel latency, last-hit priority and all label content retained.','flags':'Common flag-write slot mux for mutually exclusive original FSM phases. Existing write conditions, order, data, vector loads/clear, reads and phases unchanged.'}
(x.out/'PROVENANCE.json').write_text(json.dumps({'stage':x.stage,'base':str(x.base.resolve()),'production_modified':False,'changed_file':name,'before_sha256':before,'after_sha256':sha(p),'scope':scopes[x.stage]},indent=2)+'\n')
print(x.out)
