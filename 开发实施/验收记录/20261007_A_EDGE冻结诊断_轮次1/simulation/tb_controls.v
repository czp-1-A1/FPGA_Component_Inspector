`timescale 1ns/1ps
module tb_controls;
reg clk=0,rst=1; always #5 clk=~clk;
reg [3:0] btn=15;
wire req,camdone,aedone; wire [15:0] ae,ag,errors;
wire scl; tri1 sda;
ae_set #(.CLK_HZ(10000),.DEBOUNCE_MS(3),.HOLD_MS(8),.REPEAT_MS(2)) dut
 (clk,rst,btn,aedone,camdone,req,ae,ag);
uicfgcs500 cfg(.I_clk(clk),.I_rst_n(~rst),.I_ae_req(req),.I_ae(ae),.I_ag(ag),
 .O_cam_scl(scl),.IO_cam_sda(sda),.O_i2c_errors(errors),.O_cfg_done(camdone),.O_ae_cfg_done(aedone));
task cycles; input integer n; begin repeat(n) @(negedge clk); end endtask
task press; input [3:0] b; begin btn=b; cycles(45); btn=15; cycles(100); end endtask
integer writes=0; reg [15:0] prev_ae,prev_ag;
reg busy_d=0;
always @(posedge clk) begin
 if(!rst && cfg.iic_req && !cfg.iic_busy) begin
  writes=writes+1;
  if(writes>121 && {cfg.wr_data[15:8],cfg.wr_data[23:16]}==0) $fatal(1,"invalid AE table index");
 end
 if(!rst && busy_d && !aedone && (ae!=prev_ae || ag!=prev_ag)) $fatal(1,"payload changed while writer busy");
 busy_d<=!aedone && camdone; prev_ae<=ae; prev_ag<=ag;
end
initial begin
 cycles(3); rst=0; wait(aedone); cycles(10);
 if(writes!=126 || ae!=2244 || ag!=48) $fatal(1,"startup %d %d %d",writes,ae,ag);
 btn=14; cycles(8); btn=15; cycles(40);
 if(ae!=2244) $fatal(1,"bounce accepted");
 press(14); if(ae!=2228) $fatal(1,"exposure down %d",ae);
 press(13); if(ae!=2244) $fatal(1,"exposure up");
 press(11); if(ag!=47) $fatal(1,"gain down");
 press(7); if(ag!=48) $fatal(1,"gain up");
 btn=0; cycles(200); btn=15; cycles(100);
 if(ae!=2244 || ag!=48) $fatal(1,"opposed keys changed parameters");
 btn=14; cycles(3200); btn=15; cycles(150); if(ae!=3) $fatal(1,"lower clamp %d",ae);
 btn=13; cycles(3200); btn=15; cycles(150); if(ae!=2244) $fatal(1,"upper clamp");
 btn=11; cycles(900); btn=15; cycles(150); if(ag!=16) $fatal(1,"gain lower");
 btn=7; cycles(1700); btn=15; cycles(150); if(ag!=89) $fatal(1,"gain upper");
 $display("PASS controls: initialization, bounce, four keys, repeat, limits, opposing keys, busy payload"); $finish;
end
initial begin #2000000; $fatal(1,"timeout"); end
endmodule
// Only the bus engine is stubbed: production init table, gain table and writer run.
module uii2c #(parameter WMEN_LEN=4,RMEN_LEN=1,CLK_DIV=1)(
 input I_clk,I_rstn,input [31:0] I_wr_data,input [7:0] I_wr_cnt,I_rd_cnt,
 input I_iic_mode,I_iic_req,output reg O_iic_busy,output O_iic_scl,
 inout IO_iic_sda,output [7:0] O_rd_data,output O_iic_bus_error);
reg [3:0] n;
assign O_iic_scl=1; assign O_rd_data=0; assign O_iic_bus_error=0;
always @(posedge I_clk or negedge I_rstn) begin
 if(!I_rstn) begin n<=0; O_iic_busy<=0; end
 else if(!O_iic_busy && I_iic_req) begin n<=10; O_iic_busy<=1; end
 else if(n!=0) n<=n-1'b1;
 else O_iic_busy<=0;
end
endmodule
