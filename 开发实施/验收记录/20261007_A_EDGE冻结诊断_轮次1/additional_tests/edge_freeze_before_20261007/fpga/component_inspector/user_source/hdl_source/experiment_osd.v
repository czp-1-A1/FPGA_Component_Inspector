// Sampling UI. Three pixel clocks for RGB, DE, HS, VS and ENABLE bypass.
module experiment_osd #(
 parameter ENABLE=1,ROI_X0=256,ROI_X1=768,ROI_Y0=172,ROI_Y1=428,
 parameter SAMPLE_X0=472,SAMPLE_X1=552,SAMPLE_Y0=260,SAMPLE_Y1=340
)(
 input wire clk,rst_n,vs,hs,de,input wire [23:0] rgb,
 input wire [15:0] exposure,gain,
 input wire [1:0] view_mode,input wire [12:0] edge_count,input wire [23:0] edge_sum,
 input wire roi_valid,input wire [7:0] roi_mean,roi_min,roi_max,input wire [1:0] roi_state,
 input wire [15:0] width,height,fps,lane_errors,format_errors,i2c_errors,gaps,
 input wire [31:0] frames,uptime,input wire cfg_done,
 input wire [15:0] overflow_frames,lost_frames,underflow_frames,
 output reg out_vs,out_hs,out_de,output reg [23:0] out_rgb
);
reg vs_d,de_d;reg [10:0] x;reg [9:0] y;
wire start=vs && !vs_d;
wire [19:0] exp_bcd,gain_bcd,mean_bcd,min_bcd,max_bcd,w_bcd,h_bcd,fps_bcd;
bin16_bcd b0(clk,rst_n,start,exposure,exp_bcd);
bin16_bcd b1(clk,rst_n,start,gain,gain_bcd);
bin16_bcd b2(clk,rst_n,start,{8'd0,roi_mean},mean_bcd);
bin16_bcd b3(clk,rst_n,start,{8'd0,roi_min},min_bcd);
bin16_bcd b4(clk,rst_n,start,{8'd0,roi_max},max_bcd);
bin16_bcd b5(clk,rst_n,start,width,w_bcd);
bin16_bcd b6(clk,rst_n,start,height,h_bcd);
bin16_bcd b7(clk,rst_n,start,fps,fps_bcd);
reg [15:0] lane_s,format_s,i2c_s,gap_s,overflow_s,lost_s,underflow_s;
reg [31:0] frames_s,uptime_s;
reg sample_s,cfg_s,error_s,edge_sample_s;reg [1:0] class_s,reason_s,mode_s;
reg [15:0] edge_count_s;reg [23:0] edge_sum_s;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  vs_d<=0;de_d<=0;x<=0;y<=0;sample_s<=0;cfg_s<=0;error_s<=0;
  overflow_s<=0;lost_s<=0;underflow_s<=0;
  mode_s<=0;edge_sample_s<=0;edge_count_s<=0;edge_sum_s<=0;
  class_s<=1;reason_s<=0;lane_s<=0;format_s<=0;i2c_s<=0;gap_s<=0;frames_s<=0;uptime_s<=0;
 end else begin
  vs_d<=vs;de_d<=de;
  if(vs) begin x<=0;y<=0;end
  else if(de) x<=x+1'b1;
  else if(de_d) begin x<=0;y<=y+1'b1;end
  if(start) begin
   overflow_s<=overflow_frames;lost_s<=lost_frames;underflow_s<=underflow_frames;
   mode_s<=view_mode;edge_count_s<={3'd0,edge_count};edge_sum_s<=edge_sum;
   edge_sample_s<=roi_valid && cfg_done && fps!=0 && view_mode[1];
   sample_s<=roi_valid && cfg_done && fps!=0;
   class_s<=!cfg_done || fps==0 || !roi_valid ? 2'd1 : roi_state;
   reason_s<=!cfg_done ? 2'd0 : fps==0 ? 2'd1 : !roi_valid ? 2'd2 : 2'd3;
   lane_s<=lane_errors;format_s<=format_errors;i2c_s<=i2c_errors;gap_s<=gaps;
   frames_s<=frames;uptime_s<=uptime;cfg_s<=cfg_done;
   error_s<=|lane_errors || |format_errors || |i2c_errors || |gaps;
  end
 end
end
function [6:0] decimal;
 input [19:0] value;input [2:0] position;
 reg [3:0] nibble;reg blank;
 begin
  case(position)
   0: begin nibble=value[19:16];blank=value[19:16]==0;end
   1: begin nibble=value[15:12];blank=value[19:12]==0;end
   2: begin nibble=value[11:8];blank=value[19:8]==0;end
   3: begin nibble=value[7:4];blank=value[19:4]==0;end
   default: begin nibble=value[3:0];blank=0;end
  endcase
  decimal=blank ? 7'd32 : 7'd48+nibble;
 end
endfunction
function [6:0] hexchar;
 input [3:0] value;begin hexchar=value<10 ? 7'd48+value : 7'd55+value;end
endfunction
function [5:0] result_glyph;
 input [1:0] code;input [2:0] position;
 begin
  result_glyph=0;
  case(code)
   0: case(position)
    0: result_glyph=6'd13;
    1: result_glyph=6'd14;
    2: result_glyph=6'd15;
    default: result_glyph=0;
   endcase
   1: case(position)
    0: result_glyph=6'd16;
    1: result_glyph=6'd17;
    2: result_glyph=6'd11;
    3: result_glyph=6'd12;
    default: result_glyph=0;
   endcase
   2: case(position)
    0: result_glyph=6'd18;
    1: result_glyph=6'd19;
    default: result_glyph=0;
   endcase
   3: case(position)
    0: result_glyph=6'd20;
    1: result_glyph=6'd21;
    default: result_glyph=0;
   endcase
  endcase
 end
endfunction
function [5:0] reason_glyph;
 input [1:0] code;input [2:0] position;
 begin
  reason_glyph=0;
  case(code)
   0: case(position)
    0: reason_glyph=6'd22;
    1: reason_glyph=6'd23;
    2: reason_glyph=6'd24;
    default: reason_glyph=0;
   endcase
   1: case(position)
    0: reason_glyph=6'd25;
    1: reason_glyph=6'd26;
    2: reason_glyph=6'd27;
    default: reason_glyph=0;
   endcase
   2: case(position)
    0: reason_glyph=6'd16;
    1: reason_glyph=6'd17;
    2: reason_glyph=6'd18;
    3: reason_glyph=6'd28;
    4: reason_glyph=6'd29;
    default: reason_glyph=0;
   endcase
   3: case(position)
    0: reason_glyph=6'd11;
    1: reason_glyph=6'd12;
    2: reason_glyph=6'd18;
    3: reason_glyph=6'd28;
    default: reason_glyph=0;
   endcase
  endcase
 end
endfunction
function [6:0] mode_glyph;
 input [1:0] code;input [3:0] position;
 begin
 mode_glyph=7'd32;
 case(code)
 0: case(position)
 0: mode_glyph=7'd82;
 1: mode_glyph=7'd65;
 2: mode_glyph=7'd87;
 default: mode_glyph=7'd32;
 endcase
 1: case(position)
 0: mode_glyph=7'd71;
 1: mode_glyph=7'd82;
 2: mode_glyph=7'd65;
 3: mode_glyph=7'd89;
 default: mode_glyph=7'd32;
 endcase
 2: case(position)
 0: mode_glyph=7'd69;
 1: mode_glyph=7'd68;
 2: mode_glyph=7'd71;
 3: mode_glyph=7'd69;
 default: mode_glyph=7'd32;
 endcase
 3: case(position)
 0: mode_glyph=7'd71;
 1: mode_glyph=7'd82;
 2: mode_glyph=7'd65;
 3: mode_glyph=7'd89;
 4: mode_glyph=7'd43;
 5: mode_glyph=7'd69;
 6: mode_glyph=7'd68;
 7: mode_glyph=7'd71;
 8: mode_glyph=7'd69;
 default: mode_glyph=7'd32;
 endcase
 endcase
 end
endfunction
wire [23:0] result_color=class_s==0 ? 24'hf7b955 : class_s==2 ? 24'h74dbc7 : class_s==3 ? 24'hffae64 : 24'hb0c0d4;
reg [6:0] glyph;reg glyph_cjk;reg [4:0] glyph_col,glyph_row;reg [23:0] ink_color;
always @* begin
 glyph=0;glyph_cjk=0;glyph_col=0;glyph_row=0;ink_color=24'hffffff;
 if(x>=128 && x<240 && y>=24 && y<56) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-24)/2;
  if(x>=128 && x<144) begin glyph=7'd65;glyph_col=(x-128)/2;end
  if(x>=144 && x<160) begin glyph=7'd78;glyph_col=(x-144)/2;end
  if(x>=160 && x<176) begin glyph=7'd76;glyph_col=(x-160)/2;end
  if(x>=176 && x<192) begin glyph=7'd79;glyph_col=(x-176)/2;end
  if(x>=192 && x<208) begin glyph=7'd71;glyph_col=(x-192)/2;end
  if(x>=208 && x<224) begin glyph=7'd73;glyph_col=(x-208)/2;end
  if(x>=224 && x<240) begin glyph=7'd67;glyph_col=(x-224)/2;end
 end
 if(x>=360 && x<408 && y>=8 && y<32) begin
  glyph_cjk=1;ink_color=24'hffffff;
  glyph_row=(y-8)/1;
  if(x>=360 && x<384) begin glyph=6'd1;glyph_col=(x-360)/1;end
  if(x>=384 && x<408) begin glyph=6'd2;glyph_col=(x-384)/1;end
 end
 if(x>=424 && x<472 && y>=8 && y<40) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-8)/2;
  if(x>=424 && x<440) begin glyph=7'd69;glyph_col=(x-424)/2;end
  if(x>=440 && x<456) begin glyph=7'd88;glyph_col=(x-440)/2;end
  if(x>=456 && x<472) begin glyph=7'd80;glyph_col=(x-456)/2;end
 end
 if(x>=360 && x<440 && y>=40 && y<72) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-40)/2;
  if(x>=360 && x<376) begin glyph=decimal(exp_bcd,0);glyph_col=(x-360)/2;end
  if(x>=376 && x<392) begin glyph=decimal(exp_bcd,1);glyph_col=(x-376)/2;end
  if(x>=392 && x<408) begin glyph=decimal(exp_bcd,2);glyph_col=(x-392)/2;end
  if(x>=408 && x<424) begin glyph=decimal(exp_bcd,3);glyph_col=(x-408)/2;end
  if(x>=424 && x<440) begin glyph=decimal(exp_bcd,4);glyph_col=(x-424)/2;end
 end
 if(x>=456 && x<504 && y>=44 && y<68) begin
  glyph_cjk=1;ink_color=24'hffffff;
  glyph_row=(y-44)/1;
  if(x>=456 && x<480) begin glyph=6'd5;glyph_col=(x-456)/1;end
  if(x>=480 && x<504) begin glyph=6'd6;glyph_col=(x-480)/1;end
 end
 if(x>=688 && x<736 && y>=8 && y<32) begin
  glyph_cjk=1;ink_color=24'hffffff;
  glyph_row=(y-8)/1;
  if(x>=688 && x<712) begin glyph=6'd3;glyph_col=(x-688)/1;end
  if(x>=712 && x<736) begin glyph=6'd4;glyph_col=(x-712)/1;end
 end
 if(x>=752 && x<816 && y>=8 && y<40) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-8)/2;
  if(x>=752 && x<768) begin glyph=7'd71;glyph_col=(x-752)/2;end
  if(x>=768 && x<784) begin glyph=7'd65;glyph_col=(x-768)/2;end
  if(x>=784 && x<800) begin glyph=7'd73;glyph_col=(x-784)/2;end
  if(x>=800 && x<816) begin glyph=7'd78;glyph_col=(x-800)/2;end
 end
 if(x>=688 && x<768 && y>=40 && y<72) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-40)/2;
  if(x>=688 && x<704) begin glyph=decimal(gain_bcd,0);glyph_col=(x-688)/2;end
  if(x>=704 && x<720) begin glyph=decimal(gain_bcd,1);glyph_col=(x-704)/2;end
  if(x>=720 && x<736) begin glyph=decimal(gain_bcd,2);glyph_col=(x-720)/2;end
  if(x>=736 && x<752) begin glyph=decimal(gain_bcd,3);glyph_col=(x-736)/2;end
  if(x>=752 && x<768) begin glyph=decimal(gain_bcd,4);glyph_col=(x-752)/2;end
 end
 if(x>=784 && x<832 && y>=44 && y<68) begin
  glyph_cjk=1;ink_color=24'hffffff;
  glyph_row=(y-44)/1;
  if(x>=784 && x<808) begin glyph=6'd7;glyph_col=(x-784)/1;end
  if(x>=808 && x<832) begin glyph=6'd8;glyph_col=(x-808)/1;end
 end
 if(x>=864 && x<928 && y>=8 && y<40) begin
  glyph_cjk=0;ink_color=24'hb0c0d4;
  glyph_row=(y-8)/2;
  if(x>=864 && x<880) begin glyph=7'd77;glyph_col=(x-864)/2;end
  if(x>=880 && x<896) begin glyph=7'd79;glyph_col=(x-880)/2;end
  if(x>=896 && x<912) begin glyph=7'd68;glyph_col=(x-896)/2;end
  if(x>=912 && x<928) begin glyph=7'd69;glyph_col=(x-912)/2;end
 end
 if(x>=864 && x<1008 && y>=40 && y<72) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-40)/2;
  if(x>=864 && x<880) begin glyph=mode_glyph(mode_s,0);glyph_col=(x-864)/2;end
  if(x>=880 && x<896) begin glyph=mode_glyph(mode_s,1);glyph_col=(x-880)/2;end
  if(x>=896 && x<912) begin glyph=mode_glyph(mode_s,2);glyph_col=(x-896)/2;end
  if(x>=912 && x<928) begin glyph=mode_glyph(mode_s,3);glyph_col=(x-912)/2;end
  if(x>=928 && x<944) begin glyph=mode_glyph(mode_s,4);glyph_col=(x-928)/2;end
  if(x>=944 && x<960) begin glyph=mode_glyph(mode_s,5);glyph_col=(x-944)/2;end
  if(x>=960 && x<976) begin glyph=mode_glyph(mode_s,6);glyph_col=(x-960)/2;end
  if(x>=976 && x<992) begin glyph=mode_glyph(mode_s,7);glyph_col=(x-976)/2;end
  if(x>=992 && x<1008) begin glyph=mode_glyph(mode_s,8);glyph_col=(x-992)/2;end
 end
 if(x>=16 && x<112 && y>=510 && y<534) begin
  glyph_cjk=1;ink_color=24'hb0c0d4;
  glyph_row=(y-510)/1;
  if(x>=16 && x<40) begin glyph=6'd9;glyph_col=(x-16)/1;end
  if(x>=40 && x<64) begin glyph=6'd10;glyph_col=(x-40)/1;end
  if(x>=64 && x<88) begin glyph=6'd11;glyph_col=(x-64)/1;end
  if(x>=88 && x<112) begin glyph=6'd12;glyph_col=(x-88)/1;end
 end
 if(x>=16 && x<208 && y>=540 && y<588) begin
  glyph_cjk=1;ink_color=result_color;
  glyph_row=(y-540)/2;
  if(x>=16 && x<64) begin glyph=result_glyph(class_s,0);glyph_col=(x-16)/2;end
  if(x>=64 && x<112) begin glyph=result_glyph(class_s,1);glyph_col=(x-64)/2;end
  if(x>=112 && x<160) begin glyph=result_glyph(class_s,2);glyph_col=(x-112)/2;end
  if(x>=160 && x<208) begin glyph=result_glyph(class_s,3);glyph_col=(x-160)/2;end
 end
 if(x>=304 && x<368 && y>=510 && y<542) begin
  glyph_cjk=0;ink_color=24'hb0c0d4;
  glyph_row=(y-510)/2;
  if(x>=304 && x<320) begin glyph=7'd77;glyph_col=(x-304)/2;end
  if(x>=320 && x<336) begin glyph=7'd69;glyph_col=(x-320)/2;end
  if(x>=336 && x<352) begin glyph=7'd65;glyph_col=(x-336)/2;end
  if(x>=352 && x<368) begin glyph=7'd78;glyph_col=(x-352)/2;end
 end
 if(x>=384 && x<432 && y>=510 && y<542) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-510)/2;
  if(x>=384 && x<400) begin glyph=sample_s ? decimal(mean_bcd,2) : 7'd45;glyph_col=(x-384)/2;end
  if(x>=400 && x<416) begin glyph=sample_s ? decimal(mean_bcd,3) : 7'd45;glyph_col=(x-400)/2;end
  if(x>=416 && x<432) begin glyph=sample_s ? decimal(mean_bcd,4) : 7'd45;glyph_col=(x-416)/2;end
 end
 if(x>=464 && x<512 && y>=510 && y<542) begin
  glyph_cjk=0;ink_color=24'hb0c0d4;
  glyph_row=(y-510)/2;
  if(x>=464 && x<480) begin glyph=7'd77;glyph_col=(x-464)/2;end
  if(x>=480 && x<496) begin glyph=7'd73;glyph_col=(x-480)/2;end
  if(x>=496 && x<512) begin glyph=7'd78;glyph_col=(x-496)/2;end
 end
 if(x>=528 && x<576 && y>=510 && y<542) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-510)/2;
  if(x>=528 && x<544) begin glyph=sample_s ? decimal(min_bcd,2) : 7'd45;glyph_col=(x-528)/2;end
  if(x>=544 && x<560) begin glyph=sample_s ? decimal(min_bcd,3) : 7'd45;glyph_col=(x-544)/2;end
  if(x>=560 && x<576) begin glyph=sample_s ? decimal(min_bcd,4) : 7'd45;glyph_col=(x-560)/2;end
 end
 if(x>=624 && x<672 && y>=510 && y<542) begin
  glyph_cjk=0;ink_color=24'hb0c0d4;
  glyph_row=(y-510)/2;
  if(x>=624 && x<640) begin glyph=7'd77;glyph_col=(x-624)/2;end
  if(x>=640 && x<656) begin glyph=7'd65;glyph_col=(x-640)/2;end
  if(x>=656 && x<672) begin glyph=7'd88;glyph_col=(x-656)/2;end
 end
 if(x>=688 && x<736 && y>=510 && y<542) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-510)/2;
  if(x>=688 && x<704) begin glyph=sample_s ? decimal(max_bcd,2) : 7'd45;glyph_col=(x-688)/2;end
  if(x>=704 && x<720) begin glyph=sample_s ? decimal(max_bcd,3) : 7'd45;glyph_col=(x-704)/2;end
  if(x>=720 && x<736) begin glyph=sample_s ? decimal(max_bcd,4) : 7'd45;glyph_col=(x-720)/2;end
 end
 if(x>=768 && x<864 && y>=514 && y<538) begin
  glyph_cjk=1;ink_color=24'h74dbc7;
  glyph_row=(y-514)/1;
  if(x>=768 && x<792) begin glyph=sample_s ? 6'd11 : 6'd0;glyph_col=(x-768)/1;end
  if(x>=792 && x<816) begin glyph=sample_s ? 6'd12 : 6'd0;glyph_col=(x-792)/1;end
  if(x>=816 && x<840) begin glyph=sample_s ? 6'd18 : 6'd0;glyph_col=(x-816)/1;end
  if(x>=840 && x<864) begin glyph=sample_s ? 6'd28 : 6'd0;glyph_col=(x-840)/1;end
 end
 if(x>=304 && x<800 && y>=548 && y<564) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-548)/1;
  if(x>=304 && x<312) begin glyph=7'd73;glyph_col=(x-304)/1;end
  if(x>=312 && x<320) begin glyph=7'd78;glyph_col=(x-312)/1;end
  if(x>=320 && x<328) begin glyph=7'd32;glyph_col=(x-320)/1;end
  if(x>=328 && x<336) begin glyph=decimal(w_bcd,0);glyph_col=(x-328)/1;end
  if(x>=336 && x<344) begin glyph=decimal(w_bcd,1);glyph_col=(x-336)/1;end
  if(x>=344 && x<352) begin glyph=decimal(w_bcd,2);glyph_col=(x-344)/1;end
  if(x>=352 && x<360) begin glyph=decimal(w_bcd,3);glyph_col=(x-352)/1;end
  if(x>=360 && x<368) begin glyph=decimal(w_bcd,4);glyph_col=(x-360)/1;end
  if(x>=368 && x<376) begin glyph=7'd88;glyph_col=(x-368)/1;end
  if(x>=376 && x<384) begin glyph=decimal(h_bcd,0);glyph_col=(x-376)/1;end
  if(x>=384 && x<392) begin glyph=decimal(h_bcd,1);glyph_col=(x-384)/1;end
  if(x>=392 && x<400) begin glyph=decimal(h_bcd,2);glyph_col=(x-392)/1;end
  if(x>=400 && x<408) begin glyph=decimal(h_bcd,3);glyph_col=(x-400)/1;end
  if(x>=408 && x<416) begin glyph=decimal(h_bcd,4);glyph_col=(x-408)/1;end
  if(x>=416 && x<424) begin glyph=7'd32;glyph_col=(x-416)/1;end
  if(x>=424 && x<432) begin glyph=7'd70;glyph_col=(x-424)/1;end
  if(x>=432 && x<440) begin glyph=7'd80;glyph_col=(x-432)/1;end
  if(x>=440 && x<448) begin glyph=7'd83;glyph_col=(x-440)/1;end
  if(x>=448 && x<456) begin glyph=7'd32;glyph_col=(x-448)/1;end
  if(x>=456 && x<464) begin glyph=decimal(fps_bcd,0);glyph_col=(x-456)/1;end
  if(x>=464 && x<472) begin glyph=decimal(fps_bcd,1);glyph_col=(x-464)/1;end
  if(x>=472 && x<480) begin glyph=decimal(fps_bcd,2);glyph_col=(x-472)/1;end
  if(x>=480 && x<488) begin glyph=decimal(fps_bcd,3);glyph_col=(x-480)/1;end
  if(x>=488 && x<496) begin glyph=decimal(fps_bcd,4);glyph_col=(x-488)/1;end
  if(x>=496 && x<504) begin glyph=7'd32;glyph_col=(x-496)/1;end
  if(x>=504 && x<512) begin glyph=7'd67;glyph_col=(x-504)/1;end
  if(x>=512 && x<520) begin glyph=7'd70;glyph_col=(x-512)/1;end
  if(x>=520 && x<528) begin glyph=7'd71;glyph_col=(x-520)/1;end
  if(x>=528 && x<536) begin glyph=7'd32;glyph_col=(x-528)/1;end
  if(x>=536 && x<544) begin glyph=cfg_s ? 7'd49 : 7'd48;glyph_col=(x-536)/1;end
  if(x>=544 && x<552) begin glyph=7'd32;glyph_col=(x-544)/1;end
  if(x>=552 && x<560) begin glyph=7'd76;glyph_col=(x-552)/1;end
  if(x>=560 && x<568) begin glyph=7'd32;glyph_col=(x-560)/1;end
  if(x>=568 && x<576) begin glyph=hexchar(lane_s[12+:4]);glyph_col=(x-568)/1;end
  if(x>=576 && x<584) begin glyph=hexchar(lane_s[8+:4]);glyph_col=(x-576)/1;end
  if(x>=584 && x<592) begin glyph=hexchar(lane_s[4+:4]);glyph_col=(x-584)/1;end
  if(x>=592 && x<600) begin glyph=hexchar(lane_s[0+:4]);glyph_col=(x-592)/1;end
  if(x>=600 && x<608) begin glyph=7'd32;glyph_col=(x-600)/1;end
  if(x>=608 && x<616) begin glyph=7'd70;glyph_col=(x-608)/1;end
  if(x>=616 && x<624) begin glyph=7'd32;glyph_col=(x-616)/1;end
  if(x>=624 && x<632) begin glyph=hexchar(format_s[12+:4]);glyph_col=(x-624)/1;end
  if(x>=632 && x<640) begin glyph=hexchar(format_s[8+:4]);glyph_col=(x-632)/1;end
  if(x>=640 && x<648) begin glyph=hexchar(format_s[4+:4]);glyph_col=(x-640)/1;end
  if(x>=648 && x<656) begin glyph=hexchar(format_s[0+:4]);glyph_col=(x-648)/1;end
  if(x>=656 && x<664) begin glyph=7'd32;glyph_col=(x-656)/1;end
  if(x>=664 && x<672) begin glyph=7'd73;glyph_col=(x-664)/1;end
  if(x>=672 && x<680) begin glyph=7'd32;glyph_col=(x-672)/1;end
  if(x>=680 && x<688) begin glyph=hexchar(i2c_s[12+:4]);glyph_col=(x-680)/1;end
  if(x>=688 && x<696) begin glyph=hexchar(i2c_s[8+:4]);glyph_col=(x-688)/1;end
  if(x>=696 && x<704) begin glyph=hexchar(i2c_s[4+:4]);glyph_col=(x-696)/1;end
  if(x>=704 && x<712) begin glyph=hexchar(i2c_s[0+:4]);glyph_col=(x-704)/1;end
  if(x>=712 && x<720) begin glyph=7'd32;glyph_col=(x-712)/1;end
  if(x>=720 && x<728) begin glyph=7'd71;glyph_col=(x-720)/1;end
  if(x>=728 && x<736) begin glyph=7'd32;glyph_col=(x-728)/1;end
  if(x>=736 && x<744) begin glyph=hexchar(gap_s[12+:4]);glyph_col=(x-736)/1;end
  if(x>=744 && x<752) begin glyph=hexchar(gap_s[8+:4]);glyph_col=(x-744)/1;end
  if(x>=752 && x<760) begin glyph=hexchar(gap_s[4+:4]);glyph_col=(x-752)/1;end
  if(x>=760 && x<768) begin glyph=hexchar(gap_s[0+:4]);glyph_col=(x-760)/1;end
  if(x>=768 && x<776) begin glyph=7'd32;glyph_col=(x-768)/1;end
  if(x>=776 && x<784) begin glyph=7'd72;glyph_col=(x-776)/1;end
  if(x>=784 && x<792) begin glyph=7'd69;glyph_col=(x-784)/1;end
  if(x>=792 && x<800) begin glyph=7'd88;glyph_col=(x-792)/1;end
 end
 if(x>=808 && x<984 && y>=548 && y<564) begin
  glyph_cjk=0;ink_color=24'hffae64;
  glyph_row=(y-548)/1;
  if(x>=808 && x<816) begin glyph=7'd69;glyph_col=(x-808)/1;end
  if(x>=816 && x<824) begin glyph=7'd67;glyph_col=(x-816)/1;end
  if(x>=824 && x<832) begin glyph=7'd32;glyph_col=(x-824)/1;end
  if(x>=832 && x<840) begin glyph=edge_sample_s ? hexchar(edge_count_s[12+:4]) : 7'd45;glyph_col=(x-832)/1;end
  if(x>=840 && x<848) begin glyph=edge_sample_s ? hexchar(edge_count_s[8+:4]) : 7'd45;glyph_col=(x-840)/1;end
  if(x>=848 && x<856) begin glyph=edge_sample_s ? hexchar(edge_count_s[4+:4]) : 7'd45;glyph_col=(x-848)/1;end
  if(x>=856 && x<864) begin glyph=edge_sample_s ? hexchar(edge_count_s[0+:4]) : 7'd45;glyph_col=(x-856)/1;end
  if(x>=864 && x<872) begin glyph=7'd32;glyph_col=(x-864)/1;end
  if(x>=872 && x<880) begin glyph=7'd71;glyph_col=(x-872)/1;end
  if(x>=880 && x<888) begin glyph=7'd83;glyph_col=(x-880)/1;end
  if(x>=888 && x<896) begin glyph=7'd32;glyph_col=(x-888)/1;end
  if(x>=896 && x<904) begin glyph=edge_sample_s ? hexchar(edge_sum_s[20+:4]) : 7'd45;glyph_col=(x-896)/1;end
  if(x>=904 && x<912) begin glyph=edge_sample_s ? hexchar(edge_sum_s[16+:4]) : 7'd45;glyph_col=(x-904)/1;end
  if(x>=912 && x<920) begin glyph=edge_sample_s ? hexchar(edge_sum_s[12+:4]) : 7'd45;glyph_col=(x-912)/1;end
  if(x>=920 && x<928) begin glyph=edge_sample_s ? hexchar(edge_sum_s[8+:4]) : 7'd45;glyph_col=(x-920)/1;end
  if(x>=928 && x<936) begin glyph=edge_sample_s ? hexchar(edge_sum_s[4+:4]) : 7'd45;glyph_col=(x-928)/1;end
  if(x>=936 && x<944) begin glyph=edge_sample_s ? hexchar(edge_sum_s[0+:4]) : 7'd45;glyph_col=(x-936)/1;end
  if(x>=944 && x<952) begin glyph=7'd32;glyph_col=(x-944)/1;end
  if(x>=952 && x<960) begin glyph=7'd84;glyph_col=(x-952)/1;end
  if(x>=960 && x<968) begin glyph=7'd32;glyph_col=(x-960)/1;end
  if(x>=968 && x<976) begin glyph=7'd56;glyph_col=(x-968)/1;end
  if(x>=976 && x<984) begin glyph=7'd48;glyph_col=(x-976)/1;end
 end
 if(x>=304 && x<528 && y>=576 && y<592) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-576)/1;
  if(x>=304 && x<312) begin glyph=7'd70;glyph_col=(x-304)/1;end
  if(x>=312 && x<320) begin glyph=7'd82;glyph_col=(x-312)/1;end
  if(x>=320 && x<328) begin glyph=7'd32;glyph_col=(x-320)/1;end
  if(x>=328 && x<336) begin glyph=hexchar(frames_s[28+:4]);glyph_col=(x-328)/1;end
  if(x>=336 && x<344) begin glyph=hexchar(frames_s[24+:4]);glyph_col=(x-336)/1;end
  if(x>=344 && x<352) begin glyph=hexchar(frames_s[20+:4]);glyph_col=(x-344)/1;end
  if(x>=352 && x<360) begin glyph=hexchar(frames_s[16+:4]);glyph_col=(x-352)/1;end
  if(x>=360 && x<368) begin glyph=hexchar(frames_s[12+:4]);glyph_col=(x-360)/1;end
  if(x>=368 && x<376) begin glyph=hexchar(frames_s[8+:4]);glyph_col=(x-368)/1;end
  if(x>=376 && x<384) begin glyph=hexchar(frames_s[4+:4]);glyph_col=(x-376)/1;end
  if(x>=384 && x<392) begin glyph=hexchar(frames_s[0+:4]);glyph_col=(x-384)/1;end
  if(x>=392 && x<400) begin glyph=7'd32;glyph_col=(x-392)/1;end
  if(x>=400 && x<408) begin glyph=7'd83;glyph_col=(x-400)/1;end
  if(x>=408 && x<416) begin glyph=7'd69;glyph_col=(x-408)/1;end
  if(x>=416 && x<424) begin glyph=7'd67;glyph_col=(x-416)/1;end
  if(x>=424 && x<432) begin glyph=7'd32;glyph_col=(x-424)/1;end
  if(x>=432 && x<440) begin glyph=hexchar(uptime_s[28+:4]);glyph_col=(x-432)/1;end
  if(x>=440 && x<448) begin glyph=hexchar(uptime_s[24+:4]);glyph_col=(x-440)/1;end
  if(x>=448 && x<456) begin glyph=hexchar(uptime_s[20+:4]);glyph_col=(x-448)/1;end
  if(x>=456 && x<464) begin glyph=hexchar(uptime_s[16+:4]);glyph_col=(x-456)/1;end
  if(x>=464 && x<472) begin glyph=hexchar(uptime_s[12+:4]);glyph_col=(x-464)/1;end
  if(x>=472 && x<480) begin glyph=hexchar(uptime_s[8+:4]);glyph_col=(x-472)/1;end
  if(x>=480 && x<488) begin glyph=hexchar(uptime_s[4+:4]);glyph_col=(x-480)/1;end
  if(x>=488 && x<496) begin glyph=hexchar(uptime_s[0+:4]);glyph_col=(x-488)/1;end
  if(x>=496 && x<504) begin glyph=7'd32;glyph_col=(x-496)/1;end
  if(x>=504 && x<512) begin glyph=7'd72;glyph_col=(x-504)/1;end
  if(x>=512 && x<520) begin glyph=7'd69;glyph_col=(x-512)/1;end
  if(x>=520 && x<528) begin glyph=7'd88;glyph_col=(x-520)/1;end
 end
 if(x>=624 && x<744 && y>=572 && y<596) begin
  glyph_cjk=1;ink_color=reason_s==1 ? 24'hef7186 : 24'hb0c0d4;
  glyph_row=(y-572)/1;
  if(x>=624 && x<648) begin glyph=reason_glyph(reason_s,0);glyph_col=(x-624)/1;end
  if(x>=648 && x<672) begin glyph=reason_glyph(reason_s,1);glyph_col=(x-648)/1;end
  if(x>=672 && x<696) begin glyph=reason_glyph(reason_s,2);glyph_col=(x-672)/1;end
  if(x>=696 && x<720) begin glyph=reason_glyph(reason_s,3);glyph_col=(x-696)/1;end
  if(x>=720 && x<744) begin glyph=reason_glyph(reason_s,4);glyph_col=(x-720)/1;end
 end
 if(x>=920 && x<1016 && y>=572 && y<596) begin
  glyph_cjk=1;ink_color=24'hf7b955;
  glyph_row=(y-572)/1;
  if(x>=920 && x<944) begin glyph=error_s ? 6'd30 : 6'd0;glyph_col=(x-920)/1;end
  if(x>=944 && x<968) begin glyph=error_s ? 6'd31 : 6'd0;glyph_col=(x-944)/1;end
  if(x>=968 && x<992) begin glyph=error_s ? 6'd32 : 6'd0;glyph_col=(x-968)/1;end
  if(x>=992 && x<1016) begin glyph=error_s ? 6'd33 : 6'd0;glyph_col=(x-992)/1;end
 end
 if(x>=536 && x<592 && y>=576 && y<592) begin
  glyph_cjk=0;ink_color=24'hffae64;
  glyph_row=(y-576)/1;
  if(x>=536 && x<544) begin glyph=7'd79;glyph_col=(x-536)/1;end
  if(x>=544 && x<552) begin glyph=7'd70;glyph_col=(x-544)/1;end
  if(x>=552 && x<560) begin glyph=7'd32;glyph_col=(x-552)/1;end
  if(x>=560 && x<568) begin glyph=hexchar(overflow_s[12+:4]);glyph_col=(x-560)/1;end
  if(x>=568 && x<576) begin glyph=hexchar(overflow_s[8+:4]);glyph_col=(x-568)/1;end
  if(x>=576 && x<584) begin glyph=hexchar(overflow_s[4+:4]);glyph_col=(x-576)/1;end
  if(x>=584 && x<592) begin glyph=hexchar(overflow_s[0+:4]);glyph_col=(x-584)/1;end
 end
 if(x>=752 && x<808 && y>=576 && y<592) begin
  glyph_cjk=0;ink_color=24'hffae64;
  glyph_row=(y-576)/1;
  if(x>=752 && x<760) begin glyph=7'd86;glyph_col=(x-752)/1;end
  if(x>=760 && x<768) begin glyph=7'd70;glyph_col=(x-760)/1;end
  if(x>=768 && x<776) begin glyph=7'd32;glyph_col=(x-768)/1;end
  if(x>=776 && x<784) begin glyph=hexchar(lost_s[12+:4]);glyph_col=(x-776)/1;end
  if(x>=784 && x<792) begin glyph=hexchar(lost_s[8+:4]);glyph_col=(x-784)/1;end
  if(x>=792 && x<800) begin glyph=hexchar(lost_s[4+:4]);glyph_col=(x-792)/1;end
  if(x>=800 && x<808) begin glyph=hexchar(lost_s[0+:4]);glyph_col=(x-800)/1;end
 end
 if(x>=832 && x<888 && y>=576 && y<592) begin
  glyph_cjk=0;ink_color=24'hffae64;
  glyph_row=(y-576)/1;
  if(x>=832 && x<840) begin glyph=7'd85;glyph_col=(x-832)/1;end
  if(x>=840 && x<848) begin glyph=7'd70;glyph_col=(x-840)/1;end
  if(x>=848 && x<856) begin glyph=7'd32;glyph_col=(x-848)/1;end
  if(x>=856 && x<864) begin glyph=hexchar(underflow_s[12+:4]);glyph_col=(x-856)/1;end
  if(x>=864 && x<872) begin glyph=hexchar(underflow_s[8+:4]);glyph_col=(x-864)/1;end
  if(x>=872 && x<880) begin glyph=hexchar(underflow_s[4+:4]);glyph_col=(x-872)/1;end
  if(x>=880 && x<888) begin glyph=hexchar(underflow_s[0+:4]);glyph_col=(x-880)/1;end
 end
