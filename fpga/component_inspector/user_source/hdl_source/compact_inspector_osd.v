// Shared R13 UI: one ASCII, seven CJK glyphs, unchanged Anlogic logo,
// one sequential decimal formatter. No classifier or recorder decisions here.
// The text plane is complete before row8. Snapshot is the first active pixel,
// after DDR metadata has settled. RGB/DE/HS/VS have the original three clocks.
module compact_inspector_osd #(parameter DUAL_REGION_COUNT=0,PRESENT_TRACE=0,BUILD_R22=0,EMPTY_TRACE=0,BUILD_R20=0,BUILD_R19=0,BUILD_R18=0,BUILD_R17=0,REVIEW_PROBE=0,WIDTH=1280,HEIGHT=720,DIAG_BITS=27,ENABLE=1,REPORT_NUMBER_GAPS=1)(
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

compact_template_rom #(.DUAL_REGION_COUNT(DUAL_REGION_COUNT),.PRESENT_TRACE(PRESENT_TRACE),.BUILD_R22(BUILD_R22),.EMPTY_TRACE(EMPTY_TRACE),.BUILD_R20(BUILD_R20),.BUILD_R19(BUILD_R19),.BUILD_R18(BUILD_R18),.BUILD_R17(BUILD_R17),.REVIEW_PROBE(REVIEW_PROBE)) template_font(clk,{page_s,cursor},token);
// R15 production suppresses numbering-confidence UI only; classification
// colours and LOST/HOLD/CHECK state protection remain active.
wire [8:0] gap_id=!REPORT_NUMBER_GAPS ? 9'd0 : live[57] ? live[102:94] : live[120:112];
wire [8:0] frame_gap=!REPORT_NUMBER_GAPS ? 9'd0 : record[57] ? record[102:94] : record[120:112];
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
  case(slot)
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
wire [31:0] hexadecimal=hexvalue(token_d[7:3]);
always @*begin
 case(token_d[9:8])
  0:decoded=token_d[7:0];
  1:decoded=token_d[7:3]==20 && gap_id==0 && !(DUAL_REGION_COUNT && page_s) ? 8'd32 : "0"+((plane_q>>(token_d[2:0]*4))&4'hf);
  2:decoded=hexchar(hexadecimal>>(token_d[2:0]*4));
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
 adjusted=bcd;
 if(bcd[3:0]>=5)adjusted[3:0]=bcd[3:0]+3;
 if(bcd[7:4]>=5)adjusted[7:4]=bcd[7:4]+3;
 if(bcd[11:8]>=5)adjusted[11:8]=bcd[11:8]+3;
 if(bcd[15:12]>=5)adjusted[15:12]=bcd[15:12]+3;
 if(bcd[19:16]>=5)adjusted[19:16]=bcd[19:16]+3;
end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
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
   page_s<=page;live<=live_record[255:0];record<=frame_record[255:0];live2<=input_live2;record2<=input_record2;obs<=objects;cal<=calibration_record;
   eligible_s<=eligible;cal_s<=calibration_valid;gray_s<=roi_valid;cfg_s<=cfg_done;tune_s<=wb_tune;pending_s<=wb_pending;
   show<=eligible && frame_record[47:32]==live_record[47:32] &&
    (frame_record[50:48]==1 || frame_record[50:48]==2 || frame_record[50:48]==5) &&
    (live_record[50:48]==1 || live_record[50:48]==2 || live_record[50:48]==5);
   show2<=eligible && input_record2[223] && input_record2[47:32]==input_live2[47:32] &&
    (input_record2[50:48]==1 || input_record2[50:48]==2 || input_record2[50:48]==5) &&
    (input_live2[50:48]==1 || input_live2[50:48]==2 || input_live2[50:48]==5);
   ex<=exposure;ga<=gain;fp<=fps;iw<=width;ih<=height;wr<={8'd0,wb_r};wb<={8'd0,wb_b};
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
      if(fmt==18)label_bcd0<={adjusted[18:0],number[15]};
      if(fmt==19)label_bcd1<={adjusted[18:0],number[15]};step<=0;
      if(fmt==32)label_bcd2<={adjusted[18:0],number[15]};
      if(fmt==33)label_bcd3<={adjusted[18:0],number[15]};
      if(fmt==(DUAL_REGION_COUNT && page_s ? 33 : 31))begin formatting<=0;feeding<=1;cursor<=0;end else fmt<=fmt+1'b1;
     end else step<=step+1'b1;
    end
   end
   write_valid<=feeding;write_valid_d<=write_valid;write_cursor_d<=write_cursor;token_d<=token;
   if(feeding)begin write_cursor<=cursor;if(cursor==895)feeding<=0;else cursor<=cursor+1'b1;end
   if(write_valid_d && write_cursor_d==895)ready<=1;
  end
 end
end

reg [2:0] line;reg [9:0] plane_address;reg [7:0] code;
reg [4:0] row,col;reg panel,guide,logo;reg [23:0] ink;
reg [75:0] ob;reg [8:0] id;reg [19:0] id_bcd;
reg [10:0] lx,rx;reg [9:0] ly;reg [3:0] glyph_cell;
wire trace_cross0=!PRESENT_TRACE && EMPTY_TRACE && cal_s && cal[63] &&
 ((x==cal[62:52] && y+4>=cal[51:42] && y<=cal[51:42]+4) ||
  (y==cal[51:42] && x+4>=cal[62:52] && x<=cal[62:52]+4));
wire trace_cross1=!PRESENT_TRACE && EMPTY_TRACE && cal_s && cal[127] &&
 ((x==cal[126:116] && y+4>=cal[115:106] && y<=cal[115:106]+4) ||
  (y==cal[115:106] && x+4>=cal[126:116] && x<=cal[126:116]+4));
