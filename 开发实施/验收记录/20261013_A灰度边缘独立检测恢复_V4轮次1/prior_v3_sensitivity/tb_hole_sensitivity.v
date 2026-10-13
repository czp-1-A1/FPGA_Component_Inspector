`timescale 1ns/1ps
// Characterization of frozen V3, not a replay of the phone photograph.
// Change only input circle brightness, radius and the Y rise per 96 pixels.
module tb_hole_sensitivity;
reg clk=0,rst=0,fs=0,accept=0,commit=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire [43:0] bx;wire [39:0] by;wire [3:0] mask,verified;
wire located;wire [7:0] diagnostic;
multi_pocket_tracker dut(clk,rst,fs,1'b0,accept,commit,1'b0,x,y,rgb,
 bx,by,mask,verified,located,diagnostic);
integer rise,radius,brightness,case_no=0,rows_with_runs,rows_with_shape;
integer rejected_tilt=0;
function integer pixel(input integer xx,yy);
 integer c,cy,v;
 begin
  v=30;
  for(integer h=0;h<6;h++) begin
   c=264+96*h;cy=280+rise*h;
   if((xx-c)*(xx-c)+(yy-cy)*(yy-cy)<=radius*radius) v=brightness;
  end
  pixel=v;
 end
endfunction
task tick(input integer n);begin repeat(n) @(negedge clk);end endtask
task frame;
 integer g;
 begin
  fs=1;tick(1);fs=0;tick(4);
  for(integer row=168;row<=336;row++) begin
   y=row;
   for(integer beat=0;beat<256;beat++) begin
    x=beat*4;accept=1;
    for(integer lane=0;lane<4;lane++) begin
     g=pixel(x+lane,row);rgb[95-lane*24-:24]={g[7:0],g[7:0],g[7:0]};
    end
    tick(1);accept=0;tick(1);
   end
   tick(4);
  end
  tick(8);commit=1;tick(1);commit=0;tick(4);
 end
endtask
always @(posedge clk) if(rst && dut.a_d && dut.scan_row && dut.x_d==892) begin
 if(dut.count>=2) rows_with_runs=rows_with_runs+1;
 if(dut.shape_ok) rows_with_shape=rows_with_shape+1;
 if(case_no==4 && dut.count==4)
  $display("ROW y=%0d counts=%0d/%0d/%0d middle_widths=%0d,%0d,%0d,%0d prev=%0d,%0d,%0d,%0d next=%0d,%0d,%0d,%0d shape=%b",
   dut.y_d,dut.p2_count,dut.p1_count,dut.count,
   dut.p1_w[0],dut.p1_w[1],dut.p1_w[2],dut.p1_w[3],
   dut.p2_w[0],dut.p2_w[1],dut.p2_w[2],dut.p2_w[3],
   dut.widths[0],dut.widths[1],dut.widths[2],dut.widths[3],dut.shape_ok);
end
task trial(input integer r,s,b);
 begin
  rst=0;accept=0;fs=0;commit=0;tick(4);
  radius=r;rise=s;brightness=b;rows_with_runs=0;rows_with_shape=0;case_no=case_no+1;
  rst=1;frame();frame();
  $display("OBS sensitivity radius=%0d rise_per_96=%0d hole_gray=%0d parsed_rows=%0d accepted_rows=%0d reason=%0d seed=%0d mask=%h verified=%h",
   r,s,b,rows_with_runs,rows_with_shape,diagnostic[7:4],dut.seed_count,mask,verified);
  if(s==0 && b==200 && verified==0) $fatal(1,"horizontal bright control must acquire");
  if(s==0 && b==110 && verified!=0) $fatal(1,"below-threshold control unexpectedly acquired");
  if(s!=0 && b==200 && verified==0) rejected_tilt=rejected_tilt+1;
 end
endtask
initial begin
 trial(24,0,200);trial(24,1,200);trial(24,2,200);trial(24,4,200);trial(24,8,200);
 trial(16,0,200);trial(16,1,200);trial(16,2,200);trial(16,4,200);trial(16,8,200);
 trial(24,0,110);
 $display("DONE sensitivity characterization: %0d trials; rejected bright tilted rows=%0d; controls passed",case_no,rejected_tilt);
 $finish;
end
initial begin #100000000;$fatal(1,"sensitivity watchdog");end
endmodule
