// Two stages match the actual DDR reader; three more match experiment_osd.
module native_i60_phase(input wire clk,rst_n,
 input wire [11:0] x,input wire [10:0] y,source_x,source_y,
 input wire vs,hs,de,pair_vs,
 output wire osd_vs,osd_hs,osd_de,osd_pair_vs,
 output wire [10:0] osd_x,osd_y,
 output wire [11:0] tx_x,output wire [10:0] tx_y);
 reg [11:0] xp[0:4];reg [10:0] yp[0:4],sxp[0:1],syp[0:1];
 reg [3:0] sp[0:1];integer i;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin
   for(i=0;i<5;i=i+1)begin xp[i]<=0;yp[i]<=0;end
   for(i=0;i<2;i=i+1)begin sxp[i]<=0;syp[i]<=0;sp[i]<=0;end
  end else begin
   xp[0]<=x;yp[0]<=y;sxp[0]<=source_x;syp[0]<=source_y;sp[0]<={vs,hs,de,pair_vs};
   for(i=1;i<5;i=i+1)begin xp[i]<=xp[i-1];yp[i]<=yp[i-1];end
   sxp[1]<=sxp[0];syp[1]<=syp[0];sp[1]<=sp[0];
  end
 assign {osd_vs,osd_hs,osd_de,osd_pair_vs}=sp[1];
 assign osd_x=sxp[1];assign osd_y=syp[1];assign tx_x=xp[4];assign tx_y=yp[4];
endmodule
