`timescale 1ns/1ps
module tb_camera_startup_bus;
 reg clk=0,rst=0,slave_low=0; always #5 clk=~clk;
 wire req,cam_done,done,scl,wb_tune;wire [15:0] ae,ag,errors;wire[31:0] wb;
 tri1 sda; assign sda=slave_low ? 1'b0:1'bz;
 ae_set defaults(.I_clk(clk),.I_rst(!rst),.I_btn(4'b1111),
  .I_ae_cfg_done(done),.I_cam_cfg_done(cam_done),.O_ae_req(req),
  .O_ae(ae),.O_ag(ag),.O_wb_tune(wb_tune),.O_wb_request(wb));
 uicfgcs500 #(.CLK_DIV(31)) dut(.I_clk(clk),.I_rst_n(rst),
  .I_ae_req(req),.I_ae(ae),.I_ag(ag),.O_cam_scl(scl),.IO_cam_sda(sda),
  .O_cfg_done(cam_done),.O_ae_cfg_done(done),.O_i2c_errors(errors));
 reg[31:0] expected[0:125];
 reg active=0;reg[7:0] shift=0;reg[31:0] packet=0;
 integer bits=0,bytes=0,count=0,epoch;
 always @(negedge sda)if(rst && scl===1'b1)begin active=1;bits=0;bytes=0;packet=0;end
 always @(negedge scl)slave_low=active && bits==8;
 always @(posedge scl)if(active)begin
  if(bits<8)begin shift={shift[6:0],sda};bits=bits+1;end
  else begin packet={packet[23:0],shift};bytes=bytes+1;bits=0;end
 end
 always @(posedge sda)if(rst && scl===1'b1 && active)begin
  active=0;
  if(bytes!=4 || count>=126)$fatal(1,"invalid I2C packet length/count");
  if(packet!==expected[count])$fatal(1,"write%0d actual%08h expected%08h",count+1,packet,expected[count]);
  count=count+1;$display("BUS %0d %08h",count,packet);
 end
 initial begin
  $readmemh("camera_expected.hex",expected);
  for(epoch=0;epoch<2;epoch=epoch+1)begin
   rst=0;active=0;slave_low=0;count=0;#200;rst=1;
   wait(done);#1000;
   if(count!=126 || errors!=0 || ae!=1092 || ag!=40 || req || wb_tune || wb!==32'h00006464)
    $fatal(1,"camera startup/default/NACK mismatch count%0d errors%0d",count,errors);
   #1000;
  end
  $display("PASS CAMERA RTL BUS: 2 resets x126 complete serialized I2C packets, EXP1092 GAIN40 WB100/100, zero NACK; no optical sensor readback");
  $finish;
 end
 initial begin #100000000;$fatal(1,"startup timeout");end
endmodule
