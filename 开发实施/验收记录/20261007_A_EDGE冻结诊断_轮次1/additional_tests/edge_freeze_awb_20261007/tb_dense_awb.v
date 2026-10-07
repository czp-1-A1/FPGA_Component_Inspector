`timescale 1ns/1ps
// Scheduling diagnosis only: real TD-selected AWB/divider/ERAM and real Sobel.
module tb_dense_awb;
localparam W=1024,H=16,BEATS=W*H/4;
reg clk=0,rst=0,iv=0,early=0,il=0,ready=1;
reg [1:0] mode=0;
reg [95:0] rgb={4{24'h646464}};
always #5 clk=~clk;
wire av,as,al,ae,ir;wire [95:0] ac;
awb #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) awb_dut(
 .I_clk(clk),.I_rst_n(rst),.I_tlast(il),.I_tuser(early),.I_tdata(rgb),.I_tvalid(iv),.I_tready(ir),
 .O_tlast(al),.O_tuser(ae),.O_pixel_sof(as),.O_tdata(ac),.O_tvalid(av),.O_tready(1'b1));
wire ov,ol,oe,fb;wire [95:0] color;wire [10:0] ox;wire [9:0] oy;
wire [12:0] cp,ec;wire [23:0] es;
roi_sobel_view #(.WIDTH(W),.HEIGHT(H)) view_dut(
 .clk(clk),.rst_n(rst),.pixel_valid(av),.pixel_sof(as),.pixel_last(al),.early_sof(ae),.rgb(ac),
 .mode(mode),.invalidate(1'b0),.view_ready(ready),.frame_bad(fb),.out_valid(ov),.out_last(ol),
 .out_early_sof(oe),.out_rgb(color),.out_x(ox),.out_y(oy),.core_pixels(cp),.edge_count(ec),.edge_sum(es));
wire packed_valid,packed_sof;wire [127:0] packed_data;
data_96bit_to_128bit pack(clk,rst,oe,ov,color,packed_sof,packed_valid,packed_data);
integer cycle=0,frame_no=0,input_gap=0,first_bad=-1,bad_row=-1,bad_read=-1,bad_group=-1;
integer awb_count=0,awb_rows=0,awb_sofs=0,view_count=0,view_rows=0,packed_count=0;
integer first_sof=-1,first_out=-1,row_start=-1,previous_start=-1,min_start=999999,max_start=0;
integer av_gap=0,min_gap=999999,max_gap=0,starts=0,csv,summary,switch_frame=0;
reg was_av=0,in_row=0,active=0;
task ticks;input integer n;begin repeat(n) @(negedge clk);#1;end endtask
always @(posedge clk) begin
 cycle=cycle+1;
 if(active) begin
  if(as) begin awb_sofs=awb_sofs+1;if(first_sof<0) first_sof=cycle;end
  if(av) begin
   awb_count=awb_count+1;
   if(!was_av && awb_count>1) begin if(av_gap<min_gap)min_gap=av_gap;if(av_gap>max_gap)max_gap=av_gap;end
   av_gap=0;if(al) awb_rows=awb_rows+1;
  end else av_gap=av_gap+1;
  was_av=av;
  if(view_dut.read_issue && !view_dut.reading) begin
   starts=starts+1;
   if(previous_start>=0) begin
    if(cycle-previous_start<min_start)min_start=cycle-previous_start;
    if(cycle-previous_start>max_start)max_start=cycle-previous_start;
   end
   previous_start=cycle;
   $fdisplay(csv,"read_start,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%b,%b,%b",frame_no,input_gap,mode,cycle,view_dut.write_y,view_dut.write_group,view_dut.read_y,view_dut.ready_rows,ready,view_dut.pipeline_idle,fb);
  end
  if(view_dut.cache_overrun && first_bad<0) begin
   first_bad=cycle;bad_row=view_dut.write_y;bad_read=view_dut.read_y;bad_group=view_dut.write_group;
   $fdisplay(csv,"cache_overrun,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%b,%b,%b",frame_no,input_gap,mode,cycle,bad_row,bad_group,bad_read,view_dut.ready_rows,ready,view_dut.pipeline_idle,fb);
  end
 end
 #1;
 if(active && ov) begin
  if(first_out<0) first_out=cycle;
  view_count=view_count+1;in_row=!ol;
  if(ol)view_rows=view_rows+1;
  if(color!=={4{24'h646464}}) $fatal(1,"constant RGB changed frame=%0d x=%0d y=%0d",frame_no,ox,oy);
 end else if(active && in_row && !fb && mode[1]) $fatal(1,"admitted edge row interrupted frame=%0d",frame_no);
 if(active && packed_valid) packed_count=packed_count+1;
end
task frame;input integer v,gap,expected_bad,hold_ready;
 begin
  active=0;iv=0;il=0;early=0;ticks(700);
  frame_no=frame_no+1;mode=2'(v);input_gap=gap;ready=!hold_ready;
  awb_count=0;awb_rows=0;awb_sofs=0;view_count=0;view_rows=0;packed_count=0;
  first_bad=-1;bad_row=-1;bad_read=-1;bad_group=-1;first_sof=-1;first_out=-1;
  previous_start=-1;min_start=999999;max_start=0;av_gap=0;min_gap=999999;max_gap=0;
  starts=0;was_av=0;in_row=0;active=1;
  early=1;ticks(1);early=0;ticks(20);
  if(fb) $fatal(1,"new early FS did not clear frame_bad frame=%0d",frame_no);
  for(integer y=0;y<H;y=y+1) begin
   for(integer b=0;b<W/4;b=b+1) begin
    iv=1;il=b==W/4-1;ticks(1);
   end
   iv=0;il=0;if(y!=H-1) ticks(gap);
  end
  ticks(700);active=0;ready=1;
  $display("OBS dense AWB frame=%0d mode=%0d input_gap=%0d awb=%0d rows=%0d sof=%0d awb_gap=%0d..%0d view=%0d rows=%0d packed=%0d bad=%b first_bad_row=%0d group=%0d read_y=%0d read_start_period=%0d..%0d ready_hold=%0d",frame_no,mode,gap,awb_count,awb_rows,awb_sofs,min_gap,max_gap,view_count,view_rows,packed_count,fb,bad_row,bad_group,bad_read,min_start,max_start,hold_ready);
  $fdisplay(summary,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%b,%0d,%0d,%0d,%0d,%0d,%0d",frame_no,mode,gap,awb_count,awb_rows,awb_sofs,min_gap,max_gap,view_count,view_rows,packed_count,fb,bad_row,bad_group,bad_read,min_start,max_start,hold_ready);
  if(expected_bad==0 && (fb || awb_count!=BEATS || awb_rows!=H || awb_sofs!=1 || view_count!=BEATS || view_rows!=H || packed_count!=BEATS*3/4))
   $fatal(1,"expected complete dense frame failed frame=%0d",frame_no);
  if(expected_bad==1 && !fb) $fatal(1,"expected starvation defect not reproduced frame=%0d",frame_no);
 end
endtask
initial begin
 csv=$fopen("events.csv","w");summary=$fopen("summary.csv","w");
 $fdisplay(csv,"event,frame,input_gap,mode,cycle,write_y,write_group,read_y,ready_rows,ready,pipeline_idle,frame_bad");
 $fdisplay(summary,"frame,mode,input_gap,awb_beats,awb_rows,awb_sofs,min_awb_gap,max_awb_gap,view_beats,view_rows,packed_words,frame_bad,bad_write_row,bad_write_group,bad_read_row,min_read_start_period,max_read_start_period,ready_hold");
 ticks(8);rst=1;ticks(8);
 // Same gap across a mode transition and a repeated EDGE epoch.
 frame(0,1,0,0);frame(2,1,-1,0);frame(2,1,-1,0);
 for(integer gap=2;gap<=8;gap=gap+2) begin frame(0,gap,0,0);frame(2,gap,-1,0);end
 frame(2,10,-1,0);frame(2,16,0,0);frame(2,384,0,0);
 // Isolate downstream admission: generous line gaps, permanently low ready.
 frame(0,384,0,1);frame(2,384,1,1);frame(2,384,1,1);frame(0,384,0,0);
 $display("PASS dense actual AWB diagnosis: RAW-to-EDGE transitions, line-gap sweep, repeated epochs and ready starvation characterized");
 $fclose(csv);$fclose(summary);$finish;
end
initial begin #10000000;$fatal(1,"dense AWB watchdog");end
endmodule
