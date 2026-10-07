`timescale 1ns/1ps
// Use the actual TD-selected AWB, divider netlist and vendor ERAM.
// The old input pipeline is empty while AWB still replays row 3.
module tb_awb_epoch;
localparam W=1024,H=8,N=W*H,BITS=N*24;
reg clk=0,run_clk=1,rst=0,iv=0,early=0,il=0;
reg [95:0] rgb=0;
reg [1:0] mode=0;
always #5 if(run_clk) clk=~clk;
wire av,as,al,ae,ir;wire [95:0] ac;
awb #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) awb_dut(
 .I_clk(clk),.I_rst_n(rst),.I_tlast(il),.I_tuser(early),
 .I_tdata(rgb),.I_tvalid(iv),.I_tready(ir),.O_tlast(al),
 .O_tuser(ae),.O_pixel_sof(as),.O_tdata(ac),.O_tvalid(av),.O_tready(1'b1));
wire ov,ol,oe,fb;wire [95:0] color;wire [10:0] ox;wire [9:0] oy;
wire [12:0] cp,ec;wire [23:0] es;
roi_sobel_view #(.WIDTH(W),.HEIGHT(H),.X0(3),.X1(W-3),.Y0(1),.Y1(7),
 .CORE_X0(9),.CORE_X1(19),.CORE_Y0(2),.CORE_Y1(6)) view_dut(
 .clk(clk),.rst_n(rst),.pixel_valid(av),.pixel_sof(as),.pixel_last(al),.early_sof(ae),
 .rgb(ac),.mode(mode),.invalidate(1'b0),.view_ready(1'b1),.frame_bad(fb),
 .out_valid(ov),.out_last(ol),.out_early_sof(oe),.out_rgb(color),.out_x(ox),.out_y(oy),
 .core_pixels(cp),.edge_count(ec),.edge_sum(es));
wire packed_valid,packed_sof;wire [127:0] packed_data;
data_96bit_to_128bit pack(clk,rst,oe,ov,color,packed_sof,packed_valid,packed_data);
reg [23:0] expected[0:N-1];integer luma[0:N-1];reg [BITS-1:0] stream;
integer cycle=0,early_cycle=0,sof_cycle=0,first_view_cycle=0;
integer residual=0,leaked_view=0,leaked_words=0,prior_epoch_words=0,new_awb=0,new_awb_rows=0;
integer seen=0,words=0,early_count=0,pixel_sofs=0,failures=0,ref_edges=0,ref_sum=0;
integer trace_file;reg epoch=0,checking=0,new_sof_seen=0,in_line=0,bad_seen=0,pack_epoch=0;
reg sampled_av,sampled_as,sampled_early,sampled_input_valid;
reg [7:0] frozen_group;reg [9:0] frozen_row;reg [95:0] frozen_bank_word;
integer suppressed=0;
function [23:0] pixel;
 input integer x,y,id;integer v;
 begin v=17+((id*7+y*11+x)%173);pixel={3{8'(v)}};end
endfunction
task ticks;input integer n;begin repeat(n) @(negedge clk);#1;end endtask
task reference;input integer id;integer x,y,i,j,k,gx,gy,mag;
 begin
  ref_edges=0;ref_sum=0;
  for(y=0;y<H;y=y+1) for(x=0;x<W;x=x+1) luma[y*W+x]=pixel(x,y,id)&255;
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
   expected[i]=pixel(x,y,id);
   if(x>3 && x<W-4 && y>1 && y<6 && mode[1] && mag>=80) expected[i]=24'hffae64;
   if(x>=9 && x<19 && y>=2 && y<6) begin ref_sum=ref_sum+mag;if(mag>=80) ref_edges=ref_edges+1;end
   stream[BITS-1-i*24-:24]=expected[i];
  end
 end
endtask
always @(posedge clk) begin
 cycle=cycle+1;sampled_av=av;sampled_as=as;sampled_early=ae;
`ifndef LEGACY_CONTRACT
`ifndef EXPECT_LEGACY
 sampled_input_valid=view_dut.input_valid;
`endif
`endif
 if(epoch && ae) early_cycle=cycle;
 if(epoch && !ae && !new_sof_seen && av && !as) residual=residual+1;
 if(epoch && as) begin new_sof_seen=1;sof_cycle=cycle;pixel_sofs=pixel_sofs+1;end
 if(checking && av && new_sof_seen && !ae) begin new_awb=new_awb+1;if(al) new_awb_rows=new_awb_rows+1;end
 #1;
 if(epoch) begin
`ifndef LEGACY_CONTRACT
`ifndef EXPECT_LEGACY
  if(sampled_early) begin
   frozen_group=view_dut.write_group;frozen_row=view_dut.write_y;
   frozen_bank_word=view_dut.line_bank[3].memory[frozen_group];
  end else if(!new_sof_seen) begin
   if(view_dut.input_armed!==0 || sampled_input_valid!==0 ||
      view_dut.write_group!==frozen_group || view_dut.write_y!==frozen_row ||
      view_dut.line_bank[3].memory[frozen_group]!==frozen_bank_word)
    $fatal(1,"old AWB tail changed input pointer or RAM before new SOF mode=%0d",mode);
   if(sampled_av) suppressed=suppressed+1;
  end
`endif
`endif
  if(cycle<=early_cycle+8 || sampled_as || (checking && seen==0 && ov))
   $fdisplay(trace_file,"%0d,%0t,%0d,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%0d,%0d",mode,$time,cycle,sampled_early,sampled_av,sampled_as,awb_dut.signal_delay_d.rd_valid,awb_dut.signal_delay_d.rd_valid_d,awb_dut.valid_d1,awb_dut.valid_d2,ov,packed_valid,fb,view_dut.write_y,view_dut.write_group);
  if(oe) early_count=early_count+1;
  if(packed_sof && packed_valid) $fatal(1,"packer emitted valid in its FS cycle mode=%0d",mode);
  if(!new_sof_seen && !sampled_early && ov) leaked_view=leaked_view+1;
  if(packed_sof) pack_epoch=1;
  if(!new_sof_seen && packed_valid) begin
   if(pack_epoch) leaked_words=leaked_words+1;
   else prior_epoch_words=prior_epoch_words+1;
  end
  if(fb) bad_seen=1;
 end
 if(checking) begin
  if(ov) begin
   if(first_view_cycle==0) first_view_cycle=cycle;
   if(seen>=N || ox!=seen%W || oy!=seen/W || ol!=(seen%W==W-4)) $fatal(1,"new frame coordinates mode=%0d seen=%0d xy=%0d,%0d",mode,seen,ox,oy);
   for(integer n=0;n<4;n=n+1) if(color[95-n*24-:24]!==expected[seen+n])
    $fatal(1,"new frame RGB mode=%0d pixel=%0d actual=%h expected=%h",mode,seen+n,color[95-n*24-:24],expected[seen+n]);
   seen=seen+4;in_line=!ol;
  end else if(in_line && mode[1]) $fatal(1,"new edge replay row interrupted mode=%0d seen=%0d",mode,seen);
  if(packed_valid) begin
   if(words>=BITS/128 || packed_data!==stream[BITS-1-words*128-:128]) $fatal(1,"new frame packed content mode=%0d word=%0d",mode,words);
   words=words+1;
  end
 end
end
task send_row;input integer y,id;integer x;
 begin
  for(x=0;x<W;x=x+4) begin
   rgb={pixel(x,y,id),pixel(x+1,y,id),pixel(x+2,y,id),pixel(x+3,y,id)};
   iv=1;il=x==W-4;ticks(1);
  end
  iv=0;il=0;
 end
endtask
task reset_case;input integer v;
 begin
  epoch=0;checking=0;iv=0;early=0;il=0;rst=0;ticks(8);rst=1;mode=2'(v);ticks(8);
  early=1;ticks(1);early=0;ticks(12);
  for(integer row=0;row<3;row=row+1) begin send_row(row,9);ticks(600);end
  send_row(3,9);ticks(6);
  if(!av || view_dut.write_y!=3 || awb_dut.I_tvalid_r0 || awb_dut.I_tvalid_r1 || awb_dut.signal_delay_d.I_valid_r)
   $fatal(1,"stop stimulus misses old AWB replay mode=%0d av=%b y=%0d",mode,av,view_dut.write_y);
  run_clk=0;begin integer held_cycle;held_cycle=cycle;#500000;if(cycle!=held_cycle) $fatal(1,"stopped CSI advanced");end
  residual=0;leaked_view=0;leaked_words=0;prior_epoch_words=0;pack_epoch=0;new_awb=0;new_awb_rows=0;seen=0;words=0;
  early_count=0;pixel_sofs=0;new_sof_seen=0;bad_seen=0;in_line=0;sof_cycle=0;first_view_cycle=0;suppressed=0;
  epoch=1;early=1;early_cycle=cycle+1;run_clk=1;ticks(1);early=0;ticks(20);
  $display("OBS real AWB pre-SOF mode=%0d old_valid_consumable=%0d leaked_view=%0d leaked_packed_after_FS=%0d prior_epoch_words_before_FS=%0d sticky_bad=%b old_write_row=%0d",mode,residual,leaked_view,leaked_words,prior_epoch_words,bad_seen,view_dut.write_y);
  if(residual!=3) $fatal(1,"real AWB residual changed mode=%0d beats=%0d",mode,residual);
  if(leaked_view || leaked_words || bad_seen || fb) failures=failures+1;
`ifdef EXPECT_LEGACY
  if(mode<2 && (leaked_view!=3 || leaked_words!=2 || bad_seen)) $fatal(1,"legacy RAW/GRAY failure was not reproduced mode=%0d",mode);
  if(mode>=2 && !bad_seen) $fatal(1,"legacy EDGE poisoning was not reproduced mode=%0d",mode);
