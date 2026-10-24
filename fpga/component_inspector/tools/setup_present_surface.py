"""One-time, declared P01-to-P02 edits in an isolated frozen source copy."""
from pathlib import Path
import json

P = Path(__file__).resolve().parents[1]
edits = {
 'user_source/hdl_source/frame_shape_search.v': [
  ('parameter REVIEW_PROBE=0,', 'parameter SURFACE_REVIEW=0,REVIEW_PROBE=0,'),
  ('HIGH_REQ=24,HIGH_CHECK=25;', 'HIGH_REQ=24,HIGH_CHECK=25,SURFACE_WAIT=26;'),
  ('reg weak_bank[0:SLOTS-1];reg [15:0] dark_bank[0:SLOTS-1];',
   'reg weak_bank[0:SLOTS-1];reg [15:0] dark_bank[0:SLOTS-1];\nlocalparam SURFACE_ACTIVE=SURFACE_REVIEW && REVIEW_PROBE && REGIONS;\nwire surface_ready,surface_normal;'),
  ('else begin origin_x<=ref_cx;origin_y<=ref_cy;phase<=REF_REQ;end',
   'else begin origin_x<=ref_cx;origin_y<=ref_cy;phase<=SURFACE_ACTIVE && state_bank[ref_index]==2 && !weak_bank[ref_index] ? SURFACE_WAIT : REF_REQ;end'),
  ('   REF_REQ:begin', '   SURFACE_WAIT:if(surface_ready)phase<=REF_REQ;\n   REF_REQ:begin'),
  ("if(reason_bank[ref_index]!=4'hf)reason_bank[ref_index][3]<=left_dark<ref_min || right_dark+dark_word<ref_min;",
   "if(SURFACE_ACTIVE && !weak_bank[ref_index])reason_bank[ref_index][3]<=!surface_normal;\n      else if(reason_bank[ref_index]!=4'hf)reason_bank[ref_index][3]<=left_dark<ref_min || right_dark+dark_word<ref_min;"),
  ('end else begin : no_review_measurement',
   '''if(SURFACE_REVIEW)begin : surface_measurement
 present_surface_check #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.FOREGROUND(FOREGROUND)) surface(
  .clk(clk),.rst_n(rst_n),.cancel(frame_start || invalidate || pixel_sof),
  .write_enable(cap_write),.write_x(gray_x),.write_y(gray_y),.write_data(gray_word),
  .measure(phase==REF_ORIGIN && found_bank[ref_index] && state_bank[ref_index]==2 && !weak_bank[ref_index]),
  .xmin({{(10-XB){1'b0}},xmin_bank[ref_index]}),.xmax({{(10-XB){1'b0}},xmax_bank[ref_index]}),
  .ymin({{(10-YB){1'b0}},ymin_bank[ref_index]}),.ymax({{(10-YB){1'b0}},ymax_bank[ref_index]}),
  .ready(surface_ready),.normal(surface_normal));
end else begin : surface_disabled
 assign surface_ready=1;assign surface_normal=0;
end
end else begin : no_review_measurement
 assign surface_ready=1;assign surface_normal=0;'''),
 ],
 'user_source/hdl_source/isp/isp_top.v': [
  ('CALIBRATION=0,REVIEW_PROBE=0,', 'CALIBRATION=0,SURFACE_REVIEW=0,REVIEW_PROBE=0,'),
  ('frame_shape_search #(.REVIEW_PROBE(', 'frame_shape_search #(.SURFACE_REVIEW(SURFACE_REVIEW),.REVIEW_PROBE('),
 ],
 'user_source/hdl_source/design_top_wrapper.v': [
  ('parameter ENABLE_REVIEW_PROBE=1,', 'parameter ENABLE_PRESENT_SURFACE=1,ENABLE_REVIEW_PROBE=1,'),
  ('isp_top #(.REVIEW_PROBE(', 'isp_top #(.SURFACE_REVIEW(ENABLE_PRESENT_SURFACE),.REVIEW_PROBE('),
 ],
 'user_source/hdl_source/compact_template_rom.v': [
  ("memory[9]=REVIEW_PROBE ? 10'h031 : 10'h033;", "memory[9]=REVIEW_PROBE ? 10'h032 : 10'h033;"),
  ("memory[1032]=REVIEW_PROBE ? 10'h031 : 10'h033;", "memory[1032]=REVIEW_PROBE ? 10'h032 : 10'h033;"),
 ],
 'td_project/camera_to_dsi_display.al': [
  ('            <File Path="../user_source/hdl_source/present_review_probe.v">',
   '            <File Path="../user_source/hdl_source/present_surface_check.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="218"/></FileInfo></File>\n            <File Path="../user_source/hdl_source/present_review_probe.v">'),
 ],
}
if __name__ == '__main__':
 for name, replacements in edits.items():
  path=P/name;text=path.read_text(encoding='utf-8-sig')
  for old,new in replacements:
   assert text.count(old)==1,(name,old,text.count(old))
   text=text.replace(old,new,1)
  path.write_text(text,encoding='utf-8')
 print('P02 declared changes applied; original tests, counter and SDC preserved')
