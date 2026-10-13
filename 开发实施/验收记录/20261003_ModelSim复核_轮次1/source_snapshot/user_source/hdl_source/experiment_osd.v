// Two-clock pixel/sync latency, optional bypass with ENABLE=0.
// Decimal EXP in half-lines and GAIN as LUT index. Counters marked HEX.
module experiment_osd #(parameter ENABLE=1)(
 input wire clk,rst_n,vs,hs,de,input wire [23:0] rgb,
 input wire [15:0] exposure,gain,width,height,fps,lane_errors,format_errors,i2c_errors,gaps,
 input wire [31:0] frames,uptime,input wire cfg_done,
 output reg out_vs,out_hs,out_de,output reg [23:0] out_rgb
);
reg vs_d,de_d;
reg [10:0] x;
reg [9:0] y;
wire start=vs && !vs_d;
wire [19:0] exp_bcd,gain_bcd,w_bcd,h_bcd,fps_bcd;
bin16_bcd b0(clk,rst_n,start,exposure,exp_bcd);
bin16_bcd b1(clk,rst_n,start,gain,gain_bcd);
bin16_bcd b2(clk,rst_n,start,width,w_bcd);
bin16_bcd b3(clk,rst_n,start,height,h_bcd);
bin16_bcd b4(clk,rst_n,start,fps,fps_bcd);
reg [15:0] lane_s,format_s,i2c_s,gap_s;
reg [31:0] frames_s,uptime_s;
reg cfg_s;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin vs_d<=0; de_d<=0; x<=0; y<=0;
  lane_s<=0; format_s<=0; i2c_s<=0; gap_s<=0; frames_s<=0; uptime_s<=0; cfg_s<=0; end
 else begin
  vs_d<=vs; de_d<=de;
  if(vs) begin x<=0; y<=0; end
  else if(de) x<=x+1'b1;
  else if(de_d) begin x<=0; y<=y+1'b1; end
  if(start) begin lane_s<=lane_errors; format_s<=format_errors; i2c_s<=i2c_errors;
   gap_s<=gaps; frames_s<=frames; uptime_s<=uptime; cfg_s<=cfg_done; end
 end
end
function [7:0] hexchar;
 input [3:0] v;
 begin hexchar=v<10 ? 8'd48+v : 8'd55+v; end