`else
  if(leaked_view || leaked_words || bad_seen || fb) $fatal(1,"new early epoch accepts old AWB tail mode=%0d",mode);
  if(suppressed!=3) $fatal(1,"real residual input suppression was not exercised mode=%0d count=%0d",mode,suppressed);
  $display("PASS old AWB inputs suppressed mode=%0d beats=%0d frozen_write_pointer=%0d,%0d RAM_word_unchanged=1 input_armed=0 input_valid=0",mode,suppressed,frozen_group,frozen_row);
`endif
 end
endtask
task finish_new;input integer id;
 begin
  reference(id);checking=1;
  for(integer row=0;row<H;row=row+1) begin send_row(row,id);ticks(600);end
  ticks(700);checking=0;
  if(new_awb!=N/4 || new_awb_rows!=H || seen!=N || words!=BITS/128 || pixel_sofs!=1 || early_count!=1 || fb)
   $fatal(1,"new frame incomplete mode=%0d awb=%0d rows=%0d pixels=%0d words=%0d sof=%0d early=%0d bad=%b",mode,new_awb,new_awb_rows,seen,words,pixel_sofs,early_count,fb);
  if(mode[1] && (cp!=40 || ec!=ref_edges || es!=ref_sum)) $fatal(1,"new frame gradient statistics mismatch mode=%0d",mode);
  if(!mode[1] && (cp || ec || es)) $fatal(1,"new bypass retained gradient statistics");
  $display("PASS real AWB recovery mode=%0d new_sof_cycle=%0d early_to_sof=%0d first_view_cycle=%0d origin=0,0 AWB=%0d rows=%0d pixels=%0d packed=%0d gradients=%0d/%0d",mode,sof_cycle,sof_cycle-early_cycle,first_view_cycle,new_awb,new_awb_rows,seen,words,ec,es);
  epoch=0;ticks(10);
 end
