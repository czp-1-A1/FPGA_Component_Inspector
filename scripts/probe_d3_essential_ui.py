"""Freeze an essential UI candidate from R55 without changing inspection logic."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil


def replace_once(text, before, after):
    assert text.count(before) == 1, before[:100]
    return text.replace(before, after, 1)


def template_cells():
    cells = [32] * 896

    def word(line, col, value):
        for offset, ch in enumerate(value):
            cells[line * 128 + col + offset] = ord(ch)

    def number(line, col, slot, digits=3):
        for offset in range(digits):
            cells[line * 128 + col + offset] = 256 | (slot << 3) | (digits - offset - 1)

    def special(line, col, slot):
        for offset in range(8):
            cells[line * 128 + col + offset] = 768 | (slot << 3) | (7 - offset)

    def chinese(line, col, glyphs):
        for glyph in glyphs:
            for offset in range(3):
                cells[line * 128 + col] = 128 | (offset << 4) | glyph
                col += 1

    word(0, 0, 'INSPECT D3 R56')
    word(0, 22, 'FPS '); number(0, 26, 14)
    number(0, 35, 15, 4); word(0, 39, 'x'); number(0, 40, 16, 4)
    for line, first, last, status in [(1, 0, 4, 1), (2, 18, 22, 2)]:
        word(line, 0, 'L1 TOTAL ' if line == 1 else 'L2 TOTAL ')
        number(line, 9, first)
        chinese(line, 16, [1, 2]); number(line, 23, first + 1)
        chinese(line, 30, [3, 4]); number(line, 37, first + 2)
        chinese(line, 44, [5, 6, 7]); number(line, 54, first + 3)
        word(line, 61, 'LAST '); number(line, 66, last)
        special(line, 75, status)
    for line, page, slots in [(3, 5, range(6, 14)), (4, 17, range(23, 31))]:
        word(line, 0, 'L1 EMPTY IDS PAGE ' if line == 3 else 'L2 EMPTY IDS PAGE ')
        number(line, 18, page); word(line, 22, ':')
        for col, slot in enumerate(slots):
            number(line, 26 + col * 5, slot)
    word(5, 0, 'K1 START   K2 PAUSE/RESUME   K3 CLEAR   K4 STOP')
    special(6, 0, 3); special(6, 8, 4)
    return cells


def rewrite(name, text):
    if name == 'design_top_wrapper.v':
        text = replace_once(text, 'ENABLE_AUTO_RELAY=1,RAW_EDGE_ONLY=1,',
                            'ENABLE_AUTO_RELAY=1,ESSENTIAL_UI=1,RAW_EDGE_ONLY=1,')
        text = replace_once(text, 'classified_dual_page_osd #(.AUTO_RELAY(',
                            'classified_dual_page_osd #(.ESSENTIAL_UI(ESSENTIAL_UI),.AUTO_RELAY(')
        old = '''status_cdc #(.WIDTH(324)) u_relay_display(
 .S_clk(S_process_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
 .S_data({motor_output,relay_mode,relay_diagnostic,relay_status}),
 .D_data({relay_display_motor,relay_display_mode,relay_display_diagnostic,relay_display_status}));'''
        new = '''// R56 relay display cone begin: keep original SDC instance binding.
localparam RELAY_UI_BITS=ESSENTIAL_UI ? 12 : 324;
wire [RELAY_UI_BITS-1:0] relay_ui_snapshot;
wire [323:0] relay_ui_source=ESSENTIAL_UI ?
 {312'd0,motor_output,relay_mode,relay_status[92:89],relay_status[28:25]} :
 {motor_output,relay_mode,relay_diagnostic,relay_status};
status_cdc #(.WIDTH(RELAY_UI_BITS)) u_relay_display(
 .S_clk(S_process_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
 .S_data(relay_ui_source[RELAY_UI_BITS-1:0]),.D_data(relay_ui_snapshot));
generate if(ESSENTIAL_UI)begin : essential_relay_ui
 assign relay_display_motor=relay_ui_snapshot[11];
 assign relay_display_mode=relay_ui_snapshot[10:8];
 assign relay_display_status={35'd0,relay_ui_snapshot[7:4],25'd0,35'd0,relay_ui_snapshot[3:0],25'd0};
 assign relay_display_diagnostic=0;
end else begin : legacy_relay_ui
 assign {relay_display_motor,relay_display_mode,relay_display_diagnostic,relay_display_status}=relay_ui_snapshot;
end endgenerate
// R56 relay display cone end.
'''
        text = replace_once(text, old, new)
        old = '''    status_cdc #(.WIDTH(160)) u_monitor_display(
        .S_clk(I_sys_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
        .S_data({mon_width,mon_height,mon_fps,mon_lane,mon_format,mon_gap,mon_frames,mon_seconds}),
        .D_data(mon_display));'''
        new = '''    // R56 monitor display cone begin: keep original SDC instance binding.
    localparam MONITOR_UI_BITS=ESSENTIAL_UI ? 48 : 160;
    wire [MONITOR_UI_BITS-1:0] monitor_ui_snapshot;
    wire [159:0] monitor_ui_source=ESSENTIAL_UI ? {112'd0,mon_width,mon_height,mon_fps} :
     {mon_width,mon_height,mon_fps,mon_lane,mon_format,mon_gap,mon_frames,mon_seconds};
    status_cdc #(.WIDTH(MONITOR_UI_BITS)) u_monitor_display(
     .S_clk(I_sys_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
     .S_data(monitor_ui_source[MONITOR_UI_BITS-1:0]),.D_data(monitor_ui_snapshot));
    assign mon_display=ESSENTIAL_UI ? {monitor_ui_snapshot[47:0],112'd0} : monitor_ui_snapshot;
    // R56 monitor display cone end.
'''
        text = replace_once(text, old, new)
        begin = text.index('    status_cdc #(.WIDTH(PUBLISH_BITS)) u_publish_display(')
        end = text.index('    wire transport_ok=', begin)
        old = text[begin:end]
        # Keep capture_ok/lost crossing: capture_ok is still an overlay guard.
        transport = old[old.index('    status_cdc #(.WIDTH(17)) u_transport_display('):]
        transport = transport[:transport.index('    status_cdc #(.WIDTH(84))')]
        legacy = old.replace('    wire [83:0] overflow_display;\n', '').replace(transport, '')
        new = '''    wire [83:0] overflow_display;
'''+transport+'''    generate if(ESSENTIAL_UI)begin : essential_diagnostics_ui
     assign publish_display=0;assign overflow_display=0;
    end else begin : legacy_diagnostics_ui
'''+legacy+'''    end endgenerate
'''
        text = replace_once(text, old, new)
        return text
    if name == 'classified_dual_page_osd.v':
        text = replace_once(text, 'parameter AUTO_RELAY=0,', 'parameter ESSENTIAL_UI=0,AUTO_RELAY=0,')
        text = replace_once(text, 'compact_inspector_osd #(.AUTO_RELAY(',
                            'compact_inspector_osd #(.ESSENTIAL_UI(ESSENTIAL_UI),.AUTO_RELAY(')
        return replace_once(text, '.rgb(rgb),.page(page_s),',
                            '.rgb(rgb),.page(ESSENTIAL_UI ? CLASSIFIED_COUNT : page_s),')
    if name == 'compact_template_rom.v':
        text = replace_once(text, '#(parameter DUAL_REGION_COUNT=0,',
                            '#(parameter ESSENTIAL_UI=0,DUAL_REGION_COUNT=0,')
        table = template_cells()
        lines = ['if(ESSENTIAL_UI)begin',
                 " for(dual_cell=0;dual_cell<2048;dual_cell=dual_cell+1)memory[dual_cell]=10'd32;"]
        for address, value in enumerate(table):
            if value != 32:
                lines.append(f" memory[{address}]=10'h{value:03x};memory[{address+1024}]=10'h{value:03x};")
        lines.append('end else begin')
        text = replace_once(text, 'initial begin\n', 'initial begin\n'+'\n'.join(lines)+'\n')
        return replace_once(text, 'end\nalways @(posedge clk)data<=memory[address];',
                            'end\nend\nalways @(posedge clk)data<=memory[address];')
    assert name == 'compact_inspector_osd.v'
    text = replace_once(text, '#(parameter AUTO_RELAY=0,', '#(parameter ESSENTIAL_UI=0,AUTO_RELAY=0,')
    text = replace_once(text, 'compact_template_rom #(.DUAL_REGION_COUNT(',
                        'compact_template_rom #(.ESSENTIAL_UI(ESSENTIAL_UI),.DUAL_REGION_COUNT(')
    text = replace_once(text, 'reg [2:0] label_prepare;',
                        'reg [2:0] label_prepare;reg [3:0] label_eligible,label_recovered;')
    frame_gap = "wire [8:0] frame_gap=!REPORT_NUMBER_GAPS ? 9'd0 : record[57] ? record[102:94] : record[120:112];"
    text = replace_once(text, frame_gap+'\n', '')
    text = replace_once(text, 'wire [75:0] prep_ob=', frame_gap+'\nwire [75:0] prep_ob=')
    text = replace_once(text, '  label_prefix[label_prepare[1:0]]<=prep_prefix;', '''  label_prefix[label_prepare[1:0]]<=prep_prefix;
  label_eligible[label_prepare[1:0]]<=prep_ob[75] && (!page_s || eligible_s && (DUAL_REGION_COUNT || label_prepare[1]==record[57]));
  label_recovered[label_prepare[1:0]]<=frame_gap!=0 && prep_id>=frame_gap;''')
    text = replace_once(text, 'wire [31:0] hexadecimal=hexvalue(token_d[7:3]);',
                        "wire [31:0] hexadecimal=ESSENTIAL_UI ? 32'd0 : hexvalue(token_d[7:3]);")
    text = replace_once(text, '  case(slot)\n   1:special_char=', '''  if(ESSENTIAL_UI)begin
   case(slot)
    1:special_char=state_char(pos,live[50:48]);
    2:special_char=state_char(pos,live2[50:48]);
    3,4:begin
     if(relay_s[28:25]==15 || relay_s[92:89]==15)message="ALARM FIVE EMPTY";
     else if(relay_s[28:25]!=0 || relay_s[92:89]!=0)message="ALARM K3 CLEAR  ";
     else if(relay_mode_s==2)message="PAUSED K2 RESUME";
     else if(relay_motor_s)message="MOTOR RUNNING   ";
     else message="READY K1 START  ";
     special_char=slot==3 ? message[64+pos*8+:8] : message[pos*8+:8];
    end
   endcase
  end else case(slot)
   1:special_char=''')
    text = replace_once(text, '  2:decoded=hexchar(hexadecimal>>(token_d[2:0]*4));',
                        "  2:decoded=ESSENTIAL_UI ? 8'd32 : hexchar(hexadecimal>>(token_d[2:0]*4));")
    text = replace_once(text, 'token_d[7:3]==20 && gap_id==0 && !(DUAL_REGION_COUNT && page_s)',
                        '!ESSENTIAL_UI && token_d[7:3]==20 && gap_id==0 && !(DUAL_REGION_COUNT && page_s)')
    marker=' adjusted=bcd;'
    mapping=''' if(ESSENTIAL_UI)begin
  next_number=0;
  case(fmt)
   0:next_number={7'd0,live[66:58]};1:next_number={7'd0,live[75:67]};
   2:next_number={7'd0,live[84:76]};3:next_number={7'd0,live[93:85]};
   4:next_number={7'd0,live[210:202]};5:next_number={10'd0,live[222:217]}+1'b1;
   6:next_number={7'd0,live[130+:9]};7:next_number={7'd0,live[139+:9]};
   8:next_number={7'd0,live[148+:9]};9:next_number={7'd0,live[157+:9]};
   10:next_number={7'd0,live[166+:9]};11:next_number={7'd0,live[175+:9]};
   12:next_number={7'd0,live[184+:9]};13:next_number={7'd0,live[193+:9]};
   14:next_number=fp;15:next_number=iw;16:next_number=ih;
   17:next_number={10'd0,live2[222:217]}+1'b1;
   18:next_number={7'd0,live2[66:58]};19:next_number={7'd0,live2[75:67]};
   20:next_number={7'd0,live2[84:76]};21:next_number={7'd0,live2[93:85]};
   22:next_number={7'd0,live2[210:202]};
   23:next_number={7'd0,live2[130+:9]};24:next_number={7'd0,live2[139+:9]};
   25:next_number={7'd0,live2[148+:9]};26:next_number={7'd0,live2[157+:9]};
   27:next_number={7'd0,live2[166+:9]};28:next_number={7'd0,live2[175+:9]};
   29:next_number={7'd0,live2[184+:9]};30:next_number={7'd0,live2[193+:9]};
   31:next_number={7'd0,record[57] ? record[112+:9] : record[94+:9]};
   32:next_number={7'd0,record[57] ? record[121+:9] : record[103+:9]};
   33:next_number={7'd0,record2[112+:9]};34:next_number={7'd0,record2[121+:9]};
  endcase
 end
'''
    text = replace_once(text, marker, mapping+marker)
    old='''   ex<=exposure;ga<=gain;fp<=fps;iw<=width;ih<=height;wr<={8'd0,wb_r};wb<={8'd0,wb_b};'''
    text = replace_once(text, old, '''   fp<=fps;iw<=width;ih<=height;
   ex<=ESSENTIAL_UI ? 0 : exposure;ga<=ESSENTIAL_UI ? 0 : gain;
   wr<=ESSENTIAL_UI ? 0 : {8'd0,wb_r};wb<=ESSENTIAL_UI ? 0 : {8'd0,wb_b};''')
    # The essential template never reads diagnostic functions or snapshots.
    first=text.index('      if(fmt==18)label_bcd0<=')
    end=text.index('      if(fmt==(AUTO_RELAY ?',first)
    old=text[first:end]
    new='''      if(ESSENTIAL_UI)begin
       if(fmt==31)label_bcd0<={adjusted[18:0],number[15]};
       if(fmt==32)label_bcd1<={adjusted[18:0],number[15]};
       if(fmt==33)label_bcd2<={adjusted[18:0],number[15]};
       if(fmt==34)label_bcd3<={adjusted[18:0],number[15]};
       step<=0;
      end else begin
'''+old+'''      end
'''
    text=replace_once(text,old,new)
    text=replace_once(text,'if(fmt==(AUTO_RELAY ? 37 : DUAL_REGION_COUNT && page_s ? 33 : 31))',
                      'if(fmt==(ESSENTIAL_UI ? 34 : AUTO_RELAY ? 37 : DUAL_REGION_COUNT && page_s ? 33 : 31))')
    text=replace_once(text,'if(trace_cross0 || trace_cross1)guide=1;',
                      'if(!ESSENTIAL_UI && (trace_cross0 || trace_cross1))guide=1;')
    text=replace_once(text,'if(ready && ob[75] && (!page_s || eligible_s && (DUAL_REGION_COUNT || t/2==record[57])))begin',
                      'if(ready && (ESSENTIAL_UI ? label_eligible[t] : ob[75] && (!page_s || eligible_s && (DUAL_REGION_COUNT || t/2==record[57]))))begin')
    text=replace_once(text,'(frame_gap!=0 && id>=frame_gap ? "R" : "N")',
                      '(ESSENTIAL_UI ? (label_recovered[label_slot] ? "R" : "N") : (frame_gap!=0 && id>=frame_gap ? "R" : "N"))')
    for term in ['x>=1080 && x<1280','x>=136 && x<344','x>=136 && x<208']:
        text=replace_once(text,'if(ready && '+term,'if(!ESSENTIAL_UI && ready && '+term)
    # Essential status is a human-readable alarm; retain original region/target.
    text=replace_once(text,'   if(page_s && gap_id!=0 && (line==1 || line==2 || line==3))ink=24\'hffe080;',
                      '''   if(page_s && gap_id!=0 && (line==1 || line==2 || line==3))ink=24'hffe080;
   if(ESSENTIAL_UI && line==6 && (relay_s[28:25]!=0 || relay_s[92:89]!=0))ink=24'hff7060;''')
    return text


def main():
    p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
    manifest=json.loads((a.baseline/'frozen_inputs.json').read_text());assert len(manifest)==704 and not a.out.exists()
    for rel,d in manifest.items():assert sha(a.baseline/'project'/rel)==d,rel
    shutil.copytree(a.baseline/'project',a.out/'project')
    names=['design_top_wrapper.v','classified_dual_page_osd.v','compact_template_rom.v','compact_inspector_osd.v'];changes={}
    for name in names:
        rel='user_source/hdl_source/'+name;q=a.out/'project'/rel
        q.write_bytes(rewrite(name,q.read_text()).encode());changes[rel]={'before_sha256':manifest[rel],'after_sha256':sha(q)}
    for rel,d in manifest.items():assert sha(a.out/'project'/rel)==changes.get(rel,{}).get('after_sha256',d),rel
    result={'status':'ISOLATED_ESSENTIAL_UI_NOT_YET_VERIFIED','baseline':str(a.baseline.resolve()),'baseline_manifest_sha256':sha(a.baseline/'frozen_inputs.json'),'changes':changes,'unchanged_inputs':700,'source_files':704,'production_modified':False,'board_operated':False,'scope':'Essential UI, frame-cached eligibility/N-R, display-only relay12bit/monitor48bit crossings; remove display-only publish/overflow/WB crossings. All counting/parking/recognition, atomic frame metadata, camera and transport guards unchanged.'}
    (a.out/'PROVENANCE.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))


if __name__=='__main__':main()
