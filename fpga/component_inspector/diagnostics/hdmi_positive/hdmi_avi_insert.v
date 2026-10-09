// Diagnostic HDMI packet insertion, one AVI per frame, 24-bit RGB.
// Register timing matches the one-pixel DVI encoder output. No extra CDC.
// HDMI 1.3a/1.4 control/TERC4 and packet mapping cross-checked with the
// original specification and hdl-util/hdmi author implementation.
module hdmi_avi_insert(input wire clk,rst,input wire [11:0] x,
 input wire [10:0] y,input wire hs,vs,
 input wire [9:0] video_b,video_g,video_r,
 output wire [9:0] out_b,out_g,out_r);
 function [9:0] control_word;
  input [1:0] value;
  begin case(value)
   0:control_word=10'b1101010100;1:control_word=10'b0010101011;
   2:control_word=10'b0101010100;3:control_word=10'b1010101011;
  endcase end
 endfunction
 function [9:0] terc_word;
  input [3:0] value;
  begin case(value)
   0:terc_word=10'b1010011100;1:terc_word=10'b1001100011;
   2:terc_word=10'b1011100100;3:terc_word=10'b1011100010;
   4:terc_word=10'b0101110001;5:terc_word=10'b0100011110;
   6:terc_word=10'b0110001110;7:terc_word=10'b0100111100;
   8:terc_word=10'b1011001100;9:terc_word=10'b0100111001;
   10:terc_word=10'b0110011100;11:terc_word=10'b1011000110;
   12:terc_word=10'b1010001110;13:terc_word=10'b1001110001;
   14:terc_word=10'b0101100011;15:terc_word=10'b1011000011;
  endcase end
 endfunction
 // Constant-expression BCH computations; no run-time CRC hardware required.
 function [7:0] bch_header;
  input [23:0] value;reg [7:0] state_value;integer i;
  begin state_value=0;for(i=0;i<24;i=i+1)
   state_value=(state_value>>1)^((state_value[0]^value[i])?8'h83:8'h00);
   bch_header=state_value;
  end
 endfunction
 function [7:0] bch_sub;
  input [55:0] value;reg [7:0] state_value;integer i;
  begin state_value=0;for(i=0;i<56;i=i+1)
   state_value=(state_value>>1)^((state_value[0]^value[i])?8'h83:8'h00);
   bch_sub=state_value;
  end
 endfunction
 // HB0=82 HB1=02 HB2=0D. PB0=2D checksum; RGB/16:9/default
 // quantization/VIC34/no pixel repetition. No EDID QS capability assumed.
 localparam [23:0] HEADER=24'h0d0282;
 localparam [55:0] SUB0=56'h0000220020002d,SUB_ZERO=56'd0;
 localparam [31:0] HEADER_BCH={bch_header(HEADER),HEADER};
 localparam [63:0] SUB0_BCH={bch_sub(SUB0),SUB0};
 localparam [63:0] ZERO_BCH={bch_sub(SUB_ZERO),SUB_ZERO};
 // Truncation intentionally computes 0..31 only inside the 32-pixel packet.
 wire [4:0] k=x-12'd1934;
 wire [5:0] even_bit={k,1'b0},odd_bit={k,1'b1};
 wire [3:0] even_nibble={ZERO_BCH[even_bit],ZERO_BCH[even_bit],ZERO_BCH[even_bit],SUB0_BCH[even_bit]};
 wire [3:0] odd_nibble={ZERO_BCH[odd_bit],ZERO_BCH[odd_bit],ZERO_BCH[odd_bit],SUB0_BCH[odd_bit]};
 wire following_active=(y<11'd1079 || y==11'd1124);
 wire video_pre=following_active && x>=12'd2190 && x<12'd2198;
 wire video_guard=following_active && x>=12'd2198;
 wire island_pre=y==11'd1080 && x>=12'd1924 && x<12'd1932;
 wire island_guard=y==11'd1080 && ((x>=12'd1932 && x<12'd1934) || (x>=12'd1966 && x<12'd1968));
 wire island_data=y==11'd1080 && x>=12'd1934 && x<12'd1966;
 reg override_r;
 reg [9:0] packet_b,packet_g,packet_r;
 always @(posedge clk or posedge rst)
  if(rst)begin override_r<=1;packet_b<=10'b1101010100;packet_g<=10'b1101010100;packet_r<=10'b1101010100;end
  else begin
   override_r<=video_pre || video_guard || island_pre || island_guard || island_data;
   packet_b<=control_word({vs,hs});packet_g<=control_word(0);packet_r<=control_word(0);
   if(video_pre)begin packet_g<=control_word(1);end
   if(video_guard)begin packet_b<=10'b1011001100;packet_g<=10'b0100110011;packet_r<=10'b1011001100;end
   if(island_pre)begin packet_g<=control_word(1);packet_r<=control_word(1);end
   if(island_guard)begin packet_b<=terc_word({2'b11,vs,hs});packet_g<=10'b0100110011;packet_r<=10'b0100110011;end
   if(island_data)begin
    packet_b<=terc_word({1'b1,HEADER_BCH[k],vs,hs});
    packet_g<=terc_word(even_nibble);packet_r<=terc_word(odd_nibble);
   end
  end
 assign out_b=override_r?packet_b:video_b;
 assign out_g=override_r?packet_g:video_g;
 assign out_r=override_r?packet_r:video_r;
endmodule
