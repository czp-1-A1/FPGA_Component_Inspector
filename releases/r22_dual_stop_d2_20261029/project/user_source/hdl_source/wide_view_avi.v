// 1080i60 RGB AVI, VIC5, once per field. 720p bypass preserves DVI fallback.
// One clock of insertion latency equals dvi_encoder latency.
module wide_view_avi(input wire clk,rst,mode,input wire [11:0] x,
 input wire [10:0] y,input wire hs,vs,
 input wire [9:0] video_b,video_g,video_r,
 output wire [9:0] out_b,out_g,out_r);
 function [9:0] control_word(input [1:0] v);
  begin case(v)
   0:control_word=10'b1101010100;1:control_word=10'b0010101011;
   2:control_word=10'b0101010100;3:control_word=10'b1010101011;
  endcase end
 endfunction
 function [9:0] terc_word(input [3:0] v);
  begin case(v)
   0:terc_word=10'b1010011100;1:terc_word=10'b1001100011;
   2:terc_word=10'b1011100100;3:terc_word=10'b1011100010;
   4:terc_word=10'b0101110001;5:terc_word=10'b0100011110;
   6:terc_word=10'b0110001110;7:terc_word=10'b0100111100;
   8:terc_word=10'b1011001100;9:terc_word=10'b0100111001;
   10:terc_word=10'b0110011100;11:terc_word=10'b1001110001;
   12:terc_word=10'b1010001110;13:terc_word=10'b0101100011;
   14:terc_word=10'b0101100011;15:terc_word=10'b1011000011;
  endcase end
 endfunction
 function [7:0] bch_header(input [23:0] v);
  reg [7:0] s;integer i;
  begin s=0;for(i=0;i<24;i=i+1)s=(s>>1)^((s[0]^v[i])?8'h83:8'h00);bch_header=s;end
 endfunction
 function [7:0] bch_sub(input [55:0] v);
  reg [7:0] s;integer i;
  begin s=0;for(i=0;i<56;i=i+1)s=(s>>1)^((s[0]^v[i])?8'h83:8'h00);bch_sub=s;end
 endfunction
 localparam [23:0] HEADER=24'h0d0282;
 // Checksum4A, RGB,16:9,default quantization,VIC5,no repetition.
 localparam [55:0] SUB0=56'h0000050020004a;
 localparam [31:0] HB={bch_header(HEADER),HEADER};
 localparam [63:0] SB={bch_sub(SUB0),SUB0};
 wire active_line=(y>=11'd20 && y<11'd560) || (y>=11'd583 && y<11'd1123);
 wire packet_line=y==11'd560 || y==11'd1123;
 wire video_pre=mode && active_line && x>=12'd182 && x<12'd190;
 wire video_guard=mode && active_line && x>=12'd190 && x<12'd192;
 wire island_pre=mode && packet_line && x>=12'd2124 && x<12'd2132;
 wire island_guard=mode && packet_line &&
              ((x>=12'd2132 && x<12'd2134) || (x>=12'd2166 && x<12'd2168));
 wire island_data=mode && packet_line && x>=12'd2134 && x<12'd2166;
 wire [4:0] k=x-12'd2134;
 wire [5:0] even_bit={k,1'b0},odd_bit={k,1'b1};
 reg override_r;
 reg [9:0] packet_b,packet_g,packet_r;
 always @(posedge clk or posedge rst)
  if(rst)begin override_r<=1;packet_b<=10'b1101010100;packet_g<=10'b1101010100;packet_r<=10'b1101010100;end
  else begin
   override_r<=video_pre || video_guard || island_pre || island_guard || island_data;
   packet_b<=control_word({vs,hs});packet_g<=control_word(0);packet_r<=control_word(0);
   if(video_pre)packet_g<=control_word(1);
   if(video_guard)begin packet_b<=10'b1011001100;packet_g<=10'b0100110011;packet_r<=10'b1011001100;end
   if(island_pre)begin packet_g<=control_word(1);packet_r<=control_word(1);end
   if(island_guard)begin packet_b<=terc_word({2'b11,vs,hs});packet_g<=10'b0100110011;packet_r<=10'b0100110011;end
   if(island_data)begin
    packet_b<=terc_word({1'b1,HB[k],vs,hs});
    packet_g<=terc_word({3'b000,SB[even_bit]});packet_r<=terc_word({3'b000,SB[odd_bit]});
   end
  end
 assign out_b=override_r?packet_b:video_b;
 assign out_g=override_r?packet_g:video_g;
 assign out_r=override_r?packet_r:video_r;
endmodule
