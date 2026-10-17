`timescale 1ns/1ps
module tb_raw_timing_probe;
reg clk=0,run_clk=1,rst=0,fs=0,rv=0;reg [39:0] raw=0;
always #4.444 if(run_clk)clk=~clk;
wire v,u,l;wire [39:0] data;
uial2axis #(.IMG_WIDTH(1920),.IMG_HEIGHT(56),.INPUT_DATA_WIDTH(40)) input_axis(clk,rst,raw,rv,fs,1'b0,v,data,u,l);
wire dv,du,dl;wire [127:0] drgb;wire [95:0] rgb;
demosaic #(.IMG_WIDTH(1920),.IMG_HEIGHT(56),.data_complete_delay(50),.BAYER_MODE("BGGR")) demosaic_dut(
 .I_clk(clk),.I_rst_n(rst),.axi4s_video_tdata(data),.axi4s_video_tdest(10'd0),.axi4s_video_tlast(l),
 .axi4s_video_tvalid(v),.axi4s_video_tuser(u),.axi4s_video_tready(),.O_tlast(dl),.O_tuser(du),.O_tdata(drgb),.O_tvalid(dv),.O_tready(1'b1));
data128_96 unpacker(drgb,rgb);
reg [127:0] reference[0:26879];integer epoch=0,n=0,diffs=0,first_changed=-1,last_changed=-1;
always @(posedge clk)if(rst)begin
 if(du)begin epoch++;n=0;end
 if(dv)begin
  if(n>=26880)$fatal(1,"extra demosaic pixels epoch%0d",epoch);
  if(epoch==2)reference[n]=drgb;
  if(epoch==3 && drgb!==reference[n])begin
   if(diffs<12)$display("PROBE_DIFF x%0d y%0d got%h ref%h",n%480*4,n/480,drgb,reference[n]);
   if(first_changed<0)first_changed=n;last_changed=n;diffs++;
  end
  n++;
 end
end
function integer source(input integer x,y);source=160+((x*3+y*5)%128);endfunction
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
integer row,beat,lane;
task frame(input integer schedule);begin
 fs=1;ticks(1);fs=0;ticks(64);
 for(row=0;row<56;row++)begin
  ticks(3);
  for(beat=0;beat<480;beat++)begin
   rv=1;for(lane=0;lane<4;lane++)raw[39-lane*10-:10]=10'(source(beat*4+lane,row));
   ticks(1);rv=0;ticks(schedule==0 ? (beat%4==3 ? 3 : 1) : ((beat+row)%7==0 ? 6 : 1));
  end
  ticks(98+row%5);if(row!=55)begin run_clk=0;#12000;run_clk=1;end
 end
 ticks(500);run_clk=0;#2000000;run_clk=1;ticks(50);
 $display("PROBE frame%0d outputs%0d diffs%0d first%0d last%0d",epoch,n,diffs,first_changed,last_changed);
end endtask
initial begin
 ticks(8);rst=1;ticks(30);frame(0);frame(0);frame(1);
 if(diffs!=0)$fatal(1,"RAW timing probe reproduced demosaic pixel dependence: %0d groups",diffs);
 $display("PASS raw timing probe: fixed source rows invariant");$finish;
end
initial begin #30000000;$fatal(1,"RAW probe watchdog");end
endmodule
