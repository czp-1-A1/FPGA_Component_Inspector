// Passive measurement of the small contour nearest the taught ROI centre.
// No class, search, ranking or counter decision depends on this diagnostic.
// The containing frame_shape_search sample_new is its only publication gate.
module empty_candidate_probe #(parameter CENTER_X=640)(
 input wire clk,rst_n,cancel,
 input wire measure,allowed,region,
 input wire [11:0] distance,
 input wire [10:0] center_x,center_y,
 input wire [9:0] width,height,
 input wire [2:0] bright_count,
 input wire geometry_ok,shape_ok,row_ok,feed,covered,raw_empty,area_ok,
 input wire ref_complete,ref_empty,ref_ok,
 input wire [10:0] ref_x,ref_y,
 input wire [9:0] ref_width,ref_height,
 input wire [303:0] records,
 output reg [31:0] word
);
 reg [31:0] best;
 reg [11:0] best_distance;
 reg [10:0] best_x,best_y;
 reg [4:0] best_width,best_height;
 wire signed [11:0] offset=$signed({1'b0,center_x})-CENTER_X;
 wire signed [11:0] half_offset=offset>>>1;
 wire [5:0] quantized=half_offset>31 ? 6'd31 : half_offset< -32 ? 6'd32 : half_offset[5:0];
 wire replace=measure && allowed && (!best[31] || distance<best_distance);
 integer slot;reg [75:0] ob;reg selected,empty_selected;
 function match_record;
  input [75:0] value;
  reg [11:0] sx;reg [10:0] sy;
  begin
   sx={1'b0,value[41:31]}+value[30:20];sy={1'b0,value[19:10]}+value[9:0];
   match_record=value[75] && sx==({best_x,1'b0}+12'd2) &&
    sy==({best_y[9:0],1'b0}+11'd2) &&
    value[55:49]=={best_width,1'b0} && value[48:42]=={best_height,1'b0};
  end
 endfunction
 always @*begin
  selected=0;empty_selected=0;ob=0;
  for(slot=0;slot<4;slot=slot+1)begin
   ob=records[slot*76+:76];
   if(best[31] && match_record(ob))begin
    selected=1;if(ob[74:73]==3)empty_selected=1;
   end
  end
  word=best;word[10]=selected;word[7]=empty_selected;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin best<=0;best_distance<=0;best_x<=0;best_y<=0;best_width<=0;best_height<=0;end
  else if(cancel)begin best<=0;best_distance<=0;end
  else begin
   if(replace)begin
    // Bits: valid,region,W5,H5,B3,G,S,R,F,C,raw,K,ref_seen,ref_ok,E,A,dx/2.
    best<={1'b1,region,width[4:0],height[4:0],bright_count,
     geometry_ok,shape_ok,row_ok,feed,covered,raw_empty,1'b0,1'b0,1'b0,1'b0,area_ok,quantized};
    best_distance<=distance;best_x<=center_x;best_y<=center_y;
    best_width<=width[4:0];best_height<=height[4:0];
   end
   if(ref_complete && ref_empty && best[31] && ref_x==best_x && ref_y==best_y &&
     ref_width=={5'd0,best_width} && ref_height=={5'd0,best_height})begin
    best[9]<=1;best[8]<=ref_ok;
   end
  end
 end
endmodule
