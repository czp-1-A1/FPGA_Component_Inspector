`timescale 1ns/1ps
module tb_manual_wb;
reg clk=0,rst=0,valid=0,sof=0,last=0,ready=1;
always #5 clk=~clk;
reg [31:0] request=32'h00004040;
reg [95:0] rgb=0;wire [95:0] out_rgb;wire ov,os,ol,op,ir;
wire [31:0] active;
awb #(.IMG_WIDTH(1024),.IMG_HEIGHT(600),.MANUAL_GAIN(1)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_tdata(rgb),.I_tvalid(valid),.I_tlast(last),.I_tuser(sof),.I_tready(ir),
 .O_tdata(out_rgb),.O_tvalid(ov),.O_tuser(os),.O_tlast(ol),.O_pixel_sof(op),.O_tready(ready),
 .I_wb_request(request),.O_wb_active(active));
reg [95:0] reference[0:2047];reg [31:0] expected_tag=32'h00004040;
integer sent=0,received=0,rows=0,firsts=0,frame_no=0,blocked=0;
integer lane,r,g,b,rr,bb,row,beat;
reg checking=0;
function [95:0] corrected;
 input [95:0] value;input [31:0] gains;
 integer k,r1,b1;
 begin
  for(k=0;k<4;k=k+1)begin
   r1=value[95-k*24-:8]*gains[15:8]/64;
   b1=value[79-k*24-:8]*gains[7:0]/64;
   corrected[95-k*24-:24]={8'(r1>255?255:r1),value[87-k*24-:8],8'(b1>255?255:b1)};
  end
 end
endfunction
always @(posedge clk)begin
 if(rst && checking && valid)begin reference[sent]=corrected(rgb,expected_tag);sent=sent+1;end
 #1;
 if(rst && checking)begin
  if(ir!==ready || os!==sof)$fatal(1,"manual WB changed ready/early SOF");
  if(ov)begin
   if(received>=sent || out_rgb!==reference[received])$fatal(1,"manual WB arithmetic/lane/first-beat frame=%0d beat=%0d got=%h expected=%h",frame_no,received,out_rgb,reference[received]);
   if(active!==expected_tag)$fatal(1,"mid-frame active gain changed %h expected %h",active,expected_tag);
   if(!ready)blocked=blocked+1;
   received=received+1;
  end
  if(op)firsts=firsts+1;
  if(ol)begin rows=rows+1;if(!ov || received%256!=0)$fatal(1,"manual WB EOL");end
 end
end
task ticks;input integer n;begin repeat(n)@(negedge clk);end endtask
task frame;input [31:0] gain;input integer change;
 begin
  frame_no=frame_no+1;expected_tag=gain;request=gain;
  sent=0;received=0;rows=0;firsts=0;blocked=0;checking=1;
  for(row=0;row<4;row=row+1)begin
   for(beat=0;beat<256;beat=beat+1)begin
    if(beat==19)begin valid=0;sof=0;last=0;ticks(3);end
    for(lane=0;lane<4;lane=lane+1)begin
     r=(beat*7+lane*47+row*13)%256;g=(beat*3+lane*11)%256;b=(beat*5+lane*23+row*29)%256;
     rgb[95-lane*24-:24]={8'(r),8'(g),8'(b)};
    end
    // Deliberately change requests before first delayed output and mid-frame.
    if(change && row==0 && beat==5)request=32'h0009c020;
    if(change && row==1 && beat==110)request=32'h000ac0c0;
    valid=1;sof=(row==0 && beat==0);last=beat==255;ready=!(beat>=100 && beat<140);ticks(1);
   end
   valid=0;sof=0;last=0;ready=1;ticks(100);
  end
  ticks(30);
  if(sent!=1024 || received!=1024 || rows!=4 || firsts!=1 || blocked==0)$fatal(1,"manual WB frame coverage");
 end
endtask
initial begin
 ticks(16);rst=1;ticks(16);
 frame(32'h00004040,1);frame(32'h00016020,1);frame(32'h000220c0,0);frame(32'h0003c0c0,0);
 checking=0;rst=0;ticks(5);if(active!==32'h00004040)$fatal(1,"manual WB reset active");
 rst=1;ticks(16);frame(32'h00004040,0);
 $display("PASS manual WB: independent Q2.6 arithmetic/clipping, four lanes, first pixel, bubbles, ready-low, EOL, pending requests held until next frame and reset");$finish;
end
initial begin #100000;$fatal(1,"manual WB watchdog");end
endmodule