reg prefix;integer t;
wire [10:0] text_dx=x-11'd136;
always @*begin
 line=0;plane_address=0;code=32;row=0;col=0;panel=0;guide=0;logo=0;ink=24'h70ffdd;
 ob=0;id=0;id_bcd=0;lx=0;rx=0;ly=0;glyph_cell=0;prefix=0;
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
  end
 end else begin
  guide=(((x==WIDTH*5/16 || x==WIDTH*11/16-1) && ((y>=HEIGHT/3 && y<HEIGHT*5/9)||(y>=HEIGHT*3/5 && y<HEIGHT*5/6))) ||
   ((y==HEIGHT/3 || y==HEIGHT*5/9-1 || y==HEIGHT*3/5 || y==HEIGHT*5/6-1) && x>=WIDTH*5/16 && x<WIDTH*11/16)) && (x[3] || y[3]);
  if(x==WIDTH/2 && y[2] && ((y>=HEIGHT/3 && y<HEIGHT*5/9 && (!page_s || DUAL_REGION_COUNT || !record[57])) ||
   (y>=HEIGHT*3/5 && y<HEIGHT*5/6 && (!page_s || DUAL_REGION_COUNT || record[57]))))guide=1;
  if(trace_cross0 || trace_cross1)guide=1;
  for(t=0;t<4;t=t+1)begin
   ob=obs[t*76+:76];id=0;id_bcd=0;
   if(page_s && (DUAL_REGION_COUNT || t/2==record[57]))begin
    id=DUAL_REGION_COUNT && t>=2 ? record2[94+t*9+:9] : record[94+t*9+:9];
    id_bcd=DUAL_REGION_COUNT && t>=2 ? (t%2==0 ? label_bcd2 : label_bcd3) : (t%2==0 ? label_bcd0 : label_bcd1);
   end
   if(ready && ob[75] && (!page_s || eligible_s && (DUAL_REGION_COUNT || t/2==record[57])))begin
    if(((x==ob[41:31] || x==ob[30:20]) && y>=ob[19:10] && y<=ob[9:0]) ||
      ((y==ob[19:10] || y==ob[9:0]) && x>=ob[41:31] && x<=ob[30:20]))guide=1;
    prefix=page_s && (DUAL_REGION_COUNT && t>=2 ? show2 : show) && id!=0;
    lx=ob[41:31]>WIDTH-112 ? WIDTH-112 : ob[41:31];
    ly=t%2==0 ? (ob[19:10]>=108 ? ob[19:10]-28 : 80) : (ob[9:0]<HEIGHT-124 ? ob[9:0]+4 : HEIGHT-120);
    rx=lx+(prefix ? 112 : 72);
    if(x>=lx && x<rx && y>=ly && y<ly+24)begin
     panel=1;row=y-ly;glyph_cell=(x-lx)>>3;col=(x-lx)&7;
     if(prefix && glyph_cell<4)code=glyph_cell==0 ? (frame_gap!=0 && id>=frame_gap ? "R" : "N") : "0"+((id_bcd>>((3-glyph_cell)*4))&4'hf);
     else if(prefix && glyph_cell==4)code=32;
     else code=class_char(ob[74:73],ob[74:73]==2 && ob[72:69]!=0,prefix ? glyph_cell-5 : glyph_cell);
     if(code[7])col={code[5:4],3'd0}+((x-lx)&7);
     ink=ob[74:73]==3 ? 24'hffe080 : ob[74:73]==2 && ob[72:69]==0 ? 24'h70ffdd : 24'hffb070;
    end
   end
  end
 end
end
reg [10:0] ascii_address;reg [7:0] cjk_address;reg [12:0] logo_address;
wire [7:0] ascii_bits;wire [23:0] cjk_bits;wire [1:0] logo_pixel;
wire [5:0] logo_y=y-10'd8;wire [6:0] logo_x=x-11'd16;
compact_ascii_rom ascii_font(clk,ascii_address,ascii_bits);
compact_cjk_rom cjk_font(clk,cjk_address,cjk_bits);
osd_logo_rom anlogic_logo(clk,logo_address,logo_pixel);
reg [1:0] vp,hp,dp,pp,lp,cp;reg [4:0] c0,c1;
reg [23:0] rgb0,rgb1,ink0,ink1;
wire text_ink=cp[1] ? c1<24 && cjk_bits[23-c1] : c1<8 && ascii_bits[7-c1];
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  ascii_address<=0;cjk_address<=0;logo_address<=0;vp<=0;hp<=0;dp<=0;pp<=0;lp<=0;cp<=0;
  c0<=0;c1<=0;rgb0<=0;rgb1<=0;ink0<=0;ink1<=0;out_vs<=0;out_hs<=0;out_de<=0;out_rgb<=0;
 end else begin
  ascii_address<={code[6:0],row[3:0]};cjk_address<={code[2:0],row};logo_address<={logo_y,logo_x};
  vp<={vp[0],vs};hp<={hp[0],hs};dp<={dp[0],de};pp<={pp[0],ENABLE && panel && de};
  lp<={lp[0],logo};cp<={cp[0],code[7]};c0<=!code[7] && row>=16 ? 5'd31 : col;c1<=c0;
  rgb0<=ENABLE && guide ? 24'h00d8d0 : rgb;rgb1<=rgb0;ink0<=ink;ink1<=ink0;
  out_vs<=vp[1];out_hs<=hp[1];out_de<=dp[1];
  out_rgb<=pp[1] ? (lp[1] ? (logo_pixel==1 ? 24'h204686 : logo_pixel==2 ? 24'hcc253b : 24'hffffff) :
   text_ink ? ink1 : 24'h142336) : rgb1;
 end
end
endmodule
