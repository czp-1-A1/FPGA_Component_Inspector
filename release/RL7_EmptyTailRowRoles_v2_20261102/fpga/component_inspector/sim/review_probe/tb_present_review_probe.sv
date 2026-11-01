`timescale 1ns/1ps
module tb_present_review_probe;
reg clk=0,rst_n=0,cancel=0,we=0,measure=0;
reg [10:0] wx=0;reg [9:0] wy=0;reg [31:0] wd=0;
reg [303:0] objects=0;reg [35:0] refs=0;
wire ready;wire [127:0] record;
always #5 clk=~clk;
present_review_probe dut(.clk(clk),.rst_n(rst_n),.cancel(cancel),.write_enable(we),
 .write_x(wx),.write_y(wy),.write_data(wd),.measure(measure),.objects(objects),
 .references(refs),.ready(ready),.record(record));
integer shift=0,checks=0,cycles,row,column,b,lane;
function automatic [75:0] object(input integer cx,cy,w,h,input [3:0] reason);
 object={1'b1,2'd2,reason,13'd1528,7'(w),7'(h),11'(cx-2*(w/4)-2),11'(cx-2*(w/4)+w+2),10'(cy-2*(h/4)-2),10'(cy-2*(h/4)+h+2)};
endfunction
function automatic integer gray(input integer x,y,bank);
 integer cx,cy;
 begin
  cx=640+shift;cy=bank ? 516 : 320;gray=30;
  if(x>=cx-18 && x<cx+18 && y>=cy-22 && y<cy+24)gray=120;
  if(x>=cx-8 && x<cx+8 && y>=cy-8 && y<cy+8)gray=bank ? 100 : 220;
  if(x>=cx-16 && x<cx-8 && y>=cy-8 && y<cy+8)gray=bank ? 120 : 160;
  if(x>=cx+8 && x<cx+16 && y>=cy-8 && y<cy+8)gray=bank ? 140 : 180;
  if(x>=cx-8 && x<cx+8 && y>=cy-16 && y<cy-8)gray=bank ? 160 : 200;
  if(x>=cx-8 && x<cx+8 && y>=cy+8 && y<cy+16)gray=bank ? 180 : 140;
 end
endfunction
task tick;@(negedge clk);endtask
task reset_frame;
 begin cancel=1;tick();cancel=0;tick();end
endtask
task capture(input integer words);
 integer n;
 begin
  for(b=0;b<2;b=b+1)begin
   for(n=0;n<words;n=n+1)begin
    row=n/16;column=n%16;wx=580+column*8;wy=(b ? 468 : 272)+row*2+1;
    for(lane=0;lane<4;lane=lane+1)wd[lane*8+:8]=8'(gray(576+column*8+lane*2,(b ? 468 : 272)+row*2,b));
    we=1;tick();we=0;
   end
  end
  tick();
 end
endtask
task publish;
 begin
  measure=1;tick();measure=0;cycles=0;
  while(!ready && cycles<1500)begin tick();cycles=cycles+1;end
  if(!ready)$fatal(1,"probe did not finish");
 end
endtask
task expect_word(input integer bank,input [63:0] expected);
 begin
  checks=checks+1;
  if(record[bank*64+:64]!==expected)$fatal(1,"bank%0d got%h expected%h",bank,record[bank*64+:64],expected);
 end
endtask
initial begin
 repeat(5)tick();rst_n=1;repeat(3)tick();
 for(integer s=0;s<4;s=s+1)begin
  shift=s*2;reset_frame();capture(768);
  objects={152'd0,object(640+shift,516,36,46,4'hf),76'd0,object(640+shift,320,36,46,4'h8)};
  refs={{1'b1,1'b1,8'hff,8'd7},{1'b0,1'b1,8'd140,8'd149}};
  publish();
  expect_word(0,{1'b1,1'b1,1'b0,4'h8,8'd140,8'd149,1'b0,8'd220,8'd160,8'd180,8'd200,8'd140});
  expect_word(1,{1'b1,1'b1,1'b1,4'hf,8'hff,8'd7,1'b0,8'd100,8'd120,8'd140,8'd160,8'd180});
 end
 // A skinny real body retains its reason but has no claimed inner window.
 reset_frame();capture(768);objects={228'd0,object(640,320,24,36,4'h5)};
 refs={18'd0,1'b0,1'b1,8'd10,8'd20};publish();
 expect_word(0,{1'b1,1'b0,1'b0,4'h5,8'd10,8'd20,1'b0,40'd0});expect_word(1,64'd0);
 // Incomplete cache must not reuse the preceding frame's image values.
 reset_frame();capture(767);objects={228'd0,object(640,320,36,46,4'h8)};
 publish();expect_word(0,{1'b1,1'b0,1'b0,4'h8,8'd10,8'd20,1'b0,40'd0});
 // A missing first slot selects the second slot; snapshot must survive input changes.
 shift=0;reset_frame();capture(768);objects={152'd0,object(640,320,36,46,4'h8),76'd0};
 measure=1;tick();measure=0;objects=0;refs=0;
 cycles=0;while(!ready && cycles<1500)begin tick();cycles=cycles+1;end
 expect_word(0,{1'b1,1'b1,1'b0,4'h8,8'd10,8'd20,1'b0,8'd220,8'd160,8'd180,8'd200,8'd140});
 // Abort an in-flight operation and prove that no delayed completion escapes.
 reset_frame();capture(768);objects={228'd0,object(640,320,36,46,4'h8)};
 refs={18'd0,1'b0,1'b1,8'd10,8'd20};measure=1;tick();measure=0;repeat(12)tick();reset_frame();
 repeat(1300)begin tick();if(ready || record!==0)$fatal(1,"stale publication after cancel");end
 $display("PASS present_review_probe: %0d exact64-bit records, four RAM byte phases, both ROIs, skinny, short capture, fallback slot, snapshot and cancel",checks);$finish;
end
initial begin #10000000;$fatal(1,"watchdog");end
endmodule
