`timescale 1ns/1ps
module tb_tail_clock;
reg clk=0, run_clk=1, rst=0, pv=0, sof=0, eol=0, early=0;
reg [95:0] rgb=0;
always #5 if(run_clk) clk=~clk;
wire ov,ol,oe;wire [95:0] oc;wire [10:0] ox;wire [9:0] oy;
wire packed_valid,packed_sof; wire [127:0] packed_data;
roi_sobel_view #(.WIDTH(1024),.HEIGHT(8),.X0(256),.X1(768),.Y0(1),.Y1(7),.CORE_X0(472),.CORE_X1(552),.CORE_Y0(2),.CORE_Y1(6)) dut(
.clk(clk),.rst_n(rst),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(eol),.early_sof(early),.rgb(rgb),.mode(2'd0),.invalidate(1'b0),.out_valid(ov),.out_last(ol),.out_early_sof(oe),.out_rgb(oc),.out_x(ox),.out_y(oy),.core_pixels(),.edge_count(),.edge_sum());
data_96bit_to_128bit pack(clk,rst,oe,ov,oc,packed_sof,packed_valid,packed_data);
integer beats[1:3];integer words[1:3];integer ci=0,ec=0;
integer id,l;
always @(posedge clk) if(rst) begin
 ci=ci+1;
 if(ov) begin id=oc[95:88];if(id>=1 && id<=3) beats[id]=beats[id]+1;end
 if(packed_valid) begin id=packed_data[127:120];if(id>=1 && id<=3) words[id]=words[id]+1;end
 if(packed_sof) begin ec=ec+1;$display("OBS early epoch=%0d CSIclock=%0d output_old=%0d,%0d,%0d",ec,ci,beats[1],beats[2],beats[3]);end
end
task ticks;input integer n;begin repeat(n) @(negedge clk);end endtask
task pulse_early;begin early=1;ticks(1);early=0;end endtask
task pixels;input integer fid;integer y,b;
begin
 for(y=0;y<8;y=y+1) begin
  for(b=0;b<256;b=b+1) begin
   pv=1;sof=(y==0&&b==0);eol=(b==255);rgb={12{8'(fid)}};ticks(1);
  end
  pv=0;sof=0;eol=0;if(y!=7) ticks(200);
 end
end endtask
initial begin
 for(l=1;l<=3;l=l+1) begin beats[l]=0;words[l]=0;end
 ticks(10);rst=1;ticks(10);
 pulse_early;ticks(100);pixels(1);ticks(600);
 $display("OBS control measured beats=%0d words=%0d read_y=%0d ready=%0d",beats[1],words[1],dut.read_y,dut.ready_rows);if(beats[1]!=2048 || words[1]!=1536) $fatal(1,"continuous clock control failed");
 $display("OBS control complete frame pixels=%0d packed=%0d",beats[1]*4,words[1]);
 pulse_early;ticks(100);pixels(2);ticks(40);
 $display("OBS stop CSI after last row +40 clocks: frame2 pixels=%0d packed=%0d read_y=%0d read_group=%0d",beats[2]*4,words[2],dut.read_y,dut.read_group);
 run_clk=0;#1000000;
 $display("OBS wall blank 1ms did not advance frame2: pixels=%0d packed=%0d",beats[2]*4,words[2]);
 run_clk=1;ticks(1);pulse_early;ticks(100);
 $display("OBS new pixel SOF preempts old tail: before SOF frame2 pixels=%0d packed=%0d read_y=%0d read_group=%0d",beats[2]*4,words[2],dut.read_y,dut.read_group);
 pixels(3);ticks(600);
 $display("OBS final frame2 pixels=%0d/8192 packed=%0d/1536; frame3 pixels=%0d/8192 packed=%0d/1536",beats[2]*4,words[2],beats[3]*4,words[3]);
 if(beats[2]>=2048) $fatal(1,"hypothesis was not reproduced");
 if(beats[3]!=2048 || words[3]!=1536) $fatal(1,"new frame did not recover");
 $display("PASS diagnostic tail interruption reproduced; conditional CSI clock-stop/early-next-SOF stimulus, not board confirmation");$finish;
end
initial begin #3000000;$fatal(1,"watchdog");end
endmodule