endfunction
reg [7:0] character;
always @* begin
 character=8'd32;
 case({y[6:4],x[9:4]})
  9'd0: character=8'd69;
  9'd1: character=8'd88;
  9'd2: character=8'd80;
  9'd4: character=hexchar(exp_bcd[16+:4]);
  9'd5: character=hexchar(exp_bcd[12+:4]);
  9'd6: character=hexchar(exp_bcd[8+:4]);
  9'd7: character=hexchar(exp_bcd[4+:4]);
  9'd8: character=hexchar(exp_bcd[0+:4]);
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
  9'd26: character=hexchar(gain_bcd[16+:4]);
  9'd27: character=hexchar(gain_bcd[12+:4]);
  9'd28: character=hexchar(gain_bcd[8+:4]);
  9'd29: character=hexchar(gain_bcd[4+:4]);
  9'd30: character=hexchar(gain_bcd[0+:4]);
  9'd32: character=8'd73;
  9'd33: character=8'd78;
  9'd34: character=8'd68;
  9'd35: character=8'd69;
  9'd36: character=8'd88;
  9'd39: character=8'd67;
  9'd40: character=8'd70;
  9'd41: character=8'd71;
  9'd42: character=cfg_s ? 8'd49 : 8'd48;
  9'd64: character=8'd73;
  9'd65: character=8'd78;
  9'd66: character=8'd80;
  9'd67: character=8'd85;
  9'd68: character=8'd84;
  9'd70: character=hexchar(w_bcd[16+:4]);
  9'd71: character=hexchar(w_bcd[12+:4]);
  9'd72: character=hexchar(w_bcd[8+:4]);
  9'd73: character=hexchar(w_bcd[4+:4]);
  9'd74: character=hexchar(w_bcd[0+:4]);
  9'd76: character=8'd88;
  9'd78: character=hexchar(h_bcd[16+:4]);
  9'd79: character=hexchar(h_bcd[12+:4]);
  9'd80: character=hexchar(h_bcd[8+:4]);
  9'd81: character=hexchar(h_bcd[4+:4]);
  9'd82: character=hexchar(h_bcd[0+:4]);
  9'd84: character=8'd70;
  9'd85: character=8'd80;
  9'd86: character=8'd83;
  9'd88: character=hexchar(fps_bcd[16+:4]);
  9'd89: character=hexchar(fps_bcd[12+:4]);
  9'd90: character=hexchar(fps_bcd[8+:4]);
  9'd91: character=hexchar(fps_bcd[4+:4]);
  9'd92: character=hexchar(fps_bcd[0+:4]);
  9'd94: character=8'd47;
  9'd95: character=8'd83;
  9'd128: character=8'd72;
  9'd129: character=8'd69;
  9'd130: character=8'd88;
  9'd132: character=8'd76;
  9'd133: character=8'd65;
  9'd134: character=8'd78;
  9'd135: character=8'd69;
  9'd137: character=hexchar(lane_s[12+:4]);
  9'd138: character=hexchar(lane_s[8+:4]);
  9'd139: character=hexchar(lane_s[4+:4]);
  9'd140: character=hexchar(lane_s[0+:4]);
  9'd142: character=8'd70;
  9'd143: character=8'd79;
  9'd144: character=8'd82;
  9'd145: character=8'd77;
  9'd146: character=8'd65;
  9'd147: character=8'd84;
  9'd149: character=hexchar(format_s[12+:4]);
  9'd150: character=hexchar(format_s[8+:4]);
  9'd151: character=hexchar(format_s[4+:4]);
  9'd152: character=hexchar(format_s[0+:4]);
  9'd154: character=8'd73;
  9'd155: character=8'd50;
  9'd156: character=8'd67;
  9'd158: character=hexchar(i2c_s[12+:4]);
  9'd159: character=hexchar(i2c_s[8+:4]);
  9'd160: character=hexchar(i2c_s[4+:4]);
  9'd161: character=hexchar(i2c_s[0+:4]);
  9'd163: character=8'd71;
  9'd164: character=8'd65;
  9'd165: character=8'd80;
  9'd166: character=hexchar(gap_s[12+:4]);
  9'd167: character=hexchar(gap_s[8+:4]);
  9'd168: character=hexchar(gap_s[4+:4]);
  9'd169: character=hexchar(gap_s[0+:4]);
  9'd192: character=8'd72;
  9'd193: character=8'd69;
  9'd194: character=8'd88;
  9'd196: character=8'd70;
  9'd197: character=8'd82;
  9'd198: character=8'd65;
  9'd199: character=8'd77;
  9'd200: character=8'd69;
  9'd201: character=8'd83;
  9'd203: character=hexchar(frames_s[28+:4]);
  9'd204: character=hexchar(frames_s[24+:4]);
  9'd205: character=hexchar(frames_s[20+:4]);
  9'd206: character=hexchar(frames_s[16+:4]);
  9'd207: character=hexchar(frames_s[12+:4]);
  9'd208: character=hexchar(frames_s[8+:4]);
  9'd209: character=hexchar(frames_s[4+:4]);
  9'd210: character=hexchar(frames_s[0+:4]);
  9'd212: character=8'd83;
  9'd213: character=8'd69;
  9'd214: character=8'd67;
  9'd215: character=8'd79;
  9'd216: character=8'd78;
  9'd217: character=8'd68;
  9'd218: character=8'd83;
  9'd220: character=hexchar(uptime_s[28+:4]);
  9'd221: character=hexchar(uptime_s[24+:4]);
  9'd222: character=hexchar(uptime_s[20+:4]);
  9'd223: character=hexchar(uptime_s[16+:4]);
  9'd224: character=hexchar(uptime_s[12+:4]);
  9'd225: character=hexchar(uptime_s[8+:4]);
  9'd226: character=hexchar(uptime_s[4+:4]);
  9'd227: character=hexchar(uptime_s[0+:4]);
  9'd256: character=8'd72;
  9'd257: character=8'd68;
  9'd258: character=8'd77;
  9'd259: character=8'd73;
  9'd261: character=8'd49;
  9'd262: character=8'd48;
  9'd263: character=8'd50;
  9'd264: character=8'd52;
  9'd265: character=8'd88;
  9'd266: character=8'd54;
  9'd267: character=8'd48;
  9'd268: character=8'd48;
  9'd271: character=8'd80;
  9'd272: character=8'd73;
  9'd273: character=8'd88;
  9'd274: character=8'd69;
  9'd275: character=8'd76;
  9'd277: character=8'd53;
  9'd278: character=8'd50;
  9'd279: character=8'd77;
  9'd280: character=8'd72;
  9'd281: character=8'd90;
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
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin ch_d<=32; gx<=0; gy<=0; panel<=0; hs_p<=0; vs_p<=0; de_p<=0; rgb_p<=0;
 out_vs<=0; out_hs<=0; out_de<=0; out_rgb<=0; end
 else begin
  ch_d<=character; gx<=x[3:1]; gy<=y[3:1]; panel<=de && y<80 && x<704;
  vs_p<=vs; hs_p<=hs; de_p<=de; rgb_p<=rgb;
  out_vs<=vs_p; out_hs<=hs_p; out_de<=de_p;
  out_rgb<=ENABLE && panel ? (ink ? 24'hffffff : 24'h102030) : rgb_p;
 end
end
endmodule