endtask
initial begin
 trace_file=$fopen("epoch_trace.csv","w");
 $fdisplay(trace_file,"mode,time_ns,cycle,early_at_sample,awb_valid_at_sample,pixel_sof_at_sample,rd_valid_after,rd_valid_d_after,valid_d1_after,valid_d2_after,view_valid_after,packed_valid_after,frame_bad_after,write_row_after,write_group_after");
 for(integer v=0;v<4;v=v+1) begin
  reset_case(v);
`ifndef LEGACY_CONTRACT
`ifndef EXPECT_LEGACY
  finish_new(31+v);
`endif
`endif
 end
`ifdef EXPECT_LEGACY
 if(failures!=4) $fatal(1,"legacy failure count differs %0d",failures);
 $display("PASS legacy defect reproduced: actual AWB leaves 3 old-valid beats; RAW/GRAY leak 3 RGB and 2 packed beats; EDGE/GRAY+EDGE poison epoch");
`else
 if(failures) $fatal(1,"unexpected epoch failures %0d",failures);
 $display("PASS real AWB epoch isolation: 4 modes, vendor ERAM and divider, stopped CSI, 3 real residual beats ignored, exact fresh frames and packed words");
`endif
 $fclose(trace_file);$finish;
end
initial begin #10000000;$fatal(1,"real AWB epoch watchdog");end
endmodule
