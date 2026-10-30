"""Prove the production observation clone adds only read-only wires/ports."""
from pathlib import Path
import argparse,hashlib,json
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
placement_attributes=[]
for declaration in ['reg [5:0] ledger[0:MAX_TOTAL-1];','reg [8:0] empty_ids[0:MAX_TOTAL-1];']:
 annotated='(* ram_style="bram" *) '+declaration
 if annotated in restored:
  assert restored.count(annotated)==1
  restored=restored.replace(annotated,declaration,1);placement_attributes.append(declaration)
assert len(placement_attributes) in [0,2],'Only the paired ledger/empty-ID placement annotations are allowed'
assert restored==original,'Observation clone changed original parameters, memory behavior, state transitions, decisions or clock phases'
assert sha(source)=='67dfbdd7f139eb275decc48d6fd19e64965679ad352b3a291a0675a09401394c'
result={'status':'PASS_R27B_ORIGINAL_BODY_EXACT_READONLY_OBSERVER','original_raw_sha256':sha(source),'observed_raw_sha256':sha(clone),'original_normalized_body_sha256':hashlib.sha256(original.encode()).hexdigest(),'restored_normalized_body_sha256':hashlib.sha256(restored.encode()).hexdigest(),'placement_attributes':placement_attributes,'difference':'Only module name, seven passive output declarations and seven read-only continuous assignments'+('; plus two explicit ledger/empty-ID bram placement annotations' if placement_attributes else '')+'; no FSM, memory behavior, parameter, threshold or clock phase edits.'}
args.out.write_text(json.dumps(result,indent=2)+'\n')
print(result['status'])
