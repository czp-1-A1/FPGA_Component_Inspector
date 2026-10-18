`timescale 1ns / 1ps
/*****************************************************************
Company : MiLianKe Electronic Technology Co., Ltd.
WebSite:https://www.milianke.com
TechWeb:https://www.uisrc.com
tmall-shop:https://milianke.tmall.com
jd-shop:https://milianke.jd.com
taobao-shop: https://milianke.taobao.com
Description: 
The reference demo provided by Milianke is only used for learning. 
We cannot ensure that the demo itself is free of bugs, so users 
should be responsible for the technical problems and consequences
caused by the use of their own products.
@Author      :   XiaoQingquan 
@Time        :   2024/10 
version:     :   1.0
@Description :   使用BRAM进行FIFO整合，并且不影响下一帧的数据传输
*****************************************************************/


module zhenghe#(
    parameter [12:0] IMG_WIDTH  = 640,
    parameter [12:0] IMG_HEIGHT = 480,
    parameter [8:0]  DATA_WIDTH = 96 ,
    parameter [8:0]  data_complete_delay = 50 //每行BRAM完成数据传输后与这行最后一个数据的距离
) 
(
    input                   I_clk  ,
    input                   I_rst_n,

    input                   I_tlast  ,
    input                   I_tuser  ,
    input [DATA_WIDTH-1:0]  I_tdata  ,
    input                   I_tvalid , 

    output reg              O_tlast  ,
    output reg              O_tuser  ,
    output [DATA_WIDTH-1:0] O_tdata  ,
    output reg              O_tvalid 
);
    localparam IMG_WIDTH_4x = IMG_WIDTH >> 2;
    localparam CREDIT_BITS = $clog2(IMG_WIDTH_4x*IMG_HEIGHT+1);
    reg [10:0] addra,addrb;
    reg valid_r0,row_reading;
    reg [DATA_WIDTH-1:0] data_d0;
    wire [DATA_WIDTH-1:0] data_d;
    reg [CREDIT_BITS-1:0] written_words,read_words;
    wire [CREDIT_BITS-1:0] available_words=written_words-read_words;
    // Start from this row's committed data, never the previous frame's timing.
    // Once started, pause only when the reader catches the committed writer.
    wire rd_valid=(available_words!=0) &&
                  (row_reading || available_words>=data_complete_delay);
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin valid_r0<=0;data_d0<=0;end
        else begin valid_r0<=I_tvalid;data_d0<=I_tdata;end
    end
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n || I_tuser)begin
            addra<=0;addrb<=0;written_words<=0;read_words<=0;row_reading<=0;
        end else begin
            if(valid_r0)begin
                written_words<=written_words+1'b1;
                addra<=addra==IMG_WIDTH_4x-1 ? 0 : addra+1'b1;
            end
            if(rd_valid)begin
                read_words<=read_words+1'b1;
                addrb<=addrb==IMG_WIDTH_4x-1 ? 0 : addrb+1'b1;
                row_reading<=addrb!=IMG_WIDTH_4x-1;
            end
        end
    end
    blk_mem_gen_zhenghe blk_mem_gen_zhenghe_d1 (
      .clka (I_clk   ),  // input wire clka
      .wea  (valid_r0),  // input wire [0 : 0] wea
      .addra(addra   ),  // input wire [10 : 0] addra
      .dia (data_d0 ),  // input wire [95 : 0] dina
      .web  (1'b0),  // read-only port B
      .dib  (32'd0), // unused write data
      .clkb (I_clk   ),  // input wire clkb
      .addrb(addrb   ),  // input wire [10 : 0] addrb
      .dob(data_d  )   // output wire [95 : 0] doutb
    );
    wire O_tuser_d=rd_valid && read_words==0;
    wire O_tvalid_d=rd_valid;
    wire O_tlast_d=rd_valid && addrb==IMG_WIDTH_4x-1;
    assign O_tdata=data_d;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_tuser  <= 0;
            O_tvalid <= 0;
            O_tlast  <= 0;
        end else begin
            O_tuser  <= O_tuser_d;
            O_tvalid <= O_tvalid_d;
            O_tlast  <= O_tlast_d;
        end
    end  
    
endmodule