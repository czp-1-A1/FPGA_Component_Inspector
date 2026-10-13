`timescale 1ns/1ps
module tb_multi_pockets;
reg clk=0,rst=0,fs=0,sof=0,accept=0,commit=0,done=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;reg [1:0] mode=1;
always #5 clk=~clk;
wire [43:0] bx;wire [39:0] by;wire [3:0] mask,verified;wire [7:0] diagnostic;
wire ev,bad;wire [10:0] ex;wire [9:0] ey;wire [43:0] mag;wire [3:0] neighborhood;
wire [339:0] records;wire ready;
multi_pocket_tracker tracker(clk,rst,fs,sof,accept,done,cancel,x,y,rgb,bx,by,mask,verified,,diagnostic);
roi_sobel_view #(.X0(96),.X1(928),.Y1(464)) sobel(.clk(clk),.rst_n(rst),.pixel_valid(accept),.pixel_sof(sof),.pixel_last(x==1020),.early_sof(fs),
 .rgb(rgb),.mode(mode),.invalidate(cancel),.view_ready(1'b1),.frame_bad(bad),
 .gradient_valid(ev),.gradient_x(ex),.gradient_y(ey),.gradient_magnitudes(mag),.gradient_neighborhood(neighborhood));
multi_pocket_statistics statistics(clk,rst,fs,sof,accept,commit,cancel,x,y,rgb,bx,by,mask,verified,ev,ex,ey,mag,neighborhood,mode,1'b1,1'b1,8'd58,records,ready);
integer checks=0,frame_no=0,move=0,cy=280,n_holes=6,mids=2,populated=5;
integer sums[0:3],counts[0:3],lows[0:3],highs[0:3],ec[0:3],gs[0:3],ep[0:3];
integer xx,yy,k,h,c,d,g,i,lo,hi,expected_state;
reg monitor=0;reg [3:0] expected_mask;
task ticks(input integer n);begin repeat(n) @(negedge clk);end endtask
task check(input bit condition,input string message);begin checks++;if(!condition) $fatal(1,"frame %0d %s",frame_no,message);end endtask
function integer pixel(input integer xx,input integer yy);
 integer hh,cc,value,px,half_width;
 begin
  value=30;
  for(hh=0;hh<n_holes;hh++) begin
   cc=264+move+hh*96;
   if(yy>=cy-16 && yy<=cy+16) begin
    half_width=16;while(half_width*half_width+(yy-cy)*(yy-cy)>256) half_width--; if(xx>=cc-half_width && xx<cc+half_width) value=200;
    else if((xx>=cc-half_width-4*mids && xx<cc-half_width) || (xx>=cc+half_width && xx<cc+half_width+4*mids)) value=110;
   end
   px=cc-72;
   if(populated[hh%4] && xx>=px+4 && xx<px+76 && yy>=cy+44 && yy<cy+116)
    value=((xx/4+yy/4)%2)==0 ? 190 : 230;
  end
  pixel=value;
 end
endfunction
always @(posedge clk) if(monitor) begin
 if(accept) for(integer p=0;p<4;p++) for(integer l=0;l<4;l++) begin
  xx=x+l;yy=y;
  if(mask[p] && xx>=bx[p*11+:11] && xx<bx[p*11+:11]+80 && yy>=by[p*10+:10] && yy<by[p*10+:10]+80) begin
   g=(int'(rgb[95-l*24-:8])+2*int'(rgb[87-l*24-:8])+int'(rgb[79-l*24-:8]))/4;
   sums[p]+=g;counts[p]++;if(g<lows[p]) lows[p]=g;if(g>highs[p]) highs[p]=g;
  end
 end
 if(ev) for(integer p=0;p<4;p++) for(integer l=0;l<4;l++)
  if(mask[p] && neighborhood[l] && ex+l>=bx[p*11+:11] && ex+l<bx[p*11+:11]+80 && ey>=by[p*10+:10] && ey<by[p*10+:10]+80) begin
   ep[p]++;gs[p]+=mag[l*11+:11];if(mag[l*11+:11]>=80) ec[p]++;
  end
end
task frame(input integer dx,dy,holes,mid,parts,view,input reg [3:0] valid_expected);
 begin
  frame_no++;move=dx;cy=dy;n_holes=holes;mids=mid;populated=parts;mode=view;
  fs=1;ticks(1);fs=0;ticks(8);
  for(i=0;i<4;i++) begin sums[i]=0;counts[i]=0;lows[i]=255;highs[i]=0;ec[i]=0;gs[i]=0;ep[i]=0;end
  monitor=1;
  for(yy=0;yy<600;yy++) begin
   // Input coordinates are assigned separately from reference-monitor scratch variables.
   y=yy;
   for(integer beat=0;beat<256;beat++) begin
    x=beat*4;accept=1;sof=yy==0 && beat==0;
    for(integer lane=0;lane<4;lane++) begin g=pixel(beat*4+lane,yy);rgb[95-lane*24-:24]={g[7:0],g[7:0],g[7:0]};end
    commit=yy==456 && beat==0;
    ticks(1);accept=0;sof=0;commit=0;ticks(1);
   end
   ticks(48);
  end
  ticks(80);monitor=0;done=1;ticks(1);done=0;ticks(2);
  check(!bad,"Sobel changed video schedule/overflowed");check(verified===valid_expected,"current-frame verification mask");
  for(i=0;i<4;i++) begin
   check(records[i*85+63]===valid_expected[i],"per-pocket validity");
   if(valid_expected[i]) begin
    check(counts[i]==6400,"independent core area");check(records[i*85+53+:8]==sums[i]/6400,"mean/reference");
    check(records[i*85+45+:8]==lows[i] && records[i*85+37+:8]==highs[i],"min/max/reference");
    if(view>=2) begin
     check(ep[i]==6400,"shared Sobel full core");check(records[i*85+24+:13]==ec[i] && records[i*85+:24]==gs[i],"per-pocket edge tap/reference");
     expected_state=ec[i]>=96 && gs[i]>=32768 ? 2 : ec[i]<=48 && gs[i]<=16384 ? 3 : 1;
     if(view==3 && expected_state!=(sums[i]>=58*6400 ? 2 : 3)) expected_state=1;
    end else expected_state=sums[i]>=58*6400 ? 2 : 3;
    check(records[i*85+61+:2]==expected_state,"independent class/mode");
   end else check(records[i*85+61+:2]==1,"invalid pocket retained class");
  end
  $display("OBS multi frame=%0d move=%0d y=%0d mode=%0d mask=%b verified=%b mean=%0d/%0d/%0d/%0d",frame_no,dx,dy,view,mask,verified,records[60:53],records[145:138],records[230:223],records[315:308]);
 end
endtask
initial begin
 ticks(6);rst=1;ticks(10);
 frame(0,280,6,2,5,1,0);frame(0,280,6,2,5,1,15);
 check(records[62:61]==2 && records[147:146]==3 && records[232:231]==2 && records[317:316]==3,"mixed PRESENT/EMPTY separately");
 frame(3,280,6,2,5,0,15);frame(0,280,6,2,5,2,15);frame(-4,280,6,2,5,3,15);
 frame(20,280,6,2,5,1,0);frame(20,280,6,2,5,1,15);
 frame(20,296,6,2,5,1,0);frame(20,296,6,2,5,1,15);
 frame(20,296,0,2,0,1,0);frame(-48,264,6,2,0,1,0);frame(-48,264,6,2,0,1,15);
 check(records[62:61]==3 && records[147:146]==3 && records[232:231]==3 && records[317:316]==3,"all empty remains locatable");
 frame(0,264,6,2,0,1,0);frame(0,264,6,2,0,1,15);
 frame(0,264,3,2,0,1,7);frame(0,264,3,2,0,1,7);
 check(mask==7,"exiting fourth pocket removed");
 frame(0,264,6,2,0,1,7);frame(0,264,6,2,0,1,15);
 check(mask==15,"new fourth pocket acquired only after fresh sampling");
 frame(-48,264,6,3,0,1,0);check(diagnostic[7:4]==2,"MID12 rejected");
 frame(0,280,1,2,1,1,0);check(diagnostic[7:4]==2,"one isolated bright object rejected");
 cancel=1;ticks(1);cancel=0;ticks(2);check(records==0 && mask==0,"parameter cancellation");
 $display("PASS multi pockets: %0d assertions; broad automatic acquisition, mixed/empty, PPC4 reference statistics/shared edges/four modes, both directions, fast/y loss and reacquire, malformed holes, cancellation",checks);$finish;
end
initial begin #100000000;$fatal(1,"multi unit watchdog");end
endmodule
