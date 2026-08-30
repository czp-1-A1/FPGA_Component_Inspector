`timescale 1ns / 1ps
//******************************************************************** 
// -------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>Copyright Notice<<<<<<<<<<<<<<<<<<<<<<<<<<<< 
// ------------------------------------------------------------------- 
//             /\ --------------- 
//            /  \ ------------- 
//           / /\ \ -----------
//          / /  \ \ ---------
//         / /    \ \ ------- 
//        / /      \ \ ----- 
//       / /_ _ _   \ \ --- 
//      /_ _ _ _ _\  \_\ -
//********************************************************************
// Author: suluyang 
// Email:luyang.su@anlogic.com 
// Date:2020/10/16 
// Description: 
// 1.0:Date:2020/10/16 通用RAM FIFO模块建立，支持PH1器件和EG4器件
// 2.0:Date:2022/03/08 通用软核BRAM FIFO模块建立
//
// web：www.anlogic.com 
//-------------------------------------------------------------------- 
//*******************************************************************/

module ram_fifo (
    rst,
    di, 
    clkr, 
    re, 
    clkw, 
    we,
    do,
    empty_flag,
    full_flag,
    rdusedw,
    wrusedw,
    afull,
    aempty
);
    // parameter DEVICE     = "PH1";//"PH1","EG4","SF1","EF2","EF3","AL"
    // parameter DATA_WIDTH = 8;    //"1~432"
    // parameter ADDR_WIDTH = 10;   //"2~15"
    // parameter SHOWAHEAD  = 1;    //"1","0"

    parameter DEVICE       = "PH1"  ;//"PH1","PH1A400","EG4","SF1","EF2","EF3","AL"
    parameter OUTREG_EN    = 0      ;//BRAM NOREG/OUTREG
    parameter DATA_WIDTH_W = 8      ;//写数据位宽
    parameter ADDR_WIDTH_W = 16     ;//写地址位宽
    parameter DATA_WIDTH_R = 8      ;//读数据位宽
    parameter ADDR_WIDTH_R = 16     ;//读地址位宽
    parameter AL_FULL_NUM  = 2**ADDR_WIDTH_W-2;
    parameter AL_EMPTY_NUM = 2      ;
    parameter SHOW_AHEAD_EN= 0      ;//普通/SHOWAHEAD模式

    input                     rst;
    input   [DATA_WIDTH_W-1:0]di;
    input                     clkr;
    input                     re;
    input                     clkw;
    input                     we;
    output  [DATA_WIDTH_R-1:0]do;
    output                    empty_flag;
    output                    full_flag;
    output  [ADDR_WIDTH_R:0]  rdusedw;
    output  [ADDR_WIDTH_W:0]  wrusedw;
    output                    afull ;
    output                    aempty ;

generic_async_fifo
#(
    .DEVICE         (DEVICE         ),//"PH1","PH1A400","EG4","SF1","EF2","EF3","AL"
    .OUTREG_EN      (OUTREG_EN      ),//BRAM NOREG/OUTREG
    .DATA_WIDTH_W   (DATA_WIDTH_W   ),//写数据位宽
    .ADDR_WIDTH_W   (ADDR_WIDTH_W   ),//写地址位宽
    .DATA_WIDTH_R   (DATA_WIDTH_R   ),//读数据位宽
    .ADDR_WIDTH_R   (ADDR_WIDTH_R   ),//读地址位宽
    .AL_FULL_NUM    (AL_FULL_NUM    ),
    .AL_EMPTY_NUM   (AL_EMPTY_NUM   ),
    .SHOW_AHEAD_EN  (SHOW_AHEAD_EN  )//普通/SHOWAHEAD模式
)
u_anlogic_soft_async_fifo
(
    .rst            (rst            ),//input                           
    .we             (we             ),//input                           
    .di             (di             ),//input   wire [DATA_WIDTH_W-1:0] 
    .re             (re             ),//input                           
    .clkr           (clkr           ),//input                           
    .clkw           (clkw           ),//input                           
    .full_flag      (full_flag      ),//output reg                      
    .dout           (do             ),//output wire [DATA_WIDTH_R-1:0]  
    .empty_flag     (empty_flag     ),//output reg                      
    .wrusedw        (wrusedw        ),//output [ADDR_WIDTH_W:0]         //写一侧看到的当前内部现存counter
    .rdusedw        (rdusedw        ),//output [ADDR_WIDTH_R:0]         //读一侧看到的当前内部现存counter
    .afull          (afull          ),//output 
    .aempty         (aempty         )//output 
);


endmodule


module generic_async_fifo
#(
    parameter DEVICE       = "PH1",//"PH1","PH1A400","EG4","SF1","EF2","EF3","AL"
    parameter OUTREG_EN    = 0,//BRAM NOREG/OUTREG
    parameter DATA_WIDTH_W = 8,//写数据位宽
    parameter ADDR_WIDTH_W = 16,//写地址位宽
    parameter DATA_WIDTH_R = 8,//读数据位宽
    parameter ADDR_WIDTH_R = 16,//读地址位宽
    parameter AL_FULL_NUM  = 2**ADDR_WIDTH_W-2,
    parameter AL_EMPTY_NUM = 2,
    parameter SHOW_AHEAD_EN= 0//普通/SHOWAHEAD模式
)
(
    input                       rst       ,
    input                       we        ,
    input   wire [DATA_WIDTH_W-1:0]di     ,
    input                       re        ,
    input                       clkr      ,
    input                       clkw      ,
    output reg                  full_flag ,
    output wire [DATA_WIDTH_R-1:0]  dout  ,
    output reg                  empty_flag,
    output [ADDR_WIDTH_W:0]     wrusedw   ,//写一侧看到的当前内部现存counter
    output [ADDR_WIDTH_R:0]     rdusedw   ,//读一侧看到的当前内部现存counter
    output afull                          ,
    output aempty                         
);

localparam BRAM_OUTREG = OUTREG_EN ? "OUTREG": "NOREG" ;

wire rrst;
wire wrst;
assign rrst = rst;
assign wrst = rst;

// wire [ADDR_WIDTH_R:0]        rdusedw;
// wire [ADDR_WIDTH_W:0]        wrusedw;
reg     [ADDR_WIDTH_R:0]        rdaddress; 
reg     [ADDR_WIDTH_W:0]        wraddress;
reg     [ADDR_WIDTH_R:0]        gray_rdaddress;
reg     [ADDR_WIDTH_W:0]        gray_wraddress;
/*同步寄存器*/
reg     [ADDR_WIDTH_W:0]        sync_w2r_r1,sync_w2r_r2;
reg     [ADDR_WIDTH_R:0]        sync_r2w_r1,sync_r2w_r2;
wire    [ADDR_WIDTH_R:0]        sync_rdaddress;
wire    [ADDR_WIDTH_W:0]        sync_wraddress;
wire    [ADDR_WIDTH_R:0]        shift_rdaddress;
wire    [ADDR_WIDTH_W:0]        shift_wraddress;
wire                            fifo_empty;
wire                            fifo_full;
wire    [ADDR_WIDTH_W:0]        wr_data_full_W;
wire    [ADDR_WIDTH_W:0]        rd_data_full_W;
wire    [ADDR_WIDTH_R+1:0]      wr_data_full_R;
wire    [ADDR_WIDTH_R+1:0]      rd_data_full_R;
wire    [ADDR_WIDTH_R+1:0]      shifter_wr_afull_R;
wire    [ADDR_WIDTH_W:0]        shifter_rd_afull_W;
wire    [ADDR_WIDTH_R:0]        shifter_wr_aempty_R;
wire    [ADDR_WIDTH_R:0]        wr_data_empty_R;    
wire    [ADDR_WIDTH_R:0]        rd_data_empty_R ;   
wire    [ADDR_WIDTH_W:0]        shifter_rd_aempty_W;
wire    [ADDR_WIDTH_W:0]        wr_data_empty_W;    
wire    [ADDR_WIDTH_W:0]        rd_data_empty_W ;   
//需要将地址乘以个倍数后，再转化为格雷码//保留数据比较宽的位.
wire    [ADDR_WIDTH_R:0]        rdaddress_next;
wire    [ADDR_WIDTH_R:0]        gray_rdaddress_next;
wire    [ADDR_WIDTH_W:0]        wraddress_next;
wire    [ADDR_WIDTH_W:0]        gray_wraddress_next;
wire                            fifo_re;
wire                            fifo_we;

assign shift_rdaddress = ( ADDR_WIDTH_R >= ADDR_WIDTH_W ) ? (rdaddress_next ) >> ( ADDR_WIDTH_R - ADDR_WIDTH_W ) : (rdaddress_next);
assign shift_wraddress = ( ADDR_WIDTH_W >= ADDR_WIDTH_R ) ? wraddress_next >> ( ADDR_WIDTH_W - ADDR_WIDTH_R ) : wraddress_next;
assign fifo_re = (re & (!fifo_empty));
assign fifo_we = (we & (!full_flag));
assign rdaddress_next = (fifo_re ? (rdaddress + 1'b1) : rdaddress); 
assign wraddress_next = (fifo_we ? (wraddress +1'b1) : wraddress);

/*二进制转化为格雷码计数器*/
assign gray_rdaddress_next = (shift_rdaddress >>1) ^ shift_rdaddress;//bin to gray.

/*二进制转化为格雷码计数器*/
assign gray_wraddress_next = (shift_wraddress >>1) ^ shift_wraddress;//bin to gray.

generate 
begin: GEN_EMPTY
    if ( ADDR_WIDTH_R <= ADDR_WIDTH_W ) 
    begin
        assign fifo_empty = (gray_rdaddress[ADDR_WIDTH_R:0] == sync_w2r_r2[ADDR_WIDTH_R:0]);
    end
    else
    begin
        assign fifo_empty = (gray_rdaddress[ADDR_WIDTH_W:0] == sync_w2r_r2[ADDR_WIDTH_W:0]);                                                        
    end
end
endgenerate

//assign fifo_full =  (gray_wraddress == {~sync_r2w_r2[ADDR_WIDTH_R:ADDR_WIDTH_W-1],sync_r2w_r2[ADDR_WIDTH_W-2:0]});    //右侧为gray_rdaddress转换而来
//如果读地址较窄，写地址较宽，gray_wraddress已经左移过了，则比较ADDR_WIDTH_R宽；如果读地址宽，写地址窄，gray_rdaddress已经左移过了，则比较ADDR_WIDTH_W宽
generate 
begin: GEN_FULL
    if ( ADDR_WIDTH_R <= ADDR_WIDTH_W ) 
    begin
        assign fifo_full =  (gray_wraddress[ADDR_WIDTH_R:0] == {~sync_r2w_r2[ADDR_WIDTH_R:ADDR_WIDTH_R-1],sync_r2w_r2[ADDR_WIDTH_R-2:0]});
    end
    else
    begin
        assign fifo_full =  (gray_wraddress[ADDR_WIDTH_W:0] == {~sync_r2w_r2[ADDR_WIDTH_W:ADDR_WIDTH_W-1],sync_r2w_r2[ADDR_WIDTH_W-2:0]});                                                         
    end
end
endgenerate

generate
if(DEVICE == "PH1" || DEVICE == "PH1A400" )
begin
    PH1_LOGIC_ERAM#(
    .DATA_WIDTH_A(DATA_WIDTH_W),
    .DATA_WIDTH_B(DATA_WIDTH_R),
    .ADDR_WIDTH_A(ADDR_WIDTH_W),
    .ADDR_WIDTH_B(ADDR_WIDTH_R),
    .DATA_DEPTH_A(2**ADDR_WIDTH_W),
    .DATA_DEPTH_B(2**ADDR_WIDTH_R),
    .MODE("PDPW"),
    .REGMODE_A("NOREG"),
    .REGMODE_B(BRAM_OUTREG),
    .WRITEMODE_A("NORMAL"),
    .WRITEMODE_B("NORMAL"),
    .IMPLEMENT("20K"),
    .ECC_ENCODE("DISABLE"),
    .ECC_DECODE("DISABLE"),
    .CLKMODE("ASYNC"),
    .SSROVERCE("DISABLE"),
    .OREGSET_A("SET"),
    .OREGSET_B("SET"),
    .RESETMODE_A("ASYNC"),
    .RESETMODE_B("ASYNC"),
    .ASYNC_RESET_RELEASE_A("ASYNC"),
    .ASYNC_RESET_RELEASE_B("SYNC"),
    .INIT_FILE("NONE"),
    .FILL_ALL("NONE"))
    inst(
    .dia(di),
    .dib('b0),
    .addra(wraddress[ADDR_WIDTH_W-1:0]),
    .addrb(rdaddress[ADDR_WIDTH_R-1:0]+ (SHOW_AHEAD_EN &fifo_re)),
    .cea((fifo_we)),
    .ceb( (SHOW_AHEAD_EN == 1'b1) ? (1'b1): (fifo_re) ),
    .ocea(1'b0),
    .oceb(OUTREG_EN),
    .clka(clkw),
    .clkb(clkr),
    .wea(1'b1),
    .web(1'b0),
    .bea(1'b0),
    .beb(1'b0),
    .rsta(1'b0),
    .rstb(1'b0),
    .ecc_sbiterr(open),
    .ecc_dbiterr(open),
    .doa(),
    .dob(dout)
    );
end 
else if(DEVICE == "EG4")
begin
    EG_LOGIC_BRAM#( 
    .DATA_WIDTH_A(DATA_WIDTH_W),
    .DATA_WIDTH_B(DATA_WIDTH_R),
    .ADDR_WIDTH_A(ADDR_WIDTH_W),
    .ADDR_WIDTH_B(ADDR_WIDTH_R),
    .DATA_DEPTH_A(2**ADDR_WIDTH_W),
    .DATA_DEPTH_B(2**ADDR_WIDTH_R),
    .MODE("PDPW"),
    .REGMODE_A("NOREG"),
    .REGMODE_B(BRAM_OUTREG),
    .WRITEMODE_A("NORMAL"),
    .WRITEMODE_B("NORMAL"),
    .IMPLEMENT("9K"),           
    .RESETMODE("ASYNC"),
    .INIT_FILE("NONE"),
    .FILL_ALL("NONE"))
    inst(
    .dia(di),
    .dib('b0),
    .addra(wraddress[ADDR_WIDTH_W-1:0]),
    .addrb(rdaddress[ADDR_WIDTH_R-1:0]+ (SHOW_AHEAD_EN &fifo_re)),
    .cea((fifo_we)),
    //.ceb(1'b1),
    .ceb( (SHOW_AHEAD_EN == 1'b1) ? (1'b1): fifo_re ),
    .ocea(1'b0),
    .oceb(OUTREG_EN),
    .clka(clkw),
    .clkb(clkr),
    .wea(1'b1),
    .web(1'b0),
    .bea(1'b0),
    .beb(1'b0),
    .rsta(1'b0),
    .rstb(1'b0),
    .doa(),
    .dob(dout));
end 
else if(DEVICE == "AL")
begin
    AL_LOGIC_BRAM#( 
    .DATA_WIDTH_A(DATA_WIDTH_W),
    .DATA_WIDTH_B(DATA_WIDTH_R),
    .ADDR_WIDTH_A(ADDR_WIDTH_W),
    .ADDR_WIDTH_B(ADDR_WIDTH_R),
    .DATA_DEPTH_A(2**ADDR_WIDTH_W),
    .DATA_DEPTH_B(2**ADDR_WIDTH_R),
    .MODE("PDPW"),
    .REGMODE_A("NOREG"),
    .REGMODE_B(BRAM_OUTREG),                
    .WRITEMODE_A("NORMAL"),
    .WRITEMODE_B("NORMAL"),
    .IMPLEMENT("9K"),           
    .RESETMODE("ASYNC"),
    .INIT_FILE("NONE"),
    .FILL_ALL("NONE"))
    inst(
    .dia(di),
    .dib('b0),
    .addra(wraddress[ADDR_WIDTH_W-1:0]),
    .addrb(rdaddress[ADDR_WIDTH_R-1:0]+ (SHOW_AHEAD_EN &fifo_re)),
    .cea((fifo_we)),
    .ceb( (SHOW_AHEAD_EN == 1'b1) ? (1'b1): fifo_re ),
    .ocea(1'b0),
    //.oceb(1'b0),
    .oceb(OUTREG_EN),               
    .clka(clkw),
    .clkb(clkr),
    .wea(1'b1),
    .web(1'b0),
    .bea(1'b0),
    .beb(1'b0),
    .rsta(1'b0),
    .rstb(1'b0),
    .doa(),
    .dob(dout));
end 
else if(DEVICE == "EF2")
begin
    EF2_LOGIC_BRAM#( 
    .DATA_WIDTH_A(DATA_WIDTH_W),
    .DATA_WIDTH_B(DATA_WIDTH_R),
    .ADDR_WIDTH_A(ADDR_WIDTH_W),
    .ADDR_WIDTH_B(ADDR_WIDTH_R),
    .DATA_DEPTH_A(2**ADDR_WIDTH_W),
    .DATA_DEPTH_B(2**ADDR_WIDTH_R),
    .MODE("PDPW"),
    .REGMODE_A("NOREG"),
    .REGMODE_B(BRAM_OUTREG),                
    .WRITEMODE_A("NORMAL"),
    .WRITEMODE_B("NORMAL"),
    .IMPLEMENT("9K"),           
    .RESETMODE("ASYNC"),
    .INIT_FILE("NONE"),
    .FILL_ALL("NONE"))
    inst(
    .dia(di),
    .dib('b0),
    .addra(wraddress[ADDR_WIDTH_W-1:0]),
    .addrb(rdaddress[ADDR_WIDTH_R-1:0]+ (SHOW_AHEAD_EN &fifo_re)),
    .cea((fifo_we)),
    //.ceb(1'b1),
    .ceb( (SHOW_AHEAD_EN == 1'b1) ? (1'b1): fifo_re ),              .ocea(1'b0),
    //.oceb(1'b0),              
    .oceb(OUTREG_EN),                               
    .clka(clkw),
    .clkb(clkr),
    .wea(1'b1),
    .web(1'b0),
    .bea(1'b0),
    .beb(1'b0),
    .rsta(1'b0),
    .rstb(1'b0),
    .doa(),
    .dob(dout));
end 
else if(DEVICE == "EF3")
begin
    EF3_LOGIC_BRAM#( 
    .DATA_WIDTH_A(DATA_WIDTH_W),
    .DATA_WIDTH_B(DATA_WIDTH_R),
    .ADDR_WIDTH_A(ADDR_WIDTH_W),
    .ADDR_WIDTH_B(ADDR_WIDTH_R),
    .DATA_DEPTH_A(2**ADDR_WIDTH_W),
    .DATA_DEPTH_B(2**ADDR_WIDTH_R),
    .MODE("PDPW"),
    .REGMODE_A("NOREG"),
    .REGMODE_B(BRAM_OUTREG),
    .WRITEMODE_A("NORMAL"),
    .WRITEMODE_B("NORMAL"),
    .IMPLEMENT("9K"),           
    .RESETMODE("ASYNC"),
    .INIT_FILE("NONE"),
    .FILL_ALL("NONE"))
    inst(
    .dia(di),
    .dib('b0),
    .addra(wraddress[ADDR_WIDTH_W-1:0]),
    .addrb(rdaddress[ADDR_WIDTH_R-1:0]+ (SHOW_AHEAD_EN &fifo_re)),
    .cea((fifo_we)),
    //.ceb(1'b1),
    .ceb( (SHOW_AHEAD_EN == 1'b1) ? (1'b1): fifo_re ),              .ocea(1'b0),
    //.oceb(1'b0),
    .oceb(OUTREG_EN),               
    .clka(clkw),
    .clkb(clkr),
    .wea(1'b1),
    .web(1'b0),
    .bea(1'b0),
    .beb(1'b0),
    .rsta(1'b0),
    .rstb(1'b0),
    .doa(),
    .dob(dout));
end 
else if(DEVICE == "SF1")
begin
    SF1_LOGIC_BRAM#( 
    .DATA_WIDTH_A(DATA_WIDTH_W),
    .DATA_WIDTH_B(DATA_WIDTH_R),
    .ADDR_WIDTH_A(ADDR_WIDTH_W),
    .ADDR_WIDTH_B(ADDR_WIDTH_R),
    .DATA_DEPTH_A(2**ADDR_WIDTH_W),
    .DATA_DEPTH_B(2**ADDR_WIDTH_R),
    .MODE("PDPW"),
    .REGMODE_A("NOREG"),
    .REGMODE_B(BRAM_OUTREG),
    .WRITEMODE_A("NORMAL"),
    .WRITEMODE_B("NORMAL"),
    .IMPLEMENT("9K"),           
    .RESETMODE("ASYNC"),
    .INIT_FILE("NONE"),
    .FILL_ALL("NONE"))
    inst(
    .dia(di),
    .dib('b0),
    .addra(wraddress[ADDR_WIDTH_W-1:0]),
    .addrb(rdaddress[ADDR_WIDTH_R-1:0]+ (SHOW_AHEAD_EN &fifo_re)),
    .cea((fifo_we)),
    //.ceb(1'b1),
    .ceb( (SHOW_AHEAD_EN == 1'b1) ? (1'b1): fifo_re ),              .ocea(1'b0),
    //.oceb(1'b0),
    .oceb(OUTREG_EN),               
    .clka(clkw),
    .clkb(clkr),
    .wea(1'b1),
    .web(1'b0),
    .bea(1'b0),
    .beb(1'b0),
    .rsta(1'b0),
    .rstb(1'b0),
    .doa(),
    .dob(dout));
end 
endgenerate



/*在读时钟域同步FIFO空 sync_w2r_r2 为同步的写指针地址 延迟两拍 非实际 写指针值 但是确保不会发生未写入数据就读取*/   
always@(*)
begin
    empty_flag <=  fifo_empty;//
end

/*在写时钟域判断FIFO满 sync_r2w_r2 实际延迟两个节拍 可能存在非满判断为满 但不会导致覆盖*/
always@(*)
begin                           
    full_flag <=  fifo_full;//格雷码判断追及问题//
end

/*写数据地址生成*/
always@(posedge clkw or posedge wrst)
if(wrst)
begin
    wraddress <= 'b0;
    gray_wraddress <= 'b0;
end
else
begin
    wraddress <= wraddress_next;//
    gray_wraddress <=  gray_wraddress_next;//
end

/*读数据地址生成*/
always@(posedge clkr or posedge rrst)
if(rrst)
begin
    rdaddress <= 'b0;
    gray_rdaddress <= 'b0;
end
else 
begin
    rdaddress <=  rdaddress_next;//
    gray_rdaddress <= gray_rdaddress_next;//
    
end

/*同步读地址到写时钟域*/
always@(posedge clkw or posedge wrst)
if(wrst )
begin
    sync_r2w_r1 <= 'd0;
    sync_r2w_r2 <= 'd0;
end 
else 
begin
    sync_r2w_r1 <=  gray_rdaddress;//
    sync_r2w_r2 <=  sync_r2w_r1;    //  
end

/*同步写地址到读时钟域, 同步以后 存在延迟两个节拍*/
always@(posedge clkr or posedge rrst)
if(rrst  )
begin
    sync_w2r_r1 <= 'd0;
    sync_w2r_r2 <= 'd0;
end 
else 
begin
    sync_w2r_r1 <=  gray_wraddress ;//
    sync_w2r_r2 <=  sync_w2r_r1;    //  
end

gray2bin#(
    .WIDTH(ADDR_WIDTH_W+1))
u6 (
.din   (sync_w2r_r2),
.dout  (sync_wraddress)
);
                
gray2bin#(
    .WIDTH(ADDR_WIDTH_R+1))
u7(
.din   (sync_r2w_r2),
.dout  (sync_rdaddress)
);


//格雷码地址gray_wraddress /gray_rdaddress 已经转换为较小宽度；
assign rdusedw =  ( ADDR_WIDTH_R >= ADDR_WIDTH_W ) ? ( ( sync_wraddress << ( ADDR_WIDTH_R - ADDR_WIDTH_W )) - rdaddress ) : ( sync_wraddress - rdaddress );
assign wrusedw =  ( ADDR_WIDTH_W >= ADDR_WIDTH_R ) ? ( wraddress - ( sync_rdaddress << ( ADDR_WIDTH_W - ADDR_WIDTH_R )) ) : ( wraddress - sync_rdaddress );

// almost_aempty    
generate 
begin:GEN_AEMPTY
    if ( ADDR_WIDTH_R >= ADDR_WIDTH_W ) 
    begin
        assign shifter_wr_aempty_R =  (sync_wraddress << ( ADDR_WIDTH_R - ADDR_WIDTH_W ));
        assign wr_data_empty_R = {shifter_wr_aempty_R[ADDR_WIDTH_R] ^ rdaddress[ADDR_WIDTH_R] ,shifter_wr_aempty_R[ADDR_WIDTH_R-1:0]} ;
        assign rd_data_empty_R = rdaddress[ADDR_WIDTH_R-1:0] + AL_EMPTY_NUM  ;
        assign aempty   = ((wr_data_empty_R)  <= rd_data_empty_R);
    end
    else
    begin
        assign aempty   = rdusedw <= AL_EMPTY_NUM; 
    end
 end
endgenerate

generate 
begin:GEN_AFULL
    if ( ADDR_WIDTH_R <= ADDR_WIDTH_W ) 
    begin
        assign shifter_rd_afull_W =  (sync_rdaddress[ADDR_WIDTH_R:0] << ( ADDR_WIDTH_W - ADDR_WIDTH_R ));
        assign wr_data_full_W = {wraddress[ADDR_WIDTH_W] ^shifter_rd_afull_W [ADDR_WIDTH_W] ,wraddress[ADDR_WIDTH_W-1:0]} ;
        assign rd_data_full_W = shifter_rd_afull_W[ADDR_WIDTH_W-1:0] + AL_FULL_NUM  ;
        assign afull   = ((wr_data_full_W)  >= rd_data_full_W);//(sync_wraddress <= (rdaddress + AL_EMPTY_NUM));   
    end
    else
    begin
        assign afull   =  (wrusedw  >= AL_FULL_NUM);//(wraddress >=sync_rdaddress+ AL_FULL_NUM); 
    end
 end
endgenerate

//参数check，读写位宽的倍数与深度要匹配
initial
begin
    if ( DATA_WIDTH_W * (2**ADDR_WIDTH_W) != DATA_WIDTH_R * (2**ADDR_WIDTH_R) )
    begin
        $display("Error parameter, dept and width of write port not match those of read port");
        $stop;
    end
end

//synthesis translate_off
integer                     wr_ptr, rd_ptr;
reg                         re_reg;
initial 
begin
wr_ptr = $fopen("fifo_wr_data.dat");
if (wr_ptr == 0) $finish;
rd_ptr = $fopen("fifo_rd_data.dat");
if (rd_ptr == 0) $finish;
end

integer             i;
generate if ( DATA_WIDTH_R <= DATA_WIDTH_W ) 
begin: LOG_PRINT_TO_FILE
    reg [DATA_WIDTH_R-1:0]  di_print;

    always @ ( posedge clkw )
    begin
        if ( we )
        begin
            for(i=0;i< DATA_WIDTH_W/DATA_WIDTH_R;i=i+1)
            begin
                di_print = (di>>DATA_WIDTH_R*i);
               $fdisplay(wr_ptr,"%h",di_print);
               $display("write fifo:%h", di_print);
            end
        end
    end

    always @ ( posedge clkr )
    begin
        re_reg  <= re;
        if ( SHOW_AHEAD_EN )
        begin
            if ( re )
            begin
                $fdisplay(rd_ptr,"%h",dout);
                $display("read fifo:%h", dout);
            end
        end
        else
        begin
            if ( re_reg )
            begin
                $fdisplay(rd_ptr,"%h",dout);
                $display("read fifo:%h", dout);
            end
        end
    end
end
else
begin
    reg     [DATA_WIDTH_W-1:0]  do_print;

    always @ ( posedge clkw )
    begin
        if ( we )
        begin
            $fdisplay(wr_ptr,"%h",di);
            $display("write fifo:%h", di);
        end
    end

    always @ ( posedge clkr )
    begin
        re_reg  <= re;
        if ( SHOW_AHEAD_EN )
        begin
            if ( re )
            begin
                for(i=0;i< DATA_WIDTH_R/DATA_WIDTH_W;i=i+1)
                begin
                    do_print = (dout>>DATA_WIDTH_W*i);
                    $fdisplay(rd_ptr,"%h",do_print );
                    $display("read fifo:%h", do_print);
                end
            end
        end
        else
        begin
            if ( re_reg )
            begin
                for(i=0;i< DATA_WIDTH_R/DATA_WIDTH_W;i=i+1)
                begin
                    do_print = (dout>>DATA_WIDTH_W*i);
                    $fdisplay(rd_ptr,"%h",do_print);
                    $display("read fifo:%h", do_print);
                end
            end
        end
    end
end
endgenerate

//synthesis translate_on

endmodule

module gray2bin (
                  // Inputs
                  din,
                  // Outputs
                  dout
                  );
                  
   parameter WIDTH = 8;
   
   input   [WIDTH-1:0]  din;
   output  [WIDTH-1:0]  dout;
   
   assign dout[WIDTH-1] = din[WIDTH-1];
   genvar i;
   generate for (i=WIDTH-2;i>=0;i=i-1) begin:G2B
      assign dout[i] = dout[i+1] ^ din[i];
   end
   endgenerate
endmodule

