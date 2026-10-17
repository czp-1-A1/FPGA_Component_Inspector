// A scaled raster is proved independently from native CSI/RAW completeness.
// Both proofs must belong to the same early-SOF epoch before publication.
module scaled_frame_guard #(parameter WIDTH=1280,HEIGHT=720)(
 input wire clk,rst_n,early_sof,valid,last,native_commit,invalidate,
 output wire pixel_accept,pixel_sof,
 output wire [10:0] x,output wire [9:0] y,
 output reg frame_commit,frame_bad);
 localparam COUNT_BITS=$clog2(WIDTH*HEIGHT+1);
 reg [COUNT_BITS-1:0] count;
 reg [10:0] cx;reg [9:0] cy;
 reg native_done,scaled_done,reported;
 assign x=cx;assign y=cy;
 assign pixel_accept=valid && !early_sof && !frame_bad && !invalidate && !scaled_done;
 assign pixel_sof=pixel_accept && count==0;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin
   count<=0;cx<=0;cy<=0;native_done<=0;scaled_done<=0;
   reported<=0;frame_commit<=0;frame_bad<=1;
  end else begin
   frame_commit<=0;
   if(early_sof)begin
    count<=0;cx<=0;cy<=0;native_done<=0;scaled_done<=0;
    reported<=0;frame_bad<=0;
   end else begin
    if(native_commit)native_done<=1;
    if(invalidate || (valid && (scaled_done || cy>=HEIGHT || last!=(cx==WIDTH-4))))frame_bad<=1;
    if(pixel_accept)begin
     count<=count+4;
     if(last)begin
      cx<=0;
      if(cy==HEIGHT-1)begin
       scaled_done<=1;
       if(count!=WIDTH*HEIGHT-4)frame_bad<=1;
      end else cy<=cy+1'b1;
     end else cx<=cx+4;
    end
    if(native_done && scaled_done && !reported && !frame_bad && !invalidate && !valid)begin
     frame_commit<=1;reported<=1;
    end
   end
  end
endmodule
