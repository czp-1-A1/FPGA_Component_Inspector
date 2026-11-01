// Shared R13 UI: one ASCII, seven CJK glyphs, unchanged Anlogic logo,
// one sequential decimal formatter. No classifier or recorder decisions here.
// The text plane is complete before row8. Snapshot is the first active pixel,
// after DDR metadata has settled. RGB/DE/HS/VS have the original three clocks.
module compact_inspector_osd #(parameter ESSENTIAL_UI=0,AUTO_RELAY=0,RELAY_TARGET_X=152,RELAY_TOL_PX=80,DUAL_REGION_COUNT=0,PRESENT_TRACE=0,BUILD_R22=0,EMPTY_TRACE=0,BUILD_R20=0,BUILD_R19=0,BUILD_R18=0,BUILD_R17=0,REVIEW_PROBE=0,WIDTH=1280,HEIGHT=720,DIAG_BITS=27,ENABLE=1,REPORT_NUMBER_GAPS=1)(
 input wire [127:0] relay_status,input wire [2:0] relay_mode,input wire relay_motor,
 input wire clk,rst_n,vs,hs,de,input wire [23:0] rgb,input wire page,
 input wire [15:0] exposure,gain,fps,width,height,
 input wire [7:0] wb_r,wb_b,roi_mean,roi_min,roi_max,
 input wire wb_tune,wb_pending,roi_valid,cfg_done,
 input wire [1:0] view_mode,input wire [12:0] edge_count,
 input wire [15:0] lane_errors,format_errors,i2c_errors,gaps,overflow_frames,lost_frames,underflow_frames,
 input wire [31:0] frames,input wire [35:0] diagnostics,input wire [DIAG_BITS-1:0] publish_diagnostic,
 input wire [303:0] objects,input wire [127:0] calibration_record,input wire calibration_valid,
 input wire [3:0] local_wait_reason,
 input wire [256*(1+DUAL_REGION_COUNT)-1:0] live_record,frame_record,input wire eligible,
 output reg out_vs,out_hs,out_de,output reg [23:0] out_rgb
);
reg de_d;reg [10:0] x;reg [9:0] y;
wire start=de && !de_d && y==0;
reg [7:0] relay_q0,relay_q1;reg [11:0] relay_id0,relay_id1;
reg [127:0] relay_s;reg [2:0] relay_mode_s;reg relay_motor_s;
reg page_s,eligible_s,show,cal_s,gray_s,cfg_s,tune_s,pending_s;
reg [1:0] mode_s;reg [3:0] wait_s;
reg [255:0] live,record,live2,record2;reg show2;
wire [255:0] input_live2=live_record[256*DUAL_REGION_COUNT+:256];
wire [255:0] input_record2=frame_record[256*DUAL_REGION_COUNT+:256];reg [303:0] obs;reg [127:0] cal;
reg [15:0] ex,ga,fp,iw,ih,wr,wb,gm,gn,gx,ec;
reg [15:0] le,fe,ie,gp,ofl,ufl,lost;
reg [31:0] fr,pub;reg [35:0] diag;
reg [75:0] primary;reg [2:0] np,ne,nu;
wire [19:0] cache[0:31];reg [19:0] label_bcd0,label_bcd1,label_bcd2,label_bcd3;reg [5:0] fmt;reg [4:0] step;
reg [15:0] number,next_number;reg [19:0] bcd,adjusted;
reg formatting,feeding,write_valid,ready;
// One shared geometry calculator runs in the existing frame preparation time.
// Data comes only from the atomic snapshot; ready masks all four writes.
reg [2:0] label_prepare;reg [3:0] label_eligible,label_recovered;
reg [10:0] label_left[0:3],label_right[0:3],label_bottom[0:3];
reg [9:0] label_top[0:3];reg [3:0] label_prefix;
wire [8:0] frame_gap=!REPORT_NUMBER_GAPS ? 9'd0 : record[57] ? record[102:94] : record[120:112];
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
  label_eligible[label_prepare[1:0]]<=prep_ob[75] && (!page_s || eligible_s && (DUAL_REGION_COUNT || label_prepare[1]==record[57]));
  label_recovered[label_prepare[1:0]]<=frame_gap!=0 && prep_id>=frame_gap;
  label_prepare<=label_prepare+1'b1;
 end
end

reg [9:0] cursor,write_cursor;
wire [9:0] token;reg [7:0] decoded;
reg [19:0] plane[0:1023];
genvar cache_word;
generate for(cache_word=0;cache_word<32;cache_word=cache_word+1)begin : numeric_cache_view
 assign cache[cache_word]=plane[896+cache_word];
