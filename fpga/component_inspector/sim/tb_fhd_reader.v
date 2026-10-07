`timescale 1ns/1ps
module tb_fhd_reader;
reg ddr=0,pix=0,runpix=1,rst=0,lock=0,prst=0,vs=0,de=0;
always #7.5 ddr=~ddr;always #6.734 if(runpix)pix=~pix;
reg ready=1,reply=0;reg [127:0] rddata=0;
wire req,busy,active,ok;wire [1:0] slot;wire [24:0] addr;wire [23:0] rgb;wire [15:0] under;
video_out #(.WIDTH(1920),.HEIGHT(1080),.CHECK_DISPLAY_LOCK(1)) dut(
 .I_rst_n(rst),.I_ddr_clk(ddr),.I_display_lock(lock),.I_pixel_rst_n(prst),
 .O_video_out_rd_busy(busy),.I_video_in_wr_busy(1'b0),.I_video_out_rp(2'd0),
 .I_completed_valid(1'b1),.I_completed_rp(2'd3),.O_active_valid(active),.O_active_rp(slot),
 .O_ddr_user_rd_en(req),.O_ddr_user_addr(addr),.I_ddr_user_ready(ready),
 .I_ddr_user_rd_valid(reply),.I_ddr_user_rd_data(rddata),.I_dsi_clk(pix),
 .I_video_vsync(vs),.I_video_rd_en(de),.O_vdieo_data(rgb),.O_display_ok(ok),.O_underflow_frames(under));
integer pending=0,accepted=0,returned=0;reg pause_reply=0;
always @(negedge ddr)begin
 reply=0;
 if(pending>0 && !pause_reply)begin reply=1;pending=pending-1;returned=returned+1;end
end
always @(posedge ddr)if(req)begin pending=pending+1;accepted=accepted+1;end
task dt(input integer n);repeat(n)@(negedge ddr);endtask
task boundary;begin vs=1;dt(8);vs=0;dt(40);end endtask
initial begin
 dt(10);rst=1;lock=1;prst=1;dt(40);boundary;dt(1300);
 if(dut.S_fifo_wr_num<360 || accepted<480)$fatal(1,"FHD prefill deadlocked accepted=%0d fifo=%0d",accepted,dut.S_fifo_wr_num);
 $display("PASS FHD reader startup: two 240-word bursts achieve 360-word prefill (reserved<=271)");
 // Consume enough to trigger another burst, then freeze replies mid burst.
 pause_reply=1;de=1;dt(1500);de=0;dt(100);
 if(dut.outstanding==0)$fatal(1,"loss scenario lacks outstanding reads");
 lock=0;prst=0;runpix=0;dt(8);
 if(dut.S_fifo_rst || dut.outstanding==0 || req)$fatal(1,"premature FIFO/counter clear after lock loss");
 lock=1;dt(2);lock=0;dt(2);lock=1;dt(2);lock=0;dt(6);
 if(dut.S_fifo_rst || dut.outstanding==0)$fatal(1,"lock bounce cleared old responses");
 pause_reply=0;dt(500);
 if(dut.outstanding!=0 || !dut.S_fifo_rst || dut.S_fifo_wr_num!=0)$fatal(1,"DDR-domain drain failed with stopped pixel clock");
 lock=1;runpix=1;prst=1;dt(80);
 if(req || active)$fatal(1,"reader restarted before clean frame boundary");
 boundary;dt(1300);
 if(!active || slot!=3 || dut.S_fifo_wr_num<360 || addr<21000000 || addr>24110400)$fatal(1,"recovery failed");
 if(pending!=0 || accepted!=returned)$fatal(1,"old responses not accounted for %0d/%0d",accepted,returned);
 $display("PASS FHD reader: outstanding-read loss, fully stopped pixel clock, lock bounce, drain before FIFO reset, clean-boundary recovery and old-response isolation");$finish;
end
initial begin #300000;$fatal(1,"reader timeout");end
endmodule
