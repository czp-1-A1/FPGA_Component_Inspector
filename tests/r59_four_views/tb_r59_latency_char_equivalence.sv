`timescale 1ns/1ps
module tb_r59_latency_char_equivalence;
reg clk=0,rst=0;always #5 clk=~clk;
reg latency_new=0,latency_valid_s=0;reg [19:0] latency_bcd_s=0;reg [11:0] lag_bcd_s=0;reg [39:0] source_bcd_s=0;
compact_inspector_osd #(.MEASURE_LATENCY(1),.ESSENTIAL_UI(1),.DUAL_REGION_COUNT(1)) dut(
 .clk(clk),.rst_n(rst),.vs(1'b0),.hs(1'b0),.de(1'b0),.rgb(24'd0),.page(1'b0),
 .latency_new(latency_new),.latency_valid(latency_valid_s),.latency_bcd(latency_bcd_s),.lag_bcd(lag_bcd_s),.source_bcd(source_bcd_s));
function [7:0] reference_char;
 input [4:0] char_pos;input source_line;reg [175:0] message;reg [3:0] digit;
 begin
  message=source_line ? "SRC                   " : "LAT ----.-ms  LAG ---f";
  reference_char=char_pos<22 ? message[(21-char_pos)*8+:8] : 8'd32;digit=0;
  if(source_line && char_pos>=4 && char_pos<14)begin
   digit=(source_bcd_s>>((13-char_pos)*4))&4'hf;reference_char=latency_valid_s ? "0"+digit : "-";
  end else if(!source_line && ((char_pos>=4 && char_pos<=7) || char_pos==9))begin
   digit=char_pos==9 ? latency_bcd_s[3:0] : (latency_bcd_s>>((8-char_pos)*4))&4'hf;
   reference_char=latency_valid_s ? "0"+digit : "-";
  end else if(!source_line && char_pos>=18 && char_pos<=20)begin
   digit=(lag_bcd_s>>((20-char_pos)*4))&4'hf;reference_char=latency_valid_s ? "0"+digit : "-";
  end
 end
endfunction
integer checks=0,seed=32'h15795232;
task compare;
 begin
  latency_new=1;@(posedge clk);#1;
  for(integer line=0;line<2;line++)for(integer pos=0;pos<32;pos++)begin
   if(dut.latency_char(5'(pos),1'(line))!==reference_char(5'(pos),1'(line)))
    $fatal(1,"character mismatch pos%0d line%0d valid%b digits%h/%h/%h",pos,line,latency_valid_s,source_bcd_s,latency_bcd_s,lag_bcd_s);
   checks++;
  end
  @(negedge clk);latency_new=0;
 end
endtask
initial begin
 repeat(4)@(negedge clk);rst=1;repeat(3)@(negedge clk);
 for(integer i=0;i<2500;i++)begin
  source_bcd_s={$random(seed),$random(seed)};latency_bcd_s=$random(seed);lag_bcd_s=$random(seed);latency_valid_s=i%3!=0;compare;
 end
 for(integer n=0;n<18;n++)for(integer d=0;d<16;d++)for(integer v=0;v<2;v++)begin
  source_bcd_s=0;latency_bcd_s=0;lag_bcd_s=0;latency_valid_s=1'(v);
  if(n<10)source_bcd_s[n*4+:4]=4'(d);else if(n<15)latency_bcd_s[(n-10)*4+:4]=4'(d);else lag_bcd_s[(n-15)*4+:4]=4'(d);
  compare;
 end
 if(checks!=196864)$fatal(1,"character miter coverage count%0d",checks);
 $display("PASS R59_LATENCY_CHAR_EQUIVALENCE: %0d exact character outputs; all32 positions, both lines, valid/invalid, every nibble/value plus deterministic independent random fields",checks);$finish;
end
endmodule
