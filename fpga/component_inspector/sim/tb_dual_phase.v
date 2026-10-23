`timescale 1ns/1ps
// Exploratory actual-pixel experiment. These are controlled generated
// fixtures, not recovered sensor frames from the user's phone videos.
module tb_dual_phase;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,fs=0,sof=0,accept=0;reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
wire ready;wire [607:0] objects;wire [31:0] probe;
frame_shape_search #(.WIDTH(256),.HEIGHT(240),.REGIONS(1),.COUNT_EMPTY_MARGIN(1),
 .ROW_GUARDED_BRIGHT_EMPTY(1),.COUNT_CANDIDATES(1),.MULTITHRESHOLD_EMPTY(1),.EMPTY_DIAGNOSTICS(1)) dut(
 .clk(clk),.rst_n(rst_n),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(1'b0),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.recorder_objects(objects),.empty_probe(probe),
 .recorder_hold_valid(1'b0),.recorder_hold_x(11'd0),.recorder_hold_y(10'd0));
localparam [59:0] expected=60'h37fffa7fff04aff;
integer scenario=0,bright=90,radius=0,xp=0,yp=0,px,py,l,v,cycles,e,p,feed_error,accepted=0;
function integer base(input integer xx,yy);
 integer a,b;begin a=xx-108;b=yy-108;
 base=a>=0 && a<10 && b>=0 && b<10 && !((a/2==0 || a/2==4) && (b/2==0 || b/2==4));end
endfunction
function integer image(input integer xx,yy);
 integer coverage,k,a,b;begin
  coverage=0;for(k=-radius;k<=radius;k++)coverage+=base(xx-xp+k,yy-yp);
  image=30+(bright-30)*coverage/(2*radius+1);
  // Fixed body and full-size feed contour; the EMPTY alone is phase-shifted
  // and convolved with a horizontal box exposure kernel.
  if(xx>=146 && xx<182 && yy>=90 && yy<134)image=180;
  a=xx-84;b=yy-82;
  if(a>=0 && a<16 && b>=0 && b<16 && !((a<4 || a>=12) && (b<4 || b>=12)))image=90;
 end
endfunction
task ticks(input integer n);repeat(n)@(negedge clk);endtask
always @(posedge clk)if(dut.phase==14 && dut.small_pass && dut.center_x>=100 && dut.center_x<=130 && dut.center_y>=100 && dut.center_y<=128)
 $display("MEASURE case%0d wh%0d,%0d fg%0d shape%0d geom%0d bright%0d row%0d kind%0d",
 scenario,dut.width_now,dut.height_now,dut.component_count,dut.circular,dut.empty_geometry,dut.bright_count,dut.empty_row_delta,dut.candidate_state);
initial begin
 ticks(5);rst_n=1;ticks(3);
 for(scenario=0;scenario<60;scenario++)begin
  bright=scenario/20==0?90:scenario/20==1?110:150;radius=(scenario%20)/4;yp=(scenario%4)/2;xp=scenario%2;
  fs=1;ticks(1);fs=0;ticks(3);
  for(py=0;py<240;py++)begin
   for(px=0;px<256;px+=4)begin
    x=px;y=py;accept=1;sof=px==0 && py==0;
    for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
    ticks(1);accept=0;sof=0;
   end
   ticks(2);
  end
  ticks(5);cycles=0;while(!ready && cycles<250000)begin ticks(1);cycles++;end
  if(!ready)$fatal(1,"classifier frame deadline case%0d",scenario);
  e=0;p=0;feed_error=0;
  for(integer j=0;j<8;j++)if(objects[j*76+75])begin
   if(objects[j*76+73+:2]==2)p++;
   if(objects[j*76+73+:2]==3)begin
    e++;if((objects[j*76+19-:10]+objects[j*76+:10])/2<100)feed_error++;
   end
  end
  if(p!=1 || feed_error!=0 || e!=expected[scenario])$fatal(1,"independent pixel reference case%0d E%0d expected%0d P%0d feed%0d",scenario,e,expected[scenario],p,feed_error);
  accepted+=e;
  $display("RESULT case%0d intensity%0d kernel%0d phase%0d,%0d P%0d E%0d probe%08h",scenario,bright,2*radius+1,xp,yp,p,e,probe);
 end
 $display("PASS dual phase 60 actual PPC4 fixtures match independent 2x2 reference; P retained60; feed not counted; E accepted%0d",accepted);
 $finish;
end
initial begin #250000000;$fatal(1,"global phase watchdog");end
endmodule
