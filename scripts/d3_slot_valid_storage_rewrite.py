"""Exact reversible word-valid encoding of the private indexed result buffer."""
import re

DECLARATION = 'reg [151:0] legacy_objects;reg [303:0] legacy_region_objects;reg [ZONES*304-1:0] recorder_storage;'
NEW_DECLARATION = 'reg [151:0] legacy_objects;reg [303:0] legacy_region_objects;wire [ZONES*304-1:0] recorder_storage;reg [ZONES*304-1:0] recorder_storage_legacy;'
ANCHOR = 'wire [151:0] sorted0=INDEXED ? recorder_storage[151:0]'
BLOCK = '''// A word-written bit represents an erased zero word. Keep the data FFs
// unreset, but preserve every partial packet, error and cancellation value.
// Main-FSM legacy storage is unused and removed when this branch is selected.
generate if(DUAL_STOP && INDEXED)begin : word_valid_result_storage
 reg [ZONES*304-1:0] raw_words;
 reg [ZONES*4-1:0] written;
 integer valid_i,raw_i;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)written<=0;
  else if(frame_start || invalidate || pixel_sof)written<=0;
  else if(!(cap_write && seen) && phase==PACK_SCAN)
   for(valid_i=0;valid_i<ZONES*4;valid_i=valid_i+1)if(pack_destination==valid_i)written[valid_i]<=1'b1;
 end
 always @(posedge clk)if(rst_n && !frame_start && !invalidate && !pixel_sof && !(cap_write && seen))begin
  if(phase==PACK_SCAN)begin
   for(raw_i=0;raw_i<ZONES*4;raw_i=raw_i+1)if(pack_destination==raw_i)raw_words[raw_i*76+:76]<=packed_one;
  end else if(phase==PACK_FINISH)begin
   if(pack_duplicate[0])raw_words[3*76+:76]<=0;
   if(pack_duplicate[1])raw_words[7*76+:76]<=0;
   if(pack_duplicate[2])raw_words[11*76+:76]<=0;
   if(pack_duplicate[3])raw_words[15*76+:76]<=0;
  end
 end
 genvar ws;
 for(ws=0;ws<ZONES*4;ws=ws+1)begin : visible_words
  assign recorder_storage[ws*76+:76]=written[ws] ? raw_words[ws*76+:76] : 76'd0;
 end
end else begin : legacy_result_storage
 assign recorder_storage=recorder_storage_legacy;
end endgenerate
'''

def apply(text):
    assert text.count(DECLARATION) == text.count(ANCHOR) == 1
    text = text.replace(DECLARATION, NEW_DECLARATION, 1)
    text, count = re.subn(r'\brecorder_storage(?=(?:\[[^\]]+\])?<=)', 'recorder_storage_legacy', text)
    assert count == 9, count
    return text.replace(ANCHOR, BLOCK + ANCHOR, 1)

def restore(text):
    assert text.count(NEW_DECLARATION) == text.count(BLOCK) == 1
    text = text.replace(BLOCK, '', 1).replace(NEW_DECLARATION, DECLARATION, 1)
    text, count = re.subn(r'\brecorder_storage_legacy(?=(?:\[[^\]]+\])?<=)', 'recorder_storage', text)
    assert count == 9, count
    return text