end
wire roi_inside=x>=ROI_X0 && x<ROI_X1 && y>=ROI_Y0 && y<ROI_Y1;
wire roi_border=roi_inside && (x==ROI_X0 || x==ROI_X1-1 || y==ROI_Y0 || y==ROI_Y1-1);
wire sample_inside=x>=SAMPLE_X0 && x<SAMPLE_X1 && y>=SAMPLE_Y0 && y<SAMPLE_Y1;
wire sample_border=sample_inside && (x==SAMPLE_X0 || x==SAMPLE_X1-1 || y==SAMPLE_Y0 || y==SAMPLE_Y1-1);
wire [9:0] gray_sum={2'd0,rgb[23:16]}+{1'd0,rgb[15:8],1'b0}+{2'd0,rgb[7:0]};
wire [7:0] gray=gray_sum[9:2];
wire [23:0] picture=ENABLE && sample_border ? 24'h00ffff :
 ENABLE && roi_border ? 24'h00ff40 : rgb;
reg [10:0] ascii_address;
reg [10:0] cjk_address;
reg [12:0] logo_address;
wire [5:0] logo_y=y-10'd8;
wire [6:0] logo_x=x-11'd16;
wire [7:0] ascii_row;wire [23:0] cjk_row;wire [1:0] logo_pixel;
osd_ascii_rom u_ascii(clk,ascii_address,ascii_row);
osd_cjk_rom u_cjk(clk,cjk_address,cjk_row);
osd_logo_rom u_logo(clk,logo_address,logo_pixel);
reg [1:0] hs_p,vs_p,de_p,panel_p,logo_p,cjk_p;
reg [4:0] col0,col1;
reg [23:0] rgb0,rgb1,ink0,ink1;
wire ink=cjk_p[1] ? (col1<24 && cjk_row[23-col1]) : (col1<8 && ascii_row[7-col1]);
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  ascii_address<=0;cjk_address<=0;logo_address<=0;
  hs_p<=0;vs_p<=0;de_p<=0;panel_p<=0;logo_p<=0;cjk_p<=0;
  col0<=0;col1<=0;rgb0<=0;rgb1<=0;ink0<=0;ink1<=0;
  out_vs<=0;out_hs<=0;out_de<=0;out_rgb<=0;
 end else begin
  ascii_address<={glyph,glyph_row[3:0]};
  cjk_address<={glyph[5:0],glyph_row};
  logo_address<={logo_y,logo_x};
  hs_p<={hs_p[0],hs};vs_p<={vs_p[0],vs};de_p<={de_p[0],de};
  panel_p<={panel_p[0],(de && (y<80 || y>=504))};
  logo_p<={logo_p[0],(x>=16 && x<112 && y>=8 && y<72)};
  cjk_p<={cjk_p[0],glyph_cjk};col0<=glyph_col;col1<=col0;
  rgb0<=picture;rgb1<=rgb0;ink0<=ink_color;ink1<=ink0;
  out_vs<=vs_p[1];out_hs<=hs_p[1];out_de<=de_p[1];
  out_rgb<=ENABLE && panel_p[1] ?
   (logo_p[1] ? (logo_pixel==1 ? 24'h204686 : logo_pixel==2 ? 24'hcc253b : 24'hffffff) :
    ink ? ink1 : 24'h142336) : rgb1;
 end
end
endmodule