end endgenerate
reg [9:0] token_d,write_cursor_d;reg write_valid_d;
wire cache_write=rst_n && !start && formatting && step==16 && fmt<32;
wire text_write=rst_n && !start && write_valid_d;
always @(posedge clk)begin
 if(cache_write)plane[{5'd28,fmt[4:0]}]<={adjusted[18:0],number[15]};
 else if(text_write)plane[write_cursor_d]<={12'd0,decoded};
end
// Predict exactly the next x/y register state, so a synchronous text-plane
// read is available for the SAME pixel as the former asynchronous lookup.
// Text is finalized before ready exposes it; fonts and the RGB/control
// output pipeline retain their original clocks. No display content removed.
wire [10:0] plane_next_x=vs ? 11'd0 : de ? x+11'd1 : de_d ? 11'd0 : x;
wire [9:0] plane_next_y=vs ? 10'd0 : !de && de_d ? y+10'd1 : y;
wire [10:0] plane_next_dx=plane_next_x-11'd136;
wire [2:0] plane_next_line=
 (plane_next_y>=32 && plane_next_y<56) ? 3'd1 :
 (plane_next_y>=56 && plane_next_y<72) ? 3'd2 :
 (plane_next_y>=8 && plane_next_y<32) ? 3'd0 :
 (plane_next_y>=HEIGHT-88 && plane_next_y<HEIGHT-64) ? 3'd3 :
 (plane_next_y>=HEIGHT-64 && plane_next_y<HEIGHT-40) ? 3'd4 :
 (plane_next_y>=HEIGHT-40 && plane_next_y<HEIGHT-16) ? 3'd5 :
 (plane_next_y>=HEIGHT-16) ? 3'd6 : 3'd0;
wire [9:0] plane_next_address={plane_next_line,plane_next_dx[9:3]};
reg [19:0] plane_q;
wire [9:0] shared_read_address=(feeding || write_valid) ? {5'd28,token[7:3]} : plane_next_address;
always @(posedge clk)plane_q<=plane[shared_read_address];

compact_template_rom #(.ESSENTIAL_UI(ESSENTIAL_UI),.DUAL_REGION_COUNT(DUAL_REGION_COUNT),.PRESENT_TRACE(PRESENT_TRACE),.BUILD_R22(BUILD_R22),.EMPTY_TRACE(EMPTY_TRACE),.BUILD_R20(BUILD_R20),.BUILD_R19(BUILD_R19),.BUILD_R18(BUILD_R18),.BUILD_R17(BUILD_R17),.REVIEW_PROBE(REVIEW_PROBE)) template_font(clk,{page_s,cursor},token);
// R15 production suppresses numbering-confidence UI only; classification
// colours and LOST/HOLD/CHECK state protection remain active.
wire [8:0] gap_id=!REPORT_NUMBER_GAPS ? 9'd0 : live[57] ? live[102:94] : live[120:112];
function [2:0] observations;
 input [303:0] data;input [1:0] kind;integer t;
 begin observations=0;for(t=0;t<4;t=t+1)
  if(data[t*76+75] && data[t*76+73+:2]==kind)observations=observations+1'b1;
 end
endfunction
function [7:0] hexchar;
 input [3:0] value;begin hexchar=value<10 ? "0"+value : "A"+value-10;end
endfunction
// Packed strings are always eight characters, indexed from the right.
function [7:0] state_char;
 input [2:0] pos;input [2:0] value;reg [63:0] word;
 begin
  case(value)
   0:word="READY   ";1:word="LOCKING ";
   2:word=gap_id!=0 ? "RUN GAP " : "RUN     ";3:word="LOST    ";
   4:word="DONE    ";5:word="HOLD    ";6:word="CHECK   ";default:word="?       ";
  endcase
  state_char=word[pos*8+:8];
 end
endfunction
// Each Chinese glyph occupies three adjacent eight-pixel text cells.
function [7:0] class_char;
 input [1:0] kind;input review;input [3:0] glyph_cell;
 reg [2:0] glyph;reg [1:0] offset;
 begin
  glyph=0;offset=0;
  if(glyph_cell<3)begin offset=glyph_cell;glyph=kind==3 ? 3 : kind==2 && !review ? 1 : 5;end
  else if(glyph_cell<6)begin offset=glyph_cell-3;glyph=kind==3 ? 4 : kind==2 && !review ? 2 : 6;end
  else if(glyph_cell<9 && (kind!=2 && kind!=3 || review))begin offset=glyph_cell-6;glyph=7;end
  class_char=glyph==0 ? 8'd32 : (8'h80 | {2'd0,offset,4'd0} | {5'd0,glyph});
 end
endfunction
// Diagnostic codes describe actual rejection, never alter a decision.
function [3:0] trace_reason;
 input [63:0] c;
 begin
  if(c[0])trace_reason=15;
  else if(!c[1])trace_reason=13;
  else if(!c[63])trace_reason=0;
  else if(c[2] || c[31:24]<6 || c[41:37]<3 || c[36:32]<3)trace_reason=1;
  else if(c[9])trace_reason=5;
  else if(c[8])trace_reason=6;
  else if(!c[13])trace_reason=2;
  else if(!c[10] && c[23:21]>5)trace_reason=4;
  else if(c[3])trace_reason=10;
  else if(c[5] && !c[4])trace_reason=9;
  else if(!c[12] && !c[11] && !c[7])trace_reason=3;
  else if(c[7] && !c[6])trace_reason=8;
  else trace_reason=7;
 end
endfunction
function [31:0] hexvalue;
 input [4:0] slot;reg [63:0] c;
 begin
  c=slot>=23 ? cal[127:64] : cal[63:0];hexvalue=0;
  case(slot)
   0:hexvalue=record[31:0];1:hexvalue=fr;2:hexvalue={16'd0,live[255:240]};
   3:hexvalue=ofl;4:hexvalue=ufl;5:hexvalue=lost;6:hexvalue=le;7:hexvalue=fe;
   8:hexvalue=ie;9:hexvalue=gp;10:hexvalue=diag[31:0];11:hexvalue=pub;12:hexvalue={28'd0,diag[35:32]};
   13:hexvalue=wait_s;14:hexvalue=live[216:213];
   16,23:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[63:61],1'b0,c[60:57]} : {24'd0,c[59:52]}) : 0;
   17,24:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[39:32]} : {24'd0,c[51:44]}) : 0;
   18,25:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[31:24]} : {24'd0,c[43:36]}) : 0;
   19,26:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[23:16]} : {25'd0,c[13:7]}) : 0;
   20,27:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[15:8]} : {25'd0,c[6:0]}) : 0;
   21,28:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {24'd0,c[7:0]} : {19'd0,c[26:14]}) : 0;
   22,29:hexvalue=cal_s && c[63] ? (REVIEW_PROBE ? {16'd0,c[56:41]} : {31'd0,c[62]}) : 0;
  endcase
  if(EMPTY_TRACE && slot>=16 && slot<=29)begin
   case(slot>=23 ? slot-7 : slot)
    16:hexvalue={21'd0,c[62:52]};17:hexvalue={22'd0,c[51:42]};
    18:hexvalue={16'd0,3'd0,c[41:37],3'd0,c[36:32]};
    19:hexvalue={24'd0,c[31:24]};20:hexvalue={20'd0,1'b0,c[23:21],2'd0,c[20:15]};
    21:hexvalue={17'd0,c[14:0]};22:hexvalue={28'd0,trace_reason(c)};
   endcase
  end

  if(PRESENT_TRACE && slot>=16 && slot<=27)begin
   hexvalue=0;
   if(cal_s && cal[123] && cal[127:124]==1)case(slot)
    16:hexvalue={24'd0,cal[117:110]};17:hexvalue={21'd0,cal[109:99]};
    18:hexvalue={22'd0,cal[98:89]};19:hexvalue={22'd0,cal[88:79]};
    20:hexvalue={22'd0,cal[78:69]};21:hexvalue={22'd0,cal[68:59]};
    22:hexvalue={23'd0,cal[58:50]};23:hexvalue={23'd0,cal[49:41]};
    24:hexvalue={23'd0,cal[40:32]};25:hexvalue={23'd0,cal[31:23]};
    26:hexvalue={29'd0,cal[22:20]};27:hexvalue={28'd0,cal[17:14]};
   endcase
  end
 end
endfunction
function [7:0] special_char;
 input [4:0] slot;input [2:0] pos;reg [127:0] message;
 begin
  special_char=32;message="IDS UNCONFIRMED ";
  if(ESSENTIAL_UI)begin
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
   1:special_char=state_char(pos,live[50:48]);
   2:special_char=hexchar(live[54:51]);
   3:special_char=!live[55] ? "?" : live[56] ? "R" : "L";
   4:special_char="1"+live[57];5:special_char=(page_s ? eligible_s : gray_s) ? "1" : "0";
   6:special_char=cfg_s ? "1" : "0";7:special_char="0"+mode_s;
   8:special_char=pending_s ? "*" : tune_s ? "T" : "L";
   9:special_char="0"+np;
   10:special_char=gap_id!=0 ? ("GAP FROM" >> (pos*8)) : 8'd32;
   11:special_char=gap_id!=0 ? "R" : "N";
   12:special_char=gap_id!=0 ? message[127-(7-pos)*8-:8] : 8'd32;
   13:special_char=live[210:202]!=0 ? class_char(live[212:211],live[212:211]==2 && live[216:213]!=0,7-pos) : 8'd32;
   14:special_char="0"+ne;
   15:special_char="0"+nu;
   16:special_char=cal_s ? "1" : "0";
   17:special_char=gap_id!=0 ? message[127-(14-pos)*8-:8] : 8'd32;
   18:special_char=live[210:202]!=0 ? class_char(live[212:211],live[212:211]==2 && live[216:213]!=0,8) : 8'd32;
   19:special_char=gap_id!=0 ? "R" : " ";
   20:if(DUAL_REGION_COUNT && page_s)special_char=state_char(pos,live2[50:48]);else if(PRESENT_TRACE)special_char=cal_s && cal[123] ? "1"+cal[122] : "0";
   21:if(DUAL_REGION_COUNT && page_s)special_char=hexchar(live2[54:51]);else if(PRESENT_TRACE)special_char=cal_s && cal[123] ? "0"+cal[121:120] : "0";
   22:if(DUAL_REGION_COUNT && page_s)special_char=!live2[55] ? "?" : live2[56] ? "R" : "L";else if(PRESENT_TRACE)special_char=!(cal_s && cal[123]) ? "-" : cal[119] ? "W" : "S";
   23:if(PRESENT_TRACE)special_char=!(cal_s && cal[123]) ? "-" : "0"+cal[118];
   24:if(PRESENT_TRACE)special_char=cal_s && cal[123] ? "1" : "0";
  endcase
 end
endfunction
wire [31:0] hexadecimal=ESSENTIAL_UI ? 32'd0 : hexvalue(token_d[7:3]);
always @*begin
 case(token_d[9:8])
  0:decoded=token_d[7:0];
  1:decoded=!ESSENTIAL_UI && token_d[7:3]==20 && gap_id==0 && !(DUAL_REGION_COUNT && page_s) ? 8'd32 : "0"+((plane_q>>(token_d[2:0]*4))&4'hf);
  2:decoded=ESSENTIAL_UI ? 8'd32 : hexchar(hexadecimal>>(token_d[2:0]*4));
  default:decoded=special_char(token_d[7:3],token_d[2:0]);
 endcase
 next_number=0;
 case(fmt)
  0:next_number={7'd0,live[66:58]};1:next_number={7'd0,live[75:67]};
  2:next_number={7'd0,live[84:76]};3:next_number={7'd0,live[93:85]};
  4:next_number=live[239:224];5:next_number={7'd0,live[210:202]};
  // Constant slices avoid an arithmetic address and variable-wide record read.
  6:next_number={7'd0,live[130+:9]};
  7:next_number={7'd0,live[139+:9]};
  8:next_number={7'd0,live[148+:9]};
  9:next_number={7'd0,live[157+:9]};
  10:next_number={7'd0,live[166+:9]};
  11:next_number={7'd0,live[175+:9]};
  12:next_number={7'd0,live[184+:9]};
  13:next_number={7'd0,live[193+:9]};
  14:next_number=ex;15:next_number=ga;16:next_number=fp;
  17:next_number={10'd0,live[222:217]}+1'b1;
  18:next_number={7'd0,record[57] ? record[112+:9] : record[94+:9]};
  19:next_number={7'd0,record[57] ? record[121+:9] : record[103+:9]};
  20:next_number={7'd0,gap_id};21:next_number=wr;22:next_number=wb;
  23:next_number=gm;24:next_number=gn;25:next_number=gx;
  26:next_number={9'd0,primary[55:49]};27:next_number={9'd0,primary[48:42]};
  28:next_number={3'd0,primary[68:56]};29:next_number=iw;30:next_number=ih;31:next_number=ec;
 endcase
 if(DUAL_REGION_COUNT && page_s)case(fmt)
  5:next_number={7'd0,live2[130+:9]};
  20:next_number={7'd0,live2[139+:9]};
  21:next_number={7'd0,live2[148+:9]};
  22:next_number={7'd0,live2[157+:9]};
  23:next_number={7'd0,live2[66:58]};24:next_number={7'd0,live2[75:67]};
  25:next_number={7'd0,live2[84:76]};26:next_number={7'd0,live2[93:85]};
  27:next_number={7'd0,live2[166+:9]};28:next_number={7'd0,live2[175+:9]};
  29:next_number={7'd0,live2[184+:9]};30:next_number={7'd0,live2[193+:9]};
  31:next_number={10'd0,live2[222:217]}+1'b1;
  32:next_number={7'd0,record2[112+:9]};33:next_number={7'd0,record2[121+:9]};
 endcase
 if(AUTO_RELAY)case(fmt)
  34:next_number={10'd0,relay_s[63:58]};35:next_number={7'd0,relay_s[20:12]};
  36:next_number={10'd0,relay_s[127:122]};37:next_number={7'd0,relay_s[84:76]};
 endcase
 if(ESSENTIAL_UI)begin
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
 adjusted=bcd;
 if(bcd[3:0]>=5)adjusted[3:0]=bcd[3:0]+3;
 if(bcd[7:4]>=5)adjusted[7:4]=bcd[7:4]+3;
 if(bcd[11:8]>=5)adjusted[11:8]=bcd[11:8]+3;
 if(bcd[15:12]>=5)adjusted[15:12]=bcd[15:12]+3;
 if(bcd[19:16]>=5)adjusted[19:16]=bcd[19:16]+3;
end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  relay_q0<=0;relay_q1<=0;relay_id0<=0;relay_id1<=0;
  relay_s<=0;relay_mode_s<=0;relay_motor_s<=0;
  de_d<=0;x<=0;y<=0;page_s<=0;eligible_s<=0;show<=0;cal_s<=0;gray_s<=0;cfg_s<=0;tune_s<=0;pending_s<=0;
  mode_s<=0;wait_s<=0;live<=0;record<=0;live2<=0;record2<=0;show2<=0;obs<=0;cal<=0;primary<=0;np<=0;ne<=0;nu<=0;
  ex<=0;ga<=0;fp<=0;iw<=0;ih<=0;wr<=0;wb<=0;gm<=0;gn<=0;gx<=0;ec<=0;
  le<=0;fe<=0;ie<=0;gp<=0;ofl<=0;ufl<=0;lost<=0;fr<=0;pub<=0;diag<=0;
  token_d<=0;write_cursor_d<=0;write_valid_d<=0;fmt<=0;step<=0;number<=0;bcd<=0;formatting<=0;feeding<=0;write_valid<=0;ready<=0;cursor<=0;write_cursor<=0;
 end else begin
  de_d<=de;
  if(vs)begin x<=0;y<=0;end
  else if(de)x<=x+1'b1;else if(de_d)begin x<=0;y<=y+1'b1;end
  if(start)begin
   relay_s<=relay_status;relay_mode_s<=relay_mode;relay_motor_s<=relay_motor;
   page_s<=page;live<=live_record[255:0];record<=frame_record[255:0];live2<=input_live2;record2<=input_record2;obs<=objects;cal<=calibration_record;
   eligible_s<=eligible;cal_s<=calibration_valid;gray_s<=roi_valid;cfg_s<=cfg_done;tune_s<=wb_tune;pending_s<=wb_pending;
   show<=eligible && frame_record[47:32]==live_record[47:32] &&
    (frame_record[50:48]==1 || frame_record[50:48]==2 || frame_record[50:48]==5) &&
    (live_record[50:48]==1 || live_record[50:48]==2 || live_record[50:48]==5);
   show2<=eligible && input_record2[223] && input_record2[47:32]==input_live2[47:32] &&
    (input_record2[50:48]==1 || input_record2[50:48]==2 || input_record2[50:48]==5) &&
    (input_live2[50:48]==1 || input_live2[50:48]==2 || input_live2[50:48]==5);
   fp<=fps;iw<=width;ih<=height;
   ex<=ESSENTIAL_UI ? 0 : exposure;ga<=ESSENTIAL_UI ? 0 : gain;
   wr<=ESSENTIAL_UI ? 0 : {8'd0,wb_r};wb<=ESSENTIAL_UI ? 0 : {8'd0,wb_b};
   gm<=roi_valid ? {8'd0,roi_mean} : 0;gn<=roi_valid ? {8'd0,roi_min} : 0;gx<=roi_valid ? {8'd0,roi_max} : 0;ec<={3'd0,edge_count};
   primary<=frame_record[57] ? (objects[227] ? objects[227:152] : objects[303:228]) : (objects[75] ? objects[75:0] : objects[151:76]);
   np<=observations(objects,2);ne<=observations(objects,3);nu<=observations(objects,1);
   le<=lane_errors;fe<=format_errors;ie<=i2c_errors;gp<=gaps;ofl<=overflow_frames;ufl<=underflow_frames;lost<=lost_frames;
   fr<=frames;pub<=publish_diagnostic;diag<=diagnostics;mode_s<=view_mode;wait_s<=local_wait_reason;
   token_d<=0;write_cursor_d<=0;write_valid_d<=0;fmt<=0;step<=0;formatting<=1;feeding<=0;write_valid<=0;ready<=0;cursor<=0;
  end else begin
   if(formatting)begin
    if(step==0)begin number<=next_number;bcd<=0;step<=1;end
    else begin
     number<={number[14:0],1'b0};bcd<={adjusted[18:0],number[15]};
     if(step==16)begin
      if(ESSENTIAL_UI)begin
       if(fmt==31)label_bcd0<={adjusted[18:0],number[15]};
       if(fmt==32)label_bcd1<={adjusted[18:0],number[15]};
       if(fmt==33)label_bcd2<={adjusted[18:0],number[15]};
       if(fmt==34)label_bcd3<={adjusted[18:0],number[15]};
       step<=0;
      end else begin
      if(fmt==18)label_bcd0<={adjusted[18:0],number[15]};
      if(fmt==19)label_bcd1<={adjusted[18:0],number[15]};step<=0;
      if(fmt==32)label_bcd2<={adjusted[18:0],number[15]};
      if(fmt==33)label_bcd3<={adjusted[18:0],number[15]};
      if(AUTO_RELAY)case(fmt)
       34:relay_q0<={adjusted[6:0],number[15]};35:relay_id0<={adjusted[10:0],number[15]};
       36:relay_q1<={adjusted[6:0],number[15]};37:relay_id1<={adjusted[10:0],number[15]};
      endcase
      end
      if(fmt==(ESSENTIAL_UI ? 34 : AUTO_RELAY ? 37 : DUAL_REGION_COUNT && page_s ? 33 : 31))begin formatting<=0;feeding<=1;cursor<=0;end else fmt<=fmt+1'b1;
     end else step<=step+1'b1;
    end
   end
   write_valid<=feeding;write_valid_d<=write_valid;write_cursor_d<=write_cursor;token_d<=token;
   if(feeding)begin write_cursor<=cursor;if(cursor==895)feeding<=0;else cursor<=cursor+1'b1;end
   if(write_valid_d && write_cursor_d==895)ready<=1;
  end
 end
end

// Compact per-lane stop status uses the existing font/read pipeline.
function [7:0] relay_hex;input [3:0] v;begin relay_hex=v<10 ? "0"+v : "A"+v-10;end endfunction
function [7:0] relay_char;
 input [4:0] char_pos;input lane;input [63:0] st;input [2:0] mode;input motor;input [7:0] q_decimal;input [11:0] id_decimal;
 reg [8:0] id;reg [5:0] q;
 begin id=st[20:12];q=st[63:58];relay_char=32;
 case(char_pos)
  0:relay_char="L";1:relay_char=lane ? "2" : "1";
  3:relay_char="S";4:relay_char="0"+st[31:29];
  6:relay_char="F";7:relay_char=relay_hex(st[28:25]);
  9:relay_char="Q";10:relay_char="0"+q_decimal[7:4];11:relay_char="0"+q_decimal[3:0];
  13:relay_char="N";14:relay_char="0"+id_decimal[11:8];15:relay_char="0"+id_decimal[7:4];16:relay_char="0"+id_decimal[3:0];
  18:relay_char="X";19:relay_char=relay_hex({1'b0,st[11:9]});20:relay_char=relay_hex(st[8:5]);21:relay_char=relay_hex(st[4:1]);
  23:relay_char=mode==2 ? "P" : "M";24:relay_char=motor ? "1" : "0";
 endcase
 end
endfunction
function [7:0] alarm_char;input [5:0] char_pos;reg [8*26-1:0] msg;
 begin msg="ALARM FIVE EMPTY K3 CLEAR ";alarm_char=char_pos<26 ? msg[(25-char_pos)*8+:8] : 8'd32;end
endfunction
reg [2:0] line;reg [9:0] plane_address;reg [7:0] code;
reg [4:0] row,col;reg panel,guide,logo,repair_border;reg [23:0] ink;
reg [75:0] ob;reg [8:0] id;reg [19:0] id_bcd;
reg [10:0] lx,rx;reg [9:0] ly;reg [3:0] glyph_cell;
wire trace_cross0=!PRESENT_TRACE && EMPTY_TRACE && cal_s && cal[63] &&
 ((x==cal[62:52] && y+4>=cal[51:42] && y<=cal[51:42]+4) ||
  (y==cal[51:42] && x+4>=cal[62:52] && x<=cal[62:52]+4));
wire trace_cross1=!PRESENT_TRACE && EMPTY_TRACE && cal_s && cal[127] &&
 ((x==cal[126:116] && y+4>=cal[115:106] && y<=cal[115:106]+4) ||
  (y==cal[115:106] && x+4>=cal[126:116] && x<=cal[126:116]+4));
reg prefix;integer t;reg label_hit;reg [1:0] label_slot;
wire [10:0] text_dx=x-11'd136;
always @*begin
 line=0;plane_address=0;code=32;row=0;col=0;panel=0;guide=0;logo=0;ink=24'h70ffdd;
 ob=0;id=0;id_bcd=0;lx=0;rx=0;ly=0;glyph_cell=0;prefix=0;repair_border=0;label_hit=0;label_slot=0;
 if(y<80 || y>=HEIGHT-96)begin
  panel=1;logo=x>=16 && x<112 && y>=8 && y<72;
  if(x>=136 && x<1160 && ready)begin
   if(y>=8 && y<32)begin line=0;row=y-8;end
   else if(y>=32 && y<56)begin line=1;row=y-32;end
   else if(y>=56 && y<72)begin line=2;row=y-56;end
   else if(y>=HEIGHT-88 && y<HEIGHT-64)begin line=3;row=y-(HEIGHT-88);end
   else if(y>=HEIGHT-64 && y<HEIGHT-40)begin line=4;row=y-(HEIGHT-64);end
   else if(y>=HEIGHT-40 && y<HEIGHT-16)begin line=5;row=y-(HEIGHT-40);end
   else if(y>=HEIGHT-16)begin line=6;row=y-(HEIGHT-16);end
   else row=31;
   plane_address={line,text_dx[9:3]};code=plane_q;col={2'd0,text_dx[2:0]};
   if(code[7])col={code[5:4],3'd0}+text_dx[2:0];
   if(row==31)code=32;
   if(page_s && gap_id!=0 && (line==1 || line==2 || line==3))ink=24'hffe080;
   if(ESSENTIAL_UI && line==6 && (relay_s[28:25]!=0 || relay_s[92:89]!=0))ink=24'hff7060;
  end
 end else begin
  guide=(((x==WIDTH*5/16 || x==WIDTH*11/16-1) && ((y>=HEIGHT/3 && y<HEIGHT*5/9)||(y>=HEIGHT*3/5 && y<HEIGHT*5/6))) ||
   ((y==HEIGHT/3 || y==HEIGHT*5/9-1 || y==HEIGHT*3/5 || y==HEIGHT*5/6-1) && x>=WIDTH*5/16 && x<WIDTH*11/16)) && (x[3] || y[3]);
  if(x==WIDTH/2 && y[2] && ((y>=HEIGHT/3 && y<HEIGHT*5/9 && (!page_s || DUAL_REGION_COUNT || !record[57])) ||
   (y>=HEIGHT*3/5 && y<HEIGHT*5/6 && (!page_s || DUAL_REGION_COUNT || record[57]))))guide=1;
  if(!ESSENTIAL_UI && (trace_cross0 || trace_cross1))guide=1;
  // Bounds retain the original four parallel hit tests and last-hit priority.
  // Only the winning label needs glyph/decimal/colour formatting on this pixel.
  for(t=0;t<4;t=t+1)begin
   ob=obs[t*76+:76];id=0;
   if(page_s && (DUAL_REGION_COUNT || t/2==record[57]))
    id=DUAL_REGION_COUNT && t>=2 ? record2[94+t*9+:9] : record[94+t*9+:9];
   if(ready && (ESSENTIAL_UI ? label_eligible[t] : ob[75] && (!page_s || eligible_s && (DUAL_REGION_COUNT || t/2==record[57]))))begin
    if(((x==ob[41:31] || x==ob[30:20]) && y>=ob[19:10] && y<=ob[9:0]) ||
      ((y==ob[19:10] || y==ob[9:0]) && x>=ob[41:31] && x<=ob[30:20]))guide=1;
    if(x>=label_left[t] && x<label_right[t] && y>=label_top[t] && y<label_bottom[t])begin label_hit=1;label_slot=t;end
   end
  end
  if(label_hit)begin
   case(label_slot)
    0:begin ob=obs[75:0];id=record[94+:9];id_bcd=label_bcd0;end
    1:begin ob=obs[151:76];id=record[103+:9];id_bcd=label_bcd1;end
    2:begin ob=obs[227:152];id=DUAL_REGION_COUNT ? record2[112+:9] : record[112+:9];id_bcd=label_bcd2;end
    3:begin ob=obs[303:228];id=DUAL_REGION_COUNT ? record2[121+:9] : record[121+:9];id_bcd=label_bcd3;end
   endcase
   if(!DUAL_REGION_COUNT)id_bcd=label_slot[0] ? label_bcd1 : label_bcd0;
   prefix=label_prefix[label_slot];
   lx=label_left[label_slot];ly=label_top[label_slot];
   panel=1;row=y-ly;glyph_cell=(x-lx)>>3;col=(x-lx)&7;
   if(prefix && glyph_cell<4)code=glyph_cell==0 ? (ESSENTIAL_UI ? (label_recovered[label_slot] ? "R" : "N") : (frame_gap!=0 && id>=frame_gap ? "R" : "N")) : "0"+((id_bcd>>((3-glyph_cell)*4))&4'hf);
   else if(prefix && glyph_cell==4)code=32;
   else code=class_char(ob[74:73],ob[74:73]==2 && ob[72:69]!=0,prefix ? glyph_cell-5 : glyph_cell);
   if(code[7])col={code[5:4],3'd0}+((x-lx)&7);
   ink=ob[74:73]==3 ? 24'hffe080 : ob[74:73]==2 && ob[72:69]==0 ? 24'h70ffdd : 24'hffb070;
  end
 end
 if(AUTO_RELAY)begin
  repair_border=(((x==RELAY_TARGET_X-RELAY_TOL_PX || x==RELAY_TARGET_X+RELAY_TOL_PX) && y[3]) ||
    ((y==HEIGHT/3 || y==HEIGHT*5/9-1 || y==HEIGHT*3/5 || y==HEIGHT*5/6-1) && x[3])) &&
   x>=RELAY_TARGET_X-RELAY_TOL_PX && x<=RELAY_TARGET_X+RELAY_TOL_PX &&
   ((y>=HEIGHT/3 && y<HEIGHT*5/9) || (y>=HEIGHT*3/5 && y<HEIGHT*5/6));
  if(!ESSENTIAL_UI && ready && x>=1080 && x<1280 && ((y>=32 && y<48) || (y>=56 && y<72)))begin
   panel=1;logo=0;row=y>=56 ? y-56 : y-32;col=(x-1080)&7;
   code=relay_char((x-1080)>>3,y>=56,y>=56 ? relay_s[127:64] : relay_s[63:0],relay_mode_s,relay_motor_s,y>=56 ? relay_q1 : relay_q0,y>=56 ? relay_id1 : relay_id0);
   ink=(y>=56 ? relay_s[92:89] : relay_s[28:25])!=0 ? 24'hff7060 : 24'h70ffdd;
  end
  if(!ESSENTIAL_UI && ready && x>=136 && x<344 && y>=80 && y<96 &&
   (relay_s[28:25]==15 || relay_s[92:89]==15))begin
   panel=1;logo=0;row=y-80;col=(x-136)&7;code=alarm_char((x-136)>>3);ink=24'hff4040;
  end
  if(!ESSENTIAL_UI && ready && x>=136 && x<208 && y>=8 && y<24)begin
   panel=1;logo=0;row=y-8;col=(x-136)&7;
   case((x-136)>>3)0:code="D";1:code="3";2:code="+";3:code="R";4:code="2";5:code="7";6:code="B";default:code=32;endcase
  end
 end
end
reg [10:0] ascii_address;reg [7:0] cjk_address;reg [12:0] logo_address;
wire [7:0] ascii_bits;wire [23:0] cjk_bits;wire [1:0] logo_pixel;
wire [5:0] logo_y=y-10'd8;wire [6:0] logo_x=x-11'd16;
wire font_pixel;

osd_logo_rom anlogic_logo(clk,logo_address,logo_pixel);
reg [1:0] vp,hp,dp,pp,lp,cp;reg [4:0] c0,c1;
compact_shared_font_rom shared_font(clk,cp[0],ascii_address,cjk_address,c0,font_pixel);
reg [23:0] rgb0,rgb1,ink0,ink1;
wire text_ink=font_pixel;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  ascii_address<=0;cjk_address<=0;logo_address<=0;vp<=0;hp<=0;dp<=0;pp<=0;lp<=0;cp<=0;
  c0<=0;c1<=0;rgb0<=0;rgb1<=0;ink0<=0;ink1<=0;out_vs<=0;out_hs<=0;out_de<=0;out_rgb<=0;
 end else begin
  ascii_address<={code[6:0],row[3:0]};cjk_address<={code[2:0],row};logo_address<={logo_y,logo_x};
  vp<={vp[0],vs};hp<={hp[0],hs};dp<={dp[0],de};pp<={pp[0],ENABLE && panel && de};
  lp<={lp[0],logo};cp<={cp[0],code[7]};c0<=!code[7] && row>=16 ? 5'd31 : col;c1<=c0;
  rgb0<=ENABLE && repair_border ? 24'hffd060 : ENABLE && guide ? 24'h00d8d0 : rgb;rgb1<=rgb0;ink0<=ink;ink1<=ink0;
  out_vs<=vp[1];out_hs<=hp[1];out_de<=dp[1];
  out_rgb<=pp[1] ? (lp[1] ? (logo_pixel==1 ? 24'h204686 : logo_pixel==2 ? 24'hcc253b : 24'hffffff) :
   text_ink ? ink1 : 24'h142336) : rgb1;
 end
end
endmodule

module compact_shared_font_rom(
 input wire clk,cjk,input wire [10:0] ascii_address,input wire [7:0] cjk_address,
 input wire [4:0] column,output wire pixel);
 wire [6:0] ac=ascii_address[10:4];wire [3:0] ar=ascii_address[3:0];
 wire [2:0] cc=cjk_address[7:5];wire [4:0] cr=cjk_address[4:0];
 wire av=ac>=32 && ac<=126 && column<8;
 wire cv=cc>=1 && cr<24 && column<24;
 wire [6:0] ascii_index=ac-7'd32;
 wire [2:0] chinese_index=cc-3'd1;
 wire [10:0] ai={ascii_index,ar};
 wire [10:0] char_offset={2'd0,chinese_index,6'd0}+{5'd0,chinese_index,3'd0};
 wire [10:0] row_offset={5'd0,cr,1'b0}+{6'd0,cr};
 wire [10:0] ci=11'd1520+char_offset+row_offset+{9'd0,column[4:3]};
 wire [13:0] address={cjk ? ci : ai,3'b000};
 wire [15:0] raw;reg valid_q;reg [2:0] column_q;
 always @(posedge clk)begin valid_q<=cjk ? cv : av;column_q<=column[2:0];end
 assign pixel=valid_q && raw[7-column_q];
 PH1P_PHY_ERAM_V2 #(
  .DATA_WIDTH_A("10"),.DATA_WIDTH_B("10"),.MODE("DP20K"),
  .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),.GSR("DISABLE"),
  .CSA0("1"),.CSA1("1"),.CSA2("1"),.CSB0("0"),.CSB1("0"),.CSB2("0"),
  .INIT_00(256'h0000001818001018181818181800000000000000000000000000000000000000),
  .INIT_01(256'h0000000068282cfe24247f2424000000000000000000000000002c2c2c000000),
  .INIT_02(256'h000000ce4a2a3e101868d4d662000000000030107c16161e3c7858683c080000),
  .INIT_03(256'h000000000000000000001818180000000000007a4ecede7230686c6c38000000),
  .INIT_04(256'h000020301808080c0c0c08081830200000000408181030202020301018080400),
  .INIT_05(256'h0000000000181818fe181818000000000000000000000010543c3c5410000000),
  .INIT_06(256'h0000000000000000003c00000000000000000000000030181818000000000000),
  .INIT_07(256'h00000040602030101018080c0406000000000000000000181800000000000000),
  .INIT_08(256'h000000007e1818181818587818000000000000003c6446625a4e46663c000000),
  .INIT_09(256'h00000000780406063c0c040478000000000000007e6030180c04044438000000),
  .INIT_0A(256'h00000000780406067c6060607c000000000000000c0cfe4c6c2c3c1c0c000000),
  .INIT_0B(256'h0000000020301018080c04067e000000000000003c664242667c60301c000000),
  .INIT_0C(256'h00000000780c063e664646643c000000000000003c66466e3c6446663c000000),
  .INIT_0D(256'h0000000030181818000000181800000000000000001818000000181800000000),
  .INIT_0E(256'h00000000000000007e007e000000000000000000040c106060100c0400000000),
  .INIT_0F(256'h00000010100010180404040c38000000000000002030180c0c18302000000000),
  .INIT_10(256'h00000000c3c27e6664242c381800000000003844c0beaaabafbddf4342261c00),
  .INIT_11(256'h000000003c624040404040623c000000000000007c4646467c4446467c000000),
  .INIT_12(256'h000000007e6060607c6060607e00000000000000784c4642424246467c000000),
  .INIT_13(256'h000000003e6242c2cec040623c00000000000000606060607c6060607e000000),
  .INIT_14(256'h000000007e181818181818187e00000000000000424242427e42424242000000),
  .INIT_15(256'h00000000464c48707050484c4600000000000000384c0404040404047c000000),
  .INIT_16(256'h00000000c2c2c2d2daea626646000000000000007e6060606060606060000000),
  .INIT_17(256'h000000003c6642c2c2c242663c0000000000000046464e4a5252726262000000),
  .INIT_18(256'h0000000f183c6642c2c2c242663c0000000000004040407c464646467c000000),
  .INIT_19(256'h000000007c0606063c6040603c000000000000004646444c784446447c000000),
  .INIT_1A(256'h000000003c6642424242424242000000000000001818181818181818fe000000),
  .INIT_1B(256'h0000000066666a5a5adac2c2c20000000000000018383c24646646c2c3000000),
  .INIT_1C(256'h0000000018181818382c6446c300000000000000c2662c3818382c6446000000),
  .INIT_1D(256'h00003c30303030303030303030303c00000000007e60201010080c047e000000),
  .INIT_1E(256'h000038080808080808080808080838000000000604040c081810302020600000),
  .INIT_1F(256'h00000000000000ff000000000000000000000000000000000046243818000000),
  .INIT_20(256'h00000000007e46663e06463c0000000000000000000000000000001020000000),
  .INIT_21(256'h00000000003e60604060201e000000000000007c64464242667c404040000000),
  .INIT_22(256'h00000000003e60407e46663c000000000000003e6e464646663e060606000000),
  .INIT_23(256'h0000007c46427e40786446643e0000000000001010101010fe1010180e000000),
  .INIT_24(256'h0000007e1818181818780018180000000000004646464646667c404040000000),
  .INIT_25(256'h000000666c7870786c66606060000000000078080c0c0c0c0c0c0c7c000c0c00),
  .INIT_26(256'h0000000000dadadadadadaf6000000000000007e181818181818181878000000),
  .INIT_27(256'h00000000003c66424242663c0000000000000000004646464646665c00000000),
  .INIT_28(256'h0000000606063e6e464646663e0000000000004040407c64464242665c000000),
  .INIT_29(256'h00000000007c06063c60603c0000000000000000006060606062767c00000000),
  .INIT_2A(256'h00000000003e6e464646464600000000000000001e3030303030fe3030000000),
  .INIT_2B(256'h0000000000666e5a5adac2c200000000000000000018382c2464464200000000),
  .INIT_2C(256'h000000e0301018382824644642000000000000000046643c1838246600000000),
  .INIT_2D(256'h00000c18101010106010101010180c0000000000007e20301008047c00000000),
  .INIT_2E(256'h00007018181818080e0818181818700000181818181818181818181818181800),
  .INIT_2F(256'h7ffeff7f00c00000c0000060000000000000000000000000ce5a720000000000),
  .INIT_30(256'h300006300046f0ffe7f0ff7730003e30001ef0ff0ff0ff07000003008003fcff),
  .INIT_31(256'h3106800106000000000000c00706e00706300006300006f0ff07f0ff07300006),
  .INIT_32(256'h598001d88081f880817980c13880c138fcff18fc7f1880610c80710c80310e80),
  .INIT_33(256'h000000800118800118800118800118800118800118800118800118feff19feff),
  .INIT_34(256'h000ec0810780c3030c82600c0060fcff7ffcff7f001800003000003000000000),
  .INIT_35(256'h7f003800003800003800003800003800e0ff0ff0ff1f0c00601c007038003cf0),
  .INIT_36(256'h0c0060fcff7ffcff7f001800001800003000003000000000000000fcff7ffcff),
  .INIT_37(256'h000cc0000ec001068001038003030083030083010087010086010c06600c0060),
  .INIT_38(256'h38fcff1c00030c0003060003060000000000000c00601e007038003870001ce0),
  .INIT_39(256'h606058fcfff9feff79600038000018fcff1dfeff0d0003460003e6000370f8ff),
  .INIT_3A(256'h0006000006000000000000c00718e00f18600018601018603818603018606018),
  .INIT_3B(256'h0ff0ff0f30000830000cf0ff0f300048f0ff6ff0ff3f000038fcff1ffcff0f00),
  .INIT_3C(256'h0000001c003cfe813fe0ff01003e4080e770e08119f0000ff0ff07008003f0ff),
  .INIT_3D(256'h7f3e60301c70181c301c1c000c7ffefffffeff0c80010c00030c00030c000000),
  .INIT_3E(256'h0c1c3c0c380e0cf0c30ce0e10ce0780c701ccc300ecc18076c8c033dccff3fe0),
  .INIT_3F(256'h00000000000000000000000000000000000000000000000000000004600c0e70)
 ) font_bits(
  .dia(16'd0),.dia_extra(4'd0),.csa(3'b111),.addra(address),.ocea(1'b1),.clka(clk),.wea(1'b0),.orsta(1'b0),
  .dib(16'd0),.dib_extra(4'd0),.csb(3'b000),.addrb(14'd0),.oceb(1'b0),.clkb(clk),.web(1'b0),.orstb(1'b0),
  .doa(raw),.doa_extra(),.dob(),.dob_extra(),.ecc_sbiterr(),.ecc_dbiterr(),.ecc_sbiterrinj(1'b0),.ecc_dbiterrinj(1'b0),
  .fifoctrl_waddr(14'd0),.fifoctrl_raddr(14'd0),.fifoctrl_we(1'b0),.fifoctrl_re(1'b0),
  .addra_casin(14'd0),.addrb_casin(14'd0),.addra_casout(),.addrb_casout(),.pib_rst_redmeet_n(1'b1),.probe_redmeet_pa(),.probe_redmeet_pb());
endmodule
