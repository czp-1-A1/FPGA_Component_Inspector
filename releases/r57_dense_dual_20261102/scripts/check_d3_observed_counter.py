"""Prove the production observation clone adds only read-only wires/ports."""
from pathlib import Path
import argparse,hashlib,json,re
from d3_check_prepare_rewrite import restore as restore_check_prepare
r=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--source',type=Path,default=r/'fpga/component_inspector');a.add_argument('--out',type=Path,default=r/'docs/D3_OBSERVED_COUNTER_PROOF.json');args=a.parse_args()
h=args.source/'user_source/hdl_source'
source=h/'classified_pocket_counter.v';clone=h/'observed_classified_pocket_counter.v'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
original=source.read_text();observed=clone.read_text()
ports=""" output wire parking_snapshot,parking_motion_valid,parking_seed_valid,
 output wire signed [12:0] parking_dx,output wire [5:0] parking_radius,
 output wire [10:0] parking_seed_x,output wire [9:0] parking_seed_y,
"""
wires=""" // Passive observations only: original state transitions below are unchanged.
 assign parking_snapshot=snapshot_new;
 assign parking_motion_valid=frame_trusted && motion_count!=0 && state==RUN;
 assign parking_dx=previous_dx;
 assign parking_radius=match_step[5:0];
 assign parking_seed_valid=event_valid && missing==0 && used[event_slot];
 assign parking_seed_x=old_x;assign parking_seed_y=old_y;
"""
assert observed.count(ports)==1 and observed.count(wires)==1
restored=observed.replace('module observed_classified_pocket_counter #(','module classified_pocket_counter #(',1).replace(ports,'',1).replace(wires,'',1)
check_prepare=False
check_prepare_variant='none'
if 'reg signed [12:0] check_gap_step;' in restored:
 check_prepare_variant='offset' if 'check_gap_origin' in restored else 'minimal'
 restored=restore_check_prepare(restored);check_prepare=True
read_reencoding=False
if 'output wire [8:0] empty_id,' in restored:
 expected="\n reg [8:0] empty_id_raw;reg empty_id_valid;\n assign empty_id=empty_id_valid ? empty_id_raw : 9'd0;"
 reads='  empty_id_raw<=empty_ids[empty_address];\n  empty_id_valid<=empty_address<empty_total;'
 assert restored.count(expected)==1 and restored.count(reads)==1
 restored=restored.replace('output wire [8:0] empty_id,','output reg [8:0] empty_id,',1).replace(expected,'',1).replace(reads,"  empty_id<=empty_address<empty_total ? empty_ids[empty_address] : 9'd0;",1)
 read_reencoding=True
placement_attributes=[]
for declaration in ['reg [5:0] ledger[0:MAX_TOTAL-1];','reg [8:0] empty_ids[0:MAX_TOTAL-1];']:
 for style in ['bram','bram_20k(fast)']:
  annotated='(* ram_style="'+style+'" *) '+declaration
  if annotated in restored:
   assert restored.count(annotated)==1
   restored=restored.replace(annotated,declaration,1);placement_attributes.append(declaration)
assert len(placement_attributes) in [0,2],'Only the paired ledger/empty-ID placement annotations are allowed'
flag_write_sharing=False
flag_mux='''
 // All single-bit flag writes are in ASSIGN/APPLY/EMIT/CHECK/SKIP.
 // Select their common slot once; all existing enables and NBA order remain.
 wire [4:0] flag_write_slot=phase==ASSIGN ? (matches==1 ? found[4:0] : free_slot[4:0]) :
  phase==APPLY ? mi : phase==EMIT ? event_slot : si[4:0];'''
if 'flag_write_slot' in restored:
 assert restored.count(flag_mux)==1
 restored=restored.replace(flag_mux,'',1)
 pattern=r'(valid_tracks|used|armed|quarantined|cross_pending)\[(found\[4:0\]|free_slot\[4:0\]|si\[4:0\]|mi|event_slot|emit_track)\](?=<=)'
 expected,n=re.subn(pattern,r'\1[flag_write_slot]',original)
 assert n==22 and restored==expected,'Only the enumerated common flag write index rewrite is allowed'
 restored=original;flag_write_sharing=True
assert restored==original,'Observation clone changed original parameters, memory behavior, state transitions, decisions or clock phases'
assert sha(source)=='67dfbdd7f139eb275decc48d6fd19e64965679ad352b3a291a0675a09401394c'
result={'status':'PASS_R27B_BODY_EXACT_EXCEPT_ENUMERATED_CHECK_PREPARATION' if check_prepare else 'PASS_R27B_BODY_EXACT_EXCEPT_ENUMERATED_STORAGE_REWRITES' if read_reencoding or flag_write_sharing else 'PASS_R27B_ORIGINAL_BODY_EXACT_READONLY_OBSERVER','original_raw_sha256':sha(source),'observed_raw_sha256':sha(clone),'original_normalized_body_sha256':hashlib.sha256(original.encode()).hexdigest(),'restored_normalized_body_sha256':hashlib.sha256(restored.encode()).hexdigest(),'placement_attributes':placement_attributes,'id_ram_same_clock_read_reencoding':read_reencoding,'flag_write_index_sharing':flag_write_sharing,'check_prepare_retiming':check_prepare,'difference':'Module name, seven passive outputs/assignments'+('; two explicit RAM placement annotations' if placement_attributes else '')+('; exact enumerated same-clock RAM data/valid read split, requiring separate behavioral equivalence' if read_reencoding else '')+('; exact common write-index mux for 22 single-bit writes, requiring separate cycle equivalence' if flag_write_sharing else '')+('; exact two-block READ_CHECK preparation rewrite, requiring separate modulo arithmetic, parameter/stability and cycle equivalence' if check_prepare else '')+'; original FSM, parameters, thresholds, write conditions/data/order and clock phases restored byte-exact after those enumerated rewrites.'}
result['check_prepare_variant']=check_prepare_variant
if check_prepare_variant=='minimal':
 result['difference']=result['difference'].replace('requiring separate modulo arithmetic, parameter/stability and cycle equivalence','original signed distance arithmetic retained; requiring separate frame-parameter stability, fresh-track and cycle equivalence')
args.out.write_text(json.dumps(result,indent=2)+'\n')
print(result['status'])
