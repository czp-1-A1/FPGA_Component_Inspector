from pathlib import Path
import copy, json, re

root=Path(__file__).resolve().parents[1]
hdl=root/'user_source/hdl_source'
def edit(name, changes):
    path=hdl/name; raw=path.read_bytes(); ending='\r\n' if b'\r\n' in raw else '\n'
    text=raw.decode('utf-8').replace('\r\n','\n')
    for old,new,count in changes:
        assert text.count(old)==count,(name,old,text.count(old),count)
        text=text.replace(old,new)
    path.write_bytes(text.replace('\n',ending).encode('utf-8'))

probe_generate='''
generate if(REVIEW_PROBE && REGIONS)begin : review_measurement
 wire [$clog2(SLOTS)-1:0] index0=found_bank[1] && (!found_bank[0] || xmin_bank[1]<xmin_bank[0]) ? 1 : 0;
 wire [$clog2(SLOTS)-1:0] index1=found_bank[REGION_SLOTS+1] && (!found_bank[REGION_SLOTS] || xmin_bank[REGION_SLOTS+1]<xmin_bank[REGION_SLOTS]) ? REGION_SLOTS+1 : REGION_SLOTS;
 wire [35:0] references={weak_bank[index1],found_bank[index1] && state_bank[index1]==2,dark_bank[index1],
                       weak_bank[index0],found_bank[index0] && state_bank[index0]==2,dark_bank[index0]};
 reg [15:0] first_gray;reg [31:0] gray_word;reg [10:0] gray_x;reg [9:0] gray_y;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin first_gray<=0;gray_word<=0;gray_x<=0;gray_y<=0;end
  else begin
   if(accept_d && y_d[0] && !x_d[2])first_gray<={block1[9:2],block0[9:2]};
   gray_word<={block1[9:2],block0[9:2],first_gray};gray_x<=x_d;gray_y<=y_d;
   if(frame_start || invalidate || pixel_sof)first_gray<=0;
  end
 end
 present_review_probe #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) probe(
  .clk(clk),.rst_n(rst_n),.cancel(frame_start || invalidate || pixel_sof),
  .write_enable(cap_write),.write_x(gray_x),.write_y(gray_y),.write_data(gray_word),
  .measure(sample_new),.objects(region_objects),.references(references),.ready(probe_ready),.record(probe_record));
end else begin : no_review_measurement
 assign probe_record=0;assign probe_ready=1;
end endgenerate
'''
edit('frame_shape_search.v',[
 ('parameter ROW_GUARDED_BRIGHT_EMPTY=0,COUNT_CANDIDATES=0,MULTITHRESHOLD_EMPTY=0,','parameter REVIEW_PROBE=0,ROW_GUARDED_BRIGHT_EMPTY=0,COUNT_CANDIDATES=0,MULTITHRESHOLD_EMPTY=0,',1),
 ('input wire recorder_hold_valid,input wire [10:0] recorder_hold_x,input wire [9:0] recorder_hold_y','input wire recorder_hold_valid,input wire [10:0] recorder_hold_x,input wire [9:0] recorder_hold_y,\n output wire [127:0] probe_record,output wire probe_ready',1),
 ('reg [1:0] state_bank [0:SLOTS-1];reg [3:0] reason_bank [0:SLOTS-1];','reg [1:0] state_bank [0:SLOTS-1];reg [3:0] reason_bank [0:SLOTS-1];\nreg weak_bank[0:SLOTS-1];reg [15:0] dark_bank[0:SLOTS-1];',1),
 ('reason_bank[bi]<=0;','reason_bank[bi]<=0;weak_bank[bi]<=0;dark_bank[bi]<=0;',2),
 ('state_bank[dst]<=state_bank[src];reason_bank[dst]<=reason_bank[src];','state_bank[dst]<=state_bank[src];reason_bank[dst]<=reason_bank[src];weak_bank[dst]<=weak_bank[src];',1),
 ('state_bank[bank1]<=state_bank[bank0];reason_bank[bank1]<=reason_bank[bank0];','state_bank[bank1]<=state_bank[bank0];reason_bank[bank1]<=reason_bank[bank0];weak_bank[bank1]<=weak_bank[bank0];',1),
 *[(f'reason_bank[{dst}]<=small_pass ? (candidate_state==2 ? 4\'hf : 4\'d0) : candidate_reason;',f'reason_bank[{dst}]<=small_pass ? (candidate_state==2 ? 4\'hf : 4\'d0) : candidate_reason;weak_bank[{dst}]<=small_pass;',1) for dst in ['dst','bank0','bank1']],
 ('if(ref_side && ref_word==2 && ref_last_row)begin','if(ref_side && ref_word==2 && ref_last_row)begin\n     if(REVIEW_PROBE)dark_bank[ref_index]<={left_dark[8] ? 8\'hff : left_dark[7:0],(right_dark+dark_word)>=256 ? 8\'hff : (right_dark[7:0]+{5\'d0,dark_word})};',1),
 ('\nendmodule','\n'+probe_generate+'endmodule',1),
])
edit('isp/isp_top.v',[
 ('REGIONS=0,CALIBRATION=0,CLASSIFIED_COUNT=0','REGIONS=0,CALIBRATION=0,REVIEW_PROBE=0,CLASSIFIED_COUNT=0',1),
 ('wire search_ready,search_new,search_located,search_review;','wire search_probe_ready;wire [127:0] search_probe_record;\nwire search_ready,search_new,search_located,search_review;',1),
 ('generate if(CALIBRATION)begin : calibration_measurement','generate if(REVIEW_PROBE && REGIONS)begin : review_calibration_measurement\n assign calibration_record=search_probe_record;\nend else if(CALIBRATION)begin : calibration_measurement',1),
 ('if(metadata_wait==1 && (!CLASSIFIED_COUNT || classified_ready)) begin','if(metadata_wait==1 && (!CLASSIFIED_COUNT || classified_ready) && (!REVIEW_PROBE || search_probe_ready)) begin',1),
 ('frame_shape_search #(.WIDTH(WIDTH),','frame_shape_search #(.REVIEW_PROBE(REVIEW_PROBE),.WIDTH(WIDTH),',1),
 ('.recorder_hold_y(recorder_hold_y));','.recorder_hold_y(recorder_hold_y),.probe_record(search_probe_record),.probe_ready(search_probe_ready));',1),
 ('assign legacy_search_objects=0;','assign search_probe_record=0;assign search_probe_ready=1;\n assign legacy_search_objects=0;',1),
])
edit('design_top_wrapper.v',[
 ('parameter ENABLE_CLASSIFIED_COUNT=1,','parameter ENABLE_REVIEW_PROBE=1,ENABLE_CLASSIFIED_COUNT=1,',1),
 ('isp_top #(.CLASSIFIED_COUNT(', 'isp_top #(.REVIEW_PROBE(ENABLE_REVIEW_PROBE && CALIBRATION_MODE),.CLASSIFIED_COUNT(',1),
 ('classified_dual_page_osd #(.COMPACT_UI(', 'classified_dual_page_osd #(.REVIEW_PROBE(ENABLE_REVIEW_PROBE && CALIBRATION_MODE),.COMPACT_UI(',1),
])
edit('classified_dual_page_osd.v',[
 ('parameter COMPACT_UI=0,','parameter REVIEW_PROBE=0,COMPACT_UI=0,',1),
 ('compact_inspector_osd #(.WIDTH(', 'compact_inspector_osd #(.REVIEW_PROBE(REVIEW_PROBE),.WIDTH(',1),
])
edit('compact_inspector_osd.v',[
 ('parameter WIDTH=1280,','parameter REVIEW_PROBE=0,WIDTH=1280,',1),
 ('compact_template_rom template_font','compact_template_rom #(.REVIEW_PROBE(REVIEW_PROBE)) template_font',1),
 ("16,23:hexvalue=cal_s && c[63] ? {24'd0,c[59:52]} : 0;","16,23:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[63:61],1'b0,c[60:57]} : {24'd0,c[59:52]}) : 0;",1),
 ("17,24:hexvalue=cal_s && c[63] ? {24'd0,c[51:44]} : 0;","17,24:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[39:32]} : {24'd0,c[51:44]}) : 0;",1),
 ("18,25:hexvalue=cal_s && c[63] ? {24'd0,c[43:36]} : 0;","18,25:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[31:24]} : {24'd0,c[43:36]}) : 0;",1),
 ("19,26:hexvalue=cal_s && c[63] ? {25'd0,c[13:7]} : 0;","19,26:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[23:16]} : {25'd0,c[13:7]}) : 0;",1),
 ("20,27:hexvalue=cal_s && c[63] ? {25'd0,c[6:0]} : 0;","20,27:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[15:8]} : {25'd0,c[6:0]}) : 0;",1),
 ("21,28:hexvalue=cal_s && c[63] ? {19'd0,c[26:14]} : 0;","21,28:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[7:0]} : {19'd0,c[26:14]}) : 0;",1),
 ("22,29:hexvalue=cal_s && c[63] ? {31'd0,c[62]} : 0;","22,29:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {16'd0,c[56:41]} : {31'd0,c[62]}) : 0;",1),
])

