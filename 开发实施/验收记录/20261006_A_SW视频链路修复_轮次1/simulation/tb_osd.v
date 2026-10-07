`timescale 1ns/1ps
module tb_osd;
reg clk=0,rst=0,vs=0,hs=0,de=0,sv=1,cfg=1;
reg [15:0] ex=1460,ga=48,rate=30;
reg [23:0] rgb=24'h556677;
reg [1:0] class_state=0;
reg [1:0] view=0;reg [12:0] ec=12;reg [23:0] es=345;
always #5 clk=~clk;
wire ov,oh,od,bv,bh,bd;wire [23:0] color,bypass_color;
experiment_osd dut(.clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(rgb),
 .overflow_frames(16'h12),.lost_frames(16'h34),.underflow_frames(16'h56),
 .exposure(ex),.gain(ga),.view_mode(view),.edge_count(ec),.edge_sum(es),.roi_valid(sv),.roi_state(class_state),.roi_mean(8'd102),.roi_min(8'd20),.roi_max(8'd240),
 .width(16'd1024),.height(16'd600),.fps(rate),.lane_errors(16'd1),.format_errors(16'd2),
 .i2c_errors(16'd3),.gaps(16'd4),.frames(32'h1234abcd),.uptime(32'd1800),.cfg_done(cfg),
 .out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(color));
experiment_osd #(.ENABLE(0)) bypass(.clk(clk),.rst_n(rst),.vs(vs),.hs(hs),.de(de),.rgb(rgb),
 .overflow_frames(16'h12),.lost_frames(16'h34),.underflow_frames(16'h56),
 .exposure(ex),.gain(ga),.view_mode(2'd0),.edge_count(13'd12),.edge_sum(24'd345),.roi_valid(sv),.roi_state(class_state),.roi_mean(8'd102),.roi_min(8'd20),.roi_max(8'd240),
 .width(16'd1024),.height(16'd600),.fps(rate),.lane_errors(16'd1),.format_errors(16'd2),
 .i2c_errors(16'd3),.gaps(16'd4),.frames(32'h1234abcd),.uptime(32'd1800),.cfg_done(cfg),
 .out_vs(bv),.out_hs(bh),.out_de(bd),.out_rgb(bypass_color));
reg [2:0] vs_q=0,hs_q=0,de_q=0;
reg [23:0] rgb_q0=0,rgb_q1=0,rgb_q2=0;
always @(posedge clk) begin
 if(!rst) begin vs_q<=0;hs_q<=0;de_q<=0;rgb_q0<=0;rgb_q1<=0;rgb_q2<=0;end
 else begin vs_q<={vs_q[1:0],vs};hs_q<={hs_q[1:0],hs};de_q<={de_q[1:0],de};rgb_q0<=rgb;rgb_q1<=rgb_q0;rgb_q2<=rgb_q1;end
 #1;
 if({ov,oh,od}!=={vs_q[2],hs_q[2],de_q[2]} || {bv,bh,bd}!=={vs_q[2],hs_q[2],de_q[2]}) $fatal(1,"three-clock sync latency");
 if(bypass_color!==rgb_q2) $fatal(1,"ENABLE bypass RGB latency");
end
reg [23:0] reference [0:614399];
reg [23:0] panel_reference [0:98303];
reg panel_test=0;
integer f=0,x,y,n=0;
task frame_start;begin vs=1;repeat(25) @(negedge clk);vs=0;end endtask
task check_mode;input integer index;
begin
 view=index;ec=12;es=345;sv=1;cfg=1;rate=30;class_state=0;ex=1460;ga=48;frame_start;
 view=index^3;ec=6400;es=24'hffffff;
 $readmemh($sformatf("osd_assets/mode_%0d.hex",index),reference);
 n=0;f=$fopen($sformatf("osd_mode_%0d.ppm",index),"w");$fwrite(f,"P3\n1024 600\n255\n");
 for(y=0;y<600;y=y+1) begin
  de=1;hs=1;for(x=0;x<1024;x=x+1) @(negedge clk);
  de=0;hs=0;repeat(20) @(negedge clk);
 end
 repeat(4) @(negedge clk);$fclose(f);f=0;
 if(n!=614400) $fatal(1,"mode raster pixel count");
end endtask
task check_state;input integer index;input [1:0] value;input valid_value,config_value;input [15:0] fps_value;
input [1:0] expected,reason;
begin
 class_state=value;sv=valid_value;cfg=config_value;rate=fps_value;frame_start;
 if(dut.class_s!==expected || dut.reason_s!==reason || dut.sample_s!==(valid_value && config_value && fps_value!=0)) $fatal(1,"state priority");
 class_state=value^2'b11;
 repeat(5) @(negedge clk);
 if(dut.class_s!==expected) $fatal(1,"state changed inside display frame");
 $readmemh($sformatf("osd_assets/state_%0d.hex",index),panel_reference);
 force dut.y=504;@(negedge clk);release dut.y;
 n=0;panel_test=1;f=$fopen($sformatf("osd_state_%0d.ppm",index),"w");$fwrite(f,"P3\n1024 96\n255\n");
 for(y=0;y<96;y=y+1) begin
  de=1;hs=1;for(x=0;x<1024;x=x+1) @(negedge clk);
  de=0;hs=0;repeat(20) @(negedge clk);
 end
 repeat(4) @(negedge clk);$fclose(f);f=0;panel_test=0;
 if(n!=98304) $fatal(1,"state panel pixel count");
end endtask
initial begin
 $readmemh("osd_assets/reference.hex",reference);
 repeat(3) @(negedge clk);rst=1;frame_start;
 if(dut.exp_bcd!=20'h01460 || dut.gain_bcd!=20'h00048 || dut.mean_bcd!=20'h00102 || dut.min_bcd!=20'h00020 || dut.max_bcd!=20'h00240) $fatal(1,"BCD");
 class_state=3;sv=0;ex=65535;ga=65535;
 f=$fopen("osd.ppm","w");$fwrite(f,"P3\n1024 600\n255\n");
 for(y=0;y<600;y=y+1) begin
  de=1;hs=1;for(x=0;x<1024;x=x+1) @(negedge clk);
  de=0;hs=0;repeat(20) @(negedge clk);
 end
 repeat(4) @(negedge clk);$fclose(f);f=0;
 if(n!=614400) $fatal(1,"raster pixel count %d",n);
 check_state(0,0,1,1,30,0,3);check_state(1,1,0,1,30,1,2);
 check_state(2,2,1,1,30,2,3);check_state(3,3,1,1,30,3,3);
 view=3;check_state(4,2,1,0,30,1,0);check_state(5,3,1,1,0,1,1);
 if(dut.exp_bcd!==20'h65535 || dut.gain_bcd!==20'h65535) $fatal(1,"maximum parameters");
 if(dut.decimal(20'h00000,4)!==7'd48 || dut.decimal(20'h00000,0)!==7'd32 || dut.decimal(20'h65535,0)!==7'd54) $fatal(1,"trim leading zeros");
 check_mode(0);check_mode(1);check_mode(2);check_mode(3);
 $display("PASS OSD decimal fields: independent 614400-pixel reference, Chinese/fonts/Logo, recent states, invalid priority, three-clock RGB/sync/bypass, maximum values and frame snapshot");$finish;
end
always @(negedge clk) if(od && f!=0) begin
 if(panel_test) begin
  if(n>=98304 || color!==panel_reference[n]) $fatal(1,"state raster x=%0d y=%0d actual=%h reference=%h",n%1024,n/1024,color,panel_reference[n]);
 end else if(n>=614400 || color!==reference[n]) $fatal(1,"raster x=%0d y=%0d actual=%h reference=%h",n%1024,n/1024,color,reference[n]);
 $fwrite(f,"%d %d %d\n",color[23:16],color[15:8],color[7:0]);n=n+1;
end
endmodule
