// Pixel domain: continuous modulo-2^32 event counters, registered Gray outputs.
// Reference domain: a 50,000,000-cycle window, as in the working old FPS monitor.
// These count the internal pixel/raster events; they are not camera FPS or an
// external measurement of the TMDS serial clock. A mixed/first window is rejected.
module clock_probe_counter(input wire clk,rst,line_end,frame_end,
 output reg [31:0] p_gray,h_gray,v_gray);
 reg [31:0] p_count,h_count,v_count;
 wire [31:0] pn=p_count+32'd1,hn=h_count+32'd1,vn=v_count+32'd1;
 always @(posedge clk or posedge rst)
  if(rst)begin p_count<=0;h_count<=0;v_count<=0;p_gray<=0;h_gray<=0;v_gray<=0;end
  else begin
   p_count<=pn;p_gray<=(pn>>1)^pn;
   if(line_end)begin h_count<=hn;h_gray<=(hn>>1)^hn;end
   if(frame_end)begin v_count<=vn;v_gray<=(vn>>1)^vn;end
  end
endmodule

module clock_probe_measure #(parameter WINDOW_CYCLES=50000000)(
 input wire clk,rst_n,locked,mode,
 input wire [31:0] p_gray,h_gray,v_gray,
 output reg [193:0] snapshot);
 localparam W=(WINDOW_CYCLES>1)?$clog2(WINDOW_CYCLES):1;
 (* async_reg="true" *) reg [31:0] p_s0,p_s1,h_s0,h_s1,v_s0,v_s1;
 (* async_reg="true" *) reg lock_s0,lock_s1,mode_s0,mode_s1;
 function [31:0] binary(input [31:0] g);
  integer i;
  begin for(i=0;i<32;i=i+1)binary[i]=^(g>>i);end
 endfunction
 reg [31:0] p_bin,h_bin,v_bin,p_base,h_base,v_base;
 reg [W-1:0] window_count;
 reg dirty,last_mode;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin
   p_s0<=0;p_s1<=0;h_s0<=0;h_s1<=0;v_s0<=0;v_s1<=0;
   lock_s0<=0;lock_s1<=0;mode_s0<=0;mode_s1<=0;
   p_bin<=0;h_bin<=0;v_bin<=0;p_base<=0;h_base<=0;v_base<=0;
   window_count<=0;dirty<=1;last_mode<=0;snapshot<=0;
  end else begin
   p_s0<=p_gray;p_s1<=p_s0;h_s0<=h_gray;h_s1<=h_s0;v_s0<=v_gray;v_s1<=v_s0;
   lock_s0<=locked;lock_s1<=lock_s0;mode_s0<=mode;mode_s1<=mode_s0;
   p_bin<=binary(p_s1);h_bin<=binary(h_s1);v_bin<=binary(v_s1);
   last_mode<=mode_s1;
   if(!lock_s1)begin snapshot[193:192]<=0;dirty<=1;end
   if(mode_s1!=last_mode)dirty<=1;
   if(window_count==WINDOW_CYCLES-1)begin
    window_count<=0;p_base<=p_bin;h_base<=h_bin;v_base<=v_bin;
    dirty<=!lock_s1 || mode_s1!=last_mode;
    if(lock_s1 && !dirty && mode_s1==last_mode)begin
     if(mode_s1)begin
      snapshot[191:96]<={p_bin-p_base,h_bin-h_base,v_bin-v_base};snapshot[193]<=1;
     end else begin
      snapshot[95:0]<={p_bin-p_base,h_bin-h_base,v_bin-v_base};snapshot[192]<=1;
     end
    end
   end else window_count<=window_count+1'b1;
  end
endmodule