layout=json.loads((root/'sim/compact_assets/layout.json').read_text(encoding='utf-8'))
def tokens(fields):
    result=[32]*1024
    for line,column,value in fields:
        if isinstance(value,str):
            values=[]
            for c in value:
                values.extend([0x80+(offset<<4)+layout['glyph_ids'][c] for offset in range(3)] if ord(c)>127 else [ord(c)])
        else:
            values=[value['mode']*256+value['slot']*8+p for p in reversed(range(value['digits']))]
        for offset,v in enumerate(values): result[line*128+column+offset]=v
    return result
original=[]
for page in layout['pages']: original+=tokens(page['fields'])
rom_path=hdl/'compact_template_rom.v'
rom=rom_path.read_text(encoding='utf-8')
actual={int(a):int(b,16) for a,b in re.findall(r"memory\[(\d+)\]=10'h([0-9a-fA-F]+);",rom)}
assert [actual[i] for i in range(2048)]==original
probe=copy.deepcopy(original)
for page,title in [(0,'DETECT P01'),(1,'COUNT P01')]:
    for i,c in enumerate(title):probe[page*1024+i]=ord(c)
for line,base in [(3,16),(4,23)]:
    fields=[(line,0,f'PRB{line-2} RS'),(line,8,dict(mode=2,slot=base,digits=2)),
      (line,12,'C'),(line,14,dict(mode=2,slot=base+1,digits=2)),(line,18,'L'),(line,20,dict(mode=2,slot=base+2,digits=2)),
      (line,24,'R'),(line,26,dict(mode=2,slot=base+3,digits=2)),(line,30,'T'),(line,32,dict(mode=2,slot=base+4,digits=2)),
      (line,36,'B'),(line,38,dict(mode=2,slot=base+5,digits=2)),(line,42,'DARK'),(line,47,dict(mode=2,slot=base+6,digits=4))]
    if line==4: fields += [(line,56,'FRAME'),(line,62,dict(mode=3,slot=16,digits=1))]
    probe[line*128:(line+1)*128]=tokens(fields)[line*128:(line+1)*128]
changes=[('module compact_template_rom(', 'module compact_template_rom #(parameter REVIEW_PROBE=0)(',1)]
for address,(old,new) in enumerate(zip(original,probe)):
    if old!=new:
        changes.append((f"memory[{address}]=10'h{old:03x};",f"memory[{address}]=REVIEW_PROBE ? 10'h{new:03x} : 10'h{old:03x};",1))
edit('compact_template_rom.v',changes)
(root/'sim/compact_assets/review_probe_template.hex').write_text(''.join(f'{x:03x}\n' for x in probe),encoding='ascii')
entry=root/'td_project/camera_to_dsi_display.al'
xml=entry.read_text(encoding='utf-8')
item='<File Path="../user_source/hdl_source/present_review_probe.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="219"/></FileInfo></File>'
xml=xml.replace('<Verilog>','<Verilog>\n            '+item,1)
entry.write_text(xml,encoding='utf-8')
print('Prepared independent P01 read-only probe; original classification expressions unchanged.')
