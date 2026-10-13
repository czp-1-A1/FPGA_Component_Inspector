`timescale 1ns/1ps
module tb_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0; reg [23:0] rgb=24'h556677;
always #5 clk=~clk;
wire ov,oh,od;wire [23:0] color;
experiment_osd dut(clk,rst,vs,hs,de,rgb,16'd2244,16'd48,16'd1024,16'd600,16'd30,
 16'd1,16'd2,16'd3,16'd4,32'h1234abcd,32'd1800,1'b1,ov,oh,od,color);
integer f,x,y;
initial begin
 repeat(3) @(negedge clk);rst=1;vs=1;repeat(25) @(negedge clk);vs=0;
 if(dut.exp_bcd!=20'h02244 || dut.gain_bcd!=20'h00048 || dut.w_bcd!=20'h01024 || dut.h_bcd!=20'h00600 || dut.fps_bcd!=20'h00030) $fatal(1,"BCD");
 f=$fopen("osd.ppm","w");$fwrite(f,"P3\n1024 96\n255\n");
 for(y=0;y<96;y=y+1) begin
  de=1;
  for(x=0;x<1024;x=x+1) @(negedge clk);
  de=0;repeat(20) @(negedge clk);
 end
 $fclose(f);$display("PASS OSD decimal fields and rendered output");$finish;
end
always @(negedge clk) if(od) begin
 if(dut.y>82 && color!=24'h556677) $fatal(1,"video outside overlay changed");
 $fwrite(f,"%d %d %d\n",color[23:16],color[15:8],color[7:0]);
end
endmodule
