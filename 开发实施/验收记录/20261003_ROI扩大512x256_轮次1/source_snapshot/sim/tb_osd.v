`timescale 1ns/1ps
module tb_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,sv=1;
reg [23:0] rgb=24'h556677;
always #5 clk=~clk;
wire ov,oh,od;wire [23:0] color;
experiment_osd dut(.clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(rgb),
 .exposure(16'd1460),.gain(16'd48),.roi_valid(sv),.roi_mean(8'd102),.roi_min(8'd20),.roi_max(8'd240),
 .width(16'd1024),.height(16'd600),.fps(16'd30),.lane_errors(16'd1),.format_errors(16'd2),
 .i2c_errors(16'd3),.gaps(16'd4),.frames(32'h1234abcd),.uptime(32'd1800),.cfg_done(1'b1),
 .out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(color));
integer f=0,x,y,output_x=0,output_y=0;
initial begin
 repeat(3) @(negedge clk);rst=1;vs=1;repeat(25) @(negedge clk);vs=0;
 if(dut.exp_bcd!=20'h01460 || dut.gain_bcd!=20'h00048 || dut.mean_bcd!=20'h00102 || dut.min_bcd!=20'h00020 || dut.max_bcd!=20'h00240) $fatal(1,"BCD");
 f=$fopen("osd.ppm","w");$fwrite(f,"P3\n1024 600\n255\n");
 for(y=0;y<600;y=y+1) begin
  de=1;for(x=0;x<1024;x=x+1) @(negedge clk);
  de=0;repeat(20) @(negedge clk);
 end
 repeat(3) @(negedge clk);$fclose(f);f=0;
 sv=0;vs=1;repeat(25) @(negedge clk);vs=0;
 if(dut.sample_s) $fatal(1,"WAIT status not latched");
 $display("PASS OSD decimal fields and rendered output: ROI gray/border/outside and WAIT");$finish;
end
always @(negedge clk) if(od && f!=0) begin
 if(output_y>=32 && !(output_y>=560 && output_y<592)) begin
  if(output_x>=256 && output_x<768 && output_y>=172 && output_y<428) begin
   if(output_x==256 || output_x==767 || output_y==172 || output_y==427) begin
    if(color!=24'h00ff40) $fatal(1,"ROI border coordinate x=%0d y=%0d",output_x,output_y);
   end else if(color!=24'h666666) $fatal(1,"ROI grayscale math");
  end else if(color!=24'h556677) $fatal(1,"video outside ROI changed");
 end
 $fwrite(f,"%d %d %d\n",color[23:16],color[15:8],color[7:0]);
 if(output_x==1023) begin output_x=0;output_y=output_y+1;end else output_x=output_x+1;
end
endmodule
