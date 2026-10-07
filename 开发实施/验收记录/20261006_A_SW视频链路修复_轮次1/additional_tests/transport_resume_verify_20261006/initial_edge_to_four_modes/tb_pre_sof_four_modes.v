`timescale 1ns/1ps
// Independent video/packer contract test. DUT RTL is compiled from the project.
module tb_pre_sof_four_modes;
localparam W=1024,H=8,N=W*H,BITS=N*24;
reg clk=0,run_clk=1,rst=0,pv=0,sof=0,last=0,early=0,invalid=0,ready=1;
reg [95:0] rgb=0;reg [1:0] mode=0;
always #5 if(run_clk) clk=~clk;
wire ov,ol,oe,fb;wire [95:0] color;wire [10:0] ox;wire [9:0] oy;
wire [12:0] cp,ec;wire [23:0] es;
roi_sobel_view #(.WIDTH(W),.HEIGHT(H),.X0(3),.X1(W-3),.Y0(1),.Y1(7),
 .CORE_X0(9),.CORE_X1(19),.CORE_Y0(2),.CORE_Y1(6)) dut(
 .clk(clk),.rst_n(rst),.pixel_valid(pv),.pixel_sof(sof),.pixel_last(last),.early_sof(early),
 .rgb(rgb),.mode(mode),.invalidate(invalid),.view_ready(ready),.frame_bad(fb),
 .out_valid(ov),.out_last(ol),.out_early_sof(oe),.out_rgb(color),.out_x(ox),.out_y(oy),
 .core_pixels(cp),.edge_count(ec),.edge_sum(es));
wire packed_valid,packed_sof;wire [127:0] packed_data;
data_96bit_to_128bit pack(clk,rst,oe,ov,color,packed_sof,packed_valid,packed_data);
reg [23:0] original[0:N-1],expected[0:N-1];integer luma[0:N-1];reg [BITS-1:0] stream;
integer seen=0,words=0,early_count=0,number=0,ref_edges=0,ref_sum=0,frame_view=0;
reg checking=0,strict=1,in_line=0,accept_bad=0;
reg sampled_pv,sampled_last;
always @(posedge clk) begin sampled_pv<=pv;sampled_last<=last;end
task ticks;input integer n;begin repeat(n) @(negedge clk);#1;end endtask
function [23:0] pixel;input integer x,y,id;integer r,g,b;
 begin r=(x*17+y*37+id*7)&255;g=(x*29+y*11+id*13)&255;b=(x*7+y*19+id*23)&255;pixel={8'(r),8'(g),8'(b)};end
endfunction
task reference;input integer id;integer x,y,i,j,k,gx,gy,mag,r,g,b;
 begin
  ref_edges=0;ref_sum=0;
  for(y=0;y<H;y=y+1) for(x=0;x<W;x=x+1) begin
   i=y*W+x;original[i]=pixel(x,y,id);r=original[i][23:16];g=original[i][15:8];b=original[i][7:0];luma[i]=(r+2*g+b)/4;
  end
  for(y=0;y<H;y=y+1) for(x=0;x<W;x=x+1) begin
   i=y*W+x;mag=0;
   if(x>3 && x<W-4 && y>1 && y<6) begin
    gx=0;gy=0;
    for(j=-1;j<=1;j=j+1) for(k=-1;k<=1;k=k+1) begin
     gx=gx+k*(j==0 ? 2 : 1)*luma[(y+j)*W+x+k];
     gy=gy+j*(k==0 ? 2 : 1)*luma[(y+j)*W+x+k];
    end
    mag=(gx<0 ? -gx : gx)+(gy<0 ? -gy : gy);
   end
   if(x>=9 && x<19 && y>=2 && y<6) begin ref_sum=ref_sum+mag;if(mag>=80) ref_edges=ref_edges+1;end
   expected[i]=original[i];
   if(x>=3 && x<W-3 && y>=1 && y<7 && (frame_view&1)) expected[i]={3{8'(luma[i])}};
   if(x>3 && x<W-4 && y>1 && y<6 && (frame_view&2) && mag>=80) expected[i]=24'hffae64;
   stream[BITS-1-i*24-:24]=expected[i];
  end
 end
endtask
always @(negedge clk) if(checking) begin
 if(oe) early_count=early_count+1;
 if(ov) begin
  if(fb && !accept_bad) $fatal(1,"bad frame still emits RGB frame=%0d",number);
  if(seen>=N || ox!=seen%W || oy!=seen/W || ol!=(seen%W==W-4)) $fatal(1,"RGB coordinates frame=%0d seen=%0d xy=%0d,%0d",number,seen,ox,oy);
  for(integer n=0;n<4;n=n+1) if(color[95-n*24-:24]!==expected[seen+n])
   $fatal(1,"RGB content frame=%0d mode=%0d pixel=%0d actual=%h expected=%h",number,frame_view,seen+n,color[95-n*24-:24],expected[seen+n]);
  seen=seen+4;in_line=!ol;
 end else if(in_line && strict && frame_view>=2) $fatal(1,"edge line was interrupted inside admitted row frame=%0d",number);
 if(strict && frame_view<2 && (ov!==sampled_pv || (ov && ol!==sampled_last))) $fatal(1,"AWB bypass timing changed mode=%0d",frame_view);
 if(packed_valid) begin
  if(words>=BITS/128 || packed_data!==stream[BITS-1-words*128-:128]) $fatal(1,"packed content frame=%0d word=%0d actual=%h expected=%h",number,words,packed_data,stream[BITS-1-words*128-:128]);
  words=words+1;
 end
end
task start_frame;input integer view,id;
 begin
  checking=0;pv=0;sof=0;last=0;early=0;invalid=0;ticks(4);
  number=number+1;frame_view=view;mode=2'(view);reference(id);
  seen=0;words=0;early_count=0;in_line=0;strict=1;accept_bad=0;checking=1;
  early=1;ticks(1);early=0;ticks(50);
  if(fb) $fatal(1,"previous cache error survived new early frame boundary");
 end
endtask
task send_rows;input integer bubbles,short_hold,switch_mid;integer x,y;
 begin
  for(y=0;y<H;y=y+1) begin
   for(x=0;x<W;x=x+4) begin
    if(switch_mid && y==3 && x==0) mode=2'(frame_view^3);
    rgb={original[y*W+x],original[y*W+x+1],original[y*W+x+2],original[y*W+x+3]};
    pv=1;sof=y==0 && x==0;last=x==W-4;ticks(1);pv=0;sof=0;last=0;
    if(bubbles) ticks((x/4+y)%3);
   end
   if(short_hold && y==1) begin ready=0;ticks(40);ready=1;end
   // Ready changes within an already admitted replay row cannot truncate it.
   if(short_hold && y==2) begin ticks(24);ready=0;ticks(80);ready=1;ticks(216);end
   else if(y!=H-1) ticks(320);
  end
 end
endtask
task finish_good;
 begin
  ticks(700);
  if(seen!=N || words!=BITS/128 || early_count!=1 || fb) $fatal(1,"good frame incomplete n=%0d mode=%0d seen=%0d words=%0d early=%0d bad=%b",number,frame_view,seen,words,early_count,fb);
  if(frame_view>=2) begin if(cp!=40 || ec!=ref_edges || es!=ref_sum) $fatal(1,"gradient counts n=%0d cp=%0d ec=%0d/%0d es=%0d/%0d",number,cp,ec,ref_edges,es,ref_sum);end
  else if(cp!=0 || ec!=0 || es!=0) $fatal(1,"bypass retained unused edge statistics");
  $display("PASS good frame=%0d mode=%0d exact pixels=%0d words=%0d gradients=%0d/%0d",number,frame_view,seen,words,ec,es);
  checking=0;ticks(10);
 end
endtask

// Preserve all four bank memories, including bytes outside the upcoming write.
reg [95:0] before0[0:W/4-1],before1[0:W/4-1];
reg [95:0] before2[0:W/4-1],before3[0:W/4-1];
integer saved_group,saved_row,boundary_early,boundary_fs;
task test_stale_preamble;input integer next_mode;
 integer a,s;
 begin
  // Leave a real old EDGE frame with an unfinished replay tail and write_y=H.
  ready=1;start_frame(3,30+next_mode);send_rows(0,0,0);ticks(40);
  if(seen>=N || fb || dut.write_y!=H) $fatal(1,"preamble setup did not leave a healthy old tail mode=%0d seen=%0d row=%0d",next_mode,seen,dut.write_y);
  checking=0;mode=2'(next_mode);pv=0;sof=0;last=0;early=1;ticks(1);
  if(ov || !oe || fb) $fatal(1,"early SOF did not cancel old output mode=%0d",next_mode);
  boundary_early=oe;boundary_fs=0;
  saved_group=dut.write_group;saved_row=dut.write_y;
  for(a=0;a<W/4;a=a+1) begin
   before0[a]=dut.line_bank[0].memory[a];before1[a]=dut.line_bank[1].memory[a];
   before2[a]=dut.line_bank[2].memory[a];before3[a]=dut.line_bank[3].memory[a];
  end
  early=0;
  // Four residual AWB valids precede the first pixel of the new frame. The
  // last marker also exercises the old row-count update path.
  for(s=0;s<4;s=s+1) begin
   pv=1;sof=0;last=(s==3);rgb=96'hdeadbe_c0ffee_123456_abcdef;ticks(1);
   boundary_early=boundary_early+oe;boundary_fs=boundary_fs+packed_sof;
   if(ov || packed_valid || fb || dut.cache_overrun || dut.input_valid || dut.input_armed)
    $fatal(1,"stale valid emitted/packed/armed/poisoned mode=%0d beat=%0d ov=%b packed=%b bad=%b",next_mode,s,ov,packed_valid,fb);
   if(dut.write_group!=saved_group || dut.write_y!=saved_row || dut.ready_rows!=0 || dut.read_y!=0 || dut.reading || pack.S_cnt!=0)
    $fatal(1,"stale valid advanced counters or replay/packer state mode=%0d beat=%0d",next_mode,s);
   if(cp!=0 || ec!=0 || es!=0) $fatal(1,"stale valid retained statistics mode=%0d beat=%0d",next_mode,s);
   for(a=0;a<W/4;a=a+1) begin
    if(dut.line_bank[0].memory[a]!==before0[a] || dut.line_bank[1].memory[a]!==before1[a] ||
       dut.line_bank[2].memory[a]!==before2[a] || dut.line_bank[3].memory[a]!==before3[a])
     $fatal(1,"stale valid wrote bank RAM mode=%0d beat=%0d address=%0d",next_mode,s,a);
   end
  end
  pv=0;last=0;
  repeat(20) begin
   ticks(1);
   boundary_early=boundary_early+oe;boundary_fs=boundary_fs+packed_sof;
   if(ov || packed_valid || fb) $fatal(1,"old tail leaked after stale preamble mode=%0d",next_mode);
  end
  if(boundary_early!=1 || boundary_fs!=1) $fatal(1,"early boundary duplicated/lost mode=%0d early=%0d packed_fs=%0d",next_mode,boundary_early,boundary_fs);
  $display("PASS: PRE_SOF_STALE mode=%0d old_valid_beats=4 ram_unchanged=1 counters_unchanged=1 rgb_words=0 packed_words=0 frame_bad=0 early=1 packed_fs=1",next_mode);
  // The next complete frame must accept its first SOF beat and match every
  // pixel, packed 128-bit word, coordinate and Sobel statistic.
  number=number+1;frame_view=next_mode;reference(50+next_mode);
  seen=0;words=0;early_count=boundary_early;in_line=0;strict=1;accept_bad=0;checking=1;
  send_rows(1,0,1);finish_good;
  $display("PASS: PRE_SOF_RECOVERY mode=%0d exact_pixels=%0d exact_words=%0d frame_bad=0",next_mode,N,BITS/128);
 end
endtask
initial begin
 ticks(4);rst=1;ticks(4);
 for(integer v=0;v<4;v=v+1) test_stale_preamble(v);
 $display("PASS: PRE_SOF_FOUR_MODES modes=4 stale_beats=16 ram_writes=0 old_rgb=0 old_packed=0 recovered_pixels=%0d recovered_words=%0d",4*N,4*BITS/128);
 $finish;
end
initial begin #10000000;$fatal(1,"Pre-SOF four modes watchdog");end
endmodule
