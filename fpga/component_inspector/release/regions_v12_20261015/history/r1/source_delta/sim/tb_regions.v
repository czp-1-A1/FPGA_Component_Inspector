`timescale 1ns/1ps
module tb_regions;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ready;wire [303:0] objects;wire [1:0] state;
frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.state(state),.region_objects(objects));
wire unknown_ready;wire [303:0] unknown_objects;
frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1)) unknown_model(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(unknown_ready),.region_objects(unknown_objects));
defparam unknown_model.regions.cfg.MODEL1=16'd9999;
integer pattern=0,cases=0,cycles,px,py,l,v,pgm,checks=0;
integer centers[0:3];
function integer image(input integer xx,yy);
 integer dx,dy,cx;
 begin
 image=pattern==6 ? ((xx>=80 && xx<1200 && yy>=140 && yy<580) ? 30 : 240) : 30;
 for(integer k=0;k<4;k++)begin
  cx=centers[k];
  if(pattern!=2 && pattern!=7 && !(pattern==5 && k<2))begin
   if(pattern==1 && (k==1 || k==2))begin
    dx=xx-cx;dy=yy-360;if(dx*dx+dy*dy<=81)image=150;
   end else if(xx>=cx-32 && xx<cx+32 && yy>=322 && yy<398)image=180;
  end
 end
 // Valid-looking parts outside the two zones must not displace any in-zone part.
 if((xx>=28 && xx<92 && yy>=322 && yy<398) ||
    (xx>=1188 && xx<1252 && yy>=322 && yy<398))image=180;
 // Feed holes within the zones are not inspection pockets.
 if(pattern==7)begin
  dx=xx-320;dy=yy-360;if(dx*dx+dy*dy<=256)image=150;
  dx=xx-800;if(dx*dx+dy*dy<=256)image=150;
 end
 end
endfunction
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame(input integer p);
 reg [75:0] rec;integer expected_count,want,cx,expected_x0;
 begin
 cases++;pattern=p;centers[0]=p==3 ? 170 : p==4 ? 150 : 320;
 centers[1]=480;centers[2]=800;centers[3]=960;
 fs=1;ticks(1);fs=0;ticks(3);
 pgm=$fopen($sformatf("region_case_%0d.pgm",cases),"w");$fwrite(pgm,"P2\n640 360\n255\n");
 for(py=0;py<720;py+=2)begin
  for(px=0;px<1280;px+=2)$fwrite(pgm,"%0d ",(image(px,py)+image(px+1,py)+image(px,py+1)+image(px+1,py+1))/4);
  $fwrite(pgm,"\n");
 end
 $fclose(pgm);
 for(py=0;py<720;py++)begin
  for(px=0;px<1280;px+=4)begin
   x=px;y=py;accept=1;sof=px==0 && py==0;
   for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
   ticks(1);accept=0;sof=0;if(px%64==0)ticks(1);
  end
  ticks(2);
 end
 ticks(5);
 cycles=0;while((!ready || !unknown_ready) && cycles<2300000)begin ticks(1);cycles++;end
 if(!ready || !unknown_ready)$fatal(1,"regions did not complete");
 expected_count=(p==2 || p==7) ? 0 : p==5 ? 2 : p==4 ? 3 : 4;
 want=0;
 for(integer k=0;k<4;k++)begin
  rec=objects[k*76+:76];if(rec[75])begin
   want++;checks++;
   if(p==2 || p==7)$fatal(1,"outside object or feed hole became inspection target");
   if(k<2 && (rec[41:31]+rec[30:20])/2>=624 || k>=2 && (rec[41:31]+rec[30:20])/2<656)
    $fatal(1,"region membership crossed");
   if(p==1 && rec[74:73]!==((k==1 || k==2) ? 2'd3 : 2'd2))$fatal(1,"per-zone P/E class incorrect");
   if(p!=1 && rec[74:73]!==2)$fatal(1,"body lost at zone edge");
   if(p==3 && k==0 && (rec[41:31]!=136 || rec[30:20]!=204))$fatal(1,"zone edge cropped full body");
  end
 end
 if(want!=expected_count)$fatal(1,"wrong zone count pattern%0d got%0d expected%0d objects%h",p,want,expected_count,objects);
 if(unknown_objects[303:152]!==0 || unknown_objects[151:0]!==objects[151:0])
  $fatal(1,"unbound model classified or contaminated trained zone");
 $display("REF regions case=%0d records=%h cycles=%0d",cases,objects,cycles);
 // A new/canceled epoch must withdraw every zone together.
 cancel=1;ticks(1);cancel=0;ticks(2);
 if(ready || objects!==0 || unknown_ready || unknown_objects!==0)$fatal(1,"stale region results after cancel");
 end
endtask
initial begin
 ticks(5);rst=1;ticks(5);
 for(integer p=0;p<8;p++)frame(p);
 $display("PASS regions: %0d full frames, %0d independently checked targets, two zones/two pockets, P/E, outside and feed rejection, full boundary body, unknown model, cancel",cases,checks);$finish;
end
initial begin #450000000;$fatal(1,"region search watchdog");end
endmodule
