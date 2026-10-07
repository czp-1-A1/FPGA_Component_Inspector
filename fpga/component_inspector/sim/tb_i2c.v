`timescale 1ns/1ps
module tb_i2c;
reg clk=0,rst=0,req=0,slave_low=0,enable_ack=1;
always #5 clk=~clk;
wire scl,busy,error;tri1 sda;
assign sda=slave_low ? 1'b0 : 1'bz;
uii2c #(.WMEN_LEN(4),.RMEN_LEN(1),.CLK_DIV(19)) dut(
 .I_clk(clk),.I_rstn(rst),.O_iic_scl(scl),.IO_iic_sda(sda),
 .I_wr_data(32'h8c013e6c),.I_wr_cnt(8'd4),.I_rd_cnt(8'd0),
 .I_iic_req(req),.I_iic_mode(1'b0),.O_iic_busy(busy),.O_iic_bus_error(error));
reg active=0,saw_error=0;
integer bit_count=0,byte_count=0,starts=0,stops=0;
reg [7:0] shift=0;
always @(negedge sda) if(rst && scl===1'b1) begin
 active=1;bit_count=0;byte_count=0;starts=starts+1;
end
always @(posedge sda) if(rst && scl===1'b1 && active) begin
 active=0;stops=stops+1;
 if(byte_count!=4) $fatal(1,"write byte count %d",byte_count);
end
always @(negedge scl) if(active) slave_low=(bit_count==8 && enable_ack); else slave_low=0;
always @(posedge scl) if(active) begin
 if(bit_count<8) begin shift={shift[6:0],sda};bit_count=bit_count+1; end
 else begin
  case(byte_count)
   0: if(shift!=8'h6c) $fatal(1,"address %h",shift);
   1: if(shift!=8'h3e) $fatal(1,"register high %h",shift);
   2: if(shift!=8'h01) $fatal(1,"register low %h",shift);
   3: if(shift!=8'h8c) $fatal(1,"write value %h",shift);
  endcase
  byte_count=byte_count+1;bit_count=0;
 end
end
always @(posedge clk) if(error) saw_error=1;
task write;begin
 @(negedge clk);req=1;wait(busy);@(negedge clk);req=0;wait(!busy);repeat(50) @(negedge clk);
end endtask
initial begin
 repeat(5) @(negedge clk);rst=1;repeat(50) @(negedge clk);
 write;
 if(starts!=1 || stops!=1 || saw_error) $fatal(1,"ACK transaction %d %d %d",starts,stops,saw_error);
 enable_ack=0;write;
 if(starts!=2 || stops!=2 || !saw_error) $fatal(1,"NACK transaction");
 $display("PASS I2C actual bus: START, four correct bytes, ACK, STOP, NACK detection");$finish;
end
initial begin #200000;$fatal(1,"I2C timeout");end
endmodule
