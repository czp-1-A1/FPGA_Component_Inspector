// Standard 720p60 progressive raster at 74.25 MHz, same as the displayed G.
// OSD coordinates are actual display pixels; glyph strokes are never skipped.
module native_720p60_vtc(input wire clk,rst_n,
 output reg [11:0] x,output reg [10:0] y,
 output wire [10:0] source_x,source_y,
 output wire vs,hs,de,pair_vs,field);
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin x<=0;y<=0;end
  else if(x==1649)begin x<=0;y<=y==749?0:y+1'b1;end
  else x<=x+1'b1;
 assign source_x=x[10:0];
 assign source_y=y;
 assign hs=x>=1390 && x<1430;
 assign vs=y>=725 && y<730;
 assign de=x<1280 && y<720;
 assign pair_vs=vs;
 assign field=0;
endmodule
