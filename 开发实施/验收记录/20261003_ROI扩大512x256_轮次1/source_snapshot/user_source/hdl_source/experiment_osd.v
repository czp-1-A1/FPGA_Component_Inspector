// Two-clock video/sync latency. Statistics describe the latest valid sample.
module experiment_osd #(
 parameter ENABLE=1,ROI_X0=256,ROI_X1=768,ROI_Y0=172,ROI_Y1=428
)(
 input wire clk,rst_n,vs,hs,de,input wire [23:0] rgb,
 input wire [15:0] exposure,gain,
 input wire roi_valid,input wire [7:0] roi_mean,roi_min,roi_max,
 input wire [15:0] width,height,fps,lane_errors,format_errors,i2c_errors,gaps,
 input wire [31:0] frames,uptime,input wire cfg_done,
 output reg out_vs,out_hs,out_de,output reg [23:0] out_rgb
);
reg vs_d,de_d;
reg [10:0] x;
reg [9:0] y;
wire start=vs && !vs_d;
wire [19:0] exp_bcd,gain_bcd,mean_bcd,min_bcd,max_bcd;
bin16_bcd b0(clk,rst_n,start,exposure,exp_bcd);
bin16_bcd b1(clk,rst_n,start,gain,gain_bcd);
bin16_bcd b2(clk,rst_n,start,{8'd0,roi_mean},mean_bcd);
bin16_bcd b3(clk,rst_n,start,{8'd0,roi_min},min_bcd);
bin16_bcd b4(clk,rst_n,start,{8'd0,roi_max},max_bcd);
wire [19:0] w_bcd,h_bcd,fps_bcd;
bin16_bcd b5(clk,rst_n,start,width,w_bcd);
bin16_bcd b6(clk,rst_n,start,height,h_bcd);
bin16_bcd b7(clk,rst_n,start,fps,fps_bcd);
reg [15:0] lane_s,format_s,i2c_s,gap_s;
reg [31:0] frames_s,uptime_s;
reg cfg_s;
reg sample_s;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin vs_d<=0; de_d<=0; x<=0; y<=0; sample_s<=0; lane_s<=0; format_s<=0; i2c_s<=0; gap_s<=0; frames_s<=0; uptime_s<=0; cfg_s<=0; end
 else begin
  vs_d<=vs; de_d<=de;
  if(vs) begin x<=0; y<=0; end
  else if(de) x<=x+1'b1;
  else if(de_d) begin x<=0; y<=y+1'b1; end
  if(start) begin
   sample_s<=roi_valid;lane_s<=lane_errors;format_s<=format_errors;
   i2c_s<=i2c_errors;gap_s<=gaps;frames_s<=frames;uptime_s<=uptime;cfg_s<=cfg_done;
  end
 end
end
function [7:0] digit;
 input [3:0] value;
 begin digit=8'd48+value; end
endfunction
function [7:0] hexchar;
 input [3:0] value;
 begin hexchar=value<10 ? 8'd48+value : 8'd55+value; end
endfunction
reg [7:0] character;
always @* begin
 character=8'd32;
 case({y[9:4],x[9:4]})
  9'd4: character=digit(exp_bcd[16+:4]);
  9'd5: character=digit(exp_bcd[12+:4]);
  9'd6: character=digit(exp_bcd[8+:4]);
  9'd7: character=digit(exp_bcd[4+:4]);
  9'd8: character=digit(exp_bcd[0+:4]);
  9'd26: character=digit(gain_bcd[16+:4]);
  9'd27: character=digit(gain_bcd[12+:4]);
  9'd28: character=digit(gain_bcd[8+:4]);
  9'd29: character=digit(gain_bcd[4+:4]);
  9'd30: character=digit(gain_bcd[0+:4]);
  9'd0: character=8'd69;
  9'd1: character=8'd88;
  9'd2: character=8'd80;
  9'd10: character=8'd72;
  9'd11: character=8'd65;
  9'd12: character=8'd76;
  9'd13: character=8'd70;
  9'd14: character=8'd45;
  9'd15: character=8'd76;
  9'd16: character=8'd73;
  9'd17: character=8'd78;
  9'd18: character=8'd69;
  9'd21: character=8'd71;
  9'd22: character=8'd65;
  9'd23: character=8'd73;
  9'd24: character=8'd78;
  9'd32: character=8'd73;
  9'd33: character=8'd78;
  9'd34: character=8'd68;
  9'd35: character=8'd69;
  9'd36: character=8'd88;
  9'd73: character=sample_s ? digit(mean_bcd[8+:4]) : 8'd45;
  9'd74: character=sample_s ? digit(mean_bcd[4+:4]) : 8'd45;
  9'd75: character=sample_s ? digit(mean_bcd[0+:4]) : 8'd45;
  9'd81: character=sample_s ? digit(min_bcd[8+:4]) : 8'd45;
  9'd82: character=sample_s ? digit(min_bcd[4+:4]) : 8'd45;
  9'd83: character=sample_s ? digit(min_bcd[0+:4]) : 8'd45;
  9'd89: character=sample_s ? digit(max_bcd[8+:4]) : 8'd45;
  9'd90: character=sample_s ? digit(max_bcd[4+:4]) : 8'd45;
  9'd91: character=sample_s ? digit(max_bcd[0+:4]) : 8'd45;
  9'd64: character=8'd82;
  9'd65: character=8'd79;
  9'd66: character=8'd73;
  9'd68: character=8'd77;
  9'd69: character=8'd69;
  9'd70: character=8'd65;
  9'd71: character=8'd78;
  9'd77: character=8'd77;
  9'd78: character=8'd73;
  9'd79: character=8'd78;
  9'd85: character=8'd77;
  9'd86: character=8'd65;
  9'd87: character=8'd88;
  9'd96: character=sample_s ? 8'd86 : 8'd87;
  9'd97: character=sample_s ? 8'd65 : 8'd65;
  9'd98: character=sample_s ? 8'd76 : 8'd73;
  9'd99: character=sample_s ? 8'd73 : 8'd84;
  9'd100: character=sample_s ? 8'd68 : 8'd32;
  12'd2243: character=digit(w_bcd[16+:4]);
  12'd2244: character=digit(w_bcd[12+:4]);
  12'd2245: character=digit(w_bcd[8+:4]);
  12'd2246: character=digit(w_bcd[4+:4]);
  12'd2247: character=digit(w_bcd[0+:4]);
  12'd2251: character=digit(h_bcd[16+:4]);
  12'd2252: character=digit(h_bcd[12+:4]);
  12'd2253: character=digit(h_bcd[8+:4]);
  12'd2254: character=digit(h_bcd[4+:4]);
  12'd2255: character=digit(h_bcd[0+:4]);
  12'd2261: character=digit(fps_bcd[16+:4]);
  12'd2262: character=digit(fps_bcd[12+:4]);
  12'd2263: character=digit(fps_bcd[8+:4]);
  12'd2264: character=digit(fps_bcd[4+:4]);
  12'd2265: character=digit(fps_bcd[0+:4]);
  12'd2270: character=hexchar(lane_s[12+:4]);
  12'd2271: character=hexchar(lane_s[8+:4]);
  12'd2272: character=hexchar(lane_s[4+:4]);
  12'd2273: character=hexchar(lane_s[0+:4]);
  12'd2277: character=hexchar(format_s[12+:4]);
  12'd2278: character=hexchar(format_s[8+:4]);
  12'd2279: character=hexchar(format_s[4+:4]);
  12'd2280: character=hexchar(format_s[0+:4]);
  12'd2284: character=hexchar(i2c_s[12+:4]);
  12'd2285: character=hexchar(i2c_s[8+:4]);
  12'd2286: character=hexchar(i2c_s[4+:4]);
  12'd2287: character=hexchar(i2c_s[0+:4]);
  12'd2291: character=hexchar(gap_s[12+:4]);
  12'd2292: character=hexchar(gap_s[8+:4]);
  12'd2293: character=hexchar(gap_s[4+:4]);
  12'd2294: character=hexchar(gap_s[0+:4]);
  12'd2240: character=8'd73;
  12'd2241: character=8'd78;
  12'd2249: character=8'd88;
  12'd2257: character=8'd70;
  12'd2258: character=8'd80;
  12'd2259: character=8'd83;
  12'd2268: character=8'd76;
  12'd2275: character=8'd70;
  12'd2282: character=8'd73;
  12'd2289: character=8'd71;
  12'd2311: character=hexchar(frames_s[28+:4]);
  12'd2312: character=hexchar(frames_s[24+:4]);
  12'd2313: character=hexchar(frames_s[20+:4]);
  12'd2314: character=hexchar(frames_s[16+:4]);
  12'd2315: character=hexchar(frames_s[12+:4]);
  12'd2316: character=hexchar(frames_s[8+:4]);
  12'd2317: character=hexchar(frames_s[4+:4]);
  12'd2318: character=hexchar(frames_s[0+:4]);
  12'd2324: character=hexchar(uptime_s[28+:4]);
  12'd2325: character=hexchar(uptime_s[24+:4]);
  12'd2326: character=hexchar(uptime_s[20+:4]);
  12'd2327: character=hexchar(uptime_s[16+:4]);
  12'd2328: character=hexchar(uptime_s[12+:4]);
  12'd2329: character=hexchar(uptime_s[8+:4]);
  12'd2330: character=hexchar(uptime_s[4+:4]);
  12'd2331: character=hexchar(uptime_s[0+:4]);
  12'd2304: character=8'd72;
  12'd2305: character=8'd69;
  12'd2306: character=8'd88;
  12'd2308: character=8'd70;
  12'd2309: character=8'd82;
  12'd2320: character=8'd83;
  12'd2321: character=8'd69;
  12'd2322: character=8'd67;
  12'd2333: character=8'd67;
  12'd2334: character=8'd70;
  12'd2335: character=8'd71;
  12'd2337: character=cfg_s ? 8'd49 : 8'd48;
  default: character=8'd32;
 endcase
end
function [34:0] font;
 input [7:0] ch;
 begin
 case(ch)
  8'd48: font=35'b01110100011001110101110011000101110;
  8'd49: font=35'b00100011000010000100001000010001110;
  8'd50: font=35'b01110100010000100010001000100011111;
  8'd51: font=35'b11110000010000101110000010000111110;
  8'd52: font=35'b00010001100101010010111110001000010;
  8'd53: font=35'b11111100001000011110000010000111110;
  8'd54: font=35'b01110100001000011110100011000101110;
  8'd55: font=35'b11111000010001000100010000100001000;
  8'd56: font=35'b01110100011000101110100011000101110;
  8'd57: font=35'b01110100011000101111000010000101110;
  8'd65: font=35'b01110100011000111111100011000110001;
  8'd66: font=35'b11110100011000111110100011000111110;
  8'd67: font=35'b01111100001000010000100001000001111;
  8'd68: font=35'b11110100011000110001100011000111110;
  8'd69: font=35'b11111100001000011110100001000011111;
  8'd70: font=35'b11111100001000011110100001000010000;
  8'd71: font=35'b01111100001000010111100011000101111;
  8'd72: font=35'b10001100011000111111100011000110001;
  8'd73: font=35'b01110001000010000100001000010001110;
  8'd76: font=35'b10000100001000010000100001000011111;
  8'd77: font=35'b10001110111010110101100011000110001;
  8'd78: font=35'b10001110011010110011100011000110001;
  8'd79: font=35'b01110100011000110001100011000101110;
  8'd80: font=35'b11110100011000111110100001000010000;
  8'd82: font=35'b11110100011000111110101001001010001;
  8'd83: font=35'b01111100001000001110000010000111110;
  8'd84: font=35'b11111001000010000100001000010000100;
  8'd85: font=35'b10001100011000110001100011000101110;
  8'd86: font=35'b10001100011000110001100010101000100;
  8'd88: font=35'b10001100010101000100010101000110001;
  8'd89: font=35'b10001100010101000100001000010000100;
  8'd47: font=35'b00001000100001000100010000100010000;
  8'd45: font=35'b00000000000000011111000000000000000;
  8'd90: font=35'b11111000010001000100010001000011111;
  8'd87: font=35'b10001100011000110101101011101110001;
  default: font=0;
 endcase
 end
endfunction
reg [7:0] ch_d;
reg [2:0] gx,gy;
reg panel;
reg hs_p,vs_p,de_p;
reg [23:0] rgb_p;
wire [34:0] bitmap=font(ch_d);
wire ink=(gx<5 && gy<7) ? bitmap[34-(gy*5+gx)] : 1'b0;
wire roi_inside=x>=ROI_X0 && x<ROI_X1 && y>=ROI_Y0 && y<ROI_Y1;
wire roi_border=roi_inside && (x==ROI_X0 || x==ROI_X1-1 || y==ROI_Y0 || y==ROI_Y1-1);
wire [9:0] gray_sum={2'd0,rgb[23:16]}+{1'd0,rgb[15:8],1'b0}+{2'd0,rgb[7:0]};
wire [7:0] gray=gray_sum[9:2];
wire [23:0] picture_rgb=ENABLE && roi_inside ? (roi_border ? 24'h00ff40 : {gray,gray,gray}) : rgb;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin ch_d<=32; gx<=0; gy<=0; panel<=0; hs_p<=0; vs_p<=0; de_p<=0; rgb_p<=0;
 out_vs<=0; out_hs<=0; out_de<=0; out_rgb<=0; end
 else begin
  ch_d<=character; gx<=x[3:1]; gy<=y[3:1]; panel<=de && ((y<32 && x<704) || (y>=560 && y<592 && x<1024));
  vs_p<=vs; hs_p<=hs; de_p<=de; rgb_p<=picture_rgb;
  out_vs<=vs_p; out_hs<=hs_p; out_de<=de_p;
  out_rgb<=ENABLE && panel ? (ink ? 24'hffffff : 24'h102030) : rgb_p;
 end
end
endmodule
