//------------------------------------------------------------------------------
//  Copyright (c) 2011-2024 Anlogic, Inc.
//  All Right Reserved.
//------------------------------------------------------------------------------

////////////////////////////////////////////////////////////////////////////////
//
//  Vendor      : Anlogic
//  Version     : 0.31
//  Description : Anlogic Functional Simulation Model for Physical IP
//                PH1P_PHY_PLL_V2
//  Filename    : ph1p_phy_pll_v2.v
//
////////////////////////////////////////////////////////////////////////////////
//
//  Revision    :
//  2024-10-21 - 0.51- GS.JI - Modify mc1_vctrl_sel default value. 
//  2024-10-18 - 0.3 - GS.JI - Add ssc UP mode.
//  2024-08-22 - 0.24- GS.JI - Fix compiler warning.
//  2024-06-06 - 0.23- GS.JI - Fix wakeup connect.
//  2023-12-02 - 0.22- GS.JI - Add PH1P_PLL_V2_FAST_SIM define.
//  2023-10-31 - 0.21- GS.JI - Remove scan_in port.
//  2023-10-30 - 0.2 - GS.JI - Remove clkc[7] port.
//  2023-10-07 - 0.1 - GS.JI - Initial version.
//
///////////////////////////////////////////////////////////////////////////////
`define PH1P_PLL_V2_FAST_SIM
`timescale 1 ps / 1 fs

module PH1P_PHY_PLL_V2(
        refclk,
        refclk_rst,
        fbclk,
        clkc,
        clkcb,
        lock,
        pllreset,
        clkc_rst,
        clkc_en,            
        wakeup,             
        cps_step,          
        pllpd,              
        drp_clk,            
        drp_rstn,          
        drp_sel,   
        drp_rd,    
        drp_wr,    
        drp_addr,  
        drp_wdata,         
        drp_err,           
        drp_rdy,           
        drp_rdata,         
        psdone,
        psclk,
        psdown,
        psstep,
        psclksel,           
        ssc_reset,
        scan_clk, 
        scan_enable,  
        scan_mode, 
        scan_resetn 
);

//Global clocks
    input           refclk;         // DEFAULT := '0' [tag:clk]                 [template:PLL reference clock input]
    input           fbclk;          // DEFAULT := '0' [tag:clk]                 [template:PLL feedback clock input] 

    output  [6:0]   clkc;           // clkt[6:0] = {clkt[6:0]} [tag:clk]        [template:PLL clock output]      
    output  [6:0]   clkcb;          // clkc[6:0] = {clkc[6:0]} [tag:clk]        [template:PLL clock output, inverse with clkc]
//PLL  lock detector
    output          lock;           // DEFAULT := '0'                           [template:PLL locks output, high active]
//PLL and output path reset 
    input           pllreset;       // DEFAULT := '0' [tag:reset]               [template:PLL reset, high active]
    input   [1:0]   clkc_rst;       // DEFAULT := (others => '0') [tag:reset]   [template:Output clock reset, high active. clkc_rst[0] for clkc[0:3], clkc_rst[1] for clkc[4:6]]
    input           refclk_rst;     // DEFAULT := '0'                           [template:PLL reference clock reset]
    input           wakeup;         // DEFAULT := '0'                           [template:PLL wakeup_sync, Switching from internal feedback to external feedback enable under lock before mode]
//PLL output clk enable
    input   [6:0]   clkc_en;        // DEFAULT := (others => '0')               [template:Output clock enable]
//PLL dynamic coarse phase shift
    input           cps_step;       // DEFAULT := '0'                           [template:Dynamic phase coarse adjustment control]
//PLL power done
    input           pllpd;          // DEFAULT := '0'                           [template:PLL power switch, high for PLL power down]
//PLL   dynami fine phase shift
    input           psclk;          // DEFAULT := '0' [tag:clk]                 [template:Dynamic phase adjustment clock]
    input   [2:0]   psclksel;       // DEFAULT := (others => '0')               [template:Output path selection for dynamic phase adjustment. 0 to 6 correspond to clkc[0] to clkc[6]]
    input           psstep;         // DEFAULT := '0'                           [template:Dynamic fine phase adjustment trigger signal, high active.]
    input           psdown;         // DEFAULT := '0'                           [template:Dynamic phase shift mode, low for left shift, high for right shift.]
    output          psdone;         // DEFAULT := '0'                           [template:Dynamic phase shift finish flag]
//Ports of drp
    input           drp_clk;        // DEFAULT := '0' [tag:clk]                 [template:Configure the clock input dynamically]
    input           drp_rstn;       // DEFAULT := '0'                           [template:Dynamic configuration reset signal, low level reset]
    input           drp_sel;        // DEFAULT := '0'                           [template:Dynamic configuration chip selective signal input, high active]
    input           drp_rd;         // DEFAULT := '0'                           [template:Dynamic configuration read enable signal, high active]
    input           drp_wr;         // DEFAULT := '0'                           [template:Dynamic configuration write enable signal, high active]
    input  [7:0]    drp_addr;       // DEFAULT := (others => '0')               [template:Dynamically configure the write address signal]
    input  [7:0]    drp_wdata;      // DEFAULT := (others => '0')               [template:Configure data input signals dynamically]
    output          drp_err;        // DEFAULT := '0'                           [template:Dynamic configuration error flag bit, high active]
    output          drp_rdy;        // DEFAULT := '0'                           [template:Configure the read end flag dynamically]
    output [7:0]    drp_rdata;      // DEFAULT := (others => '0')               [template:Dynamically configure the data read port]  
//Ports of ssc
    input           ssc_reset;      // DEFAULT := '0' [tag:reset]               [template:Spread Frequency Enable reset signal, high active. It needs fixed to high when using SSC]

    input           scan_clk    ;   //                                          [template: DFT Scan CLK Input] 
    input           scan_enable ;   //                                          [template: DFT Scan Enable Input]
    input           scan_mode   ;   //                                          [template: DFT Scan Mode Input]
    input           scan_resetn ;   //                                          [template: DFT Scan Rst Input]

//ref&fbk clk sel
parameter FBKCLK                 = "CLKC0_EXT";     // CLKC0_EXT, CLKC1_EXT, CLKC2_EXT, CLKC3_EXT, CLKC4_EXT, CLKC5_EXT, CLKC6_EXT
                                                    // CLKC0_INT, CLKC1_INT, CLKC2_INT, CLKC3_INT, CLKC4_INT, CLKC5_INT, CLKC6_INT, VCO_PHASE0
                                                    //                          [template:Feedback clock path selection]
                                                                                                  

parameter FBKCLK_INT             = "VCO_PHASE0";    // CLKC0_EXT, CLKC1_EXT, CLKC2_EXT, CLKC3_EXT, CLKC4_EXT, CLKC5_EXT, CLKC6_EXT, 
                                                    // CLKC0_INT, CLKC1_INT, CLKC2_INT, CLKC3_INT, CLKC4_INT, CLKC5_INT, CLKC6_INT, VCO_PHASE0
                                                    //                          [template:Feedback clock internal path selection]

parameter FIN                    = "100.0000";      //                          [template:No use in fact.Tag refclk frequency.]	

//loop parameter
parameter REFCLK_DIV             = 1;               // 1~128                    [template:Reference clock frequency division]                    
parameter FBCLK_DIV              = 1;               // 1~128                    [template:Feedback clock frequency division]

//fine phase shift
parameter CLKC0_FPHASE           = 0;               // 0~7                      [template:Output phase fine adjustment parameters of clock 0]                                                                
parameter CLKC1_FPHASE           = 0;               // 0~7                      [template:Output phase fine adjustment parameters of clock 1]                                                                
parameter CLKC2_FPHASE           = 0;               // 0~7                      [template:Output phase fine adjustment parameters of clock 2]                                                                
parameter CLKC3_FPHASE           = 0;               // 0~7                      [template:Output phase fine adjustment parameters of clock 3]                                                                
parameter CLKC4_FPHASE           = 0;               // 0~7                      [template:Output phase fine adjustment parameters of clock 4]                                                               
parameter CLKC5_FPHASE           = 0;               // 0~7                      [template:Output phase fine adjustment parameters of clock 5]                                                                
parameter CLKC6_FPHASE           = 0;               // 0~7                      [template:Output phase fine adjustment parameters of clock 6]                                                                
localparam CLKC7_FPHASE           = 0;               // 0~7                      [template:Output phase fine adjustment parameters of clock 7]                                                                    

//coarse phase shift
parameter PREDIV_MUXC0           = "VCO";           // "VCO", "CLKC_INT_MAIN", "REFCLK"               [template:Clock source selection control for output path 0 divider.]
parameter PREDIV_MUXC1           = "VCO";           // "VCO", "CLKC0_INT", "HIGH", "REFCLK"           [template:Clock source selection control for output path 1 divider.]
parameter PREDIV_MUXC2           = "VCO";           // "VCO", "CLKC1_INT", "HIGH", "REFCLK"           [template:Clock source selection control for output path 2 divider.]
parameter PREDIV_MUXC3           = "VCO";           // "VCO", "CLKC2_INT", "HIGH", "REFCLK"           [template:Clock source selection control for output path 3 divider.]
parameter PREDIV_MUXC4           = "VCO";           // "VCO", "CLKC3_INT", "HIGH", "REFCLK"           [template:Clock source selection control for output path 4 divider.]
parameter PREDIV_MUXC5           = "VCO";           // "VCO", "CLKC4_INT", "HIGH", "REFCLK"           [template:Clock source selection control for output path 5 divider.]
parameter PREDIV_MUXC6           = "VCO";           // "VCO", "CLKC5_INT", "HIGH", "REFCLK"           [template:Clock source selection control for output path 6 divider.]
localparam PREDIV_MUXC7           = "VCO";           // "VCO", "CLKC6_INT", "HIGH", "REFCLK"           [template:Clock source selection control for output path 7 divider.]

parameter CLKC0_CPHASE           = 0;               // 0~127                    [template: Output path 0 divider initial value control for coarse phase adjustment]     
parameter CLKC1_CPHASE           = 0;               // 0~127                    [template: Output path 1 divider initial value control for coarse phase adjustment]
parameter CLKC2_CPHASE           = 0;               // 0~127                    [template: Output path 2 divider initial value control for coarse phase adjustment]
parameter CLKC3_CPHASE           = 0;               // 0~127                    [template: Output path 3 divider initial value control for coarse phase adjustment]
parameter CLKC4_CPHASE           = 0;               // 0~127                    [template: Output path 4 divider initial value control for coarse phase adjustment]
parameter CLKC5_CPHASE           = 0;               // 0~127                    [template: Output path 5 divider initial value control for coarse phase adjustment]
parameter CLKC6_CPHASE           = 0;               // 0~127                    [template: Output path 6 divider initial value control for coarse phase adjustment]
localparam CLKC7_CPHASE           = 0;               // 0~127                    [template: Output path 7 divider initial value control for coarse phase adjustment]


//output divider
parameter CLKC0_DIV              = 1;               // 1~128                    [template:Output divide ratio for clock 0, 1=div1, 128=div128]    
parameter CLKC1_DIV              = 1;               // 1~128                    [template:Output divide ratio for clock 1, 1=div1, 128=div128]
parameter CLKC2_DIV              = 1;               // 1~128                    [template:Output divide ratio for clock 2, 1=div1, 128=div128]
parameter CLKC3_DIV              = 1;               // 1~128                    [template:Output divide ratio for clock 3, 1=div1, 128=div128]
parameter CLKC4_DIV              = 1;               // 1~128                    [template:Output divide ratio for clock 4, 1=div1, 128=div128]
parameter CLKC5_DIV              = 1;               // 1~128                    [template:Output divide ratio for clock 5, 1=div1, 128=div128]
parameter CLKC6_DIV              = 1;               // 1~128                    [template:Output divide ratio for clock 6, 1=div1, 128=div128]
localparam CLKC7_DIV              = 1;               // 1~128                    [template:Output divide ratio for clock 7, 1=div1, 128=div128]


// duty
parameter CLKC0_DUTY_INT         = 1;               // 1~127                    [template:Output clock duty cycle control for path 0, range={1,CLKC0_DIV-1}; when CLKC0_DIV=1, this parameter no use]         
parameter CLKC1_DUTY_INT         = 1;               // 1~127                    [template:Output clock duty cycle control for path 1, range={1,CLKC1_DIV-1}; when CLKC1_DIV=1, this parameter no use]
parameter CLKC2_DUTY_INT         = 1;               // 1~127                    [template:Output clock duty cycle control for path 2, range={1,CLKC2_DIV-1}; when CLKC2_DIV=1, this parameter no use]
parameter CLKC3_DUTY_INT         = 1;               // 1~127                    [template:Output clock duty cycle control for path 3, range={1,CLKC3_DIV-1}; when CLKC3_DIV=1, this parameter no use]
parameter CLKC4_DUTY_INT         = 1;               // 1~127                    [template:Output clock duty cycle control for path 4, range={1,CLKC4_DIV-1}; when CLKC4_DIV=1, this parameter no use]
parameter CLKC5_DUTY_INT         = 1;               // 1~127                    [template:Output clock duty cycle control for path 5, range={1,CLKC5_DIV-1}; when CLKC5_DIV=1, this parameter no use]
parameter CLKC6_DUTY_INT         = 1;               // 1~127                    [template:Output clock duty cycle control for path 6, range={1,CLKC6_DIV-1}; when CLKC6_DIV=1, this parameter no use]
localparam CLKC7_DUTY_INT         = 1;               // 1~127                    [template:Output clock duty cycle control for path 7, range={1,CLKC7_DIV-1}; when CLKC7_DIV=1, this parameter no use]


// clk output
parameter DIVOUT_MUXC0           = "DIV";           // "DIV", "REFCLK"          [template:Clock output path 0 output source selection control]                      
parameter DIVOUT_MUXC1           = "DIV";           // "DIV", "REFCLK"          [template:Clock output path 1 output source selection control]                      
parameter DIVOUT_MUXC2           = "DIV";           // "DIV", "REFCLK"          [template:Clock output path 2 output source selection control]                      
parameter DIVOUT_MUXC3           = "DIV";           // "DIV", "REFCLK"          [template:Clock output path 3 output source selection control]                      
parameter DIVOUT_MUXC4           = "DIV";           // "DIV", "REFCLK"          [template:Clock output path 4 output source selection control]                      
parameter DIVOUT_MUXC5           = "DIV";           // "DIV", "REFCLK"          [template:Clock output path 5 output source selection control]                      
parameter DIVOUT_MUXC6           = "DIV";           // "DIV", "REFCLK"          [template:Clock output path 6 output source selection control]                      
localparam DIVOUT_MUXC7           = "DIV";           // "DIV", "REFCLK"          [template:Clock output path 7 output source selection control]                      


parameter CLKC0_ENABLE           = "DISABLE";       // "ENABLE", "DISABLE"      [template:Output clock path 0 divider enable control]           
parameter CLKC1_ENABLE           = "DISABLE";       // "ENABLE", "DISABLE"      [template:Output clock path 1 divider enable control]         
parameter CLKC2_ENABLE           = "DISABLE";       // "ENABLE", "DISABLE"      [template:Output clock path 2 divider enable control]         
parameter CLKC3_ENABLE           = "DISABLE";       // "ENABLE", "DISABLE"      [template:Output clock path 3 divider enable control]         
parameter CLKC4_ENABLE           = "DISABLE";       // "ENABLE", "DISABLE"      [template:Output clock path 4 divider enable control]         
parameter CLKC5_ENABLE           = "DISABLE";       // "ENABLE", "DISABLE"      [template:Output clock path 5 divider enable control]         
parameter CLKC6_ENABLE           = "DISABLE";       // "ENABLE", "DISABLE"      [template:Output clock path 6 divider enable control]         
localparam CLKC7_ENABLE           = "DISABLE";       // "ENABLE", "DISABLE"      [template:Output clock path 7 divider enable control]         


/////////////////////////////////////////////////////////////////
//  The following parameter are not used to configure bits.
//  Helps parser or simulator to improve peformance.
/////////////////////////////////////////////////////////////////
parameter WORK_MODE              = "USER";          // "USER", "LOCK_BEFORE_WAKE_UP"        [template:Work mode]

parameter PD_DIG                 = "ENABLE";        // "ENABLE", "DISABLE"      [template:Default setting ENABLE]
parameter PLL_USR_RST            = "ENABLE";        // "ENABLE", "DISABLE"      [template:PLL user reset enable control]
parameter PLL_FEED_TYPE          = "INTERNAL";      // "INTERNAL", "EXTERNAL"   [template:PLL feedback mode selection control]
parameter PLL_FASTLOOP           = "DISABLE"  ;     // "ENABLE", "DISABLE"      [template:PLL fastloop mode selection control]

// loop parameter
parameter LPF_RES                = 3;               // 0~3                      [template:Parameters related to bandwidth settings]
parameter LPF_CAP                = 3;               // 0~31                     [template:Parameters related to bandwidth settings]
parameter ICP_CUR                = 1;               // 0~31                     [template:Parameters related to bandwidth settings]

//frac-N
parameter FRAC_ENABLE            = "DISABLE";       // "ENABLE", "DISABLE"      [template:Fractional frequency division enable]
parameter SDM_FRAC               = 0;               // 0~(2^28-1)               [template:PLL feedback divider ratio fractional value control. Fractional value=SDM_FRAC/2^28]

//fine phase shift
parameter PHASE_PATH_SEL         = 0;               // 0~7                      [template:Selection of output path in dynamic fine phase adjustment]
parameter DYN_PHASE_PATH_SEL     = "DISABLE";       // "ENABLE", "DISABLE"      [template:PLL dynamic phase adjustment enable]
parameter DYN_FPHASE_EN          = "DISABLE";       // "ENABLE", "DISABLE"      [template:PLL dynamic fine phase adjustment enable]

parameter CLKC0_FPHASE_RSTSEL    = 0;               // 0, 1                     [template:Divider reset release clock phase selection for output path 0. Set 0 when CLKC0_FPHASE=0~3, set 1 when CLKC0_FPHASE=4~7]   
parameter CLKC1_FPHASE_RSTSEL    = 0;               // 0, 1                     [template:Divider reset release clock phase selection for output path 1. Set 0 when CLKC1_FPHASE=0~3, set 1 when CLKC1_FPHASE=4~7]             
parameter CLKC2_FPHASE_RSTSEL    = 0;               // 0, 1                     [template:Divider reset release clock phase selection for output path 2. Set 0 when CLKC2_FPHASE=0~3, set 1 when CLKC2_FPHASE=4~7]             
parameter CLKC3_FPHASE_RSTSEL    = 0;               // 0, 1                     [template:Divider reset release clock phase selection for output path 3. Set 0 when CLKC3_FPHASE=0~3, set 1 when CLKC3_FPHASE=4~7]             
parameter CLKC4_FPHASE_RSTSEL    = 0;               // 0, 1                     [template:Divider reset release clock phase selection for output path 4. Set 0 when CLKC4_FPHASE=0~3, set 1 when CLKC4_FPHASE=4~7]  
parameter CLKC5_FPHASE_RSTSEL    = 0;               // 0, 1                     [template:Divider reset release clock phase selection for output path 5. Set 0 when CLKC5_FPHASE=0~3, set 1 when CLKC5_FPHASE=4~7]             
parameter CLKC6_FPHASE_RSTSEL    = 0;               // 0, 1                     [template:Divider reset release clock phase selection for output path 6. Set 0 when CLKC6_FPHASE=0~3, set 1 when CLKC6_FPHASE=4~7]             
localparam CLKC7_FPHASE_RSTSEL    = 0;               // 0, 1                     [template:Divider reset release clock phase selection for output path 7. Set 0 when CLKC7_FPHASE=0~3, set 1 when CLKC7_FPHASE=4~7]                                          
parameter CLKC0_DUTY50           = "ENABLE";        // "ENABLE", "DISABLE"      [template:CLKC0 50% duty cycle enable control]  
parameter CLKC1_DUTY50           = "ENABLE";        // "ENABLE", "DISABLE"      [template:CLKC1 50% duty cycle enable control]        
parameter CLKC2_DUTY50           = "ENABLE";        // "ENABLE", "DISABLE"      [template:CLKC2 50% duty cycle enable control]       
parameter CLKC3_DUTY50           = "ENABLE";        // "ENABLE", "DISABLE"      [template:CLKC3 50% duty cycle enable control]       
parameter CLKC4_DUTY50           = "ENABLE";        // "ENABLE", "DISABLE"      [template:CLKC4 50% duty cycle enable control]       
parameter CLKC5_DUTY50           = "ENABLE";        // "ENABLE", "DISABLE"      [template:CLKC5 50% duty cycle enable control]       
parameter CLKC6_DUTY50           = "ENABLE";        // "ENABLE", "DISABLE"      [template:CLKC6 50% duty cycle enable control]       
localparam CLKC7_DUTY50           = "ENABLE";        // "ENABLE", "DISABLE"      [template:CLKC7 50% duty cycle enable control]       

//ssc
parameter SSC_ENABLE             = "DISABLE";       // "ENABLE", "DISABLE"      [template:SSC mode enable]      
parameter SSC_RST                = "ENABLE";        // "ENABLE", "DISABLE"      [template:SSC reset enable control]
parameter SSC_MODE               = "CENTER";        // "UP", "DOWN", "CENTER"   [template:SSC mode selection]
parameter SSC_FREQ_DIV           = 0;               // 0~(2^18-1)               [template:SSC triangle modulation frequency control]
parameter SSC_RNGE               = 242;             // 0~(2^24-1)               [template:SSC triangle modulation amplitude control]

// lock detector
parameter REFCLK_DET_BYP         = "DISABLE";       // "ENABLE", "DISABLE"      [template:Reference clock detection bypass enable."DISABLE":enable detection; "ENABLE":bypass detection]

//channel 0 frac div related
parameter CLKC0_FRAC_EN          = "DISABLE";       // "ENABLE", "DISABLE"      [template:Path 0 Fractional 1/8 div function enable. If this is enabled, PI_OUT_SEL should be "NORMAL"]      
parameter CLKC0_FRAC             = 0;               // 0~7                      [template:1/8 fraction div control for path 0. 0 for no fracn; 1 for 1/8; 2 for 2/8; 3 for 3/8; 4 for -4/8; 5 for -3/8; 6 for -2/8; 7 for -1/8]
parameter PI_OUT_SEL             = "NORMAL";        // "NORMAL", "PI"           [template:Select clock source for path 0. PI output is only used for fine phase shift]
parameter PI_FRAC_EN             = "DISABLE";       // "ENABLE", "DISABLE"      [template:"ENABLE" for output path 0 fractional divide mode; "DISABLE" for fine phase shift mode]
parameter CLKC0_PI_SHIFT_EN      = "DISABLE";       // "ENABLE", "DISABLE"      [template:Output path 0 phase shifter by PI enable]

parameter FEEDBK_MODE            = "NORMAL";        // "NORMAL", "SOURCESYNC", "NOCOMP", "ZERODELAY"    [template:No use in fact.Tag feedback mode.]
parameter DYN_CPHASE_EN          = "DISABLE";       // "ENABLE", "DISABLE"                              [template:PLL dynamic coarse phase adjustment enable.]


//Parameter Constant
reg [2:0]       mc1_cal_counter     =   3'd0;
reg [5:0]       mc1_dig_sel         =   6'd0;
reg [1:0]       mc1_fracn_prbs_sel  =   2'd0;
reg [1:0]       mc1_divcrst_en      =   3'd3;
reg [6:0]       mc1_dyn_phc0        =   7'd0;  
reg [6:0]       mc1_dyn_phc1        =   7'd0; 
reg [6:0]       mc1_dyn_phc2        =   7'd0; 
reg [6:0]       mc1_dyn_phc3        =   7'd0; 
reg [6:0]       mc1_dyn_phc4        =   7'd0; 
reg [6:0]       mc1_dyn_phc5        =   7'd0; 
reg [6:0]       mc1_dyn_phc6        =   7'd0; 
reg [6:0]       mc1_dyn_phc7        =   7'd0; 
reg [7:0]       mc1_enclk           =   8'hff;     
reg             mc1_enclk_main      =   1'b1;
reg [6:0]       mc1_gpll_lockdet    =   7'h02;     
reg [7:0]       mc1_load_div2_en    =   8'd0;
reg [7:0]       mc1_outgate_en      =   8'd0;
reg [1:0]       mc1_bias_icfg       =   2'd1;
reg [1:0]       mc1_refclk_det_div  =   2'b11;
reg [3:0]       mc1_fracn_dither_sel=   4'd0;
reg             mc1_fracn_dither_en =   1'b0;
reg             mc1_test_en         =   1'b0;
reg [7:0]       mc1_div2_bypass_n   =   8'h00;              
reg [7:0]       mc1_div2_phc        =   8'h00;
reg             mc1_refclk_out_en   =   1'b0;
reg             mc1_mrst_en         =   1'b0;
reg             mc1_divc_outmux_main=   1'b0;
reg             mc1_enable_sync     =   1'b0;
//others
reg [2:0]       mc1_cp_dlysel       =   3'b010;
reg [2:0]       mc1_cp_refsel       =   3'b000;
reg [3:0]       mc1_pi_icfg         =   4'b0100;
reg [4:0]       mc1_icp_bias        =   5'd0;
reg [4:0]       mc1_icp_banch       =   5'd1;
reg [1:0]       mc1_ssc_lpf_sel     =   2'd0;  
reg [1:0]       mc1_vctrl_sel       =   2'b11;
reg [2:0]       mc1_outputpi_capsel =   3'd0;
reg [1:0]       mc1_lpf_r1_sel      =   2'd3;
reg [2:0]       mc1_fastlock_sel    =   3'd0;
reg [3:0]       mc1_kvco_sel        =   4'b1100; 
reg [2:0]       mc1_outputpi_icfg   =   3'd0;
reg             mc1_tda_en          =   1'b0;
reg [2:0]       mc1_pi_capsel       =   3'd0;
reg [1:0]       mc1_pi_delay        =   2'd0;     
                               


//Parameter  
reg [7:0]           mc1_ref_div;            
reg [7:0]           mc1_fbk_div;            
reg [6:0]           mc1_phc0;               
reg [6:0]           mc1_phc1;               
reg [6:0]           mc1_phc2;               
reg [6:0]           mc1_phc3;               
reg [6:0]           mc1_phc4;               
reg [6:0]           mc1_phc5;               
reg [6:0]           mc1_phc6;
reg [6:0]           mc1_phc7;               
reg [6:0]           mc1_divc0;              
reg [6:0]           mc1_divc1;              
reg [6:0]           mc1_divc2;              
reg [6:0]           mc1_divc3;              
reg [6:0]           mc1_divc4;              
reg [6:0]           mc1_divc5;              
reg [6:0]           mc1_divc6;  
reg [6:0]           mc1_divc7;             
reg [6:0]           mc1_duty0;              
reg [6:0]           mc1_duty1;              
reg [6:0]           mc1_duty2;              
reg [6:0]           mc1_duty3;              
reg [6:0]           mc1_duty4;              
reg [6:0]           mc1_duty5;              
reg [6:0]           mc1_duty6;      
reg [6:0]           mc1_duty7;         
reg [27:0]          mc1_fbfracn_sel;        
reg [2:0]           mc1_syn_sel;            
reg [7:0]           mc1_divrst_ph_sel;      
reg [17:0]          mc1_ssc_freq_div;
reg [23:0]          mc1_ssc_step;                           
reg [6:0]           mc1_frac;

//Parameter Case
reg [3:0]           mc1_fbk_sel;            
reg [3:0]           mc1_fbk_sel_wakeup;     
reg [6:0]           mc1_phic0;              
reg [2:0]           mc1_phic1;              
reg [2:0]           mc1_phic2;              
reg [2:0]           mc1_phic3;              
reg [2:0]           mc1_phic4;              
reg [2:0]           mc1_phic5;              
reg [2:0]           mc1_phic6; 
reg [2:0]           mc1_phic7;                     
reg [1:0]           mc1_divc_premux0;       
reg [1:0]           mc1_divc_premux1;       
reg [1:0]           mc1_divc_premux2;       
reg [1:0]           mc1_divc_premux3;       
reg [1:0]           mc1_divc_premux4;       
reg [1:0]           mc1_divc_premux5;       
reg [1:0]           mc1_divc_premux6; 
reg [1:0]           mc1_divc_premux7;      
reg [7:0]           mc1_divc_outmux;        
reg [7:0]           mc1_div_en;             
reg                 mc1_pllpdn;             
reg                 mc1_dig_pd;             
reg                 mc1_pllrst_en;          
reg                 mc1_intfb;   
reg                 mc1_fastloop_cfg;          

reg                 mc1_fracn_en;           
reg                 mc1_dyn_source;         
reg                 mc1_dyn_ph_shift_en;    
reg [7:0]           mc1_duty50_n;           
reg                 mc1_ssc_en;             
reg                 mc1_ssc_reset;          
reg                 mc1_ssc_mode;     
reg                 mc1_ssc_dn_loop_mode;      
reg                 mc1_refclk_det_byp;     
reg                 mc1_clk0_frac_en;       
reg [7:0]           mc1_pi_out_sel;         
reg                 mc1_pi_frac_mode;       
reg                 mc1_pi_phi_en;          
reg [7:0]           mc1_load_en;            


reg                 pll_cal_rst_n       ;
reg                 ibn_10u_vref        ;
reg                 ibn_10u_ptat        ;
reg                 pib_lockdet_clr_n   ;
//wire                rstn_cal;
wire                ssc_reset_n; 


reg                 dig_pd                      =   1'b1;   
reg                 done_gwe                    =   1'b0;
reg                 pib_clkout_glitchless_en_n  =   1'b1;
reg                 pib_done_pll                =   1'b1;
reg                 ibp_10u_poly                =   1'b0;
reg                 pib_en_pll2io_n             =   1'b1;
reg                 pib_fbkshot                 =   1'b1;
reg                 pib_load_div2_reg           =   1'b1;
reg                 pib_refshot                 =   1'b1;
reg                 pib_rst_m                   =   1'b0;
reg                 pll_wakeup_sync             =   1'b1;

reg                 refclk_sel  =   0;


//reg                 scan_in             ;
//reg                 scan_mode           ;  
//reg                 scan_resetn         ;
//wire                scan_enable         ;
//reg                 scan_clk            ;


initial
begin    
//    scan_mode       =   1'b0;      
//    scan_resetn     =   1'b0;
//    scan_clk        =   1'b0;
//    scan_in         =   1'b1;

    pll_cal_rst_n   =   1'b0; 
    ibn_10u_vref    =   1'b0; 
    ibn_10u_ptat    =   1'b0;
    pib_lockdet_clr_n   =   1'b0; 
    #1    
//    scan_resetn     =   1'b1;
//    scan_in         =   1'b0;

    ibn_10u_vref    =   1'b1; 
    ibn_10u_ptat    =   1'b1;    
    pll_cal_rst_n   =   1'b1;
    pib_lockdet_clr_n   =   1'b1; 

end

//always #1   scan_clk    <=  ~scan_clk;


//no use
  //reg [3:0]         mc1_vco_band;       
  //reg               mc1_vco_cal_mode;   
  //reg               mc1_freq_lock;      

initial begin  
    mc1_ref_div         =   REFCLK_DIV ;            
    mc1_fbk_div         =   FBCLK_DIV ;             
    mc1_phc0            =   CLKC0_CPHASE;               
    mc1_phc1            =   CLKC1_CPHASE;               
    mc1_phc2            =   CLKC2_CPHASE;               
    mc1_phc3            =   CLKC3_CPHASE;               
    mc1_phc4            =   CLKC4_CPHASE;               
    mc1_phc5            =   CLKC5_CPHASE;               
    mc1_phc6            =   CLKC6_CPHASE;
    mc1_phc7            =   CLKC7_CPHASE;              
    mc1_divc0           =   CLKC0_DIV - 1;             
    mc1_divc1           =   CLKC1_DIV - 1;             
    mc1_divc2           =   CLKC2_DIV - 1;             
    mc1_divc3           =   CLKC3_DIV - 1;             
    mc1_divc4           =   CLKC4_DIV - 1;             
    mc1_divc5           =   CLKC5_DIV - 1;             
    mc1_divc6           =   CLKC6_DIV - 1;  
    mc1_divc7           =   CLKC7_DIV - 1;        
    mc1_duty0           =   CLKC0_DUTY_INT;            
    mc1_duty1           =   CLKC1_DUTY_INT;            
    mc1_duty2           =   CLKC2_DUTY_INT;            
    mc1_duty3           =   CLKC3_DUTY_INT;            
    mc1_duty4           =   CLKC4_DUTY_INT;            
    mc1_duty5           =   CLKC5_DUTY_INT;            
    mc1_duty6           =   CLKC6_DUTY_INT;  
    mc1_duty7           =   CLKC7_DUTY_INT;        
    mc1_fbfracn_sel     =   SDM_FRAC;
    mc1_syn_sel         =   PHASE_PATH_SEL;
    mc1_divrst_ph_sel[0]=   CLKC0_FPHASE_RSTSEL;
    mc1_divrst_ph_sel[1]=   CLKC1_FPHASE_RSTSEL;
    mc1_divrst_ph_sel[2]=   CLKC2_FPHASE_RSTSEL;
    mc1_divrst_ph_sel[3]=   CLKC3_FPHASE_RSTSEL;
    mc1_divrst_ph_sel[4]=   CLKC4_FPHASE_RSTSEL;
    mc1_divrst_ph_sel[5]=   CLKC5_FPHASE_RSTSEL;
    mc1_divrst_ph_sel[6]=   CLKC6_FPHASE_RSTSEL;
    mc1_divrst_ph_sel[7]=   CLKC6_FPHASE_RSTSEL;
    mc1_ssc_freq_div    =   SSC_FREQ_DIV;
    mc1_ssc_step        =   SSC_RNGE;
    mc1_frac            =   {CLKC0_FRAC,4'b0000};
 

    case (FBKCLK)
        "VCO_PHASE0"    : mc1_fbk_sel   = 4'b0000;
        "CLKC0_EXT"     : mc1_fbk_sel   = 4'b0001;
        "CLKC1_EXT"     : mc1_fbk_sel   = 4'b0010;
        "CLKC2_EXT"     : mc1_fbk_sel   = 4'b0011;
        "CLKC3_EXT"     : mc1_fbk_sel   = 4'b0100;
        "CLKC4_EXT"     : mc1_fbk_sel   = 4'b0101;
        "CLKC5_EXT"     : mc1_fbk_sel   = 4'b0110;
        "CLKC6_EXT"     : mc1_fbk_sel   = 4'b0111;
        "CLKC7_EXT"     : mc1_fbk_sel   = 4'b0000;
        "CLKC0_INT"     : mc1_fbk_sel   = 4'b1000;
        "CLKC1_INT"     : mc1_fbk_sel   = 4'b1001;
        "CLKC2_INT"     : mc1_fbk_sel   = 4'b1010;
        "CLKC3_INT"     : mc1_fbk_sel   = 4'b1011;
        "CLKC4_INT"     : mc1_fbk_sel   = 4'b1100;
        "CLKC5_INT"     : mc1_fbk_sel   = 4'b1101;
        "CLKC6_INT"     : mc1_fbk_sel   = 4'b1110;
        "CLKC7_INT"     : mc1_fbk_sel   = 4'b1111;
        default   : begin
            $display("\n== attribute syntax error : the attribute FBKCLK on pll instance %m is set to %s.", FBKCLK);
            $display("==   legal values for this attribute are VCO_PHASE0(...).");
            $finish;
      end
    endcase

    case (FBKCLK_INT)
        "VCO_PHASE0"    : mc1_fbk_sel_wakeup   = 4'b0000;
        "CLKC0_EXT"     : mc1_fbk_sel_wakeup   = 4'b0001;
        "CLKC1_EXT"     : mc1_fbk_sel_wakeup   = 4'b0010;
        "CLKC2_EXT"     : mc1_fbk_sel_wakeup   = 4'b0011;
        "CLKC3_EXT"     : mc1_fbk_sel_wakeup   = 4'b0100;
        "CLKC4_EXT"     : mc1_fbk_sel_wakeup   = 4'b0101;
        "CLKC5_EXT"     : mc1_fbk_sel_wakeup   = 4'b0110;
        "CLKC6_EXT"     : mc1_fbk_sel_wakeup   = 4'b0111;
        "CLKC7_EXT"     : mc1_fbk_sel_wakeup   = 4'b0000;
        "CLKC0_INT"     : mc1_fbk_sel_wakeup   = 4'b1000;
        "CLKC1_INT"     : mc1_fbk_sel_wakeup   = 4'b1001;
        "CLKC2_INT"     : mc1_fbk_sel_wakeup   = 4'b1010;
        "CLKC3_INT"     : mc1_fbk_sel_wakeup   = 4'b1011;
        "CLKC4_INT"     : mc1_fbk_sel_wakeup   = 4'b1100;
        "CLKC5_INT"     : mc1_fbk_sel_wakeup   = 4'b1101;
        "CLKC6_INT"     : mc1_fbk_sel_wakeup   = 4'b1110;
        "CLKC7_INT"     : mc1_fbk_sel_wakeup   = 4'b1111;
        default   : begin
            $display("\n== attribute syntax error : the attribute FBKCLK_INT on pll instance %m is set to %s.", FBKCLK_INT);
            $display("==   legal values for this attribute are VCO_PHASE0(...).");
            $finish;
      end
    endcase

    case (CLKC0_FPHASE)
         0     : mc1_phic0           = 7'b110_0000;
         1     : mc1_phic0           = 7'b111_0000;
         2     : mc1_phic0           = 7'b000_0000;
         3     : mc1_phic0           = 7'b001_0000;
         4     : mc1_phic0           = 7'b010_0000;
         5     : mc1_phic0           = 7'b011_0000;
         6     : mc1_phic0           = 7'b100_0000;
         7     : mc1_phic0           = 7'b101_0000;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC0_FPHASE on pll instance %m is set to %d.", CLKC0_FPHASE);
            $display("==   legal values for this attribute are 0~7.");
            $finish;
      end
    endcase    

    case (CLKC1_FPHASE)
         0     : mc1_phic1           = 3'b001;
         1     : mc1_phic1           = 3'b000;
         2     : mc1_phic1           = 3'b111;
         3     : mc1_phic1           = 3'b110;
         4     : mc1_phic1           = 3'b101;
         5     : mc1_phic1           = 3'b100;
         6     : mc1_phic1           = 3'b011;
         7     : mc1_phic1           = 3'b010;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC1_FPHASE on pll instance %m is set to %d.", CLKC1_FPHASE);
            $display("==   legal values for this attribute are 0~7.");
            $finish;
      end
    endcase
    
    case (CLKC2_FPHASE)
         0     : mc1_phic2           = 3'b001;
         1     : mc1_phic2           = 3'b000;
         2     : mc1_phic2           = 3'b111;
         3     : mc1_phic2           = 3'b110;
         4     : mc1_phic2           = 3'b101;
         5     : mc1_phic2           = 3'b100;
         6     : mc1_phic2           = 3'b011;
         7     : mc1_phic2           = 3'b010;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC2_FPHASE on pll instance %m is set to %d.", CLKC2_FPHASE);
            $display("==   legal values for this attribute are 0~7.");
            $finish;
      end
    endcase
    
    case (CLKC3_FPHASE)
         0     : mc1_phic3           = 3'b001;
         1     : mc1_phic3           = 3'b000;
         2     : mc1_phic3           = 3'b111;
         3     : mc1_phic3           = 3'b110;
         4     : mc1_phic3           = 3'b101;
         5     : mc1_phic3           = 3'b100;
         6     : mc1_phic3           = 3'b011;
         7     : mc1_phic3           = 3'b010;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC3_FPHASE on pll instance %m is set to %d.", CLKC3_FPHASE);
            $display("==   legal values for this attribute are 0~7.");
            $finish;
      end
    endcase
    
    case (CLKC4_FPHASE)
         0     : mc1_phic4           = 3'b001;
         1     : mc1_phic4           = 3'b000;
         2     : mc1_phic4           = 3'b111;
         3     : mc1_phic4           = 3'b110;
         4     : mc1_phic4           = 3'b101;
         5     : mc1_phic4           = 3'b100;
         6     : mc1_phic4           = 3'b011;
         7     : mc1_phic4           = 3'b010;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC4_FPHASE on pll instance %m is set to %d.", CLKC4_FPHASE);
            $display("==   legal values for this attribute are 0~7.");
            $finish;
      end
    endcase
    
    case (CLKC5_FPHASE)
         0     : mc1_phic5           = 3'b001;
         1     : mc1_phic5           = 3'b000;
         2     : mc1_phic5           = 3'b111;
         3     : mc1_phic5           = 3'b110;
         4     : mc1_phic5           = 3'b101;
         5     : mc1_phic5           = 3'b100;
         6     : mc1_phic5           = 3'b011;
         7     : mc1_phic5           = 3'b010;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC5_FPHASE on pll instance %m is set to %d.", CLKC5_FPHASE);
            $display("==   legal values for this attribute are 0~7.");
            $finish;
      end
    endcase
    
    
    case (CLKC6_FPHASE)
         0     : mc1_phic6           = 3'b001;
         1     : mc1_phic6           = 3'b000;
         2     : mc1_phic6           = 3'b111;
         3     : mc1_phic6           = 3'b110;
         4     : mc1_phic6           = 3'b101;
         5     : mc1_phic6           = 3'b100;
         6     : mc1_phic6           = 3'b011;
         7     : mc1_phic6           = 3'b010;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC6_FPHASE on pll instance %m is set to %d.", CLKC6_FPHASE);
            $display("==   legal values for this attribute are 0~7.");
            $finish;
      end
    endcase

    case (CLKC7_FPHASE)
         0     : mc1_phic7           = 3'b001;
         1     : mc1_phic7           = 3'b000;
         2     : mc1_phic7           = 3'b111;
         3     : mc1_phic7           = 3'b110;
         4     : mc1_phic7           = 3'b101;
         5     : mc1_phic7           = 3'b100;
         6     : mc1_phic7           = 3'b011;
         7     : mc1_phic7           = 3'b010;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC7_FPHASE on pll instance %m is set to %d.", CLKC7_FPHASE);
            $display("==   legal values for this attribute are 0~7.");
            $finish;
      end
    endcase

    case (PREDIV_MUXC0)
        "VCO"           : mc1_divc_premux0    = 2'b00;   
        "CLKC6_INT"      : mc1_divc_premux0    = 2'b01;
        "CLKC_INT_MAIN"  : mc1_divc_premux0    = 2'b10;
        "REFCLK"        : mc1_divc_premux0    = 2'b11;
        default   : begin
            $display("\n== attribute syntax error : the attribute PREDIV_MUXC0 on pll instance %m is set to %s.", PREDIV_MUXC0);
            $display("==   legal values for this attribute are VCO or REFCLK or CLK7_INT or CLK_INT_MAIN.");
            $finish;
      end
    endcase
    
    case (PREDIV_MUXC1)
        "VCO"     : mc1_divc_premux1    = 2'b00;    
        "CLKC0_INT": mc1_divc_premux1    = 2'b01;
        "HIGH"    : mc1_divc_premux1    = 2'b10;
        "REFCLK"  : mc1_divc_premux1    = 2'b11;
        default   : begin
            $display("\n== attribute syntax error : the attribute PREDIV_MUXC1 on pll instance %m is set to %s.", PREDIV_MUXC1);
            $display("==   legal values for this attribute are VCO or REFCLK or CLK0_INT or HIGH.");
            $finish;
      end
    endcase
    
    case (PREDIV_MUXC2)
        "VCO"     : mc1_divc_premux2    = 2'b00;    
        "CLKC1_INT": mc1_divc_premux2    = 2'b01;
        "HIGH"    : mc1_divc_premux2    = 2'b10;
        "REFCLK"  : mc1_divc_premux2    = 2'b11;
        default   : begin
            $display("\n== attribute syntax error : the attribute PREDIV_MUXC2 on pll instance %m is set to %s.", PREDIV_MUXC2);
            $display("==   legal values for this attribute are VCO or REFCLK or CLK1_INT or HIGH.");
            $finish;
      end
    endcase
    
    case (PREDIV_MUXC3)
        "VCO"     : mc1_divc_premux3    = 2'b00;   
        "CLKC2_INT": mc1_divc_premux3    = 2'b01;
        "HIGH"    : mc1_divc_premux3    = 2'b10;
        "REFCLK"  : mc1_divc_premux3    = 2'b11;
        default   : begin
            $display("\n== attribute syntax error : the attribute PREDIV_MUXC3 on pll instance %m is set to %s.", PREDIV_MUXC3);
            $display("==   legal values for this attribute are VCO or REFCLK or CLK2_INT or HIGH.");
            $finish;
      end
    endcase
    
    case (PREDIV_MUXC4)
        "VCO"     : mc1_divc_premux4    = 2'b00;    
        "CLKC3_INT": mc1_divc_premux4    = 2'b01;
        "HIGH"    : mc1_divc_premux4    = 2'b10;
        "REFCLK"  : mc1_divc_premux4    = 2'b11;
        default   : begin
            $display("\n== attribute syntax error : the attribute PREDIV_MUXC4 on pll instance %m is set to %s.", PREDIV_MUXC4);
            $display("==   legal values for this attribute are VCO or REFCLK or CLK3_INT or HIGH.");
            $finish;
      end
    endcase
    
    case (PREDIV_MUXC5)
        "VCO"     : mc1_divc_premux5    = 2'b00;    
        "CLKC4_INT": mc1_divc_premux5    = 2'b01;
        "HIGH"    : mc1_divc_premux5    = 2'b10;
        "REFCLK"  : mc1_divc_premux5    = 2'b11;
        default   : begin
            $display("\n== attribute syntax error : the attribute PREDIV_MUXC5 on pll instance %m is set to %s.", PREDIV_MUXC5);
            $display("==   legal values for this attribute are VCO or REFCLK or CLK4_INT or HIGH.");
            $finish;
      end
    endcase
    
    case (PREDIV_MUXC6)
        "VCO"     : mc1_divc_premux6    = 2'b00;    
        "CLKC5_INT": mc1_divc_premux6    = 2'b01;
        "HIGH"    : mc1_divc_premux6    = 2'b10;
        "REFCLK"  : mc1_divc_premux6    = 2'b11;
        default   : begin
            $display("\n== attribute syntax error : the attribute PREDIV_MUXC6 on pll instance %m is set to %s.", PREDIV_MUXC6);
            $display("==   legal values for this attribute are VCO or REFCLK or CLK5_INT or HIGH.");
            $finish;
      end
    endcase

    case (PREDIV_MUXC7)
        "VCO"     : mc1_divc_premux7    = 2'b00;    
        "CLKC5_INT": mc1_divc_premux7    = 2'b01;
        "HIGH"    : mc1_divc_premux7    = 2'b10;
        "REFCLK"  : mc1_divc_premux7    = 2'b11;
        default   : begin
            $display("\n== attribute syntax error : the attribute PREDIV_MUXC7 on pll instance %m is set to %s.", PREDIV_MUXC7);
            $display("==   legal values for this attribute are VCO or REFCLK or CLK5_INT or HIGH.");
            $finish;
      end
    endcase

    case (DIVOUT_MUXC0)
        "DIV"     : mc1_divc_outmux[0]  = 1'b0;         
        "REFCLK"  : mc1_divc_outmux[0]  = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute DIVOUT_MUXC0 on pll instance %m is set to %s.", DIVOUT_MUXC0);
            $display("==   legal values for this attribute are DIV or REFCLK.");
            $finish;
      end
    endcase

    case (DIVOUT_MUXC1)
        "DIV"     : mc1_divc_outmux[1]  = 1'b0;
        "REFCLK"  : mc1_divc_outmux[1]  = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute DIVOUT_MUXC1 on pll instance %m is set to %s.", DIVOUT_MUXC1);
            $display("==   legal values for this attribute are DIV or REFCLK.");
            $finish;
      end
    endcase

    case (DIVOUT_MUXC2)
        "DIV"     : mc1_divc_outmux[2]  = 1'b0;
        "REFCLK"  : mc1_divc_outmux[2]  = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute DIVOUT_MUXC2 on pll instance %m is set to %s.", DIVOUT_MUXC2);
            $display("==   legal values for this attribute are DIV or REFCLK.");
            $finish;
      end
    endcase

    case (DIVOUT_MUXC3)
        "DIV"     : mc1_divc_outmux[3]  = 1'b0;
        "REFCLK"  : mc1_divc_outmux[3]  = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute DIVOUT_MUXC3 on pll instance %m is set to %s.", DIVOUT_MUXC3);
            $display("==   legal values for this attribute are DIV or REFCLK.");
            $finish;
      end
    endcase

    case (DIVOUT_MUXC4)
        "DIV"     : mc1_divc_outmux[4]  = 1'b0;
        "REFCLK"  : mc1_divc_outmux[4]  = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute DIVOUT_MUXC4 on pll instance %m is set to %s.", DIVOUT_MUXC4);
            $display("==   legal values for this attribute are DIV or REFCLK.");
            $finish;
      end
    endcase

    case (DIVOUT_MUXC5)
        "DIV"     : mc1_divc_outmux[5]  = 1'b0;
        "REFCLK"  : mc1_divc_outmux[5]  = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute DIVOUT_MUXC5 on pll instance %m is set to %s.", DIVOUT_MUXC5);
            $display("==   legal values for this attribute are DIV or REFCLK.");
            $finish;
      end
    endcase

    case (DIVOUT_MUXC6)
        "DIV"     : mc1_divc_outmux[6]  = 1'b0;
        "REFCLK"  : mc1_divc_outmux[6]  = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute DIVOUT_MUXC6 on pll instance %m is set to %s.", DIVOUT_MUXC6);
            $display("==   legal values for this attribute are DIV or REFCLK.");
            $finish;
      end
    endcase

    case (DIVOUT_MUXC7)
        "DIV"    : mc1_divc_outmux[7] = 1'b0;
        "REFCLK"  : mc1_divc_outmux[7] = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute DIVOUT_MUXC7 on pll instance %m is set to %s.", DIVOUT_MUXC7);
            $display("==   legal values for this attribute are DIV or REFCLK.");
            $finish;
      end
    endcase

    case(CLKC0_ENABLE)
        "ENABLE"  : mc1_div_en[0]       = 1'b1;
        "DISABLE" : mc1_div_en[0]       = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC0_ENABLE on pll instance %m is set to %s.", CLKC0_ENABLE);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
        end
    endcase

    case(CLKC1_ENABLE)
        "ENABLE"  : mc1_div_en[1]       = 1'b1;
        "DISABLE" : mc1_div_en[1]       = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC1_ENABLE on pll instance %m is set to %s.", CLKC1_ENABLE);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
        end
    endcase

    case(CLKC2_ENABLE)
        "ENABLE"  : mc1_div_en[2]       = 1'b1;
        "DISABLE" : mc1_div_en[2]       = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC2_ENABLE on pll instance %m is set to %s.", CLKC2_ENABLE);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
        end
    endcase

    case(CLKC3_ENABLE)
        "ENABLE"  : mc1_div_en[3]       = 1'b1;
        "DISABLE" : mc1_div_en[3]       = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC3_ENABLE on pll instance %m is set to %s.", CLKC3_ENABLE);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
        end
    endcase

    case(CLKC4_ENABLE)
        "ENABLE"  : mc1_div_en[4]       = 1'b1;
        "DISABLE" : mc1_div_en[4]       = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC4_ENABLE on pll instance %m is set to %s.", CLKC4_ENABLE);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
        end
    endcase

    case(CLKC5_ENABLE)
        "ENABLE"  : mc1_div_en[5]       = 1'b1;
        "DISABLE" : mc1_div_en[5]       = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC5_ENABLE on pll instance %m is set to %s.", CLKC5_ENABLE);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
        end
    endcase

    case(CLKC6_ENABLE)
        "ENABLE"  : mc1_div_en[6]       = 1'b1;
        "DISABLE" : mc1_div_en[6]       = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC6_ENABLE on pll instance %m is set to %s.", CLKC6_ENABLE);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
        end
    endcase

    case(CLKC7_ENABLE)
        "ENABLE"  : mc1_div_en[7]       = 1'b1;
        "DISABLE" : mc1_div_en[7]       = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC7_ENABLE on pll instance %m is set to %s.", CLKC7_ENABLE);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
        end
    endcase

    case (WORK_MODE)
        "USER"                : mc1_pllpdn          = 1'b0;
        "LOCK_BEFORE_WAKE_UP" : mc1_pllpdn          = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute WORK_MODE on pll instance %m is set to %s.", WORK_MODE);
            $display("==   legal values for this attribute are USER or WAKE_UP.");
            $finish;
      end
    endcase

    case (PD_DIG)
        "ENABLE"  : mc1_dig_pd          = 1'b1;
        "DISABLE" : mc1_dig_pd          = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute PD_DIG on pll instance %m is set to %s.", PD_DIG);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (PLL_USR_RST)
        "ENABLE"  : mc1_pllrst_en       = 1'b1;
        "DISABLE" : mc1_pllrst_en       = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute PLL_USR_RST on pll instance %m is set to %s.", PLL_USR_RST);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (PLL_FEED_TYPE)
        "EXTERNAL"      : mc1_intfb     = 1'b0;
        "INTERNAL"      : mc1_intfb     = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute PLL_FEED_TYPE on pll instance %m is set to %s.", PLL_FEED_TYPE);
            $display("==   legal values for this attribute are EXTERNAL or INTERNAL.");
            $finish;
      end
    endcase

    case (PLL_FASTLOOP)
        "ENABLE"        : mc1_fastloop_cfg     = 1'b0;
        "DISABLE"       : mc1_fastloop_cfg     = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute PLL_FASTLOOP on pll instance %m is set to %s.", PLL_FASTLOOP);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase


    case (FRAC_ENABLE)
        "ENABLE"  : mc1_fracn_en        = 1'b1;
        "DISABLE" : mc1_fracn_en        = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute FRAC_ENABLE on pll instance %m is set to %s.", FRAC_ENABLE);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (DYN_PHASE_PATH_SEL)
        "ENABLE"  : mc1_dyn_source      = 1'b1;
        "DISABLE" : mc1_dyn_source      = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute DYN_PHASE_PATH_SEL on pll instance %m is set to %s.", DYN_PHASE_PATH_SEL);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (DYN_FPHASE_EN)
        "ENABLE"  : mc1_dyn_ph_shift_en = 1'b1;
        "DISABLE" : mc1_dyn_ph_shift_en = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute DYN_FPHASE_EN on pll instance %m is set to %s.", DYN_FPHASE_EN);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (CLKC0_DUTY50)
        "ENABLE"  : mc1_duty50_n[0]     = 1'b0;
        "DISABLE" : mc1_duty50_n[0]     = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC0_DUTY50 on pll instance %m is set to %s.", CLKC0_DUTY50);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (CLKC1_DUTY50)
        "ENABLE"  : mc1_duty50_n[1]     = 1'b0;
        "DISABLE" : mc1_duty50_n[1]     = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC1_DUTY50 on pll instance %m is set to %s.", CLKC1_DUTY50);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (CLKC2_DUTY50)
        "ENABLE"  : mc1_duty50_n[2]     = 1'b0;
        "DISABLE" : mc1_duty50_n[2]     = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC2_DUTY50 on pll instance %m is set to %s.", CLKC2_DUTY50);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (CLKC3_DUTY50)
        "ENABLE"  : mc1_duty50_n[3]     = 1'b0;
        "DISABLE" : mc1_duty50_n[3]     = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC3_DUTY50 on pll instance %m is set to %s.", CLKC3_DUTY50);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (CLKC4_DUTY50)
        "ENABLE"  : mc1_duty50_n[4]     = 1'b0;
        "DISABLE" : mc1_duty50_n[4]     = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC4_DUTY50 on pll instance %m is set to %s.", CLKC4_DUTY50);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (CLKC5_DUTY50)
        "ENABLE"  : mc1_duty50_n[5]     = 1'b0;
        "DISABLE" : mc1_duty50_n[5]     = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC5_DUTY50 on pll instance %m is set to %s.", CLKC5_DUTY50);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (CLKC6_DUTY50)
        "ENABLE"  : mc1_duty50_n[6]     = 1'b0;
        "DISABLE" : mc1_duty50_n[6]     = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC6_DUTY50 on pll instance %m is set to %s.", CLKC6_DUTY50);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (CLKC7_DUTY50)
        "ENABLE"  : mc1_duty50_n[7]     = 1'b0;
        "DISABLE" : mc1_duty50_n[7]     = 1'b1;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC7_DUTY50 on pll instance %m is set to %s.", CLKC7_DUTY50);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (SSC_ENABLE)
        "ENABLE"  : mc1_ssc_en          = 1'b1;
        "DISABLE" : mc1_ssc_en          = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute SSC_ENABLE on pll instance %m is set to %s.", SSC_ENABLE);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case(SSC_RST)
        "ENABLE"  : mc1_ssc_reset    = 1'b1;
        "DISABLE" : mc1_ssc_reset    = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute SSC_RST on pll instance %m is set to %s.", SSC_RST);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
        end
    endcase

    case (SSC_MODE)
        "UP"      : begin
                    mc1_ssc_mode            = 1'b1;
                    mc1_ssc_dn_loop_mode    = 1'b0;
        end
        "DOWN"    : begin
                    mc1_ssc_mode            = 1'b1;
                    mc1_ssc_dn_loop_mode    = 1'b1;
        end
        "CENTER"  : begin
                    mc1_ssc_mode            = 1'b0;
                    mc1_ssc_dn_loop_mode    = 1'b1;
        end
        default   : begin
            $display("\n== attribute syntax error : the attribute SSC_MODE on pll instance %m is set to %s.", SSC_MODE);
            $display("==   legal values for this attribute are DOWN or CENTER.");
            $finish;
      end
    endcase

    case (REFCLK_DET_BYP)
        "ENABLE"  : mc1_refclk_det_byp  = 1'b1;
        "DISABLE" : mc1_refclk_det_byp  = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute REFCLK_DET_BYP on pll instance %m is set to %s.", REFCLK_DET_BYP);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case(CLKC0_FRAC_EN)
        "ENABLE"  : mc1_clk0_frac_en    = 1'b1;
        "DISABLE" : mc1_clk0_frac_en    = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC0_FRAC_EN on pll instance %m is set to %s.", CLKC0_FRAC_EN);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
        end
    endcase

    case (PI_OUT_SEL)
        "PI"     : mc1_pi_out_sel       = 8'b0000_0001;
        "NORMAL" : mc1_pi_out_sel       = 8'b0000_0000;
        default   : begin
            $display("\n== attribute syntax error : the attribute PI_OUT_SEL on pll instance %m is set to %s.", PI_OUT_SEL);
            $display("==   legal values for this attribute are PI or NORMAL.");
            $finish;
      end
    endcase

    case (PI_FRAC_EN)
        "ENABLE"  : mc1_pi_frac_mode          = 1'b1;
        "DISABLE" : mc1_pi_frac_mode          = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute PI_FRAC_EN on pll instance %m is set to %s.", PI_FRAC_EN);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (CLKC0_PI_SHIFT_EN)
        "ENABLE"  : mc1_pi_phi_en          = 1'b1;
        "DISABLE" : mc1_pi_phi_en          = 1'b0;
        default   : begin
            $display("\n== attribute syntax error : the attribute CLKC0_PI_SHIFT_EN on pll instance %m is set to %s.", CLKC0_PI_SHIFT_EN);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end
    endcase

    case (DYN_CPHASE_EN)
        "ENABLE"  : mc1_load_en          = 8'hff;
        "DISABLE" : mc1_load_en          = 8'h00;
        default   : begin
            $display("\n== attribute syntax error : the attribute DYN_CPHASE_EN on pll instance %m is set to %s.", DYN_CPHASE_EN);
            $display("==   legal values for this attribute are ENABLE or DISABLE.");
            $finish;
      end

    endcase

    #1;
    done_gwe    =   1'b1;

end
//`ifdef GPLL_PWR_AWARE
  `ifdef FC_PG_SIM
  `else
    reg vccaux_r    =1;     wire vccaux     =vccaux_r;
    reg vccd_r      =1;     wire vccd       =vccd_r;
    reg vssa_r      =0;     wire vssa       =vssa_r;
  `endif


wire    [31:0]  s_tdata_o;
wire    [31:0]  m_tdata_o;
wire    [7:0]   drp_pll_rdata;
wire    [3:0]   mc1_ref_sel;
wire    [31:0]  pll_cfg_o;

reg     [11:0]  map_i           = 0;
reg     [31:0]  s_rdata_i       = 0;
reg     [31:0]  m_rdata_i       = 0;
/*
reg    axis_clk_i; 
reg    axis_rst_n_i;

initial 
begin
    axis_clk_i      =   1'b1;    
    axis_rst_n_i    =   1'b0;
    #1_000
    axis_rst_n_i    =   1'b1;
end

always #10_000  axis_clk_i  <= ~axis_clk_i;
*/

parameter PADDRW                        = 32;
parameter PDATAW                        = 32;


wire [7:0]  dyn_mc1_ref_div; 
wire        dyn_mc1_fastloop_cfg;
wire [1:0]  dyn_mc1_lpf_r1_sel;
wire [4:0]  dyn_mc1_icp_bias;
wire [4:0]  dyn_mc1_icp_banch;
wire [1:0]  dyn_mc1_bias_icfg;
wire        dyn_mc1_clk0_frac_en;
wire [7:0]  dyn_mc1_div_en; 
wire [6:0]  dyn_mc1_divc0;
wire [6:0]  dyn_mc1_divc1;
wire [6:0]  dyn_mc1_divc2;
wire [6:0]  dyn_mc1_divc3;
wire [6:0]  dyn_mc1_divc4;
wire [6:0]  dyn_mc1_divc5;
wire [6:0]  dyn_mc1_divc6;
wire [6:0]  dyn_mc1_divc7;
wire [7:0]  dyn_mc1_divc_outmux;
wire        dyn_mc1_divc_outmux_main;
wire [1:0]  dyn_mc1_divc_premux0;
wire [1:0]  dyn_mc1_divc_premux1;
wire [1:0]  dyn_mc1_divc_premux2;
wire [1:0]  dyn_mc1_divc_premux3;
wire [1:0]  dyn_mc1_divc_premux4;
wire [1:0]  dyn_mc1_divc_premux5;
wire [1:0]  dyn_mc1_divc_premux6;
wire [1:0]  dyn_mc1_divc_premux7;
wire [1:0]  dyn_mc1_divcrst_en;
wire [7:0]  dyn_mc1_divrst_ph_sel;
wire [6:0]  dyn_mc1_duty0   ;       
wire [6:0]  dyn_mc1_duty1   ;
wire [6:0]  dyn_mc1_duty2   ;
wire [6:0]  dyn_mc1_duty3   ;
wire [6:0]  dyn_mc1_duty4   ;
wire [6:0]  dyn_mc1_duty5   ;
wire [7:0]  dyn_mc1_duty50_n;
wire [6:0]  dyn_mc1_duty6   ;
wire [6:0]  dyn_mc1_duty7   ;
wire        dyn_mc1_dyn_ph_shift_en;
wire [6:0]  dyn_mc1_dyn_phc0;
wire [6:0]  dyn_mc1_dyn_phc1;
wire [6:0]  dyn_mc1_dyn_phc2;
wire [6:0]  dyn_mc1_dyn_phc3;
wire [6:0]  dyn_mc1_dyn_phc4;
wire [6:0]  dyn_mc1_dyn_phc5;
wire [6:0]  dyn_mc1_dyn_phc6;
wire [6:0]  dyn_mc1_dyn_phc7;
wire [7:0]  dyn_mc1_enclk;
wire [7:0]  dyn_mc1_fbk_div;
wire [3:0]  dyn_mc1_fbk_sel;
wire [6:0]  dyn_mc1_frac;
wire        dyn_mc1_fracn_en;
wire [6:0]  dyn_mc1_gpll_lockdet;
wire [6:0]  dyn_mc1_phc0;
wire [6:0]  dyn_mc1_phc1;
wire [6:0]  dyn_mc1_phc2;
wire [6:0]  dyn_mc1_phc3;
wire [6:0]  dyn_mc1_phc4;
wire [6:0]  dyn_mc1_phc5;
wire [6:0]  dyn_mc1_phc6;
wire [6:0]  dyn_mc1_phc7;
wire [6:0]  dyn_mc1_phic0;
wire [2:0]  dyn_mc1_phic1;
wire [2:0]  dyn_mc1_phic2;
wire [2:0]  dyn_mc1_phic3;
wire [2:0]  dyn_mc1_phic4;
wire [2:0]  dyn_mc1_phic5;
wire [2:0]  dyn_mc1_phic6;
wire [2:0]  dyn_mc1_phic7;
wire        dyn_mc1_ssc_dn_loop_mode;
wire        dyn_mc1_ssc_en;
wire [17:0] dyn_mc1_ssc_freq_div;
wire [1:0]  dyn_mc1_ssc_lpf_sel;
wire        dyn_mc1_ssc_mode;
wire        dyn_mc1_ssc_reset;
wire [23:0] dyn_mc1_ssc_step                ;

    /*  axis2apb_gpll AUTO_TEMPLATE (
            .wakeup_mux_dly20_i     (pll_wakeup_sync),
            .test_mode              (scan_mode),
        ); */

    axis2apb_gpll
  `ifndef GATE_SIM
    #(
        .TOW                        ( 9         ),
        .TIMEOUT                    ( 9'h1ff    ),
        .LENW                       ( 19        ),
        .MAX_LEN                    ( 19'd2     ),
        .PADDRW                     ( PADDRW    ),
        .PDATAW                     ( PDATAW    )
    )
  `endif
    xaxis2apb_gpll (
  `ifdef FC_PG_SIM
        .vccd                       (vccd       ),
        .vssd                       (vssa       ),
  `endif
                      // Outputs
                      .s_rready_o       (s_rready_o),
                      .s_tvalid_o       (s_tvalid_o),
                      .s_tdata_o        (s_tdata_o[31:0]),
                      .s_tlast_o        (s_tlast_o),
                      .s_tuser_o        (s_tuser_o),
                      .m_tvalid_o       (m_tvalid_o),
                      .m_tdata_o        (m_tdata_o[31:0]),
                      .m_tlast_o        (m_tlast_o),
                      .m_rready_o       (m_rready_o),
                      .drp_pll_err      (drp_err),
                      .drp_pll_rdata    (drp_rdata),
                      .drp_pll_rdy      (drp_rdy),

                      .pll_cfg_o        (pll_cfg_o),
                      .mc1_fastloop_cfg (dyn_mc1_fastloop_cfg),
                      .mc1_bias_icfg    (dyn_mc1_bias_icfg[1:0]),
                      //.mc1_cal_counter  (mc1_cal_counter[2:0]),
                      .mc1_clk0_frac_en (dyn_mc1_clk0_frac_en),
                      //.mc1_cp_dlysel    (mc1_cp_dlysel[2:0]),
                      //.mc1_cp_refsel    (mc1_cp_refsel[2:0]),
                      //.mc1_dig_pd       (mc1_dig_pd),
                      //.mc1_dig_sel      (mc1_dig_sel[5:0]),
                      //.mc1_div2_bypass_n(mc1_div2_bypass_n[7:0]),
                      //.mc1_div2_phc     (mc1_div2_phc[7:0]),
                      .mc1_div_en       (dyn_mc1_div_en[7:0]),
                      .mc1_divc0        (dyn_mc1_divc0[6:0]),
                      .mc1_divc1        (dyn_mc1_divc1[6:0]),
                      .mc1_divc2        (dyn_mc1_divc2[6:0]),
                      .mc1_divc3        (dyn_mc1_divc3[6:0]),
                      .mc1_divc4        (dyn_mc1_divc4[6:0]),
                      .mc1_divc5        (dyn_mc1_divc5[6:0]),
                      .mc1_divc6        (dyn_mc1_divc6[6:0]),
                      .mc1_divc7        (dyn_mc1_divc7[6:0]),
                      .mc1_divc_outmux  (dyn_mc1_divc_outmux[7:0]),
                      .mc1_divc_outmux_main(dyn_mc1_divc_outmux_main),
                      .mc1_divc_premux0 (dyn_mc1_divc_premux0[1:0]),
                      .mc1_divc_premux1 (dyn_mc1_divc_premux1[1:0]),
                      .mc1_divc_premux2 (dyn_mc1_divc_premux2[1:0]),
                      .mc1_divc_premux3 (dyn_mc1_divc_premux3[1:0]),
                      .mc1_divc_premux4 (dyn_mc1_divc_premux4[1:0]),
                      .mc1_divc_premux5 (dyn_mc1_divc_premux5[1:0]),
                      .mc1_divc_premux6 (dyn_mc1_divc_premux6[1:0]),
                      .mc1_divc_premux7 (dyn_mc1_divc_premux7[1:0]),
                      .mc1_divcrst_en   (dyn_mc1_divcrst_en[1:0]),
                      .mc1_divrst_ph_sel(dyn_mc1_divrst_ph_sel[7:0]),
                      .mc1_duty0        (dyn_mc1_duty0[6:0]),
                      .mc1_duty1        (dyn_mc1_duty1[6:0]),
                      .mc1_duty2        (dyn_mc1_duty2[6:0]),
                      .mc1_duty3        (dyn_mc1_duty3[6:0]),
                      .mc1_duty4        (dyn_mc1_duty4[6:0]),
                      .mc1_duty5        (dyn_mc1_duty5[6:0]),
                      .mc1_duty50_n     (dyn_mc1_duty50_n[7:0]),
                      .mc1_duty6        (dyn_mc1_duty6[6:0]),
                      .mc1_duty7        (dyn_mc1_duty7[6:0]),
                      .mc1_dyn_ph_shift_en(dyn_mc1_dyn_ph_shift_en),
                      .mc1_dyn_phc0     (dyn_mc1_dyn_phc0[6:0]),
                      .mc1_dyn_phc1     (dyn_mc1_dyn_phc1[6:0]),
                      .mc1_dyn_phc2     (dyn_mc1_dyn_phc2[6:0]),
                      .mc1_dyn_phc3     (dyn_mc1_dyn_phc3[6:0]),
                      .mc1_dyn_phc4     (dyn_mc1_dyn_phc4[6:0]),
                      .mc1_dyn_phc5     (dyn_mc1_dyn_phc5[6:0]),
                      .mc1_dyn_phc6     (dyn_mc1_dyn_phc6[6:0]),
                      .mc1_dyn_phc7     (dyn_mc1_dyn_phc7[6:0]),
                      //.mc1_dyn_source   (mc1_dyn_source),
                      //.mc1_enable_sync  (mc1_enable_sync),
                      .mc1_enclk        (dyn_mc1_enclk[7:0]),
                      //.mc1_enclk_main   (mc1_enclk_main),
                      //.mc1_fastlock_sel (mc1_fastlock_sel[2:0]),
                      //.mc1_fbfracn_sel  (mc1_fbfracn_sel[23:0]),
                      .mc1_fbk_div      (dyn_mc1_fbk_div[7:0]),
                      .mc1_fbk_sel      (dyn_mc1_fbk_sel[3:0]),
                      //.mc1_fbk_sel_wakeup(mc1_fbk_sel_wakeup[3:0]),
                      .mc1_frac         (dyn_mc1_frac[6:0]),
                      //.mc1_fracn_dither_en(mc1_fracn_dither_en),
                      //.mc1_fracn_dither_sel(mc1_fracn_dither_sel[3:0]),
                      .mc1_fracn_en     (dyn_mc1_fracn_en),
                      //.mc1_fracn_prbs_sel(mc1_fracn_prbs_sel[1:0]),
                      ////.mc1_freq_lock    (mc1_freq_lock),
                      .mc1_gpll_lockdet (dyn_mc1_gpll_lockdet[6:0]),
                      .mc1_icp_banch    (dyn_mc1_icp_banch[4:0]),
                      .mc1_icp_bias     (dyn_mc1_icp_bias[4:0]),
                      //.mc1_intfb        (mc1_intfb),
                      //.mc1_kvco_sel     (mc1_kvco_sel[3:0]),
                      //.mc1_load_div2_en (mc1_load_div2_en[7:0]),
                      //.mc1_load_en      (mc1_load_en[7:0]),
                      .mc1_lpf_r1_sel   (dyn_mc1_lpf_r1_sel[1:0]),
                      //.mc1_mrst_en      (mc1_mrst_en),
                      //.mc1_outgate_en   (mc1_outgate_en[7:0]),
                      //.mc1_outputpi_capsel(mc1_outputpi_capsel[2:0]),
                      //.mc1_outputpi_icfg(mc1_outputpi_icfg[2:0]),
                      .mc1_phc0         (dyn_mc1_phc0[6:0]),
                      .mc1_phc1         (dyn_mc1_phc1[6:0]),
                      .mc1_phc2         (dyn_mc1_phc2[6:0]),
                      .mc1_phc3         (dyn_mc1_phc3[6:0]),
                      .mc1_phc4         (dyn_mc1_phc4[6:0]),
                      .mc1_phc5         (dyn_mc1_phc5[6:0]),
                      .mc1_phc6         (dyn_mc1_phc6[6:0]),
                      .mc1_phc7         (dyn_mc1_phc7[6:0]),
                      .mc1_phic0        (dyn_mc1_phic0[6:0]),
                      .mc1_phic1        (dyn_mc1_phic1[2:0]),
                      .mc1_phic2        (dyn_mc1_phic2[2:0]),
                      .mc1_phic3        (dyn_mc1_phic3[2:0]),
                      .mc1_phic4        (dyn_mc1_phic4[2:0]),
                      .mc1_phic5        (dyn_mc1_phic5[2:0]),
                      .mc1_phic6        (dyn_mc1_phic6[2:0]),
                      .mc1_phic7        (dyn_mc1_phic7[2:0]),
                      //.mc1_pi_capsel    (mc1_pi_capsel[2:0]),
                      //.mc1_pi_frac_mode (mc1_pi_frac_mode),
                      //.mc1_pi_icfg      (mc1_pi_icfg[3:0]),
                      //.mc1_pi_out_sel   (mc1_pi_out_sel[7:0]),
                      //.mc1_pi_phi_en    (mc1_pi_phi_en),
                      //.mc1_pllpdn       (mc1_pllpdn),
                      //.mc1_pllrst_en    (mc1_pllrst_en),
                      .mc1_ref_div      (dyn_mc1_ref_div[7:0]),
                      //.mc1_refclk_det_byp(mc1_refclk_det_byp),
                      //.mc1_refclk_det_div(mc1_refclk_det_div[1:0]),
                      //.mc1_refclk_out_en(mc1_refclk_out_en),
                      .mc1_ssc_dn_loop_mode(dyn_mc1_ssc_dn_loop_mode),
                      .mc1_ssc_en       (dyn_mc1_ssc_en),
                      .mc1_ssc_freq_div (dyn_mc1_ssc_freq_div[17:0]),
                      .mc1_ssc_lpf_sel  (dyn_mc1_ssc_lpf_sel[1:0]),
                      .mc1_ssc_mode     (dyn_mc1_ssc_mode),
                      .mc1_ssc_reset    (dyn_mc1_ssc_reset),
                      .mc1_ssc_step     (dyn_mc1_ssc_step[23:0]),
                      //.mc1_syn_sel      (mc1_syn_sel[2:0]),
                      //.mc1_tda_en       (mc1_tda_en),
                      //.mc1_test_en      (mc1_test_en),
                      ////.mc1_vco_band     (mc1_vco_band[3:0]),
                      ////.mc1_vco_cal_mode (mc1_vco_cal_mode),
                      //.mc1_vctrl_sel    (mc1_vctrl_sel[1:0]),
                      //.mc1_ref_sel      (mc1_ref_sel[3:0]),
                      //.mc1_pi_delay     (mc1_pi_delay),
                      //// Inputs
                      .test_mode        (1'b0),             // Templated
                      //.map_i            (map_i[11:0]),
                      //.axis_clk_i       (axis_clk_i),
                      //.axis_rst_n_i     (axis_rst_n_i),
                      //.s_rvalid_i       (s_rvalid_i),
                      //.s_rdata_i        (s_rdata_i[31:0]),
                      //.s_rlast_i        (s_rlast_i),
                      //.s_tready_i       (s_tready_i),
                      //.m_tready_i       (m_tready_i),
                      //.m_rvalid_i       (m_rvalid_i),
                      //.m_rdata_i        (m_rdata_i[31:0]),
                      //.m_rlast_i        (m_rlast_i),
                      //.m_tuser_i        (m_tuser_i),
                      .drp_clk          (drp_clk),
                      .drp_pll_addr     (drp_addr),
                      .drp_pll_rd       (drp_rd),
                      .drp_pll_sel      (drp_sel),
                      .drp_pll_wdata    (drp_wdata),
                      .drp_pll_wr       (drp_wr),
                      .drp_rst_n        (drp_rstn),
                      .wakeup_mux_dly20_i(pll_wakeup_sync),
                      .scan_resetn      (1'b1    ),
                      .scan_enable      (1'b1    ),
                      .scan_clk         (1'b1       ),
                      //.scan_in          (scan_in      ),      //use drp_pll_rd
                      .scan_out         (scan_out       ));     //to fbdiv

always @(*)
begin
    if(drp_wr && drp_addr == 8'd4)
      #50  mc1_ref_div         <=  dyn_mc1_ref_div         ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd78)
      #50  mc1_fastloop_cfg    <=  dyn_mc1_fastloop_cfg    ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd74)
      #50  mc1_lpf_r1_sel      <=  dyn_mc1_lpf_r1_sel      ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd75)
      #50  mc1_icp_bias        <=  dyn_mc1_icp_bias        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd76)
      #50  mc1_icp_banch       <=  dyn_mc1_icp_banch       ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd69)
    begin
      #50  mc1_clk0_frac_en    <=  dyn_mc1_clk0_frac_en    ;
      #50   mc1_frac           <=  dyn_mc1_frac            ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd26)
      #50  mc1_div_en          <=  dyn_mc1_div_en          ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd37)
    begin
      #50  mc1_divc0           <=  dyn_mc1_divc0           ;
      #50  mc1_divc_premux0[1] <=  dyn_mc1_divc_premux0[1] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd41)
    begin
      #50  mc1_divc1           <=  dyn_mc1_divc1           ;
      #50  mc1_divc_premux1[1] <=  dyn_mc1_divc_premux1[1] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd45)
    begin
      #50  mc1_divc2           <=  dyn_mc1_divc2           ;
      #50  mc1_divc_premux2[1] <=  dyn_mc1_divc_premux2[1] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd49)
    begin
      #50  mc1_divc3           <=  dyn_mc1_divc3           ;
      #50  mc1_divc_premux3[1] <=  dyn_mc1_divc_premux3[1] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd53)
    begin
      #50  mc1_divc4           <=  dyn_mc1_divc4           ;
      #50  mc1_divc_premux4[1] <=  dyn_mc1_divc_premux4[1] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd57)
    begin
      #50  mc1_divc5           <=  dyn_mc1_divc5           ;
      #50  mc1_divc_premux5[1] <=  dyn_mc1_divc_premux5[1] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd61)
    begin
      #50  mc1_divc6           <=  dyn_mc1_divc6           ;
      #50  mc1_divc_premux6[1] <=  dyn_mc1_divc_premux6[1] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd65)
    begin
      #50  mc1_divc7           <=  dyn_mc1_divc7           ;
      #50  mc1_divc_premux7[1] <=  dyn_mc1_divc_premux7[1] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd66)
      #50  mc1_divc_outmux     <=  dyn_mc1_divc_outmux     ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd77)
      #50  mc1_divc_outmux_main<=  dyn_mc1_divc_outmux_main;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd1)
      #50  mc1_divcrst_en      <=  dyn_mc1_divcrst_en      ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd2)
      #50  mc1_divrst_ph_sel   <=  dyn_mc1_divrst_ph_sel   ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd34)
      #50   mc1_duty0           <=  dyn_mc1_duty0           ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd38)
      #50   mc1_duty1           <=  dyn_mc1_duty1           ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd42)
      #50   mc1_duty2           <=  dyn_mc1_duty2           ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd46)
      #50   mc1_duty3           <=  dyn_mc1_duty3           ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd50)
      #50   mc1_duty4           <=  dyn_mc1_duty4           ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd54)
      #50   mc1_duty5           <=  dyn_mc1_duty5           ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd58)
      #50   mc1_duty6           <=  dyn_mc1_duty6           ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd62)
      #50   mc1_duty7           <=  dyn_mc1_duty7           ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd30)
      #50   mc1_duty50_n        <=  dyn_mc1_duty50_n        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd12)
      #50   mc1_dyn_ph_shift_en <=  dyn_mc1_dyn_ph_shift_en ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd35)
      #50   mc1_dyn_phc0        <=  dyn_mc1_dyn_phc0        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd39)
      #50   mc1_dyn_phc1        <=  dyn_mc1_dyn_phc1        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd43)
      #50   mc1_dyn_phc2        <=  dyn_mc1_dyn_phc2        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd47)
      #50   mc1_dyn_phc3        <=  dyn_mc1_dyn_phc3        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd51)
      #50   mc1_dyn_phc4        <=  dyn_mc1_dyn_phc4        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd55)
      #50   mc1_dyn_phc5        <=  dyn_mc1_dyn_phc5        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd59)
      #50   mc1_dyn_phc6        <=  dyn_mc1_dyn_phc6        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd63)
      #50   mc1_dyn_phc7        <=  dyn_mc1_dyn_phc7        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd29)
      #50   mc1_enclk           <=  dyn_mc1_enclk           ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd18)
      #50   mc1_fbk_div         <=  dyn_mc1_fbk_div         ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd5)
      #50   mc1_fbk_sel         <=  dyn_mc1_fbk_sel         ;
 end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd17)
      #50   mc1_fracn_en        <=  dyn_mc1_fracn_en        ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd70)
      #50   mc1_gpll_lockdet    <=  dyn_mc1_gpll_lockdet    ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd36)
    begin
      #50   mc1_phc0            <=  dyn_mc1_phc0            ;
      #50   mc1_divc_premux0[0] <=  dyn_mc1_divc_premux0[0] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd40)
    begin
      #50   mc1_phc1            <=  dyn_mc1_phc1            ;
      #50   mc1_divc_premux1[0] <=  dyn_mc1_divc_premux1[0] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd44)
    begin
      #50   mc1_phc2            <=  dyn_mc1_phc2            ;
      #50   mc1_divc_premux2[0] <=  dyn_mc1_divc_premux2[0] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd48)
    begin
      #50   mc1_phc3            <=  dyn_mc1_phc3            ;
      #50   mc1_divc_premux3[0] <=  dyn_mc1_divc_premux3[0] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd52)
    begin
      #50   mc1_phc4            <=  dyn_mc1_phc4            ;
      #50   mc1_divc_premux4[0] <=  dyn_mc1_divc_premux4[0] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd56)
    begin
      #50   mc1_phc5            <=  dyn_mc1_phc5            ;
      #50   mc1_divc_premux5[0] <=  dyn_mc1_divc_premux5[0] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd60)
    begin
      #50   mc1_phc6            <=  dyn_mc1_phc6            ;
      #50   mc1_divc_premux6[0] <=  dyn_mc1_divc_premux6[0] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd64)
    begin
      #50   mc1_phc7            <=  dyn_mc1_phc7            ;
      #50   mc1_divc_premux7[0] <=  dyn_mc1_divc_premux7[0] ;
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd9)
      #50   mc1_phic0           <=  dyn_mc1_phic0           ;
 end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd10)
    begin
      #50   mc1_phic1           <=  dyn_mc1_phic1           ;
      #50   mc1_phic2           <=  dyn_mc1_phic2           ;
    end
 end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd11)
    begin
      #50   mc1_phic3           <=  dyn_mc1_phic3           ;
      #50   mc1_phic4           <=  dyn_mc1_phic4           ;
    end
 end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd12)
    begin
      #50   mc1_phic5           <=  dyn_mc1_phic5           ;
      #50   mc1_phic6           <=  dyn_mc1_phic6           ;
      #50   mc1_dyn_ph_shift_en <=  dyn_mc1_dyn_ph_shift_en ;
    end
 end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd13)
      #50   mc1_phic7           <=  dyn_mc1_phic7           ;
 end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd25)
    begin
      #50   mc1_ssc_dn_loop_mode<=  dyn_mc1_ssc_dn_loop_mode;
      #50   mc1_ssc_lpf_sel     <=  dyn_mc1_ssc_lpf_sel     ;
      #50   mc1_ssc_mode        <=  dyn_mc1_ssc_mode        ;
      #50   mc1_ssc_en          <=  dyn_mc1_ssc_en          ;
      
    end
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd22)
      #50   mc1_ssc_freq_div    <=  dyn_mc1_ssc_freq_div    ;
 end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd0)
      #50   mc1_ssc_reset       <=  dyn_mc1_ssc_reset       ;
end

always @(*)
begin
    if(drp_wr && drp_addr == 8'd19)
      #50   mc1_ssc_step        <=  dyn_mc1_ssc_step        ;
end

wire    clkc_7;
wire    clkcb_7;
wire    clkc_en_7;
wire    clkc_en_main;


    /*  gpll_top AUTO_TEMPLATE (
        ); */
    gpll_top xpll (
//`ifdef FC_PG_SIM
        .vccaux                     (vccaux),
        .vccd                       (vccd),
        .vssa                       (vssa),
//`endif
        .int_lock_in                (1'b1           ),
        .int_lock_out               (int_lock_out   ),
        .tieh                       (tieh           ),
        .tiel                       (tiel           ),
    /*AUTOINST*/


 //Param TBD
        .mc1_cal_counter                (mc1_cal_counter),
        .mc1_dig_sel                    (mc1_dig_sel),
        .mc1_fracn_prbs_sel             (mc1_fracn_prbs_sel),
        .mc1_dyn_phc0                   (mc1_dyn_phc0),
        .mc1_dyn_phc1                   (mc1_dyn_phc1),
        .mc1_dyn_phc2                   (mc1_dyn_phc2),
        .mc1_dyn_phc3                   (mc1_dyn_phc3),
        .mc1_dyn_phc4                   (mc1_dyn_phc4),
        .mc1_dyn_phc5                   (mc1_dyn_phc5),
        .mc1_dyn_phc6                   (mc1_dyn_phc6),
        .mc1_dyn_phc7                   (mc1_dyn_phc7),       
        .mc1_divcrst_en                 (mc1_divcrst_en),
        .mc1_enable_sync                (mc1_enable_sync),
        .mc1_enclk                      (mc1_enclk),    
        .mc1_enclk_main                 (mc1_enclk_main),
        .mc1_gpll_lockdet               (mc1_gpll_lockdet), 
        .mc1_load_div2_en               (mc1_load_div2_en),

        .mc1_outgate_en                 (mc1_outgate_en),
        .mc1_bias_icfg                  (mc1_bias_icfg),
        .mc1_lpf_r1_sel                 (mc1_lpf_r1_sel),
        .mc1_icp_bias                   (mc1_icp_bias), 
        .mc1_icp_banch                  (mc1_icp_banch),
        .mc1_refclk_det_div             (mc1_refclk_det_div),
        .mc1_fracn_dither_sel           (mc1_fracn_dither_sel),
        .mc1_fracn_dither_en            (mc1_fracn_dither_en),
        .mc1_ssc_dn_loop_mode           (mc1_ssc_dn_loop_mode),
        .mc1_test_en                    (mc1_test_en),
        .mc1_div2_bypass_n              (mc1_div2_bypass_n),
        .mc1_div2_phc                   (mc1_div2_phc),
        .mc1_refclk_out_en              (mc1_refclk_out_en),
        .mc1_mrst_en                    (mc1_mrst_en),


        .mc1_fastloop_cfg               (mc1_fastloop_cfg),
        .mc1_cp_dlysel                  (mc1_cp_dlysel[2:0]),
        .mc1_cp_refsel                  (mc1_cp_refsel[2:0]),
        .mc1_vctrl_sel                  (mc1_vctrl_sel[1:0]),
        .mc1_outputpi_capsel            (mc1_outputpi_capsel[2:0]),
        .mc1_fastlock_sel               (mc1_fastlock_sel[2:0]),
        .mc1_kvco_sel                   (mc1_kvco_sel[3:0]),
        .mc1_outputpi_icfg              (mc1_outputpi_icfg[2:0]),

        .mc1_tda_en                     (mc1_tda_en),
        .mc1_pi_capsel                  (mc1_pi_capsel[2:0]),

//Param
        .mc1_pllpdn                     (mc1_pllpdn),
        .mc1_dig_pd                     (mc1_dig_pd),
        .mc1_pllrst_en                  (mc1_pllrst_en),
        .mc1_ssc_en                     (mc1_ssc_en),
        .mc1_ssc_reset                  (mc1_ssc_reset),
        .mc1_ssc_mode                   (mc1_ssc_mode),
        .mc1_ssc_lpf_sel                (mc1_ssc_lpf_sel),
        .mc1_divrst_ph_sel              (mc1_divrst_ph_sel),
        .mc1_intfb                      (mc1_intfb),      
        .mc1_fbk_sel_wakeup             (mc1_fbk_sel_wakeup),
        .mc1_fbk_sel                    (mc1_fbk_sel),
        .mc1_ref_div                    (mc1_ref_div),
        .mc1_fbk_div                    (mc1_fbk_div),
        .mc1_fbfracn_sel                (mc1_fbfracn_sel),    //CHANGE
        .mc1_fracn_en                   (mc1_fracn_en),  
        .mc1_dyn_source                 (mc1_dyn_source),
        .mc1_syn_sel                    (mc1_syn_sel),
        .mc1_dyn_ph_shift_en            (mc1_dyn_ph_shift_en),
        .mc1_phic0                      (mc1_phic0),
        .mc1_phic1                      (mc1_phic1),
        .mc1_phic2                      (mc1_phic2),
        .mc1_phic3                      (mc1_phic3),
        .mc1_phic4                      (mc1_phic4),  
        .mc1_phic5                      (mc1_phic5),
        .mc1_phic6                      (mc1_phic6),   
        .mc1_phic7                      (mc1_phic7),
        .mc1_ssc_freq_div               (mc1_ssc_freq_div),
        .mc1_ssc_step                   (mc1_ssc_step),
        .mc1_pi_frac_mode               (mc1_pi_frac_mode),     
        .mc1_pi_out_sel                 (mc1_pi_out_sel),
        .mc1_clk0_frac_en               (mc1_clk0_frac_en),
        .mc1_frac                       (mc1_frac),
        .mc1_div_en                     (mc1_div_en),
        .mc1_duty50_n                   (mc1_duty50_n),
        .mc1_divc_outmux                (mc1_divc_outmux),
        .mc1_load_en                    (mc1_load_en),
        .mc1_divc_outmux_main           (mc1_divc_outmux_main),
        .mc1_divc_premux0               (mc1_divc_premux0),
        .mc1_divc0                      (mc1_divc0),
        .mc1_phc0                       (mc1_phc0),
        .mc1_duty0                      (mc1_duty0), 
        .mc1_divc_premux1               (mc1_divc_premux1),
        .mc1_divc1                      (mc1_divc1),
        .mc1_phc1                       (mc1_phc1),
        .mc1_duty1                      (mc1_duty1), 
        .mc1_divc_premux2               (mc1_divc_premux2),
        .mc1_divc2                      (mc1_divc2),
        .mc1_phc2                       (mc1_phc2),
        .mc1_duty2                      (mc1_duty2), 
        .mc1_divc_premux3               (mc1_divc_premux3),
        .mc1_divc3                      (mc1_divc3),
        .mc1_phc3                       (mc1_phc3),
        .mc1_duty3                      (mc1_duty3), 
        .mc1_divc_premux4               (mc1_divc_premux4),
        .mc1_divc4                      (mc1_divc4),
        .mc1_phc4                       (mc1_phc4),
        .mc1_duty4                      (mc1_duty4), 
        .mc1_divc_premux5               (mc1_divc_premux5),
        .mc1_divc5                      (mc1_divc5),
        .mc1_phc5                       (mc1_phc5),
        .mc1_duty5                      (mc1_duty5), 
        .mc1_divc_premux6               (mc1_divc_premux6),
        .mc1_divc6                      (mc1_divc6),
        .mc1_phc6                       (mc1_phc6),
        .mc1_duty6                      (mc1_duty6), 
        .mc1_divc_premux7               (mc1_divc_premux7),
        .mc1_divc7                      (mc1_divc7),
        .mc1_phc7                       (mc1_phc7),
        .mc1_duty7                      (mc1_duty7), 
        .mc1_refclk_det_byp             (mc1_refclk_det_byp),
        .mc1_pi_phi_en                  (mc1_pi_phi_en),
        .ibn_10u_vref                   (ibn_10u_vref),
        .pib_lockdet_clr_n              (pib_lockdet_clr_n),   
        .ibn_10u_ptat                   (ibn_10u_ptat),         // input
        .mc1_pi_delay                   (mc1_pi_delay), 
        .mc1_pi_icfg                    (mc1_pi_icfg),   

//Global clocks
        .gpll_refck                     ({15'b00_0000_0000_0000,refclk}),
        .mc1_ref_sel                    ({3'b000,refclk_sel}),
        .fbkck                          ({7{fbclk}}),
        .ckout_t                        ({clkc_7,clkc[6:0]}), 
        .ckout_c                        ({clkcb_7,clkcb[6:0]}),
        .ckout_t_main                   (ckout_t_main),
        .ckout_c_main                   (ckout_c_main),

//PLL and output path reset		
        .pib_rst_divc                   (clkc_rst),
        .pib_pllreset                   (pllreset),

//PLL POWER DOWN
        .pllpd                          (pllpd),

//PLL dynamic fine phase shift
        .pib_psclk                      (psclk),
        .pib_psclksel                   (psclksel),          
        .pib_psstep                     (psstep),
        .pib_psdown                     (psdown),
        .pib_psdone                     (psdone),  

//PLL dynamic coarse phase shift
        .pib_load_reg                   (cps_step),
        
//Ports of SSC
        .pib_ssc_reset                  (ssc_reset),

//PLL output clk enable	
        .pib_enclk                      ({clkc_en_7,clkc_en[6:0]}),
        .pib_enclk_main                 (clkc_en_main),            
//PLL  lock detector
        .lock                           (lock),
        .int_lock                       (int_lock),            
    
        .dig_pd                         (dig_pd),
        .done_gwe                       (done_gwe),
        .pib_clkout_glitchless_en_n     (pib_clkout_glitchless_en_n),         
        .pib_done_pll                   (pib_done_pll),
        .ibp_10u_poly                   (ibp_10u_poly),
        .pib_en_pll2io_n                (pib_en_pll2io_n),        
        .pib_fbkshot                    (pib_fbkshot),        
        .pib_load_div2_reg              (pib_load_div2_reg),       
        .pib_refshot                    (pib_refshot),       
        .pib_rst_m                      (refclk_rst),
        .pll_wakeup_sync                (wakeup),

//others parmaeter port
        .scan_mode                      (1'b0),       
        .scan_resetn                    (1'b1),
        .scan_enable                    (1'b1),
        .scan_clk                       (1'b1),
        .scan_in                        (1'b1),              
        .ck_pll2io                      (ck_pll2io),
        //inout
        .pib_dig_out                    (pib_dig_out),
        .pib_dyn_status                 (pib_dyn_status),
        .refclk_out                     (refclk_out)

);
endmodule




// SystemVerilog netlist generated by the Virtuoso SystemVerilog Netlister
// IC subversion:  IC6.1.8-64b.500.12 
// IUS version: 15.10-s010
// Copyright(C) 2005-2009, Cadence Design Systems, Inc
// User: zcwang Pid: 319492
// Design library name: al6100_analog
// Design cell name: gpll_top
// Design view name: config

//systemVerilog HDL for "al6100_serdes_pll", "cpll_div_n_logic" "systemVerilog"

`timescale 1ns/1fs
module cpll_div_n_logic ( bypass, en_out, p_out, pu, pxb, d, en_in, vcca, vssa );
input 			vcca;
input 			vssa;

input 			en_in;
input   [7:0] 	d;

output			pu;
output 			pxb;
output 			bypass;

output  [6:0] 	p_out;
output  [6:0] 	en_out;

//logic begin
wire    [6:0]   en;
wire 			div4;

assign en[6]  =  d[7];
assign en[5]  =  en[6] | d[6];
assign en[4]  =  en[5] | d[5];
assign en[3]  =  en[4] | d[4];
assign en[2]  =  en[3] | d[3];
assign en[1]  =  en[2] | d[2];
assign en[0]  =  en[1] | d[1];
assign bypass =  !(en[0] | !en_in);

assign pu 	  =  en_in;
assign pxb    =  !( !( !( !d[0] & !d[1] & d[2] ) & !en[2]) & !en[2]);
assign div4   =  !pxb;
// en_logic
assign en_out[0]   = en[0];
assign en_out[1]   = !( div4 | !en[1] );
assign en_out[6:2] = en[6:2];
// p_logic
assign p_out[0]	   = div4 | d[0];
assign p_out[6:1]  = d[6:1];

endmodule


// Library - al6100_analog, Cell - gpll_vco_mux_top, View - schematic
// LAST TIME SAVED: May 22 15:13:28 2023


`timescale 1ns / 1ps
module gpll_vco_mux_top ( 
output  [7:0] ck_out, 
output  [7:0] phasedone, 
output   phomux0, 
output  [7:0] phomux, 
input   ck0_div, 
input   ck0_div_by_one, 
input  [7:0] ck_out_path_en, 
input  [7:0] direction, 
input  [1:0] ibn_5u, 
input   ibn_100u_poly, 
input   ibn_100u_vco, 
input   mc1_clk0_frac_en, 
input   mc1_dyn_ph_shift_en, 
input  [6:0] mc1_frac, 
input   mc1_outputpi_icfg, 
input  [7:0] mc1_phomux_sel, 
input  [2:0] mc1_pi_capsel, 
input   mc1_pi_frac_mode, 
input   mc1_pi_phshift_en, 
input  [7:0] mc1_pi_sel, 
input  [7:0] phin, 
input  [6:0] phsel_0, 
input  [2:0] phsel_1, 
input  [2:0] phsel_2, 
input  [2:0] phsel_3, 
input  [2:0] phsel_4, 
input  [2:0] phsel_5, 
input  [2:0] phsel_6, 
input  [2:0] phsel_7, 
input   pllrst_n, 
input  [7:0] rotate, 
input  [7:0] scanclk, 
input wire  vccd , 
input wire  vco_en , 
input   vreg_0p9, 
input   vreg_rdy, 
input wire  vssa  );

// Buses in the design

wire [7:0]  vco_phase;
//add analog delay for output path 0
reg ck0_div_dly;

  always @(*)
    ck0_div_dly <= #0.1 ck0_div;

wire [6:0]  phc;


gpll_vco_mux_pi_top x_gpll_vco_mux_pi_top ( .vco_en(vco_en), 
    .pi_capsel(mc1_pi_capsel[2:0]), .pi_icfg(mc1_outputpi_icfg), 
    .ibn_5u(ibn_5u[1:0]), .ibn_100u_vco(ibn_100u_vco), 
    .ibn_100u_poly(ibn_100u_poly), .vreg_0p9(vreg_0p9), .ckout(ck_pi), 
    .dpher(phc[6:0]), .ph_in(vco_phase[7:0]), .pi_en(pi_en), 
    .pll_rst_n(pllrst_n), .vccd(vccd), .vreg_rdy(vreg_rdy), 
    .vssa(vssa));

gpll_vco_mux  x_gpll_vco_mux ( .mc1_pi_sel(mc1_pi_sel[7:0]), 
    .ck_mux_out(ck_out[7:0]), .en_clk(ck_out_path_en[7:0]), 
    .pllrst_n(pllrst_n), .mc1_phomux_sel(mc1_phomux_sel[7:0]), 
    .mc1_pi_frac_mode(mc1_pi_frac_mode), .mc1_frac(mc1_frac[6:0]), 
    .mc1_dyn_ph_shift_en(mc1_dyn_ph_shift_en), 
    .mc1_pi_phshift_en(mc1_pi_phshift_en), 
    .mc1_clk0_frac_en(mc1_clk0_frac_en), .phsel_6(phsel_6[2:0]), 
    .phsel_7(phsel_7[2:0]), .phsel_5(phsel_5[2:0]), 
    .phsel_4(phsel_4[2:0]), .phsel_3(phsel_3[2:0]), 
    .phsel_2(phsel_2[2:0]), .phsel_0(phsel_0[6:0]), 
    .phsel_1(phsel_1[2:0]), .direction(direction[7:0]), 
    .pi_enable(pi_en), .phomux0(phomux0), .phasedone(phasedone[7:0]), 
    .ck0_div(ck0_div_dly), .ck0_div_by_one(ck0_div_by_one), .ck_pi(ck_pi), 
    .phomux(phomux[7:0]), .vco_phase(vco_phase[7:0]), .phc(phc[6:0]), 
    .scanclk(scanclk[7:0]), .phin(phin[7:0]), .rotate(rotate[7:0]), 
    .vccd(vccd), .vssd(vssa));

endmodule


// Library - al6100_analog, Cell - gpll_fracn_top_v1, View - schematic
// LAST TIME SAVED: May 22 15:13:30 2023


module gpll_fracn_top_v1 ( 
output wire  ck_div , 
output wire  ck_out_n , 
output wire  ck_out_p , 
output wire  dig_rstn , 
output wire  fracn_dig_en , 
output wire  ssc_dig_en , 
input wire   ck_vco_n, 
input wire   ck_vco_p, 
input   divn_en, 
input wire [7:0] fb_divn, 
input  [7:0] fb_divn_dig, 
input   fracn_en, 
input wire   i40u_src, 
input wire  [2:0] pi_capsel, 
input  [5:0] pi_ctrl_dig, 
input   rstn, 
input   ssc_en, 
input wire  vcca , 
input wire  vssa  );


wire  pb;
// Buses in the design

wire [7:0] fb_divn_sync ;

wire [7:0]  fb_divn_mux;

wire [5:0]  pi_ctrl_sync;


al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_7 ( .qout(fb_divn_sync[7]), 
    .ck(ck_div), .din(fb_divn_dig[7]), .rstn(diff_rstn), .vccd(vcca), 
    .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_6 ( .qout(fb_divn_sync[6]), 
    .ck(ck_div), .din(fb_divn_dig[6]), .rstn(diff_rstn), .vccd(vcca), 
    .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_5 ( .qout(fb_divn_sync[5]), 
    .ck(ck_div), .din(fb_divn_dig[5]), .rstn(diff_rstn), .vccd(vcca), 
    .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_4 ( .qout(fb_divn_sync[4]), 
    .ck(ck_div), .din(fb_divn_dig[4]), .rstn(diff_rstn), .vccd(vcca), 
    .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_3 ( .qout(fb_divn_sync[3]), 
    .ck(ck_div), .din(fb_divn_dig[3]), .rstn(diff_rstn), .vccd(vcca), 
    .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_2 ( .qout(fb_divn_sync[2]), 
    .ck(ck_div), .din(fb_divn_dig[2]), .rstn(diff_rstn), .vccd(vcca), 
    .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_1 ( .qout(fb_divn_sync[1]), 
    .ck(ck_div), .din(fb_divn_dig[1]), .rstn(diff_rstn), .vccd(vcca), 
    .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_0 ( .qout(fb_divn_sync[0]), 
    .ck(ck_div), .din(fb_divn_dig[0]), .rstn(diff_rstn), .vccd(vcca), 
    .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_53_5 ( .Q(pi_ctrl_sync[5]), 
    .D(pi_ctrl_dig[5]), .CK(net0127), .RDN(diff_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_53_4 ( .Q(pi_ctrl_sync[4]), 
    .D(pi_ctrl_dig[4]), .CK(net0127), .RDN(diff_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_53_3 ( .Q(pi_ctrl_sync[3]), 
    .D(pi_ctrl_dig[3]), .CK(net0127), .RDN(diff_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_53_2 ( .Q(pi_ctrl_sync[2]), 
    .D(pi_ctrl_dig[2]), .CK(net0127), .RDN(diff_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_53_1 ( .Q(pi_ctrl_sync[1]), 
    .D(pi_ctrl_dig[1]), .CK(net0127), .RDN(diff_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_53_0 ( .Q(pi_ctrl_sync[0]), 
    .D(pi_ctrl_dig[0]), .CK(net0127), .RDN(diff_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

com_hss_tiel x_com_hss_tiel_102 ( .tiel(tile_l), .vdda(vcca), 
    .vssa(vssa));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_85 ( .vssa(vssa), .dat_out(net098), 
    .vdda(vcca), .dat_in(p0));

al6100gpll_com_hss_inv2x x_com_hss_inv4x_84 ( .vssa(vssa), .dat_out(net022), 
    .vdda(vcca), .dat_in(p0));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_104 ( .vssa(vssa), .dat_out(net0122), 
    .vdda(vcca), .dat_in(net0148));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_99 ( .vssa(vssa), .dat_out(net0124), 
    .vdda(vcca), .dat_in(ck_div_out));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_127 ( .vssa(vssa), .dat_out(ck_out_p), 
    .vdda(vcca), .dat_in(net0144));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_125_1 ( .vssa(vssa), .dat_out(ck_div), 
    .vdda(vcca), .dat_in(net0129));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_125_0 ( .vssa(vssa), .dat_out(ck_div), 
    .vdda(vcca), .dat_in(net0129));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_96 ( .vssa(vssa), .dat_out(ck_out_n), 
    .vdda(vcca), .dat_in(net0126));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_123 ( .vssa(vssa), .dat_out(net0129), 
    .vdda(vcca), .dat_in(net0100));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_126 ( .vssa(vssa), .dat_out(net0127), 
    .vdda(vcca), .dat_in(pi_outn));

al6100gpll_NAND2CV1_140P12T40L  x_NAND2CV1_140P12T40L_117 ( .A1(mux_out), 
    .ZN(net0157), .A2(rstn), .VDD(vcca), .VSS(vssa), .VNW(vcca), 
    .VPW(vssa));

al6100gpll_NAND2CV1_140P12T40L  x_NAND2CV1_140P12T40L_115 ( .A1(rstn), 
    .ZN(divn_enb_rst), .A2(divn_en), .VDD(vcca), .VSS(vssa), 
    .VNW(vcca), .VPW(vssa));

al6100gpll_NAND2CV1_140P12T40L  x_NAND2CV1_140P12T40L_107 ( .A1(divn_en), 
    .ZN(fracn_dig_enb), .A2(fracn_en), .VDD(vcca), .VSS(vssa), 
    .VNW(vcca), .VPW(vssa));

al6100gpll_com_hss_tgate_2x x_com_hss_tgate_2x_100 ( .seln(tile_l), 
    .va(ck_div_out), .vcca(vcca), .sel(tile_h), .vssa(vssa), 
    .vz(net0123));

com_hss_tieh x_com_hss_tieh_101 ( .tieh(tile_h), .vdda(vcca), 
    .vssa(vssa));

al6100gpll_NAND2BV1_140P12T40L  x_NAND2BV1_140P12T40L_108 ( .A1(fracn_en), 
    .ZN(mux_inb), .VSS(vssa), .B1(divn_en), .VDD(vcca), .VNW(vcca), 
    .VPW(vssa));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_88 ( .vssa(vssa), .dat_out(net0100), 
    .vdda(vcca), .dat_in(net022));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_86 ( .vssa(vssa), .dat_out(net094), 
    .vdda(vcca), .dat_in(net098));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_118 ( .vssa(vssa), .dat_out(diff_rstn), 
    .vdda(vcca), .dat_in(net0157));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_116 ( .vssa(vssa), 
    .dat_out(divn_en_rstn), .vdda(vcca), .dat_in(divn_enb_rst));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_110 ( .vssa(vssa), .dat_out(mux_out), 
    .vdda(vcca), .dat_in(fracn_dig_enb));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_111 ( .vssa(vssa), .dat_out(mux_in), 
    .vdda(vcca), .dat_in(mux_inb));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_112 ( .vssa(vssa), .dat_out(ssc_dig_en), 
    .vdda(vcca), .dat_in(ssc_dig_enb));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_119 ( .vssa(vssa), .dat_out(dig_rstn), 
    .vdda(vcca), .dat_in(net0157));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_120 ( .vssa(vssa), 
    .dat_out(fracn_dig_en), .vdda(vcca), .dat_in(fracn_dig_enb));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_95 ( .vssa(vssa), .dat_out(net0144), 
    .vdda(vcca), .dat_in(net049));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_94 ( .vssa(vssa), .dat_out(net049), 
    .vdda(vcca), .dat_in(net0124));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_91 ( .vssa(vssa), .dat_out(net0126), 
    .vdda(vcca), .dat_in(net050));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_90 ( .vssa(vssa), .dat_out(net050), 
    .vdda(vcca), .dat_in(net0123));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_121 ( .vssa(vssa), .dat_out(pi_en), 
    .vdda(vcca), .dat_in(fracn_dig_enb));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_103 ( .vssa(vssa), .dat_out(ck_div_out), 
    .vdda(vcca), .dat_in(net0122));

al6100gpll_com_hss_mux2x x_com_hss_mux2x_54 ( .dat_in1(pi_outp), 
    .dat_out(net0148), .sel(mux_out), .vssa(vssa), .dat_in0(net094), 
    .vdda(vcca));

al6100gpll_com_hss_mux2x x_com_hss_mux2x_0_7 ( .dat_in1(fb_divn[7]), 
    .dat_out(fb_divn_mux[7]), .sel(mux_in), .vssa(vssa), 
    .dat_in0(fb_divn_sync[7]), .vdda(vcca));

al6100gpll_com_hss_mux2x x_com_hss_mux2x_0_6 ( .dat_in1(fb_divn[6]), 
    .dat_out(fb_divn_mux[6]), .sel(mux_in), .vssa(vssa), 
    .dat_in0(fb_divn_sync[6]), .vdda(vcca));

al6100gpll_com_hss_mux2x x_com_hss_mux2x_0_5 ( .dat_in1(fb_divn[5]), 
    .dat_out(fb_divn_mux[5]), .sel(mux_in), .vssa(vssa), 
    .dat_in0(fb_divn_sync[5]), .vdda(vcca));

al6100gpll_com_hss_mux2x x_com_hss_mux2x_0_4 ( .dat_in1(fb_divn[4]), 
    .dat_out(fb_divn_mux[4]), .sel(mux_in), .vssa(vssa), 
    .dat_in0(fb_divn_sync[4]), .vdda(vcca));

al6100gpll_com_hss_mux2x x_com_hss_mux2x_0_3 ( .dat_in1(fb_divn[3]), 
    .dat_out(fb_divn_mux[3]), .sel(mux_in), .vssa(vssa), 
    .dat_in0(fb_divn_sync[3]), .vdda(vcca));

al6100gpll_com_hss_mux2x x_com_hss_mux2x_0_2 ( .dat_in1(fb_divn[2]), 
    .dat_out(fb_divn_mux[2]), .sel(mux_in), .vssa(vssa), 
    .dat_in0(fb_divn_sync[2]), .vdda(vcca));

al6100gpll_com_hss_mux2x x_com_hss_mux2x_0_1 ( .dat_in1(fb_divn[1]), 
    .dat_out(fb_divn_mux[1]), .sel(mux_in), .vssa(vssa), 
    .dat_in0(fb_divn_sync[1]), .vdda(vcca));

al6100gpll_com_hss_mux2x x_com_hss_mux2x_0_0 ( .dat_in1(fb_divn[0]), 
    .dat_out(fb_divn_mux[0]), .sel(mux_in), .vssa(vssa), 
    .dat_in0(fb_divn_sync[0]), .vdda(vcca));

al6100gpll_CLKNAND2V2_140P12T40L  x_CLKNAND2V2_140P12T40L_51 ( .A1(pb), 
    .ZN(net0145), .A2(net0181), .VDD(vcca), .VSS(vssa), .VNW(vcca), 
    .VPW(vssa));

al6100gpll_CLKNAND2V2_140P12T40L  x_CLKNAND2V2_140P12T40L_54 ( .A1(pa), 
    .ZN(net0146), .A2(tile_h), .VDD(vcca), .VSS(vssa), .VNW(vcca), 
    .VPW(vssa));

al6100gpll_com_hss_dff2x x_com_hss_dff2x_59 ( .dat_out(pa), .ckt(ck_sync_p), 
    .dat_in(p0), .ckc(ck_sync_n), .vssa(vssa), .vdda(vcca));

al6100gpll_com_hss_dff2x x_com_hss_dff2x_61 ( .dat_out(pb), .ckt(ck_sync_p), 
    .dat_in(pa), .ckc(ck_sync_n), .vssa(vssa), .vdda(vcca));

gpll_pi_64bit x_gpll_pi_64bit_0 ( .pi_capsel(pi_capsel), 
    .pi_ctrl(pi_ctrl_sync), .pa(clk_early), .pb(clk_late), 
    .pi_outp(pi_outp), .i40u_src(i40u_src), .enable(pi_en), 
    .vssa(vssa), .pi_outn(pi_outn), .vcca(vcca));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_58 ( .VDD(vcca), .I(ck_p), 
    .ZN(net0185), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_137 ( .VDD(vcca), .I(net0185), 
    .ZN(ck_sync_p), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_70 ( .VDD(vcca), .I(ck_n), 
    .ZN(net0118), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_141 ( .VDD(vcca), .I(net0118), 
    .ZN(ck_sync_n), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_34 ( .VDD(vcca), .I(net0178), 
    .ZN(net0141), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_35 ( .VDD(vcca), .I(net0183), 
    .ZN(net0179), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_56 ( .VDD(vcca), .I(pb), 
    .ZN(net0180), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV2_140P12T40L  x_CLKINV2_140P12T40L_52 ( .VDD(vcca), .I(net0145), 
    .ZN(net0183), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV2_140P12T40L  x_CLKINV2_140P12T40L_63 ( .VDD(vcca), .I(pa), 
    .ZN(net0147), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV2_140P12T40L  x_CLKINV2_140P12T40L_62 ( .VDD(vcca), .I(net0147), 
    .ZN(net0181), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV2_140P12T40L  x_CLKINV2_140P12T40L_53 ( .VDD(vcca), .I(net0146), 
    .ZN(net0178), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV8_140P12T40L  x_CLKINV8_140P12T40L_38 ( .VDD(vcca), .I(net0179), 
    .ZN(clk_late), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKINV8_140P12T40L  x_CLKINV8_140P12T40L_37 ( .VDD(vcca), .I(net0141), 
    .ZN(clk_early), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_NAND3CV1_140P12T40L  x_NAND3CV1_140P12T40L_109 ( .A3(ssc_en), 
    .A1(divn_en), .ZN(ssc_dig_enb), .A2(fracn_en), .VDD(vcca), 
    .VSS(vssa), .VPW(vssa), .VNW(vcca));

cpll_div_n_top x_cpll_div_n_top_0 ( .divn(fb_divn_mux[7:0]), 
    .ck_out(p0), .vcca(vcca), .vssa(vssa), .en(divn_en_rstn), 
    .ck_sync_p(ck_p), .ck_sync_n(ck_n), .ck_in_p(ck_vco_p), 
    .ck_in_n(ck_vco_n));

endmodule








// Library - al6100_analog, Cell - cpll_div_n_dff, View - schematic
// LAST TIME SAVED: May 24 14:57:55 2022


module al6100gpll_cpll_div_n_dff ( 
output   qout, 
input   ck, 
input   din, 
input   rstn, 
input   vccd, 
input   vnw, 
input   vpw, 
input   vssd );


al6100gpll_DRSNQV2_140P12T40L  x_DRSNQV2_140P12T40L_0 ( .Q(qout), .RDN(rdn), 
    .D(din), .VDD(vccd), .CK(ck), .SDN(sdn), .VSS(vssd), .VPW(vpw), 
    .VNW(vnw));

al6100gpll_NAND2V2_140P12T40L  x_NAND2V2_140P12T40L_1 ( .A1(din), .ZN(sdn), 
    .A2(rst), .VDD(vccd), .VSS(vssd), .VNW(vnw), .VPW(vpw));

al6100gpll_INV2_140P12T40L  x_INV2_140P12T40L_3 ( .VDD(vccd), .I(net08), .ZN(rst), 
    .VSS(vssd), .VNW(vnw), .VPW(vpw));

al6100gpll_OR2V2_140P12T40L  x_XOR2V2_140P12T40L_2 ( .A2(net08), .A1(din), 
    .Z(rdn), .VDD(vccd), .VSS(vssd), .VPW(vpw), .VNW(vnw));

al6100gpll_BUFV2_140P12T40L  x_BUFV2_140P12T40L_5 ( .Z(net08), .I(rstn), 
    .VDD(vccd), .VSS(vssd), .VNW(vnw), .VPW(vpw));

endmodule



// Library - al6100_analog, Cell - gpll_top, View - schematic
// LAST TIME SAVED: Sep 11 11:40:50 2023


module gpll_top ( 
output wire   ck_pll2io, 
output wire  [7:0] ckout_c, 
output wire   ckout_c_main, 
output wire  [7:0] ckout_t, 
output wire   ckout_t_main, 
output   int_lock, 
output wire   int_lock_out, 
output   lock, 
output   pib_dyn_status, 
output   pib_psdone, 
output wire   refclk_out, 
inout   pib_dig_out, 
inout wire  tieh , 
inout wire  tiel , 
input wire   dig_pd, 
input wire  done_gwe , 
input wire  [6:0] fbkck, 
input wire  [15:0] gpll_refck, 
input   ibn_10u_ptat, 
input wire   ibn_10u_vref, 
input wire   ibp_10u_poly, 
input wire   int_lock_in, 
input wire  [1:0] mc1_bias_icfg, 
input  [2:0] mc1_cal_counter, 
input   mc1_clk0_frac_en, 
input  [2:0] mc1_cp_dlysel, 
input  [2:0] mc1_cp_refsel, 
input wire   mc1_dig_pd, 
input  [5:0] mc1_dig_sel, 
input wire  [7:0] mc1_div2_bypass_n, 
input wire  [7:0] mc1_div2_phc, 
input wire  [7:0] mc1_div_en, 
input wire  [6:0] mc1_divc0, 
input wire  [6:0] mc1_divc1, 
input wire  [6:0] mc1_divc2, 
input wire  [6:0] mc1_divc3, 
input wire  [6:0] mc1_divc4, 
input wire  [6:0] mc1_divc5, 
input wire  [6:0] mc1_divc6, 
input wire  [6:0] mc1_divc7, 
input wire  [7:0] mc1_divc_outmux, 
input wire   mc1_divc_outmux_main, 
input wire  [1:0] mc1_divc_premux0, 
input wire  [1:0] mc1_divc_premux1, 
input wire  [1:0] mc1_divc_premux2, 
input wire  [1:0] mc1_divc_premux3, 
input wire  [1:0] mc1_divc_premux4, 
input wire  [1:0] mc1_divc_premux5, 
input wire  [1:0] mc1_divc_premux6, 
input wire  [1:0] mc1_divc_premux7, 
input wire  [1:0] mc1_divcrst_en, 
input  [7:0] mc1_divrst_ph_sel, 
input wire  [6:0] mc1_duty0, 
input wire  [6:0] mc1_duty1, 
input wire  [6:0] mc1_duty2, 
input wire  [6:0] mc1_duty3, 
input wire  [6:0] mc1_duty4, 
input wire  [6:0] mc1_duty5, 
input wire  [6:0] mc1_duty6, 
input wire  [6:0] mc1_duty7, 
input wire  [7:0] mc1_duty50_n, 
input   mc1_dyn_ph_shift_en, 
input wire  [6:0] mc1_dyn_phc0, 
input wire  [6:0] mc1_dyn_phc1, 
input wire  [6:0] mc1_dyn_phc2, 
input wire  [6:0] mc1_dyn_phc3, 
input wire  [6:0] mc1_dyn_phc4, 
input wire  [6:0] mc1_dyn_phc5, 
input wire  [6:0] mc1_dyn_phc6, 
input wire  [6:0] mc1_dyn_phc7, 
input wire   mc1_dyn_source, 
input wire   mc1_enable_sync, 
input wire  [7:0] mc1_enclk, 
input wire   mc1_enclk_main, 
input  [2:0] mc1_fastlock_sel, 
input   mc1_fastloop_cfg, 
input  [27:0] mc1_fbfracn_sel, 
input wire  [7:0] mc1_fbk_div, 
input wire  [3:0] mc1_fbk_sel, 
input wire  [3:0] mc1_fbk_sel_wakeup, 
input  [6:0] mc1_frac, 
input wire   mc1_fracn_dither_en, 
input wire  [3:0] mc1_fracn_dither_sel, 
input   mc1_fracn_en, 
input wire  [1:0] mc1_fracn_prbs_sel, 
input  [6:0] mc1_gpll_lockdet, 
input  [4:0] mc1_icp_banch, 
input  [4:0] mc1_icp_bias, 
input wire   mc1_intfb, 
input  [3:0] mc1_kvco_sel, 
input wire  [7:0] mc1_load_div2_en, 
input wire  [7:0] mc1_load_en, 
input  [1:0] mc1_lpf_r1_sel, 
input wire   mc1_mrst_en, 
input wire  [7:0] mc1_outgate_en, 
input  [2:0] mc1_outputpi_capsel, 
input wire  [2:0] mc1_outputpi_icfg, 
input wire  [6:0] mc1_phc0, 
input wire  [6:0] mc1_phc1, 
input wire  [6:0] mc1_phc2, 
input wire  [6:0] mc1_phc3, 
input wire  [6:0] mc1_phc4, 
input wire  [6:0] mc1_phc5, 
input wire  [6:0] mc1_phc6, 
input wire  [6:0] mc1_phc7, 
input  [6:0] mc1_phic0, 
input  [2:0] mc1_phic1, 
input  [2:0] mc1_phic2, 
input  [2:0] mc1_phic3, 
input  [2:0] mc1_phic4, 
input  [2:0] mc1_phic5, 
input  [2:0] mc1_phic6, 
input  [2:0] mc1_phic7, 
input wire  [2:0] mc1_pi_capsel, 
input  [1:0] mc1_pi_delay, 
input   mc1_pi_frac_mode, 
input wire  [3:0] mc1_pi_icfg, 
input  [7:0] mc1_pi_out_sel, 
input   mc1_pi_phi_en, 
input wire   mc1_pllpdn, 
input wire   mc1_pllrst_en, 
input wire  [7:0] mc1_ref_div, 
input wire  [3:0] mc1_ref_sel, 
input   mc1_refclk_det_byp, 
input  [1:0] mc1_refclk_det_div, 
input wire   mc1_refclk_out_en, 
input wire   mc1_ssc_dn_loop_mode, 
input   mc1_ssc_en, 
input wire  [17:0] mc1_ssc_freq_div, 
input wire  [1:0] mc1_ssc_lpf_sel, 
input wire   mc1_ssc_mode, 
input wire   mc1_ssc_reset, 
input wire  [23:0] mc1_ssc_step, 
input wire  [2:0] mc1_syn_sel, 
input   mc1_tda_en, 
input wire  mc1_test_en , 
input  [1:0] mc1_vctrl_sel, 
input wire   pib_clkout_glitchless_en_n, 
input wire   pib_done_pll, 
input wire   pib_en_pll2io_n, 
input wire  [7:0] pib_enclk, 
input wire   pib_enclk_main, 
input   pib_fbkshot, 
input wire   pib_load_div2_reg, 
input wire   pib_load_reg, 
input   pib_lockdet_clr_n, 
input wire   pib_pllreset, 
input wire   pib_psclk, 
input wire  [2:0] pib_psclksel, 
input wire   pib_psdown, 
input wire   pib_psstep, 
input   pib_refshot, 
input wire  [1:0] pib_rst_divc, 
input wire   pib_rst_m, 
input wire   pib_ssc_reset, 
input wire   pll_wakeup_sync, 
input wire   pllpd, 
input wire   scan_clk, 
input wire   scan_enable, 
input wire   scan_in, 
input wire   scan_mode, 
input wire   scan_resetn, 
input wire  vccaux , 
input wire  vccd , 
input wire  vssa  );

// Buses in the design

wire [7:0]  out_path_divrst_clk;

wire [7:0]  phaseout;

wire [7:0]  ckout_int;

wire [7:0]  phasedone;

wire [7:0] fbdiv_code ;

wire [7:0]  scanclk;

wire [7:0]  load_div2_reg;

wire [7:0]  rotate;

wire [7:0]  direction;

wire [7:0]  ck_out_path_en;

wire [1:0]  rstdivc_n;

wire [3:0]  sel_fbk;

wire [7:0]  load_reg;

wire [5:0] pi_code ;

wire [7:0]  ckout_test;

wire [3:0]  vco_band;

wire [2:0]  fracn_c_sum;


gpll_output  x_gpll_output ( .ck0_div_by_one(sgcc_clk0_div1), 
    .ckc_en(ck_out_path_en[7:0]), .ck0_div(ck0_div), 
    .ckout_test(ckout_test[7:0]), .ck_pll2io(ck_pll2io), 
    .ckout_main_test(ckout_main_test), .ckout_t(ckout_t[7:0]), 
    .ckout_c(ckout_c[7:0]), .ckout_t_main(ckout_t_main), 
    .ckout_c_main(ckout_c_main), .ckout_int(ckout_int[7:0]), 
    .phc(phaseout[7:0]), .mc1_divc7(mc1_divc7[6:0]), 
    .mc1_divc_premux7(mc1_divc_premux7[1:0]), .mc1_phc7(mc1_phc7[6:0]), 
    .mc1_div_en(mc1_div_en[7:0]), .mc1_dyn_phc7(mc1_dyn_phc7[6:0]), 
    .test_dig_en(mc1_test_en), .mc1_enclk(mc1_enclk[7:0]), 
    .mc1_dyn_phc0(mc1_dyn_phc0[6:0]), .mc1_dyn_phc1(mc1_dyn_phc1[6:0]), 
    .mc1_dyn_phc2(mc1_dyn_phc2[6:0]), .mc1_dyn_phc3(mc1_dyn_phc3[6:0]), 
    .mc1_dyn_phc4(mc1_dyn_phc4[6:0]), .mc1_dyn_phc5(mc1_dyn_phc5[6:0]), 
    .mc1_dyn_phc6(mc1_dyn_phc6[6:0]), .mc1_load_en(mc1_load_en[7:0]), 
    .mc1_refclk_out_en(mc1_refclk_out_en), .refclk_out(refclk_out), 
    .mc1_load_div2_en(mc1_load_div2_en[7:0]), 
    .mc1_duty7(mc1_duty7[6:0]), .load_reg(load_reg[7:0]), 
    .load_div2_reg(load_div2_reg[7:0]), 
    .mc1_duty50_n(mc1_duty50_n[7:0]), 
    .mc1_div2_bypass_n(mc1_div2_bypass_n[7:0]), 
    .mc1_divc0(mc1_divc0[6:0]), .mc1_divc1(mc1_divc1[6:0]), 
    .mc1_divc2(mc1_divc2[6:0]), .mc1_divc3(mc1_divc3[6:0]), 
    .mc1_divc4(mc1_divc4[6:0]), .mc1_divc5(mc1_divc5[6:0]), 
    .mc1_divc6(mc1_divc6[6:0]), .mc1_div2_phc_en(mc1_div2_phc[7:0]), 
    .mc1_divc_outmux_main(mc1_divc_outmux_main), 
    .mc1_divc_premux0(mc1_divc_premux0[1:0]), 
    .mc1_divc_premux1(mc1_divc_premux1[1:0]), 
    .mc1_divc_premux2(mc1_divc_premux2[1:0]), 
    .mc1_divc_premux3(mc1_divc_premux3[1:0]), 
    .mc1_divc_premux4(mc1_divc_premux4[1:0]), 
    .mc1_divc_premux5(mc1_divc_premux5[1:0]), 
    .mc1_divc_premux6(mc1_divc_premux6[1:0]), 
    .mc1_duty0(mc1_duty0[6:0]), .mc1_duty1(mc1_duty1[6:0]), 
    .mc1_duty2(mc1_duty2[6:0]), .mc1_duty3(mc1_duty3[6:0]), 
    .mc1_duty4(mc1_duty4[6:0]), .mc1_duty5(mc1_duty5[6:0]), 
    .mc1_duty6(mc1_duty6[6:0]), .mc1_divc_outmux(mc1_divc_outmux[7:0]), 
    .mc1_enable_sync(mc1_enable_sync), .mc1_enclk_main(mc1_enclk_main), 
    .mc1_phc0(mc1_phc0[6:0]), .mc1_phc1(mc1_phc1[6:0]), 
    .mc1_phc2(mc1_phc2[6:0]), .mc1_phc3(mc1_phc3[6:0]), 
    .mc1_phc4(mc1_phc4[6:0]), .mc1_phc5(mc1_phc5[6:0]), 
    .mc1_phc6(mc1_phc6[6:0]), 
    .pib_clkout_glitchless_en_n(pib_clkout_glitchless_en_n), 
    .pib_enclk(pib_enclk[7:0]), .pib_en_pll2io_n(pib_en_pll2io_n), 
    .mc1_outgate_en(mc1_outgate_en[7:0]), .rst_div_n(rstdivc_n[1:0]), 
    .rst_out_n(fbdiv_rstn), .done_gwe(done), .ssc_clk(tieh), 
    .out_path_divrst_clk(out_path_divrst_clk[7:0]), .phomux(phomux), 
    .fb_div_clk(gpll_fbkck), .refclk(refclk_mux), .vccd(vccd), 
    .vssd(vssa), .pib_enclk_main(pib_enclk_main));

gpll_ctrl  x_gpll_ctrl ( .bandcal1_rstn(bandcal1_rstn), 
    .pfd_rstn(pfd_rstn), .int_lock_out(int_lock_out), 
    .int_lock_in(int_lock_in), .vssd(vssa), .vccd(vccd), 
    .pll_digpd(dig_pd), .direction(direction[7:0]), 
    .bandcal_rstn(bandcal_rstn), .vcc_vco_rdy(vco_cal_done), 
    .trig_vco_en(tiel), .psstep(pib_psstep), .psdown(pib_psdown), 
    .psclksel(pib_psclksel[2:0]), .psclk(pib_psclk), 
    .pllreset(pib_pllreset), .pllpd(pllpd), 
    .pll_wakeup_sync(pll_wakeup_sync), .pib_ssc_reset(pib_ssc_reset), 
    .pib_rst_m(pib_rst_m), .pib_rst_divc(pib_rst_divc[1:0]), 
    .pib_load_reg(pib_load_reg), .pib_load_div2_reg(pib_load_div2_reg), 
    .done_gwe(done), .en_lock_ext(en_lock_ext), .en_vco(en_vco), 
    .load_div2_reg(load_div2_reg[7:0]), .dyn_status(pib_dyn_status), 
    .load_reg(load_reg[7:0]), 
    .pll_sl_prechr_sw_en(pll_sl_prechr_sw_en), .lb_rstn(fbdiv_rstn), 
    .pwd_pll_n(pwd_pll_n), .cal_rstn(pll_cal_rstn), 
    .ssc_reset_n(ssc_rstn), .pll_vreg_en(gpll_en), 
    .sel_fbk(sel_fbk[3:0]), .pllrst_n(gpll_rstn), 
    .scanck(scanclk[7:0]), .rstlock_n(rstlock_n), .rstdivm_n(pwd_rstn), 
    .rstdivc_n(rstdivc_n[1:0]), .pwd_dig_n(pwd_dig_n), 
    .rotate(rotate[7:0]), .psdone(pib_psdone), 
    .mc1_fbk_sel_wakeup(mc1_fbk_sel_wakeup[3:0]), 
    .mc1_fbk_sel(mc1_fbk_sel[3:0]), .mc1_dyn_source(mc1_dyn_source), 
    .pdone(phasedone[7:0]), .mc1_syn_sel(mc1_syn_sel[2:0]), 
    .mc1_ssc_reset(mc1_ssc_reset), .mc1_dig_pd(mc1_dig_pd), 
    .mc1_pllrst(mc1_pllrst_en), .mc1_pllpdn(mc1_pllpdn), 
    .mc1_mrst(mc1_mrst_en), .mc1_intfb(mc1_intfb), 
    .mc1_divcrst(mc1_divcrst_en[1:0]), .done_pll(pib_done_pll), 
    .int_lock(int_lock));

gpll_test  x_gpll_test ( .in32(fbdiv_code[7]), .in33(fbdiv_code[6]), 
    .in34(fbdiv_code[5]), .in35(fbdiv_code[4]), .in36(fbdiv_code[3]), 
    .in37(fbdiv_code[2]), .in38(fbdiv_code[1]), .in39(fbdiv_code[0]), 
    .in40(vco_band[3]), .in41(vco_band[2]), .in42(vco_band[1]), 
    .in43(vco_band[0]), .in44(tiel), .in45(tiel), .in46(tiel), 
    .in47(tiel), .in48(tiel), .in49(tiel), .in50(tiel), .in51(tiel), 
    .in52(tiel), .in53(tiel), .in54(tiel), .in55(tiel), .in56(tiel), 
    .in57(tiel), .in58(tiel), .in59(tiel), .in60(tiel), .in61(tiel), 
    .in62(tiel), .in63(tiel), .mfg_dig_sel(mc1_dig_sel[5:0]), 
    .mc1_test_en(test_en), .dig_out(pib_dig_out), .vccd(vccd), 
    .vssd(vssa), .in0(fbkck_test), .in1(refck_test), 
    .in2(fracn_c_sum[2]), .in3(fracn_c_sum[1]), .in4(fracn_c_sum[0]), 
    .in5(prbs_out), .in6(ssc_mod_clk), .in7(ssc_signbit), .in8(tiel), 
    .in9(pi_code[5]), .in10(pi_code[4]), .in11(pi_code[3]), 
    .in12(pi_code[2]), .in13(pi_code[1]), .in14(pi_code[0]), 
    .in15(vreg_rdy), .in16(refclk_mux), .in17(ck_divn), 
    .in18(fast_lock), .in19(int_lock), .in20(lock), .in21(pib_psdone), 
    .in22(pib_dyn_status), .in23(ckout_main_test), 
    .in24(ckout_test[7]), .in25(ckout_test[6]), .in26(ckout_test[5]), 
    .in27(ckout_test[4]), .in28(ckout_test[3]), .in29(ckout_test[2]), 
    .in30(ckout_test[1]), .in31(ckout_test[0]));

com_hss_tiel x_com_hss_tiel_18 ( .tiel(tiel), .vdda(vccd), 
    .vssa(vssa));

al6100gpll_com_hss_bufx4 x_com_hss_bufx4_3 ( .out(net05), .in(mc1_test_en), 
    .vccd(vccd), .vssd(vssa));

al6100gpll_com_hss_bufx4 x_com_hss_bufx4_2 ( .out(done), .in(net04), .vccd(vccd), 
    .vssd(vssa));

al6100gpll_com_hss_bufx4 x_com_hss_bufx4_1 ( .out(net04), .in(done_gwe), 
    .vccd(vccd), .vssd(vssa));

al6100gpll_com_hss_bufx4 x_com_hss_bufx4_4 ( .out(test_en), .in(net05), 
    .vccd(vccd), .vssd(vssa));

com_hss_tieh x_com_hss_tieh_17 ( .tieh(tieh), .vdda(vccd), 
    .vssa(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_36 ( .VDD(vccd), 
    .I(gpll_fbkck_int), .ZN(net017), .VSS(vssa), .VNW(vccd), 
    .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_38 ( .VDD(vccd), 
    .I(fbkck_test_int), .ZN(net03), .VSS(vssa), .VNW(vccd), 
    .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_35 ( .VDD(vccd), 
    .I(refclk_mux_int), .ZN(net08), .VSS(vssa), .VNW(vccd), 
    .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_27 ( .VDD(vccd), 
    .I(refck_test_int), .ZN(net016), .VSS(vssa), .VNW(vccd), 
    .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_31 ( .VDD(vccd), 
    .I(ck_divn_int), .ZN(net018), .VSS(vssa), .VNW(vccd), .VPW(vssa));

al6100gpll_CLKINV8_140P12T40L  x_CLKINV8_140P12T40L_37 ( .VDD(vccd), .I(net03), 
    .ZN(fbkck_test), .VSS(vssa), .VNW(vccd), .VPW(vssa));

al6100gpll_CLKINV8_140P12T40L  x_CLKINV8_140P12T40L_28 ( .VDD(vccd), .I(net016), 
    .ZN(refck_test), .VSS(vssa), .VNW(vccd), .VPW(vssa));

al6100gpll_CLKINV8_140P12T40L  x_CLKINV8_140P12T40L_29 ( .VDD(vccd), .I(net017), 
    .ZN(gpll_fbkck), .VSS(vssa), .VNW(vccd), .VPW(vssa));

al6100gpll_CLKINV8_140P12T40L  x_CLKINV8_140P12T40L_34 ( .VDD(vccd), .I(net08), 
    .ZN(refclk_mux), .VSS(vssa), .VNW(vccd), .VPW(vssa));

al6100gpll_CLKINV8_140P12T40L  x_CLKINV8_140P12T40L_30 ( .VDD(vccd), .I(net018), 
    .ZN(ck_divn), .VSS(vssa), .VNW(vccd), .VPW(vssa));

gpll_core x_gpll_core ( .sg09_gpll_fbfracn_sel(mc1_fbfracn_sel[27:0]), 
    .scan_in(scan_in), .sg09_pfd_rstn(pfd_rstn), 
    .bandcal1_rstn(bandcal1_rstn), .mc1_pi_delay(mc1_pi_delay[1:0]), 
    .sg09_gpll_fastloop_cfg(mc1_fastloop_cfg), 
    .sg09_gpll_ssc_rstn(ssc_rstn), .fast_lock(fast_lock), 
    .sg09_gpll_fastlock_sel(mc1_fastlock_sel[2:0]), 
    .mc1_outputpi_icfg(mc1_outputpi_icfg[2:0]), 
    .mc1_outputpi_capsel(mc1_outputpi_capsel[2:0]), 
    .sg09_gpll_lpf_r1_sel(mc1_lpf_r1_sel[1:0]), 
    .sg09_gpll_pi_icfg(mc1_pi_icfg[3:0]), 
    .sg09_gpll_pi_code(pi_code[5:0]), .bandcal_rstn(bandcal_rstn), 
    .int_lock(int_lock), .lock(lock), 
    .out_path_divrst_clk(out_path_divrst_clk[7:0]), 
    .phasedone(phasedone[7:0]), .phaseout(phaseout[7:0]), 
    .phomux(phomux), .sg09_gpll_ck_divn(ck_divn_int), 
    .sg09_gpll_fbdiv_code(fbdiv_code[7:0]), 
    .sg09_gpll_fbkck(gpll_fbkck_int), 
    .sg09_gpll_fbkck_test(fbkck_test_int), 
    .sg09_gpll_fracn_c_sum(fracn_c_sum[2:0]), 
    .sg09_gpll_prbs_out(prbs_out), .sg09_gpll_refck(refclk_mux_int), 
    .sg09_gpll_refck_test(refck_test_int), 
    .sg09_gpll_ssc_mod_clk(ssc_mod_clk), 
    .sg09_gpll_ssc_signbit(ssc_signbit), .sgcc_cal_done(vco_cal_done), 
    .sgcc_vco_band(vco_band[3:0]), .vreg_rdy(vreg_rdy), 
    .ck0_div(ck0_div), .ck_out_path_en(ck_out_path_en[7:0]), 
    .direction(direction[7:0]), .done_gwe(done_gwe), 
    .ext_lock_en(en_lock_ext), .gpll_fbkck({ckout_int[7:0], 
    fbkck[6:0]}), .gpll_refck(gpll_refck[15:0]), 
    .ibn_10u_ptat(ibn_10u_ptat), .ibn_10u_vref(ibn_10u_vref), 
    .ibp_10u_poly(ibp_10u_poly), 
    .mc1_cal_counter(mc1_cal_counter[2:0]), 
    .mc1_clk0_frac_en(mc1_clk0_frac_en), 
    .mc1_dyn_ph_shift_en(mc1_dyn_ph_shift_en), 
    .mc1_frac(mc1_frac[6:0]), .mc1_gpll_lockdet(mc1_gpll_lockdet[6:0]), 
    .mc1_phomux_sel(mc1_divrst_ph_sel[7:0]), 
    .mc1_pi_frac_mode(mc1_pi_frac_mode), 
    .mc1_pi_out_sel(mc1_pi_out_sel[7:0]), 
    .mc1_pi_phshift_en(mc1_pi_phi_en), 
    .mc1_refclk_det_byp(mc1_refclk_det_byp), 
    .mc1_refclk_det_div(mc1_refclk_det_div[1:0]), 
    .phsel_0(mc1_phic0[6:0]), .phsel_1(mc1_phic1[2:0]), 
    .phsel_2(mc1_phic2[2:0]), .phsel_3(mc1_phic3[2:0]), 
    .phsel_4(mc1_phic4[2:0]), .phsel_5(mc1_phic5[2:0]), 
    .phsel_6(mc1_phic6[2:0]), .phsel_7(mc1_phic7[2:0]), 
    .pib_lockdet_clr_n(pib_lockdet_clr_n), 
    .pll_cal_rst_n(pll_cal_rstn), .rotate(rotate[7:0]), 
    .scan_clk(scan_clk), .scan_enable(scan_enable), 
    .scan_mode(scan_mode), .scan_resetn(scan_resetn), 
    .scanclk(scanclk[7:0]), .sg09_gpll_bias_icfg(mc1_bias_icfg[1:0]), 
    .sg09_gpll_cp_dlysel(mc1_cp_dlysel[2:0]), 
    .sg09_gpll_cp_refsel(mc1_cp_refsel[2:0]), .sg09_gpll_en(gpll_en), 
    .sg09_gpll_fbdiv(mc1_fbk_div[7:0]), 
    .sg09_gpll_fbdiv_rstn(fbdiv_rstn), 
    .sg09_gpll_fbkck_sel(sel_fbk[3:0]), 
    .sg09_gpll_fbkck_shot(pib_fbkshot), 
    .sg09_gpll_fracn_dither_en(mc1_fracn_dither_en), 
    .sg09_gpll_fracn_dither_sel(mc1_fracn_dither_sel[3:0]), 
    .sg09_gpll_fracn_en(mc1_fracn_en), 
    .sg09_gpll_fracn_prbs_sel(mc1_fracn_prbs_sel[1:0]), 
    .sg09_gpll_icp_banch(mc1_icp_banch[4:0]), 
    .sg09_gpll_icp_bias(mc1_icp_bias[4:0]), 
    .sg09_gpll_kvco_sel(mc1_kvco_sel[3:0]), 
    .sg09_gpll_pi_capsel(mc1_pi_capsel[2:0]), 
    .sg09_gpll_refck_sel(mc1_ref_sel[3:0]), 
    .sg09_gpll_refck_shot(pib_refshot), 
    .sg09_gpll_refdiv(mc1_ref_div[7:0]), .sg09_gpll_rstn(gpll_rstn), 
    .sg09_gpll_ssc_dn_loop_mode(mc1_ssc_dn_loop_mode), 
    .sg09_gpll_ssc_en(mc1_ssc_en), 
    .sg09_gpll_ssc_freq_div(mc1_ssc_freq_div[17:0]), 
    .sg09_gpll_ssc_lpf_sel(mc1_ssc_lpf_sel[1:0]), 
    .sg09_gpll_ssc_mode(mc1_ssc_mode), 
    .sg09_gpll_ssc_step(mc1_ssc_step[23:0]), 
    .sg09_gpll_tda_en(mc1_tda_en), 
    .sg09_gpll_vctrl_sel(mc1_vctrl_sel[1:0]), .sg09_pwd_rstn(pwd_rstn), 
    .sgcc_clk0_div1(sgcc_clk0_div1), .vccaux(vccaux), .vccd(vccd), 
    .vssa(vssa));

endmodule


// Library - al6100_analog, Cell - gpll_prediv, View - schematic
// LAST TIME SAVED: May 22 15:13:29 2023


module gpll_prediv ( 
output wire  ck_outn , 
output wire  ck_outp , 
input wire  [15:0] ckin, 
input wire  [3:0] ckin_sel, 
input   ckin_shot, 
input wire   div_en, 
input wire  [7:0] divn, 
input   done_gwe, 
input wire  vcca , 
input wire  vssa  );



al6100gpll_com_hss_inv4x x_com_hss_inv4x_86 ( .vssa(vssa), .dat_out(net_037), 
    .vdda(vcca), .dat_in(net_038));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_103 ( .vssa(vssa), .dat_out(net_031), 
    .vdda(vcca), .dat_in(net_035));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_91 ( .vssa(vssa), .dat_out(net033), 
    .vdda(vcca), .dat_in(net029));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_90 ( .vssa(vssa), .dat_out(net029), 
    .vdda(vcca), .dat_in(net030));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_95 ( .vssa(vssa), .dat_out(net032), 
    .vdda(vcca), .dat_in(net028));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_94 ( .vssa(vssa), .dat_out(net028), 
    .vdda(vcca), .dat_in(net031));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_96 ( .vssa(vssa), .dat_out(ck_outn), 
    .vdda(vcca), .dat_in(net033));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_127 ( .vssa(vssa), .dat_out(ck_outp), 
    .vdda(vcca), .dat_in(net032));





al6100gpll_com_hss_inv2x x_com_hss_inv2x_7 ( .vssa(vssa), .dat_out(net_039), 
    .vdda(vcca), .dat_in(ck_divout));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_6 ( .vssa(vssa), .dat_out(net_040), 
    .vdda(vcca), .dat_in(ck_divout));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_85 ( .vssa(vssa), .dat_out(net_038), 
    .vdda(vcca), .dat_in(ck_divout));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_104 ( .vssa(vssa), .dat_out(net_035), 
    .vdda(vcca), .dat_in(net_036));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_99 ( .vssa(vssa), .dat_out(net031), 
    .vdda(vcca), .dat_in(net_031));

com_hss_tiel x_com_hss_tiel_102 ( .tiel(tile_l), .vdda(vcca), 
    .vssa(vssa));

com_hss_tieh x_com_hss_tieh_101 ( .tieh(tile_h), .vdda(vcca), 
    .vssa(vssa));

al6100gpll_com_hss_tgate_2x x_com_hss_tgate_2x_100 ( .seln(tile_l), .va(net_031), 
    .vcca(vcca), .sel(tile_h), .vssa(vssa), .vz(net030));

gpll_clk_mux x_gpll_clk_mux ( .ck_out_n(ck_inn), .ck_out_p(ck_inp), 
    .ck_in(ckin[15:0]), .ck_in_sel(ckin_sel[3:0]), .done_gwe(done_gwe), 
    .load(ckin_shot), .rstn(div_en), .vcca(vcca), .vssa(vssa));

al6100gpll_com_hss_mux2x x_com_hss_mux2x_54 ( .dat_in1(tile_l), .dat_out(net_036), 
    .sel(tile_l), .vssa(vssa), .dat_in0(net_037), .vdda(vcca));

cpll_div_n_top x_cpll_div_n_top ( .divn(divn[7:0]), .ck_out(ck_divout), 
    .vcca(vcca), .vssa(vssa), .en(div_en), .ck_sync_p(ck_sync_p), 
    .ck_sync_n(ck_sync_n), .ck_in_p(ck_inp), .ck_in_n(ck_inn));

endmodule


//systemVerilog HDL for "al6100_serdes_pll", "cpll_div_23_lvt" "systemVerilog"

`timescale 1ns/1fs
module cpll_div_23_lvt ( ck_out_n, ck_out_p, modeout, ck_in_n, ck_in_p, div3, en, modin, vcca, vssa );
input vcca;
input vssa;

input ck_in_p;
input ck_in_n;

input en;
input div3;
input modin;

output modeout;
output ck_out_p;
output ck_out_n;

// circuit begin
reg q0,q1,q2,q3;
reg qb3;
reg d0,d2,d3;
reg qb1,qbb1,qb2,d1;

wire ck_in_d_p,ck_in_d_n;
wire en_d;

initial begin
	q0 = 1'b0;
	q1 = 1'b0;
	q2 = 1'b1;
	q3 = 1'b1;
	qb3 = 1'b0;
	d0 =1'b0;
	d2 =1'b0;
	d3 =1'b0;
	qb1 =1'b0;
	qbb1 =1'b0;
	qb2 =1'b0;
	d1 =1'b0;
end

//each time power down, initial these internal signals to avoid X
always @(vcca) #0.1 begin
	if(~vcca) begin
	q0 = 1'b0;
	q1 = 1'b0;
	q2 = 1'b1;
	q3 = 1'b1;
	qb3 = 1'b0;
	d0 =1'b0;
	d2 =1'b0;
	d3 =1'b0;
	qb1 =1'b0;
	qbb1 =1'b0;
	qb2 =1'b0;
	d1 =1'b0;
	end
end

//latch input logic
always @ ( * )   #0.005 begin
		d0		<= !((!q1) & q3 );
	 	qbb1    <= !qb1;
		d2 		<= !(modin & qbb1);
	 	d3 		<= !(div3 & qb2);
end

//latch feed back
always @ ( * )  #0.005 begin
	 	d1 		<= !q0;
	 	qb1 	<= !(q1 & en_d);
	 	qb2 	<= !(en & q2);
	if (en_d == 1) 
		qb3 <= !q3;
	else 
		qb3 <= div3;
end

//input output pin;
assign #0.015 ck_out_p 	 =  qb1;
assign #0.015 ck_out_n   = !qb1;
assign #0.015 modeout 	 =  qb2;
//
assign #0.015 ck_in_d_p = ck_in_p;
assign #0.015 ck_in_d_n = ck_in_n;
assign #0.045 en_d = en;

always @ ( posedge ck_in_p or negedge ck_in_p ) #0.015 begin
	if ( ck_in_p ) begin// phase 0 functional
 		q1 <=  ((qb1===1'b1)|(qb1===1'b0))	?(!qb1)	:1'b0;
		q3 <=  ((qb3===1'b1)|(qb3===1'b0))	?(!qb3)	:1'b1;
	end
	else begin			// phase 1 functional
 		q1 <=  ((d1===1'b1)|(d1===1'b0))	?(d1)	:1'b0;
    	q3 <=  ((d3===1'b1)|(d3===1'b0))	?(d3)	:1'b1;	
	end
end
always @ ( posedge ck_in_d_p or negedge ck_in_d_p ) #0.015 begin
	if ( ck_in_p ) begin// phase 0 functional
 		q0 <=  ((d0===1'b1)|(d0===1'b0))	?(d0)	:1'b0;
 		q2 <=  ((d2===1'b1)|(d2===1'b0))	?(d2)	:1'b1;
	end
	else begin			// phase 1 functional
 		q0 <=  ((d1===1'b1)|(d1===1'b0))	?(!d1)	:1'b0;
		q2 <=  ((qb2===1'b1)|(qb2===1'b0))	?(!qb2)	:1'b1;
	end
end

endmodule








// Library - al6100_analog, Cell - gpll_fbdiv_top_v1, View - schematic
// LAST TIME SAVED: Sep 11 11:34:08 2023


module gpll_fbdiv_top_v1 ( 
output wire  ck_divn , 
output wire  ck_out_n , 
output wire  ck_out_p , 
output wire  [7:0] fb_divn_probe, 
output wire [7:0] fb_divn_sync, 
output wire  [23:0] fb_fracn_probe, 
output wire  [2:0] fracn_c_sum, 
output wire [5:0] pi_ctrl_sync, 
output wire   prbs_out, 
output wire   scan_out, 
output wire  [29:0] ssc_cnt, 
output wire   ssc_mod_clk, 
output wire   ssc_signbit, 
input wire  [15:0] ck_in, 
input wire  [3:0] ck_in_sel, 
input   ck_in_shot, 
input   divn_en, 
input   done_gwe, 
input wire  [7:0] fb_divn, 
input  [27:0] fb_fracn, 
input wire   fracn_dither_en, 
input wire  [3:0] fracn_dither_sel, 
input   fracn_en, 
input wire  [1:0] fracn_prbs_sel, 
input wire   i40u_src, 
input wire  [2:0] pi_capsel, 
input   rstn, 
input wire   scan_clk, 
input wire   scan_enable, 
input wire   scan_in, 
input wire   scan_mode, 
input wire   scan_resetn, 
input wire   ssc_dn_loop_mode, 
input   ssc_en, 
input wire  [17:0] ssc_freq_div, 
input wire  [1:0] ssc_lpf_sel, 
input wire   ssc_mode, 
input wire   ssc_rstn, 
input wire  [23:0] ssc_step, 
input wire  vcca , 
input wire   vccd, 
input wire  vssa , 
input wire   vssd );

// Buses in the design

wire [0:7] net45 ;

wire [7:0]  fb_divn_dig;

wire [7:0] fb_divn_dig_sync ;

wire [5:0] fb_pi_dig_sync ;

wire [5:0]  fb_pi_dig;

wire [0:5] net054 ;


al6100gpll_com_hss_inv4x x_com_hss_inv4x_1_7 ( .vssa(vssa), 
    .dat_out(fb_divn_sync[7]), .vdda(vcca), .dat_in(net45[0]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_1_6 ( .vssa(vssa), 
    .dat_out(fb_divn_sync[6]), .vdda(vcca), .dat_in(net45[1]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_1_5 ( .vssa(vssa), 
    .dat_out(fb_divn_sync[5]), .vdda(vcca), .dat_in(net45[2]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_1_4 ( .vssa(vssa), 
    .dat_out(fb_divn_sync[4]), .vdda(vcca), .dat_in(net45[3]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_1_3 ( .vssa(vssa), 
    .dat_out(fb_divn_sync[3]), .vdda(vcca), .dat_in(net45[4]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_1_2 ( .vssa(vssa), 
    .dat_out(fb_divn_sync[2]), .vdda(vcca), .dat_in(net45[5]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_1_1 ( .vssa(vssa), 
    .dat_out(fb_divn_sync[1]), .vdda(vcca), .dat_in(net45[6]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_1_0 ( .vssa(vssa), 
    .dat_out(fb_divn_sync[0]), .vdda(vcca), .dat_in(net45[7]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_3_5 ( .vssa(vssa), 
    .dat_out(pi_ctrl_sync[5]), .vdda(vcca), .dat_in(net054[0]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_3_4 ( .vssa(vssa), 
    .dat_out(pi_ctrl_sync[4]), .vdda(vcca), .dat_in(net054[1]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_3_3 ( .vssa(vssa), 
    .dat_out(pi_ctrl_sync[3]), .vdda(vcca), .dat_in(net054[2]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_3_2 ( .vssa(vssa), 
    .dat_out(pi_ctrl_sync[2]), .vdda(vcca), .dat_in(net054[3]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_3_1 ( .vssa(vssa), 
    .dat_out(pi_ctrl_sync[1]), .vdda(vcca), .dat_in(net054[4]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_3_0 ( .vssa(vssa), 
    .dat_out(pi_ctrl_sync[0]), .vdda(vcca), .dat_in(net054[5]));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_5 ( .vssa(vssa), .dat_out(ck_divn), 
    .vdda(vcca), .dat_in(net37));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_0_7 ( .vssa(vssa), .dat_out(net45[0]), 
    .vdda(vcca), .dat_in(fb_divn_dig_sync[7]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_0_6 ( .vssa(vssa), .dat_out(net45[1]), 
    .vdda(vcca), .dat_in(fb_divn_dig_sync[6]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_0_5 ( .vssa(vssa), .dat_out(net45[2]), 
    .vdda(vcca), .dat_in(fb_divn_dig_sync[5]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_0_4 ( .vssa(vssa), .dat_out(net45[3]), 
    .vdda(vcca), .dat_in(fb_divn_dig_sync[4]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_0_3 ( .vssa(vssa), .dat_out(net45[4]), 
    .vdda(vcca), .dat_in(fb_divn_dig_sync[3]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_0_2 ( .vssa(vssa), .dat_out(net45[5]), 
    .vdda(vcca), .dat_in(fb_divn_dig_sync[2]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_0_1 ( .vssa(vssa), .dat_out(net45[6]), 
    .vdda(vcca), .dat_in(fb_divn_dig_sync[1]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_0_0 ( .vssa(vssa), .dat_out(net45[7]), 
    .vdda(vcca), .dat_in(fb_divn_dig_sync[0]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_2_5 ( .vssa(vssa), .dat_out(net054[0]), 
    .vdda(vcca), .dat_in(fb_pi_dig_sync[5]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_2_4 ( .vssa(vssa), .dat_out(net054[1]), 
    .vdda(vcca), .dat_in(fb_pi_dig_sync[4]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_2_3 ( .vssa(vssa), .dat_out(net054[2]), 
    .vdda(vcca), .dat_in(fb_pi_dig_sync[3]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_2_2 ( .vssa(vssa), .dat_out(net054[3]), 
    .vdda(vcca), .dat_in(fb_pi_dig_sync[2]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_2_1 ( .vssa(vssa), .dat_out(net054[4]), 
    .vdda(vcca), .dat_in(fb_pi_dig_sync[1]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_2_0 ( .vssa(vssa), .dat_out(net054[5]), 
    .vdda(vcca), .dat_in(fb_pi_dig_sync[0]));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_4 ( .vssa(vssa), .dat_out(net37), 
    .vdda(vcca), .dat_in(gpll_fracn_clk));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_1_5 ( .Q(fb_pi_dig_sync[5]), 
    .D(fb_pi_dig[5]), .CK(gpll_fracn_clk), .RDN(dig_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_1_4 ( .Q(fb_pi_dig_sync[4]), 
    .D(fb_pi_dig[4]), .CK(gpll_fracn_clk), .RDN(dig_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_1_3 ( .Q(fb_pi_dig_sync[3]), 
    .D(fb_pi_dig[3]), .CK(gpll_fracn_clk), .RDN(dig_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_1_2 ( .Q(fb_pi_dig_sync[2]), 
    .D(fb_pi_dig[2]), .CK(gpll_fracn_clk), .RDN(dig_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_1_1 ( .Q(fb_pi_dig_sync[1]), 
    .D(fb_pi_dig[1]), .CK(gpll_fracn_clk), .RDN(dig_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_1_0 ( .Q(fb_pi_dig_sync[0]), 
    .D(fb_pi_dig[0]), .CK(gpll_fracn_clk), .RDN(dig_rstn), .VDD(vcca), 
    .VSS(vssa), .VNW(vcca), .VPW(vssa));

gpll_clk_mux x_gpll_clk_mux_0 ( .ck_out_n(ckin_vco_n), 
    .ck_out_p(ckin_vco_p), .ck_in(ck_in[15:0]), 
    .ck_in_sel(ck_in_sel[3:0]), .done_gwe(done_gwe), .load(ck_in_shot), 
    .rstn(dig_rstn), .vcca(vcca), .vssa(vssa));

gpll_fracn_top_v1 x_gpll_fracn_top_v1_0 ( 
    .pi_ctrl_dig(fb_pi_dig_sync[5:0]), .ck_vco_p(ckin_vco_p), 
    .i40u_src(i40u_src), .pi_capsel(pi_capsel[2:0]), 
    .ck_vco_n(ckin_vco_n), .divn_en(divn_en), .ssc_en(ssc_en), 
    .ssc_dig_en(ssc_en_in), .fracn_dig_en(fracn_en_in), 
    .dig_rstn(dig_rstn), .rstn(rstn), .fracn_en(fracn_en), 
    .ck_out_p(ck_out_p), .ck_out_n(ck_out_n), .vcca(vcca), .vssa(vssa), 
    .ck_div(gpll_fracn_clk), .fb_divn_dig(fb_divn_dig_sync[7:0]), 
    .fb_divn(fb_divn[7:0]));

gpll_fbdiv_dig x_gpll_fbdiv_dig ( .fb_fracn(fb_fracn[27:0]), 
    .scan_out(scan_out), .scan_clk(scan_clk), 
    .scan_enable(scan_enable), .scan_in(scan_in), 
    .scan_mode(scan_mode), .scan_resetn(scan_resetn), 
    .fb_divn_probe(fb_divn_probe[7:0]), .ssc_step(ssc_step[23:0]), 
    .ssc_cnt(ssc_cnt[29:0]), .fracn_prbs_sel(fracn_prbs_sel[1:0]), 
    .fracn_prbs_out(prbs_out), .fracn_c_sum(fracn_c_sum[2:0]), 
    .fb_divn(fb_divn[7:0]), .ssc_mod_clk(ssc_mod_clk), 
    .fracn_dither_sel(fracn_dither_sel[3:0]), .fracn_rstn(dig_rstn), 
    .ssc_signal_bit(ssc_signbit), .fracn_dither_en(fracn_dither_en), 
    .fracn_en(fracn_en_in), .ssc_freq_div(ssc_freq_div[17:0]), 
    .fb_fracn_probe(fb_fracn_probe[23:0]), .fb_pi_dig(fb_pi_dig[5:0]), 
    .fb_divn_dig(fb_divn_dig[7:0]), 
    .ssc_dn_loop_mode(ssc_dn_loop_mode), .ck_dig(gpll_fracn_clk), 
    .ssc_mode(ssc_mode), .ssc_lpf_sel(ssc_lpf_sel[1:0]), 
    .ssc_en(ssc_en_in), .ssc_rstn(ssc_rstn), .vccd(vccd), .vssd(vssd));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_7 ( .qout(fb_divn_dig_sync[7]), 
    .ck(gpll_fracn_clk), .din(fb_divn_dig[7]), .rstn(dig_rstn), 
    .vccd(vcca), .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_6 ( .qout(fb_divn_dig_sync[6]), 
    .ck(gpll_fracn_clk), .din(fb_divn_dig[6]), .rstn(dig_rstn), 
    .vccd(vcca), .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_5 ( .qout(fb_divn_dig_sync[5]), 
    .ck(gpll_fracn_clk), .din(fb_divn_dig[5]), .rstn(dig_rstn), 
    .vccd(vcca), .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_4 ( .qout(fb_divn_dig_sync[4]), 
    .ck(gpll_fracn_clk), .din(fb_divn_dig[4]), .rstn(dig_rstn), 
    .vccd(vcca), .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_3 ( .qout(fb_divn_dig_sync[3]), 
    .ck(gpll_fracn_clk), .din(fb_divn_dig[3]), .rstn(dig_rstn), 
    .vccd(vcca), .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_2 ( .qout(fb_divn_dig_sync[2]), 
    .ck(gpll_fracn_clk), .din(fb_divn_dig[2]), .rstn(dig_rstn), 
    .vccd(vcca), .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_1 ( .qout(fb_divn_dig_sync[1]), 
    .ck(gpll_fracn_clk), .din(fb_divn_dig[1]), .rstn(dig_rstn), 
    .vccd(vcca), .vnw(vcca), .vpw(vssa), .vssd(vssa));

al6100gpll_cpll_div_n_dff x_cpll_div_n_dff_0_0 ( .qout(fb_divn_dig_sync[0]), 
    .ck(gpll_fracn_clk), .din(fb_divn_dig[0]), .rstn(dig_rstn), 
    .vccd(vcca), .vnw(vcca), .vpw(vssa), .vssd(vssa));

endmodule




/////////////////////////////////////////







/////////////////////////////////////////




// Library - al6100_analog, Cell - gpll_clk_mux, View - schematic
// LAST TIME SAVED: May 22 15:13:31 2023


module gpll_clk_mux ( 
output wire  ck_out_n , 
output wire  ck_out_p , 
input wire  [15:0] ck_in, 
input wire  [3:0] ck_in_sel, 
input   done_gwe, 
input   load, 
input   rstn, 
input wire   vcca, 
input wire   vssa );


wire  ck_in_0_7;

wire  ck_in_8_15;


com_hss_tieh x_com_hss_tieh_101 ( .tieh(tile_h), .vdda(vcca), 
    .vssa(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_53 ( .Q(q0), .D(tile_h), 
    .CK(ckb_0_15), .RDN(rstn_in), .VDD(vcca), .VSS(vssa), .VNW(vcca), 
    .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_2 ( .Q(q2), .D(q1), 
    .CK(ckb_0_15), .RDN(rstn_in), .VDD(vcca), .VSS(vssa), .VNW(vcca), 
    .VPW(vssa));

al6100gpll_DRNQV1_140P12T40L  x_DRNQV1_140P12T40L_1 ( .Q(q1), .D(q0), 
    .CK(ckb_0_15), .RDN(rstn_in), .VDD(vcca), .VSS(vssa), .VNW(vcca), 
    .VPW(vssa));

al6100gpll_NAND2CV2_140P12T40L  x_NAND2CV2_140P12T40L_3 ( .A1(load), .ZN(en_in), 
    .A2(done_gwe), .VDD(vcca), .VSS(vssa), .VNW(vcca), .VPW(vssa));

al6100gpll_AND2V2_140P12T40L  x_AND2V2_140P12T40L_6 ( .A1(q1), .Z(mux_sel), 
    .A2(q2b), .VSS(vssa), .VDD(vcca), .VNW(vcca), .VPW(vssa));

al6100gpll_AND2V2_140P12T40L  x_AND2V2_140P12T40L_4 ( .A1(en_in), .Z(rstn_in), 
    .A2(rstn), .VSS(vssa), .VDD(vcca), .VNW(vcca), .VPW(vssa));

al6100gpll_CLKMUX2V2_140P12T40L  x_CLKMUX2V2_140P12T40L_24 ( .I0(ck_in_0_7), 
    .I1(ck_in_8_15), .S(ck_in_sel[3]), .Z(net75), .VDD(vcca), 
    .VSS(vssa), .VPW(vssa), .VNW(vcca));

al6100gpll_CLKMUX2V2_140P12T40L  x_CLKMUX2V2_140P12T40L_5 ( .I0(ck_0_15), 
    .I1(tile_l), .S(mux_sel), .Z(net67), .VDD(vcca), .VSS(vssa), 
    .VPW(vssa), .VNW(vcca));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_26 ( .vssa(vssa), .dat_out(q2b), 
    .vdda(vcca), .dat_in(q2));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_11 ( .vssa(vssa), .dat_out(net052), 
    .vdda(vcca), .dat_in(net75));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_104 ( .vssa(vssa), .dat_out(net79), 
    .vdda(vcca), .dat_in(net67));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_99 ( .vssa(vssa), .dat_out(net66), 
    .vdda(vcca), .dat_in(ck_mux_out));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_25 ( .vssa(vssa), .dat_out(ckb_0_15), 
    .vdda(vcca), .dat_in(net75));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_12 ( .vssa(vssa), .dat_out(ck_0_15), 
    .vdda(vcca), .dat_in(net052));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_103 ( .vssa(vssa), .dat_out(ck_mux_out), 
    .vdda(vcca), .dat_in(net79));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_91 ( .vssa(vssa), .dat_out(ck_out_p), 
    .vdda(vcca), .dat_in(net55));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_90 ( .vssa(vssa), .dat_out(net55), 
    .vdda(vcca), .dat_in(net65));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_95 ( .vssa(vssa), .dat_out(ck_out_n), 
    .vdda(vcca), .dat_in(net54));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_94 ( .vssa(vssa), .dat_out(net54), 
    .vdda(vcca), .dat_in(net66));

com_hss_tiel x_com_hss_tiel_102 ( .tiel(tile_l), .vdda(vcca), 
    .vssa(vssa));

al6100gpll_com_hss_tgate_2x x_com_hss_tgate_2x_100 ( .seln(tile_l), 
    .va(ck_mux_out), .vcca(vcca), .sel(tile_h), .vssa(vssa), 
    .vz(net65));

gpll_fbdiv_mux x_gpll_fbdiv_mux_0 ( .ck_out(ck_in_0_7), 
    .ck_phase_000(ck_in[0]), .ck_phase_045(ck_in[1]), 
    .ck_phase_090(ck_in[2]), .ck_phase_135(ck_in[3]), 
    .ck_phase_180(ck_in[4]), .ck_phase_225(ck_in[5]), 
    .ck_phase_270(ck_in[6]), .ck_phase_315(ck_in[7]), 
    .sel(ck_in_sel[2:0]), .vcca(vcca), .vssa(vssa));

gpll_fbdiv_mux x_gpll_fbdiv_mux_23 ( .ck_out(ck_in_8_15), 
    .ck_phase_000(ck_in[8]), .ck_phase_045(ck_in[9]), 
    .ck_phase_090(ck_in[10]), .ck_phase_135(ck_in[11]), 
    .ck_phase_180(ck_in[12]), .ck_phase_225(ck_in[13]), 
    .ck_phase_270(ck_in[14]), .ck_phase_315(ck_in[15]), 
    .sel(ck_in_sel[2:0]), .vcca(vcca), .vssa(vssa));

endmodule


//systemVerilog HDL for "al6100_pll", "gpll_pi_64bit" "systemVerilog"
//-------------------------------------------------------------------
`timescale 1ns/1fs 
//-------------------------------------------------------------------
//---------------------------begin-----------------------------------
//-------------------------------------------------------------------
module gpll_pi_64bit ( pi_outn, pi_outp, enable, i40u_src, pa, pb, pi_capsel, pi_ctrl, vcca, vssa );
//-------------------------------------------------------------------
//---------------------------pin define------------------------------
//-------------------------------------------------------------------
input	vcca;
input 	vssa;
input 	enable;
input 	i40u_src;
input	pa;
input	pb;
input	[2:0] pi_capsel;
input	[5:0] pi_ctrl;
output	pi_outp;
output	pi_outn;
//---------------------------wire & reg------------------------------
reg		pi_phase;
reg 	pi_outp;
reg 	pi_outn;
wire	clk_early;
wire	clk_late;
//---------------------------pin real--------------------------------
real 	trise_early; 
real	trise_late;
real	delta_delay;
real	pi_step;
real	delay_time;
real	pi_sel;
//-------------------------------------------------------------------
//---------------------------initial---------------------------------
//-------------------------------------------------------------------
initial begin
  trise_early = 1'b0;
  trise_late  = 1'b0;
  delta_delay = 1'b0;
  pi_step     = 1'b0; 
  pi_sel      = 1'b0;
  delay_time  = 1'b0;
  pi_phase    = 1'b0;
  pi_outp     = 1'b1;
  pi_outn     = 1'b1;
end
//-------------------------------------------------------------------
//---------------------------code------------------------------------
//-------------------------------------------------------------------
always @( * ) 	begin
	if     (pi_ctrl[5:0] == 6'b000000) begin pi_sel = 0; end
	else if(pi_ctrl[5:0] == 6'b000001) begin pi_sel = 1; end
	else if(pi_ctrl[5:0] == 6'b000010) begin pi_sel = 2; end
	else if(pi_ctrl[5:0] == 6'b000011) begin pi_sel = 3; end
	else if(pi_ctrl[5:0] == 6'b000100) begin pi_sel = 4; end
	else if(pi_ctrl[5:0] == 6'b000101) begin pi_sel = 5; end
	else if(pi_ctrl[5:0] == 6'b000110) begin pi_sel = 6; end
	else if(pi_ctrl[5:0] == 6'b000111) begin pi_sel = 7; end
	else if(pi_ctrl[5:0] == 6'b001000) begin pi_sel = 8; end
	else if(pi_ctrl[5:0] == 6'b001001) begin pi_sel = 9; end
	else if(pi_ctrl[5:0] == 6'b001010) begin pi_sel = 10; end
	else if(pi_ctrl[5:0] == 6'b001011) begin pi_sel = 11; end
	else if(pi_ctrl[5:0] == 6'b001100) begin pi_sel = 12; end
	else if(pi_ctrl[5:0] == 6'b001101) begin pi_sel = 13; end
	else if(pi_ctrl[5:0] == 6'b001110) begin pi_sel = 14; end
	else if(pi_ctrl[5:0] == 6'b001111) begin pi_sel = 15; end
	else if(pi_ctrl[5:0] == 6'b010000) begin pi_sel = 16; end
	else if(pi_ctrl[5:0] == 6'b010001) begin pi_sel = 17; end
	else if(pi_ctrl[5:0] == 6'b010010) begin pi_sel = 18; end
	else if(pi_ctrl[5:0] == 6'b010011) begin pi_sel = 19; end
	else if(pi_ctrl[5:0] == 6'b010100) begin pi_sel = 20; end
	else if(pi_ctrl[5:0] == 6'b010101) begin pi_sel = 21; end
	else if(pi_ctrl[5:0] == 6'b010110) begin pi_sel = 22; end
	else if(pi_ctrl[5:0] == 6'b010111) begin pi_sel = 23; end
	else if(pi_ctrl[5:0] == 6'b011000) begin pi_sel = 24; end
	else if(pi_ctrl[5:0] == 6'b011001) begin pi_sel = 25; end
	else if(pi_ctrl[5:0] == 6'b011010) begin pi_sel = 26; end
	else if(pi_ctrl[5:0] == 6'b011011) begin pi_sel = 27; end
	else if(pi_ctrl[5:0] == 6'b011100) begin pi_sel = 28; end
	else if(pi_ctrl[5:0] == 6'b011101) begin pi_sel = 29; end
	else if(pi_ctrl[5:0] == 6'b011110) begin pi_sel = 30; end
	else if(pi_ctrl[5:0] == 6'b011111) begin pi_sel = 31; end
	else if(pi_ctrl[5:0] == 6'b100000) begin pi_sel = 32; end
	else if(pi_ctrl[5:0] == 6'b100001) begin pi_sel = 33; end
	else if(pi_ctrl[5:0] == 6'b100010) begin pi_sel = 34; end
	else if(pi_ctrl[5:0] == 6'b100011) begin pi_sel = 35; end
	else if(pi_ctrl[5:0] == 6'b100100) begin pi_sel = 36; end
	else if(pi_ctrl[5:0] == 6'b100101) begin pi_sel = 37; end
	else if(pi_ctrl[5:0] == 6'b100110) begin pi_sel = 38; end
	else if(pi_ctrl[5:0] == 6'b100111) begin pi_sel = 39; end
	else if(pi_ctrl[5:0] == 6'b101000) begin pi_sel = 40; end
	else if(pi_ctrl[5:0] == 6'b101001) begin pi_sel = 41; end
	else if(pi_ctrl[5:0] == 6'b101010) begin pi_sel = 42; end
	else if(pi_ctrl[5:0] == 6'b101011) begin pi_sel = 43; end
	else if(pi_ctrl[5:0] == 6'b101100) begin pi_sel = 44; end
	else if(pi_ctrl[5:0] == 6'b101101) begin pi_sel = 45; end
	else if(pi_ctrl[5:0] == 6'b101110) begin pi_sel = 46; end
	else if(pi_ctrl[5:0] == 6'b101111) begin pi_sel = 47; end
	else if(pi_ctrl[5:0] == 6'b110000) begin pi_sel = 48; end
	else if(pi_ctrl[5:0] == 6'b110001) begin pi_sel = 49; end
	else if(pi_ctrl[5:0] == 6'b110010) begin pi_sel = 50; end
	else if(pi_ctrl[5:0] == 6'b110011) begin pi_sel = 51; end
	else if(pi_ctrl[5:0] == 6'b110100) begin pi_sel = 52; end
	else if(pi_ctrl[5:0] == 6'b110101) begin pi_sel = 53; end
	else if(pi_ctrl[5:0] == 6'b110110) begin pi_sel = 54; end
	else if(pi_ctrl[5:0] == 6'b110111) begin pi_sel = 55; end
	else if(pi_ctrl[5:0] == 6'b111000) begin pi_sel = 56; end
	else if(pi_ctrl[5:0] == 6'b111001) begin pi_sel = 57; end
	else if(pi_ctrl[5:0] == 6'b111010) begin pi_sel = 58; end
	else if(pi_ctrl[5:0] == 6'b111011) begin pi_sel = 59; end
	else if(pi_ctrl[5:0] == 6'b111100) begin pi_sel = 60; end
	else if(pi_ctrl[5:0] == 6'b111101) begin pi_sel = 61; end
	else if(pi_ctrl[5:0] == 6'b111110) begin pi_sel = 62; end
	else if(pi_ctrl[5:0] == 6'b111111) begin pi_sel = 63; end
	else pi_sel = 0;
end

//get clk_early/clk_late delta phi
assign clk_early	=pa;
assign clk_late		=pb;

always @(posedge clk_early) begin
		trise_early <= $realtime;
end

always @(negedge clk_late) begin
		pi_phase <= 1'b0;
end

always @(posedge clk_late) begin
		delta_delay  <= $realtime - trise_early;
		pi_step      <= delta_delay/64;
		delay_time   <= pi_sel * pi_step;
		pi_phase     <= 1'b1;
end

always @* begin
	pi_outp <= #(delay_time)  pi_phase;
	pi_outn <= #(delay_time) !pi_phase;
end

endmodule
//-------------------------------------------------------------------
//---------------------------end-------------------------------------
//-------------------------------------------------------------------












// Library - al6100_analog, Cell - gpll_vco_mux_pi_top, View -
//schematic
// LAST TIME SAVED: May 22 15:13:28 2023


module gpll_vco_mux_pi_top ( 
output   ckout, 
input  [6:0] dpher, 
input  [1:0] ibn_5u, 
input   ibn_100u_poly, 
input   ibn_100u_vco, 
input  [7:0] ph_in, 
input  [2:0] pi_capsel, 
input wire  pi_en , 
input   pi_icfg, 
input   pll_rst_n, 
input wire  vccd , 
input wire  vco_en , 
input   vreg_0p9, 
input   vreg_rdy, 
input wire  vssa  );

// Buses in the design

wire [15:0]  pi_ctrl1;

wire [15:0]  pi_ctrl0;

wire [15:0]  pi_ctrl3;

wire [3:0]  ph;

wire [15:0]  pi_ctrl2;


gpll_ouput_pi_top  x_gpll_ouput_pi_top ( .ck_filter(ckout), 
    .ph(ph[3:0]), .ck_early(ck_early), .ck_late(ck_late), 
    .ibn_100u_vco(ibn_100u_vco), .ibn_100u_poly(ibn_100u_poly), 
    .isource_vco_en(pi_icfg), .ibn_5u(ibn_5u[1:0]), 
    .mc1_pi_capsel(pi_capsel[2:0]), .ckout(ckout), .pi_out(pi_out), 
    .mc1_phshift_en(pi_en_internal), .pi_ctrl0(pi_ctrl0[15:0]), 
    .pi_ctrl1(pi_ctrl1[15:0]), .pi_ctrl2(pi_ctrl2[15:0]), 
    .pi_ctrl3(pi_ctrl3[15:0]), .vbg_rdy(vreg_rdy), .vccd(vreg_0p9), 
    .vssa(vssa));

al6100gpll_com_hss_and2_2x x_com_hss_and2_2x_9 ( .vcca(vccd), .do_n(net34), 
    .d2(vco_en), .d1(pi_en), .vssa(vssa));

gpll_pi_dec_top  x_gpll_pi_dec_top ( .ckin(ckout), .ph(ph[3:0]), 
    .ph_in(ph_in[7:0]), .ck_late(ck_late), .ck_early(ck_early), 
    .pi_ctrl3(pi_ctrl3[15:0]), .pi_ctrl2(pi_ctrl2[15:0]), 
    .pi_ctrl1(pi_ctrl1[15:0]), .pi_ctrl0(pi_ctrl0[15:0]), .vssd(vssa), 
    .vccd(vccd), .resetn(pll_rst_n), .en(pi_en_internal), 
    .dpher(dpher[6:0]));

al6100gpll_com_hss_buf4x x_com_hss_buf4x_10 ( .din(net34), .dout(pi_en_internal), 
    .vcca_v0p9(vccd), .vssa(vssa));

endmodule


//-------------------------------------------------------------------
`timescale 1ns / 1fs
//-------------------------------------------------------------------
//---------------------------begin-----------------------------------
//-------------------------------------------------------------------
module gpll_ibias ( ibn_5u, ibn_10u, ibn_40u, ibp_5u, ibp_10u, ibp_100u_outputpi,
bias_en, bias_icfg, ibn_30u_pi, ibp_10u_poly, outputpi_icfg, pi_icfg, sg18_poc,
vccaux, vccd, vssa );
//-------------------------------------------------------------------
//---------------------------pin define------------------------------
//-------------------------------------------------------------------
//---------------------------input------------------------------------
input 		vccaux;
input 		vssa;
input 		vccd;
input 		sg18_poc;
input 		bias_en;
input 		ibn_30u_pi;
input 		ibp_10u_poly;
input  	[1:0] 	outputpi_icfg;
input  	[1:0] 	bias_icfg;
input  	[3:0] 	pi_icfg;
//-------------------------------------------------------------------
output  [2:0] 	ibp_10u;
output  [1:0] 	ibp_5u;
output 		ibp_100u_outputpi;
output  [2:0] 	ibn_5u;
output 		ibn_40u;
output 		ibn_10u;
//reg		ibp_10u_poly;
//reg		ibn_10u_ptat;
wire	[2:0]	ibp_10u;
wire	[1:0] 	ibp_5u;
wire 		ibp_100u_outputpi;
wire  	[2:0] 	ibn_5u;
wire 		ibn_40u;
wire 	[1:0]	ibn_10u;
//-------------------------------------------------------------------
//-------------------------------------------------------------------
//--ibp_10u_poly is gpll top currents--pmos---1 means off 0 means on-
//-------------------------------------------------------------------
//---------------------------code------------------------------------
//-------------------------------------------------------------------
	assign		ibp_10u [2:0] 		= (vccaux && vccd && bias_en && ~sg18_poc && ~ibp_10u_poly)? 3'b111 : 3'b000;
	assign		ibp_5u	[1:0] 		= (vccaux && vccd && bias_en && ~sg18_poc && ~ibp_10u_poly)? 2'b11 : 2'b00;
	assign		ibp_100u_outputpi 	= (vccaux && vccd && bias_en && ~sg18_poc && ~ibp_10u_poly)? 1'b1 : 1'b0;
	assign		ibn_5u 	[2:0] 		= (vccaux && vccd && bias_en && ~sg18_poc && ~ibp_10u_poly)? 3'b111 : 3'b000;
	assign		ibn_40u 		= (vccaux && vccd && bias_en && ~sg18_poc && ~ibp_10u_poly && ibn_30u_pi)? 1'b1 : 1'b0;
	assign		ibn_10u [1:0]		= (vccaux && vccd && bias_en && ~sg18_poc && ~ibp_10u_poly)? 2'b11 : 2'b00;
endmodule
//-------------------------------------------------------------------
//-------------------------------------------------------------------
//--ibn_10u_ptat is vco v2i currents---nmos---0 means off 1 means on-
//--ibn_10u_vref is LDO currents-------nmos---0 means off 1 means on-
//-------------------------------------------------------------------
//---------------------------end-------------------------------------
//-------------------------------------------------------------------







// Library - al6100_analog, Cell - gpll_vco_buf, View - schematic
// LAST TIME SAVED: May 22 15:13:29 2023


module gpll_vco_buf ( 
output wire  buf_000 , 
output wire  buf_045 , 
output wire  buf_090 , 
output wire  buf_135 , 
output wire  buf_180 , 
output wire  buf_225 , 
output wire  buf_270 , 
output wire  buf_315 , 
output wire  ck000_fbdiv , 
output wire  ck045_fbdiv , 
output wire  ck090_fbdiv , 
output wire  ck135_fbdiv , 
output wire  ck180_fbdiv , 
output wire  ck225_fbdiv , 
output wire  ck270_fbdiv , 
output wire  ck315_fbdiv , 
input wire  ckin_000 , 
input wire  ckin_045 , 
input wire  ckin_090 , 
input wire  ckin_135 , 
input wire  ckin_180 , 
input wire  ckin_225 , 
input wire  ckin_270 , 
input wire  ckin_315 , 
input wire  vccd , 
input wire  vssd  );


gpll_vco_buf_unit x_gpll_vco_buf_unit_61 ( .outn(buf_315), 
    .outp(buf_135), .ckinn(ckin_315), .ckinp(ckin_135), 
    .ckp_fbdiv(ck135_fbdiv), .ckn_fbdiv(ck315_fbdiv), .vccd(vccd), 
    .vssd(vssd));

gpll_vco_buf_unit x_gpll_vco_buf_unit_62 ( .outn(buf_270), 
    .outp(buf_090), .ckinn(ckin_270), .ckinp(ckin_090), 
    .ckp_fbdiv(ck090_fbdiv), .ckn_fbdiv(ck270_fbdiv), .vccd(vccd), 
    .vssd(vssd));

gpll_vco_buf_unit x_gpll_vco_buf_unit_56 ( .ckinn(ckin_180), 
    .ckinp(ckin_000), .ckp_fbdiv(ck000_fbdiv), .ckn_fbdiv(ck180_fbdiv), 
    .outn(buf_180), .outp(buf_000), .vccd(vccd), .vssd(vssd));

gpll_vco_buf_unit x_gpll_vco_buf_unit_60 ( .outn(buf_225), 
    .outp(buf_045), .ckinn(ckin_225), .ckinp(ckin_045), 
    .ckp_fbdiv(ck045_fbdiv), .ckn_fbdiv(ck225_fbdiv), .vccd(vccd), 
    .vssd(vssd));

endmodule


//systemVerilog HDL for "al6100_bandgap", "bg_sgaux_init" "systemVerilog"
//-------------------------------------------------------------------
`timescale 1ns / 1fs 
//-------------------------------------------------------------------
//---------------------------begin-----------------------------------
//-------------------------------------------------------------------
module bg_sgaux_init (sg09_por_n, vccaux, vcc0p9, vssa, vsgaux_init);
//-------------------------------------------------------------------
//---------------------------pin define------------------------------
//-------------------------------------------------------------------
input	vcc0p9;
input	vccaux;
input	vssa;
input	sg09_por_n;
//---------------------------pin real--------------------------------
output	reg	vsgaux_init;
//-------------------------------------------------------------------
//---------------------------code------------------------------------
//-------------------------------------------------------------------
always@* begin
	if((vccaux)&&(!vcc0p9)&&(!sg09_por_n)) begin
		vsgaux_init<=1;
	end
	else	begin
		vsgaux_init<=0;
	end
end
endmodule
//-------------------------------------------------------------------
//---------------------------end-------------------------------------
//-------------------------------------------------------------------


// Library - al6100_analog, Cell - gpll_ana_buf_unit_x3, View -
//schematic
// LAST TIME SAVED: Sep  3 14:03:40 2022


module gpll_ana_buf_unit_x3 ( 
output wire  outp0 , 
output wire  outp1 , 
output wire  outp2 , 
input wire  inn , 
input wire  inp , 
input wire  vcca , 
input wire  vssa  );


al6100gpll_com_hss_inv4x x_com_hss_inv4x_8 ( .vssa(vssa), .dat_out(net08), 
    .vdda(vcca), .dat_in(net017));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_7 ( .vssa(vssa), .dat_out(outp2), 
    .vdda(vcca), .dat_in(net018));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_5 ( .vssa(vssa), .dat_out(net09), 
    .vdda(vcca), .dat_in(net017));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_4 ( .vssa(vssa), .dat_out(outp1), 
    .vdda(vcca), .dat_in(net018));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_0 ( .vssa(vssa), .dat_out(net018), 
    .vdda(vcca), .dat_in(inp));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_1 ( .vssa(vssa), .dat_out(outp0), 
    .vdda(vcca), .dat_in(net018));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_3 ( .vssa(vssa), .dat_out(net010), 
    .vdda(vcca), .dat_in(net017));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_2 ( .vssa(vssa), .dat_out(net017), 
    .vdda(vcca), .dat_in(inn));

endmodule


//systemVerilog HDL for "al6100_pll", "gpll_fbdiv_mux" "systemVerilog"

`timescale 1ns/1fs
module gpll_fbdiv_mux ( ck_out, ck_phase_000, ck_phase_045, ck_phase_090, ck_phase_135, ck_phase_180, ck_phase_225, ck_phase_270, ck_phase_315, sel, vcca, vssa );
input vcca;
input vssa;

input ck_phase_000;
input ck_phase_045;
input ck_phase_090;
input ck_phase_135;
input ck_phase_180;
input ck_phase_225;
input ck_phase_270;
input ck_phase_315;

input  [2:0] sel;

output ck_out;
//circutis begin
reg ck_out;
always @ ( * ) begin 
	case(sel)
		3'b000:	begin ck_out = ck_phase_000; end
		3'b001:	begin ck_out = ck_phase_045; end
		3'b010:	begin ck_out = ck_phase_090; end
		3'b011:	begin ck_out = ck_phase_135; end
		3'b100:	begin ck_out = ck_phase_180; end
		3'b101:	begin ck_out = ck_phase_225; end
		3'b110:	begin ck_out = ck_phase_270; end
		3'b111:	begin ck_out = ck_phase_315; end
		default:begin ck_out = 1'b0;		 end
	endcase
end

endmodule











//systemVerilog HDL for "al6100_serdes_pll", "cpll_div_n_sync" "systemVerilog"

`timescale 1ns/1fs
module cpll_div_n_sync ( en_out, p_out, pout, ck_in_n, ck_in_p, en, en_in, mod, p_in, pin, ck_mbo, eno, bpi, bpo , vcca, vssa );
input vcca;
input vssa;

input en;
input bpi;
input pin;

input  [6:0] p_in;
input  [6:0] en_in;

input  [6:0] mod;
input  [6:0] ck_in_p;
input  [6:0] ck_in_n;

output bpo;
output eno;
output pout;
output ck_mbo;

output  [6:0] p_out;
output  [6:0] en_out;

//sync logic
wire mod0_b,mod0_bb,mod1_b,mod2_b,mod3_b,mod4_b,mod5_b;
wire pu_in;
wire [5:0] ck_mod;
reg [6:0] en_out;
reg [6:0] p_out;
reg pout;
reg p_sync0,p_sync1;
reg p0_sync0;

reg en1_sync0,en1_sync1;
reg en2_sync0;
reg en3_sync0;
reg en4_sync0;
reg en5_sync0;
reg en6_sync0;

//initial begin
initial begin
en1_sync0=1'b0;
en1_sync1=1'b0;
en2_sync0=1'b0;
en3_sync0=1'b0;
en4_sync0=1'b0;
en5_sync0=1'b0;
en6_sync0=1'b0;
p0_sync0=1'b0;
p_sync0=1'b0;
p_sync1=1'b0;
pout=1'b0;
en_out[6:0]=7'b000_1000;
p_out[6:0]=7'b000_1000;
end

assign pu_in = en;
assign eno   = en;
assign bpo   = bpi;

//div234_0 sync_logic
assign mod0_b = !mod[0];
assign mod0_bb = !mod0_b;

always@ (posedge ck_in_n[0] or negedge pu_in ) #0.035 begin 
	if ( !pu_in ) begin
		en_out[0] <= 1'b1;
	end
	else begin
		en_out[0] <= ((en_in[0]===1'b1)|(en_in[0]===1'b0))?en_in[0]:1'b1;		
	end
end
always@ (posedge mod0_b or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		p_sync0  <= 1'b1;
		p0_sync0 <= 1'b1;
	end
	else begin
		p_sync0  <= ((pin===1'b1)|(pin===1'b0))? pin:1'b1;
		p0_sync0 <= ((p_in[0]===1'b1)|(p_in[0]===1'b0))? p_in[0]:1'b1;		
	end
end
always@ (posedge mod0_bb or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		p_sync1  <= 1'b1;
	end
	else begin
		p_sync1  <= ((p_sync0===1'b1)|(p_sync0===1'b0))?p_sync0:1'b1;		
	end
end
always@ ( * ) begin
	pout 	= en_out[0] & p_sync1 ;
	p_out[0] = en_out[0] & !(pout & !p0_sync0) ;
end
//div23_1 sync_logic
always@ (posedge mod0_b or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en1_sync0  	<= 1'b1;
		p_out[1] 	<= 1'b1;	
	end
	else begin
		en1_sync0  	<= ((en_in[1]===1'b1)|(en_in[1]===1'b0))?en_in[1]:1'b1;
		p_out[1] 	<= ((p_in[1]===1'b1)|(p_in[1]===1'b0))? p_in[1]:1'b1;	
	end
end
assign ck_mod[0] = !(ck_in_n[1] | !mod0_bb);
always@ (posedge ck_mod[0] or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en1_sync1  	<= 1'b1;
	end
	else begin
		en1_sync1  	<= ((en1_sync0===1'b1)|(en1_sync0===1'b0))?en1_sync0:1'b1;
	end
end
always@ ( * ) begin
	en_out[1] = pout & en1_sync1;
end
//div23_2 sync_logic
assign mod1_b = !mod[1];
always@ (posedge mod1_b or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en2_sync0  	<= 1'b0;
		p_out[2] 	<= 1'b0;	
	end
	else begin
		en2_sync0  	<= ((en_in[2]===1'b1)|(en_in[2]===1'b0))? en_in[2]:1'b1;
		p_out[2] 	<= ((p_in[2]===1'b1)|(p_in[2]===1'b0))? p_in[2]:1'b1;	
	end
end
assign ck_mod[1] = !(ck_in_n[2] | mod1_b);
always@ (posedge ck_mod[1] or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en_out[2]  	<= 1'b0;
	end
	else begin
		en_out[2]  	<= ((en2_sync0===1'b1)|(en2_sync0===1'b0))?en2_sync0:1'b0;
	end
end

//div23_3 sync_logic
assign mod2_b = !mod[2];
always@ (posedge mod2_b or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en3_sync0  	<= 1'b0;
		p_out[3] 	<= 1'b0;	
	end
	else begin
		en3_sync0  	<= ((en_in[3]===1'b1)|(en_in[3]===1'b0))?en_in[3]:1'b0;
		p_out[3] 	<= ((p_in[3]===1'b1)|(p_in[3]===1'b0))?p_in[3]:1'b0;	
	end
end
assign ck_mod[2] = !(ck_in_n[3] | mod2_b);
always@ (posedge ck_mod[2] or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en_out[3]  	<= 1'b0;
	end
	else begin
		en_out[3]  	<= ((en3_sync0===1'b1)|(en3_sync0===1'b0))? en3_sync0:1'b0;
	end
end

//div23_4 sync_logic
assign mod3_b = !mod[3];
always@ (posedge mod3_b or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en4_sync0  	<= 1'b0;
		p_out[4] 	<= 1'b0;	
	end
	else begin
		en4_sync0  	<= ((en_in[4]===1'b1)|(en_in[4]===1'b0))? en_in[4]:1'b0;
		p_out[4] 	<= ((p_in[4]===1'b1)|(p_in[4]===1'b0))? p_in[4]:1'b0;	
	end
end
assign ck_mod[3] = !(ck_in_n[4] | mod3_b);
always@ (posedge ck_mod[3] or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en_out[4]  	<= 1'b0;
	end
	else begin
		en_out[4]  	<= ((en4_sync0===1'b1)|(en4_sync0===1'b0))? en4_sync0:1'b0;
	end
end

//div23_5 sync_logic
assign mod4_b = !mod[4];
always@ (posedge mod4_b or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en5_sync0  	<= 1'b0;
		p_out[5] 	<= 1'b0;	
	end
	else begin
		en5_sync0  	<= ((en_in[5]===1'b1)|(en_in[5]===1'b0))?en_in[5]:1'b0;
		p_out[5] 	<= ((p_in[5]===1'b1)|(p_in[5]===1'b0))?p_in[5]:1'b0;	
	end
end
assign ck_mod[4] = !(ck_in_n[5] | mod4_b);
always@ (posedge ck_mod[4] or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en_out[5]  	<= 1'b0;
	end
	else begin
		en_out[5]  	<= ((en5_sync0===1'b1)|(en5_sync0===1'b0))? en5_sync0:1'b0;
	end
end

//div23_5 sync_logic
assign mod5_b = !mod[5];
always@ (posedge mod5_b or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en6_sync0  	<= 1'b0;
		p_out[6] 	<= 1'b0;	
	end
	else begin
		en6_sync0  	<= ((en_in[6]===1'b1)|(en_in[6]===1'b0))? en_in[6]:1'b0;
		p_out[6] 	<= ((p_in[6]===1'b1)|(p_in[6]===1'b0))? p_in[6]:1'b0;	
	end
end
assign ck_mod[5] = !(ck_in_n[6] | mod5_b);
always@ (posedge ck_mod[5] or negedge pu_in ) #0.035 begin
	if ( !pu_in ) begin
		en_out[6]  	<= 1'b0;
	end
	else begin
		en_out[6]  	<= ((en6_sync0===1'b1)|(en6_sync0===1'b0))? en6_sync0:1'b0;
	end
end

//duty-cycle shift
wire en1_outd,en2_outd,en3_outd,en4_outd,en5_outd,en6_outd;
assign #0.005 en1_outd = en_out[1];
assign #0.005 en2_outd = en_out[2];
assign #0.005 en3_outd = en_out[3];
assign #0.005 en4_outd = en_out[4];
assign #0.005 en5_outd = en_out[5];
assign #0.005 en6_outd = en_out[6];

wire [6:1] ck_mb;
assign ck_mb[1] = !(mod[1] & en1_outd);
assign ck_mb[2] = !(mod[2] & en2_outd);
assign ck_mb[3] = !(mod[3] & en3_outd);
assign ck_mb[4] = !(mod[4] & en4_outd);
assign ck_mb[5] = !(mod[5] & en5_outd);
assign ck_mb[6] = !(mod[6] & en6_outd);

wire ck_mb0123456,ck_mb123456,ck_mb23456,ck_mb3456,ck_mb456,ck_mb56;
assign ck_mb0123456 = !(mod0_b & ck_mb123456 );
assign ck_mb123456  =  ck_mb[1] & ck_mb23456;
assign ck_mb23456   =  ck_mb[2] & ck_mb3456;
assign ck_mb3456    =  ck_mb[3] & ck_mb456;
assign ck_mb456     =  ck_mb[4] & ck_mb56;
assign ck_mb56      =  ck_mb[5] & ck_mb[6];

assign ck_mbo       =  ck_mb0123456;

endmodule


// Library - al6100_analog, Cell - gpll_core, View - schematic
// LAST TIME SAVED: Sep 11 11:38:13 2023


module gpll_core ( 
output   bandcal1_rstn, 
output   bandcal_rstn, 
output   fast_lock, 
output   int_lock, 
output   lock, 
output  [7:0] out_path_divrst_clk, 
output  [7:0] phasedone, 
output  [7:0] phaseout, 
output   phomux, 
output wire  sg09_gpll_ck_divn , 
output wire [7:0] sg09_gpll_fbdiv_code, 
output wire  sg09_gpll_fbkck , 
output wire  sg09_gpll_fbkck_test , 
output wire  [2:0] sg09_gpll_fracn_c_sum, 
output wire [5:0] sg09_gpll_pi_code, 
output wire   sg09_gpll_prbs_out, 
output wire  sg09_gpll_refck , 
output wire  sg09_gpll_refck_test , 
output wire   sg09_gpll_ssc_mod_clk, 
output wire   sg09_gpll_ssc_signbit, 
output   sgcc_cal_done, 
output  [3:0] sgcc_vco_band, 
output   vreg_rdy, 
input   ck0_div, 
input  [7:0] ck_out_path_en, 
input  [7:0] direction, 
input   done_gwe, 
input   ext_lock_en, 
input wire  [14:0] gpll_fbkck, 
input wire  [15:0] gpll_refck, 
input   ibn_10u_ptat, 
input wire   ibn_10u_vref, 
input wire   ibp_10u_poly, 
input  [2:0] mc1_cal_counter, 
input   mc1_clk0_frac_en, 
input   mc1_dyn_ph_shift_en, 
input  [6:0] mc1_frac, 
input  [6:0] mc1_gpll_lockdet, 
input  [2:0] mc1_outputpi_capsel, 
input wire  [2:0] mc1_outputpi_icfg, 
input  [7:0] mc1_phomux_sel, 
input  [1:0] mc1_pi_delay, 
input   mc1_pi_frac_mode, 
input  [7:0] mc1_pi_out_sel, 
input   mc1_pi_phshift_en, 
input   mc1_refclk_det_byp, 
input  [1:0] mc1_refclk_det_div, 
input  [6:0] phsel_0, 
input  [2:0] phsel_1, 
input  [2:0] phsel_2, 
input  [2:0] phsel_3, 
input  [2:0] phsel_4, 
input  [2:0] phsel_5, 
input  [2:0] phsel_6, 
input  [2:0] phsel_7, 
input   pib_lockdet_clr_n, 
input   pll_cal_rst_n, 
input  [7:0] rotate, 
input wire   scan_clk, 
input wire   scan_enable, 
input wire   scan_in, 
input wire   scan_mode, 
input wire   scan_resetn, 
input  [7:0] scanclk, 
input wire  [1:0] sg09_gpll_bias_icfg, 
input  [2:0] sg09_gpll_cp_dlysel, 
input  [2:0] sg09_gpll_cp_refsel, 
input   sg09_gpll_en, 
input  [2:0] sg09_gpll_fastlock_sel, 
input   sg09_gpll_fastloop_cfg, 
input wire  [7:0] sg09_gpll_fbdiv, 
input   sg09_gpll_fbdiv_rstn, 
input  [27:0] sg09_gpll_fbfracn_sel, 
input wire  [3:0] sg09_gpll_fbkck_sel, 
input   sg09_gpll_fbkck_shot, 
input wire   sg09_gpll_fracn_dither_en, 
input wire  [3:0] sg09_gpll_fracn_dither_sel, 
input   sg09_gpll_fracn_en, 
input wire  [1:0] sg09_gpll_fracn_prbs_sel, 
input  [4:0] sg09_gpll_icp_banch, 
input  [4:0] sg09_gpll_icp_bias, 
input  [3:0] sg09_gpll_kvco_sel, 
input  [1:0] sg09_gpll_lpf_r1_sel, 
input wire  [2:0] sg09_gpll_pi_capsel, 
input wire  [3:0] sg09_gpll_pi_icfg, 
input wire  [3:0] sg09_gpll_refck_sel, 
input   sg09_gpll_refck_shot, 
input wire  [7:0] sg09_gpll_refdiv, 
input   sg09_gpll_rstn, 
input wire   sg09_gpll_ssc_dn_loop_mode, 
input   sg09_gpll_ssc_en, 
input wire  [17:0] sg09_gpll_ssc_freq_div, 
input wire  [1:0] sg09_gpll_ssc_lpf_sel, 
input wire   sg09_gpll_ssc_mode, 
input wire   sg09_gpll_ssc_rstn, 
input wire  [23:0] sg09_gpll_ssc_step, 
input   sg09_gpll_tda_en, 
input  [1:0] sg09_gpll_vctrl_sel, 
input wire   sg09_pfd_rstn, 
input wire   sg09_pwd_rstn, 
input   sgcc_clk0_div1, 
input wire  vccaux , 
input   vccd, 
input wire  vssa  );

// Buses in the design

wire [1:0]  ibp_5u;

wire [2:0]  ibp_10u;

wire [1:0]  ibn_10u_poly;

wire [2:0]  ibn_5u;

wire [7:0] phase ;


gpll_lockdet  x_gpll_lockdet ( .bandcal1_rstn(bandcal1_rstn), 
    .mc1_pi_delay(mc1_pi_delay[1:0]), .vssd(vssa), 
    .bandcal_rstn(bandcal_rstn), .sgcc_vco_band(sgcc_vco_band[3:0]), 
    .lock(lock), .int_lock(int_lock), .scan_resetn(scan_resetn), 
    .scan_mode(scan_mode), .scan_in(scan_out), 
    .scan_enable(scan_enable), .scan_clk(scan_clk), 
    .pll_cal_rst_n(pll_cal_rst_n), .pfdfbk(pfdfbk), .vccd(vccd), 
    .pfdref(pfdref), .done_gwe(done_gwe), 
    .mc1_gpll_lockdet(mc1_gpll_lockdet[6:0]), 
    .ext_lock_en(ext_lock_en), 
    .mc1_refclk_det_div(mc1_refclk_det_div[1:0]), 
    .mc1_refclk_det_byp(mc1_refclk_det_byp), .rstlock_n(pll_cal_rst_n), 
    .mc1_cal_counter(mc1_cal_counter[2:0]), .vreg_rdy(vreg_rdy), 
    .pib_lockdet_clr_n(pib_lockdet_clr_n), 
    .sgcc_cal_done(sgcc_cal_done));

gpll_vco_mux_top x_gpll_vco_mux_top ( .vco_en(gpll_vco_en), 
    .ibn_5u(ibp_5u[1:0]), .ibn_100u_poly(ibp_100u_outputpi), 
    .ibn_100u_vco(ibp_100u_pi), 
    .mc1_outputpi_icfg(mc1_outputpi_icfg[2]), .vssa(vssa), 
    .mc1_pi_capsel(mc1_outputpi_capsel[2:0]), 
    .vreg_0p9(vreg_0p9_outputpi), .ck_out(phaseout[7:0]), 
    .phasedone(phasedone[7:0]), .phomux0(phomux), 
    .phomux(out_path_divrst_clk[7:0]), .ck0_div(ck0_div), 
    .ck0_div_by_one(sgcc_clk0_div1), 
    .ck_out_path_en(ck_out_path_en[7:0]), .direction(direction[7:0]), 
    .mc1_clk0_frac_en(mc1_clk0_frac_en), 
    .mc1_dyn_ph_shift_en(mc1_dyn_ph_shift_en), 
    .mc1_frac(mc1_frac[6:0]), .mc1_phomux_sel(mc1_phomux_sel[7:0]), 
    .mc1_pi_frac_mode(mc1_pi_frac_mode), 
    .mc1_pi_phshift_en(mc1_pi_phshift_en), 
    .mc1_pi_sel(mc1_pi_out_sel[7:0]), .phin(phase[7:0]), 
    .phsel_0(phsel_0[6:0]), .phsel_1(phsel_1[2:0]), 
    .phsel_2(phsel_2[2:0]), .phsel_3(phsel_3[2:0]), 
    .phsel_4(phsel_4[2:0]), .phsel_5(phsel_5[2:0]), 
    .phsel_6(phsel_6[2:0]), .phsel_7(phsel_7[2:0]), 
    .pllrst_n(sg09_gpll_rstn), .rotate(rotate[7:0]), 
    .scanclk(scanclk[7:0]), .vccd(vccd), .vreg_rdy(vreg_rdy));

gpll_ibias x_gpll_ibias ( .ibn_10u(ibn_10u_poly), .ibp_5u(ibp_5u), 
    .ibp_100u_outputpi(ibp_100u_outputpi), 
    .outputpi_icfg(mc1_outputpi_icfg[1:0]), 
    .pi_icfg(sg09_gpll_pi_icfg), .ibn_30u_pi(ibp_30u_pi), 
    .bias_icfg(sg09_gpll_bias_icfg), .ibn_40u(ibn_40u_poly), 
    .ibn_5u(ibn_5u), .ibp_10u(ibp_10u), .bias_en(sg09_gpll_en), 
    .ibp_10u_poly(ibp_10u_poly), .sg18_poc(sg18_poc), .vccaux(vccaux), 
    .vccd(vccd), .vssa(vssa));

regulator_top x_regulator_top ( .vreg_v0p9_d2c(vreg_0p9_d2c), 
    .vreg_v0p9_pi(vreg_0p9_outputpi), .vreg_v0p9_pfd(vreg_0p9_pfd), 
    .ibp_10u(ibn_10u_poly[1]), .vccaux(vccaux), .vccd(vccd), 
    .vssa(vssa), .sg09_vreg_done(vreg_rdy), .vco_vreg_0p9(vreg_0p9), 
    .vco_vreg_1p2(vreg_1p2), .sg09_pfd_rst_n(sg09_pfd_rstn), 
    .vg_vco(vg_vco), .ibn_10u_vref(ibn_10u_vref), .sg18_poc(sg18_poc), 
    .sg09_gpll_vreg_en(sg09_gpll_en), .ibp_5u_poly(ibn_5u));

bg_sgaux_init x_bg_sgaux_init ( .vcc0p9(vccd), .vccaux(vccaux), 
    .vssa(vssa), .vsgaux_init(sg18_poc), .sg09_por_n(tieh_09));

al6100gpll_PULL1_140P12T40L  x_PULL1_140P12T40L_63 ( .Z(tieh_09), .VNW(vccd), 
    .VDD(vccd), .VSS(vssa), .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_26 ( .VDD(vccd), 
    .I(pfdref_int), .ZN(net0115), .VSS(vssa), .VNW(vccd), .VPW(vssa));

al6100gpll_CLKINV4_140P12T40L  x_CLKINV4_140P12T40L_32 ( .VDD(vccd), 
    .I(pfdfbk_int), .ZN(net0120), .VSS(vssa), .VNW(vccd), .VPW(vssa));

al6100gpll_CLKINV8_140P12T40L  x_CLKINV8_140P12T40L_25 ( .VDD(vccd), .I(net0115), 
    .ZN(pfdref), .VSS(vssa), .VNW(vccd), .VPW(vssa));

al6100gpll_CLKINV8_140P12T40L  x_CLKINV8_140P12T40L_33 ( .VDD(vccd), .I(net0120), 
    .ZN(pfdfbk), .VSS(vssa), .VNW(vccd), .VPW(vssa));

gpll_ana x_gpll_ana ( 
    .sg09_gpll_fbfracn_sel(sg09_gpll_fbfracn_sel[27:0]), 
    .scan_resetn(scan_resetn), .scan_out(scan_out), 
    .scan_clk(scan_clk), .scan_enable(scan_enable), .scan_in(scan_in), 
    .scan_mode(scan_mode), .vreg_0p9_pfd(vreg_0p9_pfd), 
    .vreg_0p9_d2c(vreg_0p9_d2c), 
    .sg09_gpll_fastloop_cfg(sg09_gpll_fastloop_cfg), 
    .gpll_vco_en(gpll_vco_en), .sg09_gpll_ssc_rstn(sg09_gpll_ssc_rstn), 
    .fast_lock(fast_lock), 
    .sg09_gpll_fastlock_sel(sg09_gpll_fastlock_sel[2:0]), 
    .sg09_gpll_lpf_r1_sel(sg09_gpll_lpf_r1_sel[1:0]), 
    .ibp_100u_pi(ibp_100u_pi), .ibp_30u_pi(ibp_30u_pi), 
    .sg09_gpll_pi_code(sg09_gpll_pi_code[5:0]), 
    .sg09_gpll_fbkck(sg09_gpll_fbkck), 
    .sg09_gpll_refck_test(sg09_gpll_refck_test), 
    .gpll_refck(gpll_refck[15:0]), .done_gwe(done_gwe), 
    .gpll_fbkck(gpll_fbkck[14:0]), 
    .sg09_gpll_fbkck_sel(sg09_gpll_fbkck_sel[3:0]), 
    .sg09_gpll_fbkck_shot(sg09_gpll_fbkck_shot), 
    .sg09_gpll_refck(sg09_gpll_refck), 
    .sg09_gpll_refck_dig(pfdref_int), .sg09_gpll_fbkck_dig(pfdfbk_int), 
    .sg09_gpll_fbkck_test(sg09_gpll_fbkck_test), 
    .sg09_gpll_refck_shot(sg09_gpll_refck_shot), 
    .sg09_gpll_pi_capsel(sg09_gpll_pi_capsel[2:0]), 
    .sg09_pwd_rstn(sg09_pwd_rstn), .sg09_gpll_en(sg09_gpll_en), 
    .sg09_gpll_refdiv(sg09_gpll_refdiv[7:0]), 
    .sg09_gpll_refck_sel(sg09_gpll_refck_sel[3:0]), 
    .sg09_gpll_fbdiv(sg09_gpll_fbdiv[7:0]), 
    .sg09_gpll_ssc_step(sg09_gpll_ssc_step[23:0]), .vreg_rdy(vreg_rdy), 
    .ibp_40u_poly(ibn_40u_poly), .ibp_10u_poly(ibn_10u_poly[0]), 
    .ibn_10u_poly(ibp_10u[2:0]), .gpll_clk_000(phase[0]), 
    .gpll_clk_045(phase[1]), .gpll_clk_090(phase[2]), 
    .gpll_clk_135(phase[3]), .gpll_clk_180(phase[4]), 
    .gpll_clk_225(phase[5]), .gpll_clk_270(phase[6]), 
    .gpll_clk_315(phase[7]), .sg09_gpll_ck_divn(sg09_gpll_ck_divn), 
    .sg09_gpll_fbdiv_code(sg09_gpll_fbdiv_code[7:0]), 
    .sg09_gpll_fracn_c_sum(sg09_gpll_fracn_c_sum[2:0]), 
    .sg09_gpll_prbs_out(sg09_gpll_prbs_out), 
    .sg09_gpll_ssc_mod_clk(sg09_gpll_ssc_mod_clk), 
    .sg09_gpll_ssc_signbit(sg09_gpll_ssc_signbit), 
    .vcca_vreg_cp(vcca_vreg_cp), .vctrl_idle(vctrl_idle), 
    .vdd_ico(vdd_ico), .vreg_1p2(vreg_1p2), 
    .ibn_10u_ptat(ibn_10u_ptat), 
    .sg09_gpll_cp_dlysel(sg09_gpll_cp_dlysel[2:0]), 
    .sg09_gpll_cp_refsel(sg09_gpll_cp_refsel[2:0]), 
    .sg09_gpll_fbdiv_rstn(sg09_gpll_fbdiv_rstn), 
    .sg09_gpll_fracn_dither_en(sg09_gpll_fracn_dither_en), 
    .sg09_gpll_fracn_dither_sel(sg09_gpll_fracn_dither_sel[3:0]), 
    .sg09_gpll_fracn_en(sg09_gpll_fracn_en), 
    .sg09_gpll_fracn_prbs_sel(sg09_gpll_fracn_prbs_sel[1:0]), 
    .sg09_gpll_freq_lock(int_lock), 
    .sg09_gpll_icp_banch(sg09_gpll_icp_banch[4:0]), 
    .sg09_gpll_icp_bias(sg09_gpll_icp_bias[4:0]), 
    .sg09_gpll_kvco_sel(sg09_gpll_kvco_sel[3:0]), 
    .sg09_gpll_rstn(sg09_pfd_rstn), 
    .sg09_gpll_ssc_dn_loop_mode(sg09_gpll_ssc_dn_loop_mode), 
    .sg09_gpll_ssc_en(sg09_gpll_ssc_en), 
    .sg09_gpll_ssc_freq_div(sg09_gpll_ssc_freq_div[17:0]), 
    .sg09_gpll_ssc_lpf_sel(sg09_gpll_ssc_lpf_sel[1:0]), 
    .sg09_gpll_ssc_mode(sg09_gpll_ssc_mode), 
    .sg09_gpll_tda_en(sg09_gpll_tda_en), 
    .sg09_gpll_vctrl_sel(sg09_gpll_vctrl_sel[1:0]), 
    .sg18_poc(sg18_poc), .vccaux(vccaux), .vccd(vccd), .vssa(vssa));

endmodule


//systemVerilog HDL for "al6100_serdes_pll", "cpll_div_n_buf" "systemVerilog"

`timescale 1ns/1fs
module cpll_div_n_buf ( ck_out, ck_out_n, ck_out_p, ck_sync_n, ck_sync_p, bypass, ck_in_n, ck_in_p, en, mod0, modx, vcca, vssa );
input vssa;
input vcca;

input en;
input mod0;
input modx;
input bypass;

input ck_in_p;
input ck_in_n;

output ck_out;
output ck_out_p;
output ck_out_n;

output ck_sync_p;
output ck_sync_n;

//circuits begin
wire ck_bypass,ckb_bypass;
wire ck_latch_n,ck_latch_p;

wire bpb_in,bp_in;
wire enb_in,en_in;
wire byp_enb,byp_en;
wire div_enb,div_en;

assign bpb_in = !bypass;
assign bp_in  = !bpb_in;

assign enb_in = !en;
assign en_in  = !enb_in;

assign byp_enb = !(en_in & bp_in);
assign byp_en  = !byp_enb;

assign div_enb = !(en_in & bpb_in);
assign div_en  = !div_enb;

assign #0.01 ck_bypass  = en_in ? ck_in_p : 1'b1;
assign #0.01 ckb_bypass = en_in ? ck_in_n : 1'b0;

assign #0.01 ck_latch_p = div_en ? ck_in_p : 1'b1;
assign #0.01 ck_latch_n = div_en ? ck_in_n : 1'b0;

assign #0.01 ck_out_p  = ck_latch_p;
assign #0.01 ck_out_n  = ck_latch_n;

assign #0.02 ck_sync_p  = ck_latch_p;
assign #0.02 ck_sync_n  = ck_latch_n;


//clock_out
wire [11:0] mod0_d;
assign #0.005 mod0_d[0] = !mod0;
assign #0.005 mod0_d[1] = !mod0_d[0];
assign #0.005 mod0_d[2] = !mod0_d[1];
assign #0.005 mod0_d[3] = !mod0_d[2];
assign #0.005 mod0_d[4] = !mod0_d[3];
assign #0.005 mod0_d[5] = !mod0_d[4];
assign #0.005 mod0_d[6] = !mod0_d[5];
assign #0.005 mod0_d[7] = !mod0_d[6];
assign #0.005 mod0_d[8] = !mod0_d[7];
assign #0.005 mod0_d[9] = !mod0_d[8];
assign #0.005 mod0_d[10] = !mod0_d[9];
assign #0.005 mod0_d[11] = !mod0_d[10];

wire [8:0] cut,cutb;
assign #0.005 cut[8]  = !(mod0_d[11] | !modx);
assign #0.005 cutb[7] = !(mod0_d[3]  | cut[8]);
assign #0.005 cut[6]  = !(mod0_d[5]  | cutb[7]);
assign #0.005 cutb[5] = !(mod0       | cut[6]);

reg ck_out;
always @ ( * ) begin
	if (byp_en & en_in) begin 
		ck_out <= ck_bypass;
	end
	else if(div_en & en_in) begin 
		ck_out <= cutb[5];
	end
	else begin 
		ck_out <= 1'b0;
	end
end

endmodule


// Library - al6100_analog, Cell - cpll_div_n_top, View - schematic
// LAST TIME SAVED: May 22 15:13:26 2023


module cpll_div_n_top ( 
output wire   ck_out, 
output wire   ck_sync_n, 
output wire   ck_sync_p, 
input wire   ck_in_n, 
input wire   ck_in_p, 
input wire  [7:0] divn, 
input wire   en, 
input   vcca, 
input   vssa );

// Buses in the design

wire [6:0]  p_in;

wire [6:0]  en_in;

wire [0:6]  syn_p;

wire [0:6]  syn_en;

wire [0:7]  clkn;

wire [0:7]  clkp;

wire [0:7]  mod;


cpll_div_n_sync x_cpll_div_n_sync_0 ( .bpo(by1), .bpi(bp0), .eno(eno), 
    .ck_mbo(ck_mbo), .en_in(en_in), .p_out({syn_p[6], syn_p[5], 
    syn_p[4], syn_p[3], syn_p[2], syn_p[1], syn_p[0]}), 
    .en_out({syn_en[6], syn_en[5], syn_en[4], syn_en[3], syn_en[2], 
    syn_en[1], syn_en[0]}), .pout(sd4), .ck_in_n({clkn[6], clkn[5], 
    clkn[4], clkn[3], clkn[2], clkn[1], clkn[0]}), .pin(pxb), 
    .p_in(p_in), .ck_in_p({clkp[6], clkp[5], clkp[4], clkp[3], clkp[2], 
    clkp[1], clkp[0]}), .mod({mod[6], mod[5], mod[4], mod[3], mod[2], 
    mod[1], mod[0]}), .vcca(vcca), .vssa(vssa), .en(pu));

cpll_div_23_lvt x_cpll_div23_lvt_6 ( .en(syn_en[6]), 
    .ck_out_p(clkp[7]), .vcca(vcca), .div3(syn_p[6]), 
    .ck_in_n(clkn[6]), .vssa(vssa), .ck_out_n(clkn[7]), 
    .ck_in_p(clkp[6]), .modeout(mod[6]), .modin(mod[7]));

cpll_div_23_lvt x_cpll_div23_lvt_3 ( .en(syn_en[3]), 
    .ck_out_p(clkp[4]), .vcca(vcca), .div3(syn_p[3]), 
    .ck_in_n(clkn[3]), .vssa(vssa), .ck_out_n(clkn[4]), 
    .ck_in_p(clkp[3]), .modeout(mod[3]), .modin(mod[4]));

cpll_div_23_lvt x_cpll_div23_lvt_5 ( .en(syn_en[5]), 
    .ck_out_p(clkp[6]), .vcca(vcca), .div3(syn_p[5]), 
    .ck_in_n(clkn[5]), .vssa(vssa), .ck_out_n(clkn[6]), 
    .ck_in_p(clkp[5]), .modeout(mod[5]), .modin(mod[6]));

cpll_div_23_lvt x_cpll_div23_lvt_2 ( .en(syn_en[2]), 
    .ck_out_p(clkp[3]), .vcca(vcca), .div3(syn_p[2]), 
    .ck_in_n(clkn[2]), .vssa(vssa), .ck_out_n(clkn[3]), 
    .ck_in_p(clkp[2]), .modeout(mod[2]), .modin(mod[3]));

cpll_div_23_lvt x_cpll_div23_lvt_4 ( .en(syn_en[4]), 
    .ck_out_p(clkp[5]), .vcca(vcca), .div3(syn_p[4]), 
    .ck_in_n(clkn[4]), .vssa(vssa), .ck_out_n(clkn[5]), 
    .ck_in_p(clkp[4]), .modeout(mod[4]), .modin(mod[5]));

cpll_div_23_lvt x_cpll_div23_lvt_1 ( .en(syn_en[1]), 
    .ck_out_p(clkp[2]), .vcca(vcca), .div3(syn_p[1]), 
    .ck_in_n(clkn[1]), .vssa(vssa), .ck_out_n(clkn[2]), 
    .ck_in_p(clkp[1]), .modeout(mod[1]), .modin(mod[2]));

cpll_div_234_lvt x_cpll_div234_lvt_0 ( .en(syn_en[0]), 
    .ck_out_p(clkp[1]), .vcca(vcca), .div3(syn_p[0]), 
    .ck_in_n(clkn[0]), .div4(sd4), .vssa(vssa), .ck_out_n(clkn[1]), 
    .ck_in_p(clkp[0]), .modeout(mod[0]), .modin(mod[1]));

cpll_div_n_buf x_cpll_div_n_buf_0 ( .ck_sync_n(ck_sync_n), 
    .ck_sync_p(ck_sync_p), .ck_out(ck_out), .en(eno), .bypass(by1), 
    .modx(ck_mbo), .ck_in_n(ck_in_n), .ck_out_p(clkp[0]), 
    .ck_out_n(clkn[0]), .ck_in_p(ck_in_p), .vssa(vssa), .vcca(vcca), 
    .mod0(mod[0]));

cpll_div_n_logic x_cpll_div_n_logic_0 ( .pu(pu), .en_in(en), 
    .bypass(bp0), .en_out(en_in), .p_out(p_in), .pxb(pxb), .vcca(vcca), 
    .vssa(vssa), .d(divn));

com_hss_tieh x_com_hss_tieh_49 ( .tieh(mod[7]), .vdda(vcca), 
    .vssa(vssa));

endmodule





//systemVerilog HDL for "al6100_pll", "regulator_top" "systemVerilog"gg
//-------------------------------------------------------------------
`timescale 1ns / 1fs
//-------------------------------------------------------------------
//---------------------------begin-----------------------------------
//-------------------------------------------------------------------
module regulator_top ( sg09_vreg_done, vco_vreg_0p9, vco_vreg_1p2, vreg_v0p9_d2c,vreg_v0p9_pfd,vreg_v0p9_pi,vg_vco, ibn_10u_vref, ibp_10u,
ibp_5u_poly, sg09_gpll_vreg_en, sg09_pfd_rst_n, sg18_poc, vccaux, vccd, vssa
);
//-------------------------------------------------------------------
//---------------------------pin define------------------------------
//-------------------------------------------------------------------
//---------------------------input------------------------------------
input 		vccd;
input 		vccaux;
input 		vssa;
input 		sg18_poc;
input 		sg09_gpll_vreg_en;
input 		sg09_pfd_rst_n;
input  [2:0]	ibp_5u_poly;
input 		ibn_10u_vref;
input 		ibp_10u;
output 		vco_vreg_1p2;
output 		vco_vreg_0p9;
output 		vreg_v0p9_d2c;
output 		vreg_v0p9_pfd;
output 		vreg_v0p9_pi;
output 		sg09_vreg_done;
output 		vg_vco;
//-------------------------------------------------------------------
//---------------------------code------------------------------------
//-------------------------------------------------------------------
`ifdef PH1P_PLL_V2_FAST_SIM
    assign #1      vco_vreg_1p2     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0; 
    assign #1      vco_vreg_0p9     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;                              
    assign #1      vreg_v0p9_d2c     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;                              
    assign #1      vreg_v0p9_pfd     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;                              
    assign #1      vreg_v0p9_pi     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;                              
    assign #1      sg09_vreg_done   = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0; 
    assign #1      vg_vco           = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;                              
`elsif SUPER_FAST_SIM
    assign #1      vco_vreg_1p2     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;                              
    assign #1      vco_vreg_0p9     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0; 
    assign #1      vreg_v0p9_d2c     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0; 
    assign #1      vreg_v0p9_pfd     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0; 
    assign #1      vreg_v0p9_pi     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0; 
    assign #1      sg09_vreg_done   = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;                              
    assign #1      vg_vco           = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;                              
`else
    assign #15_000 vco_vreg_1p2     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;
    assign #15_000 vco_vreg_0p9     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;
    assign #15_000 vreg_v0p9_d2c     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;
    assign #15_000 vreg_v0p9_pfd     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;
    assign #15_000 vreg_v0p9_pi     = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;
    assign #15_000 sg09_vreg_done   = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;
    assign #15_000 vg_vco           = (vccaux && vccd && sg09_gpll_vreg_en && /*sg09_pfd_rst_n &&*/ ~sg18_poc && ibn_10u_vref && ibp_10u)? 1'b1 : 1'b0;
`endif
endmodule

//-------------------------------------------------------------------
//---------------------------end-------------------------------------
//-------------------------------------------------------------------

//systemVerilog HDL for "al6100_serdes_pll", "cpll_div_234_lvt" "systemVerilog"

`timescale 1ns/1fs
module cpll_div_234_lvt ( ck_out_n, ck_out_p, modeout, ck_in_n, ck_in_p, div3, div4, en, modin, vcca, vssa );
input vcca;
input vssa;

input ck_in_p;
input ck_in_n;

input en;
input div3;
input div4;
input modin;

output modeout;
output ck_out_p;
output ck_out_n;

// circuit begin
reg q0,q1,q2,q3;
reg qb3;
reg d0,d2,d3;
reg qb1,qbb1,qb2,d1;

wire ck_in_d_p,ck_in_d_n;

initial begin
	q0 = 1'b0;
	q1 = 1'b0;
	q2 = 1'b0;
	q3 = 1'b0;
	qb3 =1'b0;
	d0 =1'b0;
	d2 =1'b0;
	d3 =1'b0;
	qb1 =1'b0;
	qbb1 =1'b0;
	qb2 =1'b0;
	d1 =1'b0;
end

//each time power down, initial these internal signals to avoid X
always @(vcca) #0.1 begin
	if(~vcca) begin
	q0 = 1'b0;
	q1 = 1'b0;
	q2 = 1'b0;
	q3 = 1'b0;
	qb3 = 1'b0;
	d0 =1'b0;
	d2 =1'b0;
	d3 =1'b0;
	qb1 =1'b0;
	qbb1 =1'b0;
	qb2 =1'b0;
	d1 =1'b0;
	end
end

//latch input logic
always @ ( * )   begin
		d0		<= !( !(q1 & div4) & q3 );
	 	qbb1    <= !qb1;
		d2 		<= !(modin & qbb1);
	 	d3 		<= !(div3 & qb2);
end

//latch feed back
always @ ( * )   begin
	 	d1 		<= !q0;
	 	qb1 	<= !(q1 & en);
	 	qb2 	<= !(en & q2);
		qb3     <= !q3;

end

//input output pin;
assign #0.005 ck_out_p 	 =  qb1;
assign #0.005 ck_out_n   = !qb1;
assign #0.005 modeout 	 =  qb2;
//
assign #0.015 ck_in_d_p = ck_in_p;
assign #0.015 ck_in_d_n = ck_in_n;

always @ ( posedge ck_in_d_p or negedge ck_in_d_p ) #0.01 begin
	if ( ck_in_p ) begin// phase 0 functional
 		q0 <=  ((d0===1'b1)|(d0===1'b0))	?(d0)	:{$random}%2;
 		q1 <=  ((qb1===1'b1)|(qb1===1'b0))	?(!qb1)	:{$random}%2;
 		q2 <=  ((d2===1'b1)|(d2===1'b0))	?(d2)	:{$random}%2;
		q3 <=  ((qb3===1'b1)|(qb3===1'b0))	?(!qb3)	:{$random}%2;
	end
	else begin			// phase 1 functional
 		q0 <=  ((d1===1'b1)|(d1===1'b0))	?(!d1)	:{$random}%2;
 		q1 <=  ((d1===1'b1)|(d1===1'b0))	? (d1)	:{$random}%2;
		q2 <=  ((qb2===1'b1)|(qb2===1'b0))	?(!qb2)	:{$random}%2;
    	q3 <=  ((d3===1'b1)|(d3===1'b0))	? (d3)	:{$random}%2;	
	end
end

endmodule


//Verilog HDL for "al6100_analog_com", "com_hss_tieh" "functional"

`timescale 1ns / 1fs
`celldefine
module com_hss_tieh ( tieh, vdda, vssa );

  output tieh;
  input vdda;
  input vssa;

assign tieh=vdda;
endmodule
`endcelldefine


//Verilog HDL for "al6100_analog_com", "com_hss_tiel" "functional"

`timescale 1ns / 1fs
`celldefine
module com_hss_tiel ( tiel, vdda, vssa );

  output tiel;
  input vdda;
  input vssa;

  assign tiel = vssa;
endmodule
`endcelldefine


// Library - al6100_analog_com, Cell - com_hss_buf4x, View - schematic
// LAST TIME SAVED: Jul 15 09:08:03 2022


`celldefine
module al6100gpll_com_hss_buf4x ( 
output wire  dout , 
input wire  din , 
input wire  vcca_v0p9 , 
input wire  vssa  );


al6100gpll_com_hss_inv4x x_com_hss_inv4x_0 ( .vssa(vssa), .dat_out(dout), 
    .vdda(vcca_v0p9), .dat_in(net5));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_0 ( .vssa(vssa), .dat_out(net5), 
    .vdda(vcca_v0p9), .dat_in(din));

endmodule
`endcelldefine


// Library - al6100_analog, Cell - gpll_ana, View - schematic
// LAST TIME SAVED: Sep 11 11:36:04 2023


module gpll_ana ( 
output   fast_lock, 
output wire  gpll_clk_000 , 
output wire  gpll_clk_045 , 
output wire  gpll_clk_090 , 
output wire  gpll_clk_135 , 
output wire  gpll_clk_180 , 
output wire  gpll_clk_225 , 
output wire  gpll_clk_270 , 
output wire  gpll_clk_315 , 
output wire  gpll_vco_en , 
output   ibp_30u_pi, 
output   ibp_100u_pi, 
output wire   scan_out, 
output wire  sg09_gpll_ck_divn , 
output wire [7:0] sg09_gpll_fbdiv_code, 
output wire  sg09_gpll_fbkck , 
output wire  sg09_gpll_fbkck_dig , 
output wire  sg09_gpll_fbkck_test , 
output wire  [2:0] sg09_gpll_fracn_c_sum, 
output wire [5:0] sg09_gpll_pi_code, 
output wire   sg09_gpll_prbs_out, 
output wire  sg09_gpll_refck , 
output wire  sg09_gpll_refck_dig , 
output wire  sg09_gpll_refck_test , 
output wire   sg09_gpll_ssc_mod_clk, 
output wire   sg09_gpll_ssc_signbit, 
output   vcca_vreg_cp, 
output   vctrl_idle, 
output   vdd_ico, 
input   done_gwe, 
input wire  [14:0] gpll_fbkck, 
input wire  [15:0] gpll_refck, 
input  [2:0] ibn_10u_poly, 
input   ibn_10u_ptat, 
input   ibp_10u_poly, 
input wire   ibp_40u_poly, 
input wire   scan_clk, 
input wire   scan_enable, 
input wire   scan_in, 
input wire   scan_mode, 
input wire   scan_resetn, 
input  [2:0] sg09_gpll_cp_dlysel, 
input  [2:0] sg09_gpll_cp_refsel, 
input wire  sg09_gpll_en , 
input  [2:0] sg09_gpll_fastlock_sel, 
input   sg09_gpll_fastloop_cfg, 
input wire  [7:0] sg09_gpll_fbdiv, 
input   sg09_gpll_fbdiv_rstn, 
input  [27:0] sg09_gpll_fbfracn_sel, 
input wire  [3:0] sg09_gpll_fbkck_sel, 
input   sg09_gpll_fbkck_shot, 
input wire   sg09_gpll_fracn_dither_en, 
input wire  [3:0] sg09_gpll_fracn_dither_sel, 
input   sg09_gpll_fracn_en, 
input wire  [1:0] sg09_gpll_fracn_prbs_sel, 
input   sg09_gpll_freq_lock, 
input  [4:0] sg09_gpll_icp_banch, 
input  [4:0] sg09_gpll_icp_bias, 
input  [3:0] sg09_gpll_kvco_sel, 
input  [1:0] sg09_gpll_lpf_r1_sel, 
input wire  [2:0] sg09_gpll_pi_capsel, 
input wire  [3:0] sg09_gpll_refck_sel, 
input   sg09_gpll_refck_shot, 
input wire  [7:0] sg09_gpll_refdiv, 
input   sg09_gpll_rstn, 
input wire   sg09_gpll_ssc_dn_loop_mode, 
input   sg09_gpll_ssc_en, 
input wire  [17:0] sg09_gpll_ssc_freq_div, 
input wire  [1:0] sg09_gpll_ssc_lpf_sel, 
input wire   sg09_gpll_ssc_mode, 
input wire   sg09_gpll_ssc_rstn, 
input wire  [23:0] sg09_gpll_ssc_step, 
input   sg09_gpll_tda_en, 
input  [1:0] sg09_gpll_vctrl_sel, 
input wire   sg09_pwd_rstn, 
input   sg18_poc, 
input   vccaux, 
input wire  vccd , 
input wire  vreg_0p9_d2c , 
input wire  vreg_0p9_pfd , 
input   vreg_1p2, 
input wire  vreg_rdy , 
input wire  vssa  );

// Buses in the design

wire [23:0]  fb_fracn_probe;

wire [0:7]  ck_vco;

wire [29:0]  sg09_gpll_ssc_cnt;

wire [7:0]  fb_divn_probe;


gpll_prediv x_gpll_prediv ( .ckin(gpll_refck[15:0]), 
    .ckin_sel(sg09_gpll_refck_sel[3:0]), 
    .ckin_shot(sg09_gpll_refck_shot), .done_gwe(done_gwe), 
    .ck_outp(ref_clkp), .ck_outn(ref_clkn), .div_en(sg09_pwd_rstn), 
    .divn(sg09_gpll_refdiv[7:0]), .vcca(vreg_0p9_pfd), .vssa(vssa));

com_hss_tieh x_com_hss_tieh_17 ( .tieh(tieh), .vdda(vccd), 
    .vssa(vssa));

gpll_vco_buf x_gpll_vco_buf ( .ck000_fbdiv(ck_vco[0]), 
    .ck045_fbdiv(ck_vco[1]), .ck090_fbdiv(ck_vco[2]), 
    .ck135_fbdiv(ck_vco[3]), .ck180_fbdiv(ck_vco[4]), 
    .ck225_fbdiv(ck_vco[5]), .ck315_fbdiv(ck_vco[7]), 
    .buf_000(gpll_clk_000), .buf_045(gpll_clk_045), 
    .buf_090(gpll_clk_090), .buf_135(gpll_clk_135), 
    .buf_180(gpll_clk_180), .buf_225(gpll_clk_225), 
    .vccd(vreg_0p9_d2c), .buf_270(gpll_clk_270), .ckin_225(cko_225), 
    .ckin_315(cko_315), .ckin_180(cko_180), .ckin_135(cko_135), 
    .ck270_fbdiv(ck_vco[6]), .ckin_090(cko_090), .ckin_000(cko_000), 
    .ckin_270(cko_270), .ckin_045(cko_045), .buf_315(gpll_clk_315), 
    .vssd(vssa));

gpll_fbdiv_top_v1 x_gpll_fbdiv_top ( 
    .fb_fracn(sg09_gpll_fbfracn_sel[27:0]), .scan_out(scan_out), 
    .scan_clk(scan_clk), .scan_enable(scan_enable), .scan_in(scan_in), 
    .scan_mode(scan_mode), .scan_resetn(scan_resetn), 
    .ssc_rstn(sg09_gpll_ssc_rstn), 
    .pi_ctrl_sync(sg09_gpll_pi_code[5:0]), 
    .fb_divn_probe(fb_divn_probe[7:0]), 
    .fb_fracn_probe(fb_fracn_probe[23:0]), 
    .ssc_cnt(sg09_gpll_ssc_cnt[29:0]), 
    .ck_in_shot(sg09_gpll_fbkck_shot), .done_gwe(done_gwe), 
    .ck_in_sel(sg09_gpll_fbkck_sel[3:0]), 
    .ssc_step(sg09_gpll_ssc_step[23:0]), .ck_in({gpll_fbkck[14:0], 
    ck_vco[0]}), .pi_capsel(sg09_gpll_pi_capsel[2:0]), 
    .i40u_src(ibp_40u_poly), .divn_en(tieh), 
    .fb_divn(sg09_gpll_fbdiv[7:0]), 
    .ssc_lpf_sel(sg09_gpll_ssc_lpf_sel[1:0]), 
    .prbs_out(sg09_gpll_prbs_out), .ssc_mod_clk(sg09_gpll_ssc_mod_clk), 
    .ssc_signbit(sg09_gpll_ssc_signbit), 
    .ssc_freq_div(sg09_gpll_ssc_freq_div[17:0]), 
    .ck_divn(sg09_gpll_ck_divn), .ssc_mode(sg09_gpll_ssc_mode), 
    .fracn_c_sum(sg09_gpll_fracn_c_sum[2:0]), .ck_out_n(fbk_clkn), 
    .ck_out_p(fbk_clkp), .fb_divn_sync(sg09_gpll_fbdiv_code[7:0]), 
    .fracn_dither_en(sg09_gpll_fracn_dither_en), 
    .fracn_dither_sel(sg09_gpll_fracn_dither_sel[3:0]), 
    .fracn_en(sg09_gpll_fracn_en), 
    .fracn_prbs_sel(sg09_gpll_fracn_prbs_sel[1:0]), 
    .rstn(sg09_gpll_fbdiv_rstn), 
    .ssc_dn_loop_mode(sg09_gpll_ssc_dn_loop_mode), 
    .ssc_en(sg09_gpll_ssc_en), .vcca(vreg_0p9_pfd), .vccd(vccd), 
    .vssa(vssa), .vssd(vssa));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_2 ( .vssa(vssa), .dat_out(gpll_vco_en), 
    .vdda(vccd), .dat_in(net084));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_4 ( .vssa(vssa), .dat_out(pll_en), 
    .vdda(vccd), .dat_in(pll_enb));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_3 ( .vssa(vssa), .dat_out(pll_enb), 
    .vdda(vccd), .dat_in(sg09_gpll_en));

al6100gpll_com_hss_inv2x x_com_hss_inv2x_1 ( .vssa(vssa), .dat_out(net084), 
    .vdda(vccd), .dat_in(net094));

al6100gpll_com_hss_and2_2x x_com_hss_and2_2x_26 ( .vcca(vccd), .do_n(net094), 
    .d2(vreg_rdy), .d1(pll_en), .vssa(vssa));

gpll_ana_buf_unit_x3 x_gpll_ana_buf_unit_x3_2 ( 
    .outp2(sg09_gpll_refck_dig), .inp(ref_clkp), .inn(ref_clkn), 
    .outp0(sg09_gpll_refck_test), .outp1(sg09_gpll_refck), .vcca(vccd), 
    .vssa(vssa));

gpll_ana_buf_unit_x3 x_gpll_ana_buf_unit_x3_1 ( 
    .outp2(sg09_gpll_fbkck_dig), .inp(fbk_clkp), .inn(fbk_clkn), 
    .outp0(sg09_gpll_fbkck_test), .outp1(sg09_gpll_fbkck), .vcca(vccd), 
    .vssa(vssa));

gpll_ana_core  x_gpll_ana_core ( .vreg_0p9_d2c(vreg_0p9_d2c), 
    .vreg_0p9_pfd(vreg_0p9_pfd), .fastloop_cfg(sg09_gpll_fastloop_cfg), 
    .sg09_gpll_fastlock_sel(sg09_gpll_fastlock_sel[2:0]), 
    .fast_lock(fast_lock), 
    .sg09_gpll_lpf_r1_sel(sg09_gpll_lpf_r1_sel[1:0]), 
    .ibp_100u_pi(ibp_100u_pi), .ibp_30u_pi(ibp_30u_pi), 
    .vdd_ico(vdd_ico), .sg09_gpll_vco_en(gpll_vco_en), 
    .cko_000(cko_000), .cko_045(cko_045), .cko_090(cko_090), 
    .cko_135(cko_135), .cko_180(cko_180), .cko_225(cko_225), 
    .cko_270(cko_270), .cko_315(cko_315), .vcca_vreg_cp(vcca_vreg_cp), 
    .vctrl_idle(vctrl_idle), .freq_lock(sg09_gpll_freq_lock), 
    .ibn_10u_poly(ibn_10u_poly[2:0]), .ibn_10u_ptat(ibn_10u_ptat), 
    .ibp_10u_poly(ibp_10u_poly), 
    .sg09_gpll_cp_dlysel(sg09_gpll_cp_dlysel[2:0]), 
    .sg09_gpll_cp_refsel(sg09_gpll_cp_refsel[2:0]), 
    .sg09_gpll_fbk_clkn(fbk_clkn), .sg09_gpll_fbk_clkp(fbk_clkp), 
    .sg09_gpll_icp_banch(sg09_gpll_icp_banch[4:0]), 
    .sg09_gpll_icp_bias(sg09_gpll_icp_bias[4:0]), 
    .sg09_gpll_initial_vctrl(sg09_gpll_vctrl_sel[1:0]), 
    .sg09_gpll_pfd_cp_en(pll_en), .sg09_gpll_ref_clkn(ref_clkn), 
    .sg09_gpll_ref_clkp(ref_clkp), .sg09_gpll_rstn(sg09_gpll_rstn), 
    .sg09_gpll_tda_en(sg09_gpll_tda_en), .sg18_poc(sg18_poc), 
    .vccaux(vccaux), .vccd(vccd), .vco_band(sg09_gpll_kvco_sel[3:0]), 
    .vreg_1p2(vreg_1p2), .vssa(vssa));

endmodule





// Library - al6100_analog_com, Cell - com_hss_bufx4, View - schematic
// LAST TIME SAVED: Apr 19 20:09:03 2022


`celldefine
module al6100gpll_com_hss_bufx4 ( 
output wire  out , 
input wire  in , 
input wire  vccd , 
input wire  vssd  );


al6100gpll_com_hss_inv2x x_com_hss_inv2x_105 ( .vssa(vssd), .dat_out(net7), 
    .vdda(vccd), .dat_in(in));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_0 ( .vssa(vssd), .dat_out(out), 
    .vdda(vccd), .dat_in(net7));

endmodule
`endcelldefine


// Library - al6100_analog, Cell - gpll_vco_buf_unit, View - schematic
// LAST TIME SAVED: Oct 12 21:22:20 2022


module gpll_vco_buf_unit ( 
output wire  ckn_fbdiv , 
output wire  ckp_fbdiv , 
output wire  outn , 
output wire  outp , 
input wire  ckinn , 
input wire  ckinp , 
input wire  vccd , 
input wire  vssd  );


al6100gpll_com_hss_inv8x x_com_hss_inv8x_11_1 ( .vssa(vssd), .dat_out(outn), 
    .vdda(vccd), .dat_in(net017));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_11_0 ( .vssa(vssd), .dat_out(outn), 
    .vdda(vccd), .dat_in(net017));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_9 ( .vssa(vssd), .dat_out(net018), 
    .vdda(vccd), .dat_in(net72));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_10 ( .vssa(vssd), .dat_out(net017), 
    .vdda(vccd), .dat_in(net71));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_12_1 ( .vssa(vssd), .dat_out(outp), 
    .vdda(vccd), .dat_in(net018));

al6100gpll_com_hss_inv8x x_com_hss_inv8x_12_0 ( .vssa(vssd), .dat_out(outp), 
    .vdda(vccd), .dat_in(net018));





al6100gpll_com_hss_inv4x x_com_hss_inv4x_3 ( .vssa(vssd), .dat_out(net70), 
    .vdda(vccd), .dat_in(ckinp));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_8 ( .vssa(vssd), .dat_out(ckn_fbdiv), 
    .vdda(vccd), .dat_in(net69));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_4 ( .vssa(vssd), .dat_out(net69), 
    .vdda(vccd), .dat_in(ckinn));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_15 ( .vssa(vssd), .dat_out(ckp_fbdiv), 
    .vdda(vccd), .dat_in(net70));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_6 ( .vssa(vssd), .dat_out(net71), 
    .vdda(vccd), .dat_in(net69));

al6100gpll_com_hss_inv4x x_com_hss_inv4x_5 ( .vssa(vssd), .dat_out(net72), 
    .vdda(vccd), .dat_in(net70));

endmodule



//manually created std cell lib file, to be used in analog sim model

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_DRNQV1_140P12T40L (D, RDN, CK, Q, VDD, VSS, VNW, VPW); 
  input D, RDN, CK;

inout VDD, VSS, VNW, VPW;
  output Q;
wire Q_temp;

  reg NOTIFIER;
  supply1 xSN;
wire ENABLE_D;
  buf   XX0 (xRN, RDN );
  buf     IC (clk, CK );
  udp_dff I0 (n0, D, clk, xRN, xSN, NOTIFIER );
  buf     I1 (Q_temp, n0 );
  assign ENABLE_D= (D) ? 1'b1:1'b0;
  assign Q = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? Q_temp : 1'bx;
  `ifdef functional // functional //

  `else // functional //
    buf SMC_I5(ENABLE_RDN,RDN);


  specify


	// arc CK --> Q
	(posedge CK => (Q : D))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

        $width(negedge CK,1.0,0,NOTIFIER);

        $width(posedge CK,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN == 1'b1),
            negedge D &&& (ENABLE_RDN == 1'b1), 1.0, 1.0, NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN == 1'b1),
            posedge D &&& (ENABLE_RDN == 1'b1), 1.0, 1.0, NOTIFIER);



        $setuphold(posedge CK &&& (ENABLE_D == 1'b1), posedge RDN &&& (ENABLE_D == 1'b1), 1.0, 1.0, NOTIFIER);


        $width(negedge RDN,1.0,0,NOTIFIER);


  endspecify

  `endif // functional //
endmodule
`endcelldefine



/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_NAND2CV1_140P12T40L ( ZN, A1, A2, VDD, VSS, VNW, VPW); 
input A1, A2;
inout VDD, VSS, VNW, VPW;
output ZN;
wire ZN_temp;

    nand I0(ZN_temp, A1, A2 );
  assign ZN = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? ZN_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
 	// arc A1 --> ZN
	 (A1 => ZN) = (1.0,1.0);

	// arc A2 --> ZN
	 (A2 => ZN) = (1.0,1.0);
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine



/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_PULL1_140P12T40L ( Z, VDD, VSS, VNW, VPW); 
inout VDD, VSS, VNW, VPW;
output Z;
wire Z_temp;

	assign Z_temp = 1'b1; 
  assign Z = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? Z_temp : 1'bx;
   `ifdef functional  //  functional //

   `else




   specify

   endspecify

  `endif // functional //

endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_NAND3CV1_140P12T40L ( ZN, A1, A2, A3, VDD, VSS, VNW, VPW); 
input A1, A2, A3;
inout VDD, VSS, VNW, VPW;
output ZN;
wire ZN_temp;

      nand I0(ZN_temp, A1, A2, A3 );
  assign ZN = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? ZN_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	 	// arc A1 --> ZN
	 (A1 => ZN) = (1.0,1.0);

	// arc A2 --> ZN
	 (A2 => ZN) = (1.0,1.0);

	// arc A3 --> ZN
	 (A3 => ZN) = (1.0,1.0);
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_NAND2BV1_140P12T40L ( ZN, A1, B1, VDD, VSS, VNW, VPW); 
input A1, B1;
inout VDD, VSS, VNW, VPW;
output ZN;
wire ZN_temp;

    not  I1(OUT0, A1 );
    nand I0(ZN_temp, OUT0, B1 );
  assign ZN = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? ZN_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 	// arc A1 --> ZN
	 (A1 => ZN) = (1.0,1.0);

	// arc B1 --> ZN
	 (B1 => ZN) = (1.0,1.0);
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine



/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_NAND2CV2_140P12T40L ( ZN, A1, A2, VDD, VSS, VNW, VPW); 
input A1, A2;
inout VDD, VSS, VNW, VPW;
output ZN;
wire ZN_temp;

    nand I0(ZN_temp, A1, A2 );
  assign ZN = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? ZN_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
 	// arc A1 --> ZN
	 (A1 => ZN) = (1.0,1.0);

	// arc A2 --> ZN
	 (A2 => ZN) = (1.0,1.0);
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_AND2V2_140P12T40L ( Z, A1, A2, VDD, VSS, VNW, VPW); 
input A1, A2;
inout VDD, VSS, VNW, VPW;
output Z;
wire Z_temp;

    and SMC_I0(Z_temp, A1, A2 );
  assign Z = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? Z_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc A1 --> Z 
	 (A1 => Z) = (1.0,1.0); 
 
	// arc A2 --> Z 
	 (A2 => Z) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_CLKMUX2V2_140P12T40L ( Z, I0, I1, S, VDD, VSS, VNW, VPW); 
input I0, I1, S;
inout VDD, VSS, VNW, VPW;
output Z;
wire Z_temp;

  udp_mux2 U0 (Z_temp, I0, I1, S );
  assign Z = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? Z_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 

	if(I1==1'b0)
	// arc I0 --> Z
	 (I0 => Z) = (1.0,1.0);
 
	if(I1==1'b1) 
	// arc I0 --> Z 
	 (I0 => Z) = (1.0,1.0); 

 	ifnone
	(I0 => Z) = (1.0,1.0);	
  
	if(I0==1'b0) 
	// arc I1 --> Z 
	 (I1 => Z) = (1.0,1.0); 
 
	if(I0==1'b1) 
	// arc I1 --> Z 
	 (I1 => Z) = (1.0,1.0); 

 	ifnone
	(I1 => Z) = (1.0,1.0);	
 
	// arc posedge S --> (Z:S) 
	 (posedge S => (Z:S)) = (1.0,1.0); 
 
	// arc negedge S --> (Z:S) 
	 (negedge S => (Z:S)) = (1.0,1.0);
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_CLKINV2_140P12T40L ( ZN, I, VDD, VSS, VNW, VPW); 
input I;
inout VDD, VSS, VNW, VPW;
output ZN;
wire ZN_temp;

    not SMC_I0 (ZN_temp, I );
  assign ZN = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? ZN_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 	// arc I --> ZN
	 (I => ZN) = (1.0,1.0);
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_CLKINV4_140P12T40L ( ZN, I, VDD, VSS, VNW, VPW); 
input I;
inout VDD, VSS, VNW, VPW;
output ZN;
wire ZN_temp;

    not SMC_I0 (ZN_temp, I );
  assign ZN = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? ZN_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 	// arc I --> ZN
	 (I => ZN) = (1.0,1.0);
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_CLKINV8_140P12T40L ( ZN, I, VDD, VSS, VNW, VPW); 
input I;
inout VDD, VSS, VNW, VPW;
output ZN;
wire ZN_temp;

    not SMC_I0 (ZN_temp, I );
  assign ZN = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? ZN_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 	// arc I --> ZN
	 (I => ZN) = (1.0,1.0);
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_DRSNQV2_140P12T40L (D, RDN, SDN, CK, Q, VDD, VSS, VNW, VPW); 
  input D, RDN, SDN, CK;

inout VDD, VSS, VNW, VPW;
  output Q;
wire Q_temp;

  reg NOTIFIER;
wire ENABLE_D_AND_SDN;
wire ENABLE_NOT_D_AND_RDN;
  buf   XX0 (xSN, SDN );
  buf   XX1 (xRN, RDN );
  buf     IC (clk, CK );
  udp_dff I0 (n0, D, clk, xRN, xSN, NOTIFIER );
  buf     I1 (Q_temp, n0 );
  assign ENABLE_D_AND_SDN = ( D & SDN )? 1'b1:1'b0;
  assign ENABLE_NOT_D_AND_RDN = ( !D & RDN ) ? 1'b1:1'b0;
  assign Q = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? Q_temp : 1'bx;
  `ifdef functional // functional //

  `else // functional //
    and SMC_I6(ENABLE_RDN_AND_SDN,RDN,SDN);

    buf SMC_I7(ENABLE_SDN,SDN);

    buf SMC_I8(ENABLE_RDN,RDN);


  specify


	// arc CK --> Q
	(posedge CK => (Q : D))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

        $width(negedge CK,1.0,0,NOTIFIER);

        $width(posedge CK,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN_AND_SDN == 1'b1),
            negedge D &&& (ENABLE_RDN_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN_AND_SDN == 1'b1),
            posedge D &&& (ENABLE_RDN_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);



        $setuphold(posedge CK &&& (ENABLE_D_AND_SDN == 1'b1),
            posedge RDN &&& (ENABLE_D_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);


        $width(negedge RDN,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_NOT_D_AND_RDN == 1'b1),
            posedge SDN &&& (ENABLE_NOT_D_AND_RDN == 1'b1), 1.0, 1.0, NOTIFIER);


        $setuphold(posedge RDN, posedge SDN, 1.0, 1.0, NOTIFIER);


        $width(negedge SDN,1.0,0,NOTIFIER);


  endspecify

  `endif // functional //
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_NAND2V2_140P12T40L ( ZN, A1, A2, VDD, VSS, VNW, VPW); 
input A1, A2;
inout VDD, VSS, VNW, VPW;
output ZN;
wire ZN_temp;

    nand I0(ZN_temp, A1, A2 );
  assign ZN = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? ZN_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc A1 --> ZN 
	 (A1 => ZN) = (1.0,1.0); 
 
	// arc A2 --> ZN 
	 (A2 => ZN) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_INV2_140P12T40L ( ZN, I, VDD, VSS, VNW, VPW); 
input I;
inout VDD, VSS, VNW, VPW;
output ZN;
wire ZN_temp;

    not I0(ZN_temp, I );
  assign ZN = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? ZN_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc I --> ZN 
	 (I => ZN) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine
/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_OR2V2_140P12T40L ( Z, A1, A2, VDD, VSS, VNW, VPW); 
input A1, A2;
inout VDD, VSS, VNW, VPW;
output Z;
wire Z_temp;

    or (Z_temp, A1, A2 );
  assign Z = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? Z_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc A1 --> Z 
	 (A1 => Z) = (1.0,1.0); 
 
	// arc A2 --> Z 
	 (A2 => Z) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_BUFV2_140P12T40L ( Z, I, VDD, VSS, VNW, VPW); 
input I;
inout VDD, VSS, VNW, VPW;
output Z;
wire Z_temp;

    buf I0(Z_temp, I );
  assign Z = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? Z_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc I --> Z 
	 (I => Z) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

/*****************************************************************************/
`timescale 10 ps / 1 ps

`ifdef functional
                                // none
`else
        `define SMC_NFORCE 1    // Flag to force output to x if notifer changes
`endif

`celldefine 
module al6100gpll_CLKNAND2V2_140P12T40L ( ZN, A1, A2, VDD, VSS, VNW, VPW); 
input A1, A2;
inout VDD, VSS, VNW, VPW;
output ZN;
wire ZN_temp;

    nand SMC_I0 (ZN_temp, A1, A2 );
  assign ZN = ((VDD === 1'b1) && (VSS === 1'b0) && (VNW === 1'b1) && (VPW === 1'b0)) ? ZN_temp : 1'bx;
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc A1 --> ZN 
	 (A1 => ZN) = (1.0,1.0); 
 
	// arc A2 --> ZN 
	 (A2 => ZN) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

















//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////





//Verilog HDL for "al6100_analog_com", "com_hss_inv8x" "functional"

`timescale 1ns/1ps
`celldefine
module al6100gpll_com_hss_inv8x ( dat_out, dat_in, vdda, vssa );

  output dat_out;
  input dat_in;
  input vdda;
  input vssa;

  reg   dat_out;

always @(*)
    dat_out <= #0.01 ~dat_in;

//assign dat_out=~dat_in;

endmodule
`endcelldefine



//Verilog HDL for "al6100_analog_com", "com_hss_inv4x" "functional"

`timescale 1ns/1ps
`celldefine
module al6100gpll_com_hss_inv4x ( dat_out, dat_in, vdda, vssa );

  output dat_out;
  input dat_in;
  input vdda;
  input vssa;

  reg   dat_out;

always @(*)
    dat_out <= #0.01 ~dat_in;

//assign dat_out=~dat_in;

endmodule
`endcelldefine



//Verilog HDL for "al6100_analog_com", "com_hss_inv2x" "functional"

`timescale 1ns/1ps
`celldefine
module al6100gpll_com_hss_inv2x ( dat_out, dat_in, vdda, vssa );

  output dat_out;
  input dat_in;
  input vdda;
  input vssa;

  reg   dat_out;

always @(*)
    dat_out <= #0.01 ~dat_in;

//assign dat_out=~dat_in;

endmodule
`endcelldefine



//Verilog HDL for "al6100_analog_com", "com_hss_inv1x" "functional"

//`timescale 1ns/1ps
//`celldefine
//module com_hss_inv1x ( dat_out, dat_in, vdda, vssa );
//
//  output dat_out;
//  input dat_in;
//  input vdda;
//  input vssa;
//
//  reg   dat_out;
//
//always @(*)
//    dat_out <= #0.01 ~dat_in;
//
////assign dat_out=~dat_in;
//
//endmodule
//`endcelldefine



//Verilog HDL for "al6100_analog_com", "com_hss_tgate_2x" "functional"

`timescale 1ns/1ps
`celldefine
module al6100gpll_com_hss_tgate_2x ( vz, sel, seln, va, vcca, vssa );

  input va;
  input vcca;
  output vz;
  input vssa;
  input sel;
  input seln;

  reg   vz;
  wire  va_temp;

  wire  eninternal = vcca & ~vssa & sel & ~seln;
//tranif1 (vz,      va, eninternal);
//tranif1 (va_temp, va, eninternal);
  assign   va_temp = eninternal ? va : (vcca ? 1'bz : 1'b0);

  always @(*)
    vz  <= #0.01 va_temp;

endmodule
`endcelldefine



//Verilog HDL for "al6100_analog_com", "com_hss_mux2x" "functional"

`timescale 1ns/1ps
`celldefine
module al6100gpll_com_hss_mux2x ( dat_out, dat_in0, dat_in1, sel, vdda, vssa );

  input dat_in1;
  output dat_out;
  input vdda;
  input vssa;
  input sel;
  input dat_in0;

  reg   dat_out;

always @(*)
    dat_out <= #0.01 sel? dat_in1:dat_in0;
    
//assign dat_out=sel? dat_in1:dat_in0;

endmodule
`endcelldefine



//Verilog HDL for "al6100_analog_com", "com_hss_dff2x" "functional"

`timescale 1ns / 1ps
`celldefine
module al6100gpll_com_hss_dff2x ( dat_out, ckc, ckt, dat_in, vdda, vssa );

  output reg dat_out;
  input dat_in;
  input ckt;
  input vdda;
  input ckc;
  input vssa;

always@(posedge ckt or vdda) begin
  if(vdda)
    dat_out <= #0.01 ((dat_in===1'b1)|(dat_in===1'b0))?dat_in:{$random}%2;
  else
    dat_out <= #0.01 1'b0;
end
endmodule
`endcelldefine



//Verilog HDL for "al6100_analog_com", "com_hss_and2_2x" "functional"

`timescale 1ns / 1ps
`celldefine
module al6100gpll_com_hss_and2_2x ( do_n, d1, d2, vcca, vssa );

  output do_n;
  input vcca;
  input d1;
  input vssa;
  input d2;

  reg   do_n;

always @(*)
    do_n    <= #0.01 vcca?d2&d1:0;

 //assign do_n=vcca?d2&d1:0;

endmodule
`endcelldefine
`timescale 1ns / 1ps

module gpll_ctrl ( direction, dyn_status, en_lock_ext, en_vco,
    load_div2_reg, load_reg, pll_sl_prechr_sw_en, pll_vreg_en,
    pllrst_n, psdone, pwd_dig_n, pwd_pll_n, rotate, rstdivc_n,
    rstdivm_n, rstlock_n, scanck, sel_fbk, ssc_reset_n, vccd, vssd,
    done_gwe, done_pll, int_lock, mc1_dig_pd, mc1_divcrst,
    mc1_dyn_source, mc1_fbk_sel, mc1_fbk_sel_wakeup, mc1_intfb,
    mc1_mrst, mc1_pllpdn, mc1_pllrst, mc1_ssc_reset, mc1_syn_sel,
    pdone, pib_load_div2_reg, pib_load_reg, pib_rst_divc, pib_rst_m,
    pib_ssc_reset, pll_digpd, pll_wakeup_sync, pllpd, pllreset, psclk,
    int_lock_in, int_lock_out,
    psclksel, psdown, psstep, trig_vco_en, vcc_vco_rdy, cal_rstn, lb_rstn, pfd_rstn,
    bandcal_rstn, bandcal1_rstn );

    inout                               vccd, vssd;
    
    output                              dyn_status,
                                        en_lock_ext,
                                        int_lock_out,
                                        en_vco,
                                        pll_sl_prechr_sw_en,
                                        pll_vreg_en,                // vreg en
                                        pllrst_n,                   // pfd rstn
                                        cal_rstn,                   // band calib rstn
                                        psdone,
                                        pwd_dig_n,
                                        pwd_pll_n,
                                        rstdivm_n,                  // ref/fbk div rstn
                                        rstlock_n,
                                        ssc_reset_n,
                                        lb_rstn,                    // loop back logic rstn
                                        pfd_rstn;
    
    input                               done_gwe,
                                        done_pll,
                                        int_lock,
                                        int_lock_in,
                                        mc1_dig_pd,
                                        mc1_dyn_source,
                                        mc1_intfb,
                                        mc1_mrst,
                                        mc1_pllpdn,
                                        mc1_pllrst,
                                        mc1_ssc_reset,
                                        pib_load_div2_reg,
                                        pib_load_reg,
                                        pib_rst_m,
                                        pib_ssc_reset,
                                        pll_digpd,
                                        pll_wakeup_sync,
                                        pllpd,
                                        pllreset,
                                        psclk,
                                        psdown,
                                        psstep,
                                        trig_vco_en,
                                        vcc_vco_rdy,
                                        bandcal_rstn,
                                        bandcal1_rstn;
    
  //output                      [ 6: 0] load_div2_reg;
  //output                      [ 6: 0] rotate;
  //output                      [ 6: 0] direction;
  //output                      [ 6: 0] scanck;
  //output                      [ 6: 0] load_reg;
    output                      [ 7: 0] load_div2_reg;              // updated
    output                      [ 7: 0] rotate;                     // updated
    output                      [ 7: 0] direction;                  // updated
    output                      [ 7: 0] scanck;                     // updated
    output                      [ 7: 0] load_reg;                   // updated

    output                      [ 1: 0] rstdivc_n;
    output                      [ 3: 0] sel_fbk;

    
    input                       [ 3: 0] mc1_fbk_sel;
    input                       [ 1: 0] mc1_divcrst;
    input                       [ 3: 0] mc1_fbk_sel_wakeup;
    input                       [ 1: 0] pib_rst_divc;
    input                       [ 2: 0] mc1_syn_sel;
    input                       [ 2: 0] psclksel;

  //input                       [ 6: 0] pdone;
    input                       [ 7: 0] pdone;                      // updated

    wire                                pllpdn_gate;
    wire                                fall_trig;
    wire                                pllreset_gate;
    wire                                pllrstn_gate2;
    wire                                rst_m_gate;
    wire                                rstn_m_gate2;
    wire                                pllrst_n_pre;
    wire                        [ 1: 0] rst_divc_gate;
    wire                        [ 1: 0] rst_div_b;
    wire                                fb_rst1n;
    wire                                fb_rst2n;
    wire                                ssc_reset_gate;
    wire                                ssc_rstn_gate2;

    wire                        [ 7: 0] out_sel;
    wire                        [ 2: 0] cnt_sel;

    wire                        [ 3: 0] sel_fbk;

  //gpll_fphase_ctrl xgpll_fphase_ctrl ( .done_gwe(done_gwe),
  //    .pib_load_div2_reg(pib_load_div2_reg),
  //    .load_div2_reg(load_div2_reg[7:0]), .direction(direction[7:0]),
  //    .pdone(pdone[7:0]), .scanck(scanck[7:0]), .rotate(rotate[7:0]),
  //    .load_reg(load_reg[7:0]), .vcca(vccd), .vssa(vssd),
  //    .dyn_status(dyn_status), .phasedone(psdone), .done_pll(done_pll),
  //    .mc1_dyn_source(mc1_dyn_source), .mc1_syn_sel(mc1_syn_sel[2:0]),
  //    .phasecntsel(psclksel[2:0]), .phasestep(psstep),
  //    .phaseupdown(psdown), .pib_load_reg(pib_load_reg),
  //    .scanclk(psclk));

    //======================================================
    // gpll_fphase_ctrl begin

    assign dyn_status           = mc1_dyn_source & done_pll ;

    assign cnt_sel              = dyn_status ? psclksel
                                :              mc1_syn_sel ;

    assign out_sel              = cnt_sel==3'd7 ? 8'b1000_0000
                                : cnt_sel==3'd6 ? 8'b0100_0000
                                : cnt_sel==3'd5 ? 8'b0010_0000
                                : cnt_sel==3'd4 ? 8'b0001_0000
                                : cnt_sel==3'd3 ? 8'b0000_1000
                                : cnt_sel==3'd2 ? 8'b0000_0100
                                : cnt_sel==3'd1 ? 8'b0000_0010
                                :                 8'b0000_0001 ;

    assign rotate               = out_sel & {8{done_gwe & psstep}} ;

    assign direction            = out_sel & {8{psdown}} ;

    assign load_reg             = out_sel & {8{done_gwe & pib_load_reg}} ;

    assign load_div2_reg        = out_sel & {8{done_gwe & pib_load_div2_reg}} ;

    assign scanck               = out_sel & {8{done_gwe & psclk}} ;

    assign psdone               = ^pdone ;

    // gpll_fphase_ctrl end
    //======================================================

  //gpll_ext2int xgpll_loop_mode_ctrl (
  //    .mc1_fbk_sel_wakeup(mc1_fbk_sel_wakeup[3:0]), .vccd(vccd),
  //    .vssd(vssd), .en_lock_ext(en_lock_ext), .sel_fbk(sel_fbk[3:0]),
  //    .done_gwe(done_gwe), .int_lock(int_lock),
  //    .mc1_fbk_sel(mc1_fbk_sel[3:0]), .mc1_intfb(mc1_intfb),
  //    .pll_wakeup_sync(pll_wakeup_sync));

    //======================================================
    // gpll_ext2int begin

    assign en_lock_ext          = done_gwe &
                                  (pll_wakeup_sync & int_lock | ~mc1_intfb) ;

    assign sel_fbk              = en_lock_ext ? mc1_fbk_sel
                                :               mc1_fbk_sel_wakeup ;

    // gpll_ext2int end
    //======================================================

 //gpll_pwd_rst_ctrl xgpll_rst_power_ctrl ( .fbk_sel(sel_fbk[3:0]),
 //     .mc1_divcrst(mc1_divcrst[1:0]), .pib_rst_divc(pib_rst_divc[1:0]),
 //     .rstdivc_n(rstdivc_n[1:0]), .mc1_dig_pd(mc1_dig_pd),
 //     .en_ext_trig_vco(trig_vco_en), .vcc_vco_ok(vcc_vco_rdy),
 //     .pll_sl_prechr_sw_en(pll_sl_prechr_sw_en), .done_gwe(done_gwe),
 //     .mc1_ssc_reset(mc1_ssc_reset), .mc1_pllrst(mc1_pllrst),
 //     .mc1_mrst(mc1_mrst), .pll_digpd(pll_digpd), .pllpd(pllpd),
 //     .pib_ssc_reset(pib_ssc_reset), .ssc_reset_n(ssc_reset_n),
 //     .pwd_pll_n(pwd_pll_n), .pll_vreg_en(pll_vreg_en), .vccd(vccd),
 //     .vssd(vssd), .en_vco(en_vco), .pllrst_n(pllrst_n),
 //     .pwd_dig_n(pwd_dig_n), .rstdivm_n(rstdivm_n),
 //     .rstlock_n(rstlock_n), .done_pll(done_pll),
 //     .mc1_pllpdn(mc1_pllpdn), .pib_rst_m(pib_rst_m),
 //     .pllreset(pllreset));

    //======================================================
    // gpll_pwd_rst_ctrl begin

    assign pllpdn_gate          = ~(done_gwe   & pllpd) ;

    assign pllreset_gate        =   done_gwe   & pllreset ;

    assign rst_m_gate           =   done_gwe   & pib_rst_m ;

    //no longer needed for al7000
    assign pll_sl_prechr_sw_en  =   done_gwe   | mc1_pllpdn ;

    assign rst_divc_gate        ={2{done_gwe}} & pib_rst_divc ;

    assign ssc_reset_gate       =   done_gwe   & pib_ssc_reset ;

    assign pllrstn_gate2        = ~(pllreset_gate  & mc1_pllrst) ;

    assign rstn_m_gate2         = ~(rst_m_gate     & mc1_mrst) ;

    assign ssc_rstn_gate2       = ~(ssc_reset_gate & mc1_ssc_reset) ;

    //no longer needed for al7000
    //in al006 there is a pulse gen module after this signal
    assign fall_trig            = ~( done_pll & rstn_m_gate2 & pllrstn_gate2 & vcc_vco_rdy
                                   & ~(~trig_vco_en & done_gwe) ) ;

    //no loading, no longer needed for al7000
    //for al006 design, this is a pulse to start VCO oscilation after vreg OK
    assign en_vco               = ~(pll_sl_prechr_sw_en & pllpdn_gate)
                                | ~done_pll
                                | ~fall_trig ;

    //directly drive vreg,                          in-directly drive rstdivm_n
    assign pll_vreg_en          = ((mc1_pllpdn & done_pll) | done_gwe) & pllpdn_gate ;

    //no loading, no longer needed for al7000
    assign pwd_pll_n            = pll_vreg_en ;

    //no loading, no longer needed for al7000
    assign pwd_dig_n            = pwd_pll_n & ~(mc1_dig_pd & pll_digpd & done_gwe) ;

    //directly drive refdiv,                        in-directly drive fbkdiv/outputdiv/bandcal_ldt/pfd/francN/vco_mux/SSC
    assign rstdivm_n            = pll_vreg_en & rstn_m_gate2 ;

    //directly drive outputdiv
    assign rstdivc_n            = ~(rst_divc_gate & mc1_divcrst) ;

    //directly drive bandcal_ldt,                   in-directly drive fbkdiv/francN/outputdiv/pfd/vco_mux/SSC
    assign cal_rstn             = rstdivm_n & pllrstn_gate2 & fb_rst1n & fb_rst2n ;

    //directly drive fbkdiv/francN/outputdiv 
    assign lb_rstn              = cal_rstn & bandcal_rstn;

    assign pfd_rstn             = cal_rstn & bandcal1_rstn;

    assign pllrst_n_pre         = cal_rstn & vcc_vco_rdy ;

    //if fbclk select from outputdiv, when output is reset, also reset PLL loop
    //when select output 0/1/2/3
    assign fb_rst1n             = rstdivc_n[0] | ~(sel_fbk[3] & ~sel_fbk[2]) ;

    //when select output 4/5/6/7
  //assign fb_rst2n             = rstdivc_n[1] |
  //                              ~((sel_fbk[3] & sel_fbk[2]) & ~(sel_fbk[1] & sel_fbk[0])) ; //this is from al006
    assign fb_rst2n             = rstdivc_n[1] | ~(sel_fbk[3] &  sel_fbk[2]) ;

    //directly drive pfd/vco_mux,                   in-directly drive SSC
    assign pllrst_n             = pllrst_n_pre ;

    //no loading for al7000
    assign rstlock_n            = pllrst_n ;

    //directly drive SSC
    assign ssc_reset_n          = pllrst_n & ssc_rstn_gate2 ;

    // gpll_pwd_rst_ctrl end
    //======================================================

    //Logic for lock before wakeup cascading
    assign int_lock_out         = (~mc1_pllpdn | int_lock) & int_lock_in ;

endmodule

`timescale 1ns / 1ps

module gpll_test ( dig_out, vccd, vssd,
    in0,  in1,  in2,  in3,  in4,  in5,  in6,  in7,  in8,  in9,
    in10, in11, in12, in13, in14, in15, in16, in17, in18, in19,
    in20, in21, in22, in23, in24, in25, in26, in27, in28, in29,
    in30, in31, in32, in33, in34, in35, in36, in37, in38, in39,
    in40, in41, in42, in43, in44, in45, in46, in47, in48, in49,
    in50, in51, in52, in53, in54, in55, in56, in57, in58, in59,
    in60, in61, in62, in63,
    mc1_test_en, mfg_dig_sel );

    inout                               vccd, vssd;

    output                              dig_out;

    input                               in0,  in1,  in2,  in3,  in4,  in5,  in6,  in7,  in8,  in9,
                                        in10, in11, in12, in13, in14, in15, in16, in17, in18, in19,
                                        in20, in21, in22, in23, in24, in25, in26, in27, in28, in29,
                                        in30, in31, in32, in33, in34, in35, in36, in37, in38, in39,
                                        in40, in41, in42, in43, in44, in45, in46, in47, in48, in49,
                                        in50, in51, in52, in53, in54, in55, in56, in57, in58, in59,
                                        in60, in61, in62, in63,
                                        mc1_test_en;

    input                       [ 5: 0] mfg_dig_sel;

    wire                                sel7;
    wire                                sel6;
    wire                                sel5;
    wire                                sel4;
    wire                                sel3;
    wire                                sel2;
    wire                                sel1;
    wire                                sel0;
    wire                                net72;
    wire                        [ 7: 0] dig_out_pre;

    gpll_test_cell I7 ( .dig_out(dig_out_pre[7]),
        .in0(in56), .in1(in57), .in2(in58),
        .in3(in59), .in4(in60), .in5(in61), .in6(in62), .in7(in63),
        .mfg_dig_sel(mfg_dig_sel[2:0]));
    
    gpll_test_cell I6 ( .dig_out(dig_out_pre[6]),
        .in0(in48), .in1(in49), .in2(in50),
        .in3(in51), .in4(in52), .in5(in53), .in6(in54), .in7(in55),
        .mfg_dig_sel(mfg_dig_sel[2:0]));
    
    gpll_test_cell I5 ( .dig_out(dig_out_pre[5]),
        .in0(in40), .in1(in41), .in2(in42),
        .in3(in43), .in4(in44), .in5(in45), .in6(in46), .in7(in47),
        .mfg_dig_sel(mfg_dig_sel[2:0]));
    
    gpll_test_cell I4 ( .dig_out(dig_out_pre[4]),
        .in0(in32), .in1(in33), .in2(in34),
        .in3(in35), .in4(in36), .in5(in37), .in6(in38), .in7(in39),
        .mfg_dig_sel(mfg_dig_sel[2:0]));

    gpll_test_cell I3 ( .dig_out(dig_out_pre[3]),
        .in0(in24), .in1(in25), .in2(in26),
        .in3(in27), .in4(in28), .in5(in29), .in6(in30), .in7(in31),
        .mfg_dig_sel(mfg_dig_sel[2:0]));
    
    gpll_test_cell I2 ( .dig_out(dig_out_pre[2]),
        .in0(in16), .in1(in17), .in2(in18),
        .in3(in19), .in4(in20), .in5(in21), .in6(in22), .in7(in23),
        .mfg_dig_sel(mfg_dig_sel[2:0]));
    
    gpll_test_cell I1 ( .dig_out(dig_out_pre[1]),
        .in0(in8), .in1(in9), .in2(in10),
        .in3(in11), .in4(in12), .in5(in13), .in6(in14), .in7(in15),
        .mfg_dig_sel(mfg_dig_sel[2:0]));
    
    gpll_test_cell I0 ( .dig_out(dig_out_pre[0]),
        .in0(in0), .in1(in1), .in2(in2),
        .in3(in3), .in4(in4), .in5(in5), .in6(in6), .in7(in7),
        .mfg_dig_sel(mfg_dig_sel[2:0]));

    assign sel7                 = mfg_dig_sel[5:3]==3'b111 ;
    assign sel6                 = mfg_dig_sel[5:3]==3'b110 ;
    assign sel5                 = mfg_dig_sel[5:3]==3'b101 ;
    assign sel4                 = mfg_dig_sel[5:3]==3'b100 ;
    assign sel3                 = mfg_dig_sel[5:3]==3'b011 ;
    assign sel2                 = mfg_dig_sel[5:3]==3'b010 ;
    assign sel1                 = mfg_dig_sel[5:3]==3'b001 ;
    assign sel0                 = mfg_dig_sel[5:3]==3'b000 ;

  `ifdef FPGA_SIM
    assign net72                = 
                                  sel7 ? dig_out_pre[7]
                                : sel6 ? dig_out_pre[6]
                                : sel5 ? dig_out_pre[5]
                                : sel4 ? dig_out_pre[4]
                                : sel3 ? dig_out_pre[3]
                                : sel2 ? dig_out_pre[2]
                                : sel1 ? dig_out_pre[1]
                                :        dig_out_pre[0] ;
  `else
      `ifdef FC_PG_SIM
        TBUFV8_140P9T40H    u7_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[7]), .OE(sel7),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u6_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[6]), .OE(sel6),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u5_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[5]), .OE(sel5),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u4_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[4]), .OE(sel4),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u3_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[3]), .OE(sel3),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u2_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[2]), .OE(sel2),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u1_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[1]), .OE(sel1),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u0_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[0]), .OE(sel0),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        TBUFV8_140P9T40H    u7_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[7]), .OE(sel7));
        TBUFV8_140P9T40H    u6_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[6]), .OE(sel6));
        TBUFV8_140P9T40H    u5_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[5]), .OE(sel5));
        TBUFV8_140P9T40H    u4_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[4]), .OE(sel4));
        TBUFV8_140P9T40H    u3_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[3]), .OE(sel3));
        TBUFV8_140P9T40H    u2_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[2]), .OE(sel2));
        TBUFV8_140P9T40H    u1_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[1]), .OE(sel1));
        TBUFV8_140P9T40H    u0_donttouch_buft_out   (.Z(net72), .I(dig_out_pre[0]), .OE(sel0));
      `endif
  `endif

    assign dig_out              = mc1_test_en ? net72 : 1'b0 ;

endmodule

`timescale 1ns / 1ps

module gpll_test_cell ( dig_out, in0, in1, in2, in3,
    in4, in5, in6, in7, mfg_dig_sel );

    output                              dig_out;

    input                               in0, in1, in2, in3, in4, in5, in6, in7;
  //input                               mc1_test_en;    // seems no use

    input                       [ 2: 0] mfg_dig_sel;

    assign dig_out              = mfg_dig_sel==3'd7 ? in7
                                : mfg_dig_sel==3'd6 ? in6
                                : mfg_dig_sel==3'd5 ? in5
                                : mfg_dig_sel==3'd4 ? in4
                                : mfg_dig_sel==3'd3 ? in3
                                : mfg_dig_sel==3'd2 ? in2
                                : mfg_dig_sel==3'd1 ? in1
                                :                     in0 ;

endmodule

`timescale 1ns/1ps

module gpll_output ( ck_pll2io, ckc_en, ckout_test,
    ckout_c, ckout_c_main, ckout_int,
    ckout_main_test, ckout_t, ckout_t_main, refclk_out, vccd, vssd,
    done_gwe, pib_en_pll2io_n, fb_div_clk, load_div2_reg, load_reg,
    mc1_div2_bypass_n, mc1_div2_phc_en, mc1_div_en, mc1_divc0,
    mc1_divc1, mc1_divc2, mc1_divc3, mc1_divc4, mc1_divc5, mc1_divc6,
    mc1_divc_outmux, mc1_divc_outmux_main, mc1_divc_premux0,
    mc1_divc_premux1, mc1_divc_premux2, mc1_divc_premux3,
    mc1_divc_premux4, mc1_divc_premux5, mc1_divc_premux6, mc1_duty0,
    mc1_duty1, mc1_duty2, mc1_duty3, mc1_duty4, mc1_duty5, mc1_duty6,
    mc1_duty50_n, mc1_dyn_phc0, mc1_dyn_phc1, mc1_dyn_phc2,
    mc1_dyn_phc3, mc1_dyn_phc4, mc1_dyn_phc5, mc1_dyn_phc6,
    mc1_enable_sync, mc1_enclk, mc1_enclk_main, mc1_load_div2_en,
    mc1_load_en, mc1_outgate_en, mc1_phc0, mc1_phc1, mc1_phc2,
    mc1_phc3, mc1_phc4, mc1_phc5, mc1_phc6, mc1_refclk_out_en,
    out_path_divrst_clk, phc, phomux, pib_clkout_glitchless_en_n,
    pib_enclk, pib_enclk_main, refclk, rst_div_n, rst_out_n, ssc_clk,
    test_dig_en, ck0_div_by_one, ck0_div,
    mc1_divc7, mc1_duty7, mc1_phc7, mc1_dyn_phc7, mc1_divc_premux7 );

    inout                               vccd, 
                                        vssd;

    output                              ck_pll2io, 
                                        ckout_t_main,
                                        ckout_c_main, 
                                        ckout_main_test,  
                                        refclk_out;
    output                      [ 7: 0] ckout_test;                 // updated
                                      //clkout0_test, 
                                      //clkout1_test, 
                                      //clkout2_test,
                                      //clkout3_test, 
                                      //clkout4_test, 
                                      //clkout5_test, 
                                      //clkout6_test,

    output                              ck0_div_by_one;             // updated
    output                              ck0_div;                    // updated

  //output                      [ 6: 0] ckc_en;
  //output                      [ 6: 0] ckout_int;
  //output                      [ 6: 0] ckout_t;
  //output                      [ 6: 0] ckout_c;
    output                      [ 7: 0] ckc_en;                     // updated
    output                      [ 7: 0] ckout_int;                  // updated
    output                      [ 7: 0] ckout_t;                    // updated
    output                      [ 7: 0] ckout_c;                    // updated

    input                               done_gwe,  
                                        fb_div_clk, 
                                        phomux,                     // vco phase0 
                                        pib_clkout_glitchless_en_n, 
                                        pib_enclk_main, 
                                        refclk, 
                                        ssc_clk,
                                        rst_out_n, 
                                        test_dig_en, 
                                        mc1_divc_outmux_main,
                                        mc1_enable_sync, 
                                        mc1_enclk_main, 
                                        mc1_refclk_out_en;
  //input                               en_pll2io_n;
    input                               pib_en_pll2io_n;            // updated
    
    input                       [ 6: 0] mc1_divc0;                  // div ratio
    input                       [ 6: 0] mc1_duty0;                  // clk duty
    input                       [ 6: 0] mc1_phc0;                   // initial phase
    input                       [ 6: 0] mc1_dyn_phc0;               // dynamic phase
    input                       [ 1: 0] mc1_divc_premux0;           // mux control after div2

    input                       [ 6: 0] mc1_divc1;
    input                       [ 6: 0] mc1_duty1;
    input                       [ 6: 0] mc1_phc1;
    input                       [ 6: 0] mc1_dyn_phc1;
    input                       [ 1: 0] mc1_divc_premux1;

    input                       [ 6: 0] mc1_divc2;
    input                       [ 6: 0] mc1_duty2;
    input                       [ 6: 0] mc1_phc2;
    input                       [ 6: 0] mc1_dyn_phc2;
    input                       [ 1: 0] mc1_divc_premux2;

    input                       [ 6: 0] mc1_divc3;
    input                       [ 6: 0] mc1_duty3;
    input                       [ 6: 0] mc1_phc3;
    input                       [ 6: 0] mc1_dyn_phc3;
    input                       [ 1: 0] mc1_divc_premux3;

    input                       [ 6: 0] mc1_divc4;
    input                       [ 6: 0] mc1_duty4;
    input                       [ 6: 0] mc1_phc4;
    input                       [ 6: 0] mc1_dyn_phc4;
    input                       [ 1: 0] mc1_divc_premux4;

    input                       [ 6: 0] mc1_divc5;
    input                       [ 6: 0] mc1_duty5;
    input                       [ 6: 0] mc1_phc5;
    input                       [ 6: 0] mc1_dyn_phc5;
    input                       [ 1: 0] mc1_divc_premux5;

    input                       [ 6: 0] mc1_divc6;
    input                       [ 6: 0] mc1_duty6;
    input                       [ 6: 0] mc1_phc6;
    input                       [ 6: 0] mc1_dyn_phc6;
    input                       [ 1: 0] mc1_divc_premux6;

    input                       [ 6: 0] mc1_divc7;                  // updated
    input                       [ 6: 0] mc1_duty7;                  // updated
    input                       [ 6: 0] mc1_phc7;                   // updated
    input                       [ 6: 0] mc1_dyn_phc7;               // updated
    input                       [ 1: 0] mc1_divc_premux7;           // updated

    input                       [ 1: 0] rst_div_n;
  //input                       [ 6: 0] phc;
  //input                       [ 6: 0] load_reg;
  //input                       [ 6: 0] load_div2_reg;
  //input                       [ 6: 0] pib_enclk;
  //input                       [ 6: 0] out_path_divrst_clk;
    input                       [ 7: 0] phc;                        // updated, vco clk
    input                       [ 7: 0] load_reg;                   // updated, div2   phase shift load
    input                       [ 7: 0] load_div2_reg;              // updated, div128 phase shift load
    input                       [ 7: 0] pib_enclk;                  // updated, output channel enable
    input                       [ 7: 0] out_path_divrst_clk;        // updated, 

  //input                       [ 6: 0] mc1_outgate_en;
  //input                       [ 6: 0] mc1_load_div2_en;
  //input                       [ 6: 0] mc1_load_en;
  //input                       [ 6: 0] mc1_divc_outmux;
  //input                       [ 6: 0] mc1_div2_bypass_n;
  //input                       [ 6: 0] mc1_duty50_n;
  //input                       [ 6: 0] mc1_div2_phc_en;
  //input                       [ 6: 0] mc1_enclk;
  //input                       [ 6: 0] mc1_div_en;
    input                       [ 7: 0] mc1_outgate_en;             // updated,
    input                       [ 7: 0] mc1_load_div2_en;           // updated,
    input                       [ 7: 0] mc1_load_en;                // updated,
    input                       [ 7: 0] mc1_divc_outmux;            // updated,
    input                       [ 7: 0] mc1_div2_bypass_n;          // updated,
    input                       [ 7: 0] mc1_duty50_n;               // updated,
    input                       [ 7: 0] mc1_div2_phc_en;            // updated,
    input                       [ 7: 0] mc1_enclk;                  // updated,
    input                       [ 7: 0] mc1_div_en;                 // updated,

    // Buses in the design
    
    wire                        [ 7: 0] sel_clk_path;
    
    wire                        [ 7: 0] en_clk_path;
    
    wire                        [ 7: 0] pd_clk_path;
    
    wire                        [ 7: 0] en_div_rst_n;

    wire                                refclk_buf;
  //wire                                pdn_pll2io;
    wire                                clkout0_test;
    wire                                clkout1_test;
    wire                                clkout2_test;
    wire                                clkout3_test;
    wire                                clkout4_test;
    wire                                clkout5_test;
    wire                                clkout6_test;
    wire                                clkout7_test;

    wire                                clk_int7;
    wire                                clk_int6;
    wire                                enable_all;
    wire                                clk_int5;
    wire                                clk_int4;
    wire                                clk_int3;
    wire                                clk_int2;
    wire                                clk_int1;
    wire                                clk_int0;
    wire                                clk_int_main;
    wire                                sel_clk_main;
    wire                                en_clk_main;
    wire                                clkc_en_main;
    wire                                pd_clk_main;
    wire                                en_out_rst_n;
    wire                                pd_pll2io_n;

    gpll_out_duty xout7 (
        .p_out                              (clkout7_test                   ),
        .enc                                (ckc_en[7]                      ),
        .out_int                            (ckout_int[7]                   ),
        .out                                (ckout_t[7]                     ),
        .outb                               (ckout_c[7]                     ),
        .out_glitchless_en_n                (pib_clkout_glitchless_en_n     ),
        .refclk                             (refclk_buf                     ),
        .dclk1                              (ssc_clk                        ),
        .en_pout                            (test_dig_en                    ),
        .mc1_enable_sync                    (mc1_enable_sync                ),
        .mc1_divc                           (mc1_divc7[6:0]                 ),
        .mc1_duty                           (mc1_duty7[6:0]                 ),
        .mc1_phc                            (mc1_phc7[6:0]                  ),
        .mc1_phc_load                       (mc1_dyn_phc7[6:0]              ),
        .mc1_divc_premux                    (mc1_divc_premux7[1:0]          ),
        .vco                                (phc[7]                         ),
        .load                               (load_reg[7]                    ),
        .load_div2                          (load_div2_reg[7]               ),
        .mc1_outgate_en                     (mc1_outgate_en[7]              ),
        .mc1_load_div2_en                   (mc1_load_div2_en[7]            ),
        .mc1_load_en                        (mc1_load_en[7]                 ),
        .mc1_divc_outmux                    (mc1_divc_outmux[7]             ),
        .mc1_div2_bypass_n                  (mc1_div2_bypass_n[7]           ),
        .mc1_duty50_n                       (mc1_duty50_n[7]                ),
        .mc1_div2_phc                       (mc1_div2_phc_en[7]             ),
        .mc1_div_en                         (mc1_div_en[7]                  ),
        .clk_int                            (clk_int7                       ),
        .dclk0                              (clk_int6                       ),
        .sel_clk                            (sel_clk_path[7]                ),
        .en_out                             (en_clk_path[7]                 ),
        .clk_en                             (enable_all                     ),
        .pd                                 (pd_clk_path[7]                 ),
        .rstn                               (en_div_rst_n[7]                ),

        .rstn_sync_out                      (                               ),
        .enabled                            (                               ),
        .vccd                               (vccd                           ),
        .vssd                               (vssd                           )
    );

    gpll_out_duty xout6 ( .out_glitchless_en_n(pib_clkout_glitchless_en_n),
         .mc1_outgate_en(mc1_outgate_en[6]), .rstn_sync_out(),
         .en_pout(test_dig_en), .mc1_load_div2_en(mc1_load_div2_en[6]),
         .mc1_load_en(mc1_load_en[6]), .mc1_phc_load(mc1_dyn_phc6[6:0]),
         .load_div2(load_div2_reg[6]), .mc1_div2_phc(mc1_div2_phc_en[6]),
         .sel_clk(sel_clk_path[6]), .outb(ckout_c[6]),
         .mc1_div_en(mc1_div_en[6]), .vccd(vccd), .vssd(vssd),
         .clk_int(clk_int6), .en_out(en_clk_path[6]), .enabled(),
         .out(ckout_t[6]), .out_int(ckout_int[6]), .p_out(clkout6_test),
         .clk_en(enable_all), .dclk0(clk_int5), .dclk1(ssc_clk),
         .enc(ckc_en[6]), .load(load_reg[6]),
         .mc1_div2_bypass_n(mc1_div2_bypass_n[6]),
         .mc1_divc(mc1_divc6[6:0]), .mc1_divc_outmux(mc1_divc_outmux[6]),
         .mc1_divc_premux(mc1_divc_premux6[1:0]),
         .mc1_duty50_n(mc1_duty50_n[6]), .mc1_duty(mc1_duty6[6:0]),
         .mc1_enable_sync(mc1_enable_sync), .mc1_phc(mc1_phc6[6:0]),
         .pd(pd_clk_path[6]), .refclk(refclk_buf), .rstn(en_div_rst_n[6]),
         .vco(phc[6]));

    gpll_out_duty xout5 ( .out_glitchless_en_n(pib_clkout_glitchless_en_n),
         .mc1_outgate_en(mc1_outgate_en[5]), .rstn_sync_out(),
         .en_pout(test_dig_en), .mc1_load_div2_en(mc1_load_div2_en[5]),
         .mc1_load_en(mc1_load_en[5]), .mc1_phc_load(mc1_dyn_phc5[6:0]),
         .load_div2(load_div2_reg[5]), .mc1_div2_phc(mc1_div2_phc_en[5]),
         .sel_clk(sel_clk_path[5]), .outb(ckout_c[5]),
         .mc1_div_en(mc1_div_en[5]), .vccd(vccd), .vssd(vssd),
         .clk_int(clk_int5), .en_out(en_clk_path[5]), .enabled(),
         .out(ckout_t[5]), .out_int(ckout_int[5]), .p_out(clkout5_test),
         .clk_en(enable_all), .dclk0(clk_int4), .dclk1(ssc_clk),
         .enc(ckc_en[5]), .load(load_reg[5]),
         .mc1_div2_bypass_n(mc1_div2_bypass_n[5]),
         .mc1_divc(mc1_divc5[6:0]), .mc1_divc_outmux(mc1_divc_outmux[5]),
         .mc1_divc_premux(mc1_divc_premux5[1:0]),
         .mc1_duty50_n(mc1_duty50_n[5]), .mc1_duty(mc1_duty5[6:0]),
         .mc1_enable_sync(mc1_enable_sync), .mc1_phc(mc1_phc5[6:0]),
         .pd(pd_clk_path[5]), .refclk(refclk_buf), .rstn(en_div_rst_n[5]),
         .vco(phc[5]));
    
    gpll_out_duty xout4 ( .out_glitchless_en_n(pib_clkout_glitchless_en_n),
         .mc1_outgate_en(mc1_outgate_en[4]), .rstn_sync_out(),
         .en_pout(test_dig_en), .mc1_load_div2_en(mc1_load_div2_en[4]),
         .mc1_load_en(mc1_load_en[4]), .mc1_phc_load(mc1_dyn_phc4[6:0]),
         .load_div2(load_div2_reg[4]), .mc1_div2_phc(mc1_div2_phc_en[4]),
         .sel_clk(sel_clk_path[4]), .outb(ckout_c[4]),
         .mc1_div_en(mc1_div_en[4]), .vccd(vccd), .vssd(vssd),
         .clk_int(clk_int4), .en_out(en_clk_path[4]), .enabled(),
         .out(ckout_t[4]), .out_int(ckout_int[4]), .p_out(clkout4_test),
         .clk_en(enable_all), .dclk0(clk_int3), .dclk1(ssc_clk),
         .enc(ckc_en[4]), .load(load_reg[4]),
         .mc1_div2_bypass_n(mc1_div2_bypass_n[4]),
         .mc1_divc(mc1_divc4[6:0]), .mc1_divc_outmux(mc1_divc_outmux[4]),
         .mc1_divc_premux(mc1_divc_premux4[1:0]),
         .mc1_duty50_n(mc1_duty50_n[4]), .mc1_duty(mc1_duty4[6:0]),
         .mc1_enable_sync(mc1_enable_sync), .mc1_phc(mc1_phc4[6:0]),
         .pd(pd_clk_path[4]), .refclk(refclk_buf), .rstn(en_div_rst_n[4]),
         .vco(phc[4]));

    gpll_out_duty xout3 ( .out_glitchless_en_n(pib_clkout_glitchless_en_n),
         .mc1_outgate_en(mc1_outgate_en[3]), .rstn_sync_out(),
         .en_pout(test_dig_en), .mc1_load_div2_en(mc1_load_div2_en[3]),
         .mc1_load_en(mc1_load_en[3]), .mc1_phc_load(mc1_dyn_phc3[6:0]),
         .load_div2(load_div2_reg[3]), .mc1_div2_phc(mc1_div2_phc_en[3]),
         .sel_clk(sel_clk_path[3]), .outb(ckout_c[3]),
         .mc1_div_en(mc1_div_en[3]), .vccd(vccd), .vssd(vssd),
         .clk_int(clk_int3), .en_out(en_clk_path[3]), .enabled(),
         .out(ckout_t[3]), .out_int(ckout_int[3]), .p_out(clkout3_test),
         .clk_en(enable_all), .dclk0(clk_int2), .dclk1(ssc_clk),
         .enc(ckc_en[3]), .load(load_reg[3]),
         .mc1_div2_bypass_n(mc1_div2_bypass_n[3]),
         .mc1_divc(mc1_divc3[6:0]), .mc1_divc_outmux(mc1_divc_outmux[3]),
         .mc1_divc_premux(mc1_divc_premux3[1:0]),
         .mc1_duty50_n(mc1_duty50_n[3]), .mc1_duty(mc1_duty3[6:0]),
         .mc1_enable_sync(mc1_enable_sync), .mc1_phc(mc1_phc3[6:0]),
         .pd(pd_clk_path[3]), .refclk(refclk_buf), .rstn(en_div_rst_n[3]),
         .vco(phc[3]));

    gpll_out_duty xout2 ( .out_glitchless_en_n(pib_clkout_glitchless_en_n),
         .mc1_outgate_en(mc1_outgate_en[2]), .rstn_sync_out(),
         .en_pout(test_dig_en), .mc1_load_div2_en(mc1_load_div2_en[2]),
         .mc1_load_en(mc1_load_en[2]), .mc1_phc_load(mc1_dyn_phc2[6:0]),
         .load_div2(load_div2_reg[2]), .mc1_div2_phc(mc1_div2_phc_en[2]),
         .sel_clk(sel_clk_path[2]), .outb(ckout_c[2]),
         .mc1_div_en(mc1_div_en[2]), .vccd(vccd), .vssd(vssd),
         .clk_int(clk_int2), .en_out(en_clk_path[2]), .enabled(),
         .out(ckout_t[2]), .out_int(ckout_int[2]), .p_out(clkout2_test),
         .clk_en(enable_all), .dclk0(clk_int1), .dclk1(ssc_clk),
         .enc(ckc_en[2]), .load(load_reg[2]),
         .mc1_div2_bypass_n(mc1_div2_bypass_n[2]),
         .mc1_divc(mc1_divc2[6:0]), .mc1_divc_outmux(mc1_divc_outmux[2]),
         .mc1_divc_premux(mc1_divc_premux2[1:0]),
         .mc1_duty50_n(mc1_duty50_n[2]), .mc1_duty(mc1_duty2[6:0]),
         .mc1_enable_sync(mc1_enable_sync), .mc1_phc(mc1_phc2[6:0]),
         .pd(pd_clk_path[2]), .refclk(refclk_buf), .rstn(en_div_rst_n[2]),
         .vco(phc[2]));

    gpll_out_duty xout1 ( .out_glitchless_en_n(pib_clkout_glitchless_en_n),
         .mc1_outgate_en(mc1_outgate_en[1]), .rstn_sync_out(),
         .en_pout(test_dig_en), .mc1_load_div2_en(mc1_load_div2_en[1]),
         .mc1_load_en(mc1_load_en[1]), .mc1_phc_load(mc1_dyn_phc1[6:0]),
         .load_div2(load_div2_reg[1]), .mc1_div2_phc(mc1_div2_phc_en[1]),
         .sel_clk(sel_clk_path[1]), .outb(ckout_c[1]),
         .mc1_div_en(mc1_div_en[1]), .vccd(vccd), .vssd(vssd),
         .clk_int(clk_int1), .en_out(en_clk_path[1]), .enabled(),
         .out(ckout_t[1]), .out_int(ckout_int[1]), .p_out(clkout1_test),
         .clk_en(enable_all), .dclk0(clk_int0), .dclk1(ssc_clk),
         .enc(ckc_en[1]), .load(load_reg[1]),
         .mc1_div2_bypass_n(mc1_div2_bypass_n[1]),
         .mc1_divc(mc1_divc1[6:0]), .mc1_divc_outmux(mc1_divc_outmux[1]),
         .mc1_divc_premux(mc1_divc_premux1[1:0]),
         .mc1_duty50_n(mc1_duty50_n[1]), .mc1_duty(mc1_duty1[6:0]),
         .mc1_enable_sync(mc1_enable_sync), .mc1_phc(mc1_phc1[6:0]),
         .pd(pd_clk_path[1]), .refclk(refclk_buf), .rstn(en_div_rst_n[1]),
         .vco(phc[1]));

    gpll_out_duty xout0 ( .out_glitchless_en_n(pib_clkout_glitchless_en_n),
         .mc1_outgate_en(mc1_outgate_en[0]), .rstn_sync_out(),
         .en_pout(1'b1), .mc1_load_div2_en(mc1_load_div2_en[0]),
         .mc1_load_en(mc1_load_en[0]), .mc1_phc_load(mc1_dyn_phc0[6:0]),
         .load_div2(load_div2_reg[0]), .mc1_div2_phc(mc1_div2_phc_en[0]),
         .sel_clk(sel_clk_path[0]), .outb(ckout_c[0]),
         .mc1_div_en(mc1_div_en[0]), .vccd(vccd), .vssd(vssd),
         .clk_int(clk_int0), .clk_div_by_one(ck0_div_by_one), .clk_int_early(ck0_div),
         .en_out(en_clk_path[0]), .enabled(enable_all),
         .out(ckout_t[0]), .out_int(ckout_int[0]), .p_out(clkout0_test),
         .clk_en(enable_all), .dclk0(clk_int7), .dclk1(clk_int_main),
         .enc(ckc_en[0]), .load(load_reg[0]),
         .mc1_div2_bypass_n(mc1_div2_bypass_n[0]),
         .mc1_divc(mc1_divc0[6:0]), .mc1_divc_outmux(mc1_divc_outmux[0]),
         .mc1_divc_premux(mc1_divc_premux0[1:0]),
         .mc1_duty50_n(mc1_duty50_n[0]), .mc1_duty(mc1_duty0[6:0]),
         .mc1_enable_sync(mc1_enable_sync), .mc1_phc(mc1_phc0[6:0]),
         .pd(pd_clk_path[0]), .refclk(refclk_buf), .rstn(en_div_rst_n[0]),
         .vco(phc[0]));

    gpll_out_main xmain ( .en_pout(test_dig_en), .sel_clk(sel_clk_main),
         .clk_divout(fb_div_clk), .outb(ckout_c_main),
         .mc1_clk_mux(mc1_divc_outmux_main), .vccd(vccd), .vssd(vssd),
         .clk_int(clk_int_main), .en_out(en_clk_main), .enabled(),
         .out(ckout_t_main), .p_out(ckout_main_test),
         .clk_en(enable_all), .enc(clkc_en_main),
         .mc1_enable_sync(mc1_enable_sync), .pd(pd_clk_main),
         .refclk(refclk_buf), .rstn_out(en_out_rst_n));

    gpll_out_en xen ( .done_gwe(done_gwe), .vccd(vccd), .vssd(vssd),
         .pib_enclk(pib_enclk[7:0]), .pib_enclk_main(pib_enclk_main),
         .mc1_enclk(mc1_enclk[7:0]), .mc1_enclk_main(mc1_enclk_main),
         .clkc_en(ckc_en[7:0]), .clkc_en_main(clkc_en_main));

    gpll_out_rst xrst_ctrl ( .rst_div_n(rst_div_n[1:0]), .phomux0(phomux),
         .phomux(out_path_divrst_clk[7:0]), .vccd(vccd), .vssd(vssd),
         .en_div_rst_n(en_div_rst_n[7:0]), .en_out_rst_n(en_out_rst_n),
         .rst_out_n(rst_out_n));

    gpll_out_en_stdby_ctrl xstdby_ctrl ( .pib_en_pll2io_n(pib_en_pll2io_n),
         .done_gwe(done_gwe), .vccd(vccd), .vssd(vssd),
         .pd_clk_main(pd_clk_main), .pd_clk_path(pd_clk_path[7:0]),
         .pd_pll2io_n(pd_pll2io_n), .sel_clk_main(sel_clk_main),
         .sel_clk_path(sel_clk_path[7:0]), .clk_div(clkout0_test),
         .en_clk_main(en_clk_main), .en_clk_path(en_clk_path[7:0]),
         .rst_n(en_out_rst_n));

    assign refclk_buf           = refclk ;

    assign refclk_out           = refclk_buf & mc1_refclk_out_en ;

  //assign pdn_pll2io           = ~pd_pll2io ;

    assign ck_pll2io            = pd_pll2io_n & clkout0_test ;

    assign ckout_test           = {clkout7_test, clkout6_test, clkout5_test, clkout4_test,
                                   clkout3_test, clkout2_test, clkout1_test, clkout0_test};

endmodule

`timescale 1ns/1ps

module gpll_out_div_duty ( clk_int, clk_div_by_one, clk_int_early, clk_omux, out_int, rstn_sync_out, vccd,
vssd, dclk0, dclk1, load, load_div2, mc1_div2_bypass_n, mc1_div2_phc, mc1_div_en,
mc1_divc, mc1_divc_premux, mc1_duty50_n, mc1_duty, mc1_load_div2_en,
mc1_load_en, mc1_outgate_en, mc1_phc, mc1_phc_load, out_glitchless_en_n, refclk,
rstn, vco );

    output                              clk_int;            //to next output
    output                              clk_div_by_one;
    output                              clk_int_early;
    output                              out_int;            //to fbk div
    output                              clk_omux;
    output                              rstn_sync_out;

    input                               vco;
    input                               rstn;
    input                               load;
    input                               dclk0;
    input                               dclk1;
    input                               refclk;
    input                               out_glitchless_en_n;
    input                               load_div2;
    input                       [ 6: 0] mc1_divc;
    input                       [ 6: 0] mc1_duty;
  //input                               mc1_divc_outmux;
    input                               mc1_outgate_en;
    input                       [ 6: 0] mc1_phc_load;
    input                               mc1_duty50_n;
    input                       [ 6: 0] mc1_phc;
    input                       [ 1: 0] mc1_divc_premux;
    input                               mc1_div_en;
    input                               mc1_div2_bypass_n;
    input                               mc1_load_en;
    input                               mc1_load_div2_en;
    input                               mc1_div2_phc;

    inout                               vccd;
    inout                               vssd;

    parameter C2Q               = 0.04;

    reg                                 rstn_sync0;
    reg                                 rstn_sync1;
    reg                                 rstn_sync2;
    reg                                 rstn_vco_sync1;
    reg                                 rstn_vco_sync2;
    reg                         [ 2: 0] q;
    reg                                 load_out;
    reg                                 load_out_div128_w;
    reg                         [ 2: 0] q_load;
    reg                         [ 2: 0] q_div128;
    reg                         [ 6: 0] cnt_div128;
    reg                         [ 6: 0] cnt_div128_h;           //half
  //reg                                 phc_sel;
    reg                                 q_rstn;
    reg                                 ckp_w;
    reg                                 ckn_w;
    reg                                 div_e;
    reg                                 q_divby1;
    reg                         [ 1: 0] load_sync;

    wire                                clk_divout;
    wire                                rstn_sync;
    wire                                ckin;
    wire                                rstn_in;
    wire                                vco_sync;
    wire                                clk_load;
    wire                                rstn_phc;
    wire                                rstn_phc_w1;
    wire                                rstn_phc_w2;
    wire                                rb;
    wire                                setb;
    wire                                din;
    wire                                rstn_sync_div2;
    wire                                rstn_pdn;
    wire                                clk_divmux;
    wire                                clk_divmuxb;
    wire                                clk_divmux_rstn;
    wire                                clk_sync;
    wire                                out_load;
    wire                                clk_out_int;
    wire                                clk_out_int_b;
    wire                                rstn_load;
    wire                                rstn_load_w1;
    wire                                rstn_load_w2;
    wire                                sel;
    wire                                sel_w;
    wire                                sel_load;
    wire                                sel_load_w;
    wire                                phc_en;
    wire                        [ 6: 0] phc_out;
    wire                        [ 6: 0] phc_half_out;
    wire                                rstn_sync_div128;
    wire                        [ 6: 0] load_full;
    wire                        [ 6: 0] load_half;
    wire                                qeq0;
    wire                                qnehalf;
    wire                                divby1oreven;
    wire                                divby1;
    wire                                qne0;
    wire                                rst_phc;
    wire                                rst_phc_w1;
    wire                                rst_phc_w2;
    wire                                ck_rst;
    wire                                phc_gate_trg;
    wire                                phc_gate_trg_b;
    wire                                dckp;
    wire                                eo;
    wire                                divbyeven;
    wire                                divbyodd;
    wire                                ck2;
    wire                                rstn_gate;
    wire                                phc_gate_out;
    wire                                out;
    wire                                clk_div2;
    wire                                ckp;
    wire                                ckn;
    wire                                load_out_div128;
    wire                                clk_out_int1;
    wire                                ck_or;
    wire                                ckp_b;
    wire                                ckn_b;
    wire                                clk_divmux1;
    wire                                clk_divmux2;
    wire                                phc_sel;
    wire                                phc_gate_trg0;

  `ifdef FPGA_SIM
    reg                                 ckdiv2;
    reg                                 gateout;
    reg                                 gateout_pre;
  `else
    wire                                ckdiv2;
    wire                                gateout;
    wire                                gateout_pre;
  `endif

  //assign ckin                 = vco;

  //always @(negedge ckin or negedge rstn) begin
    always @(negedge vco  or negedge rstn) begin
        if(~rstn)
            rstn_sync0          <= #C2Q 1'b0;
        else
            rstn_sync0          <= #C2Q 1'b1;
    end

  //always @(negedge out      or posedge out_glitchless_en_n) begin
    always @(negedge clk_omux or posedge out_glitchless_en_n) begin
        if(out_glitchless_en_n) begin
            rstn_sync1          <= #C2Q 1'b0;
            rstn_sync2          <= #C2Q 1'b0;
        end
        else begin
            rstn_sync1          <= #C2Q rstn_sync0;
            rstn_sync2          <= #C2Q rstn_sync1;
        end
    end

    assign rstn_sync            = rstn_sync0 | rstn_sync2;

    assign rstn_sync_out        = rstn_sync;

    assign rstn_in              = rstn_sync & mc1_div_en;

  //always @(negedge ckin or negedge rstn_in) begin
    always @(negedge vco  or negedge rstn_in) begin
        if(~rstn_in) begin
            rstn_vco_sync1      <= #C2Q 1'b0;
            rstn_vco_sync2      <= #C2Q 1'b0;
        end
        else begin
            rstn_vco_sync1      <= #C2Q 1'b1;
            rstn_vco_sync2      <= #C2Q rstn_vco_sync1;
        end
    end

    //use donttouch cell on clk output path!!!
  //assign vco_sync             = rstn_vco_sync2 & vco;
    CLKAND2V2_140P9T40R u_donttouch_vco_sync (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd),
  `endif
        .Z(vco_sync),   .A1(rstn_vco_sync2),    .A2(vco)
    );

    //======================================================
    // gpll_vco_div2 begin

    always @(negedge load_div2 or negedge rstn_phc) begin : gpll_vco_div2
        if(~rstn_phc)
            load_out            <= #C2Q 1'b1;
        else
            load_out            <= #C2Q 1'b0;
    end

    assign clk_load             = load_out | vco_sync;

    always @(posedge clk_load or negedge rstn_phc) begin
        if(~rstn_phc)
            q                   <= #C2Q 3'b0;
        else
            q                   <= #C2Q {1'b1, q[2:1]};
    end

    //rstn_sync is aysnc to vco_sync
    assign rstn_phc_w1          = mc1_load_div2_en & rstn_sync & ~q[0];

    //add delay to make sure the resetn pulse width is enough
    BUFV1_140P9T40H u_donttouch_buff_rstn_phc1 (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd),
  `endif
        .I(rstn_phc_w1), .Z(rstn_phc_w2));

    BUFV1_140P9T40H u_donttouch_buff_rstn_phc2 (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd),
  `endif
        .I(rstn_phc_w2), .Z(rstn_phc   ));

    sync_dff u0_sync_dff (
        .clk        (vco_sync                   ),
        .rst_n      (rstn_sync                  ),
        .din        (1'b1                       ),
        .dout       (rstn_sync_div2             )
    );

    assign rstn_pdn             = rstn_sync_div2 & mc1_div2_bypass_n;

    assign rb                   = rstn_pdn |  mc1_div2_phc;

    assign setb                 = rstn_pdn | ~mc1_div2_phc;

    assign din                  = (q[1]&~q[0]) ? ckdiv2 : ~ckdiv2 ;

  `ifdef FPGA_SIM
    always @(posedge vco_sync or negedge rb or negedge setb) begin
        if     (~rb)
            ckdiv2              <= #C2Q 1'b0;
        else if(~setb)
            ckdiv2              <= #C2Q 1'b1;
        else
            ckdiv2              <= #C2Q din;
    end
  `else
      `ifdef FC_PG_SIM
        DRSNQV2_140P9T40R   u0_donttouch_ckdiv2 (.Q(ckdiv2),    .D(din),   .CK(vco_sync),   .RDN(rb),   .SDN(setb), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV2_140P9T40R   u0_donttouch_ckdiv2 (.Q(ckdiv2),    .D(din),   .CK(vco_sync),   .RDN(rb),   .SDN(setb));
      `endif
  `endif

    //out gen
    //use donttouch cell on clk output path!!!
  //assign clk_div2             = mc1_div2_bypass_n ? ckdiv2 : vco_sync ;
    al6100_gpll_cell_clk_mux u_donttouch_clk_div2 (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(clk_div2),    .in1(ckdiv2),   .in0(vco_sync),     .sel(mc1_div2_bypass_n)
    );

    // gpll_vco_div2 end
    //======================================================

    //use donttouch cell on clk output path!!!
  //assign clk_divmux           = mc1_divc_premux[1:0] == 2'b11 ? refclk
  //                            : mc1_divc_premux[1:0] == 2'b10 ? dclk1
  //                            : mc1_divc_premux[1:0] == 2'b01 ? dclk0
  //                            :                                 clk_div2 ;
    al6100_gpll_cell_clk_mux u_donttouch_clk_divmux0 (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(clk_divmux1),     .in1(refclk),       .in0(dclk1),        .sel(mc1_divc_premux[0])
    );

    al6100_gpll_cell_clk_mux u_donttouch_clk_divmux1 (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(clk_divmux2),     .in1(clk_divmux1),  .in0(dclk0),        .sel(mc1_divc_premux[1])
    );

    al6100_gpll_cell_clk_mux u_donttouch_clk_divmux2 (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(clk_divmux),      .in1(clk_divmux2),  .in0(clk_div2),     .sel(|mc1_divc_premux[1:0])
    );

    assign clk_divmuxb          = ~clk_divmux;

    sync_dff u1_sync_dff (
        .clk        (clk_divmuxb                ),
        .rst_n      (rstn_in                    ),
        .din        (1'b1                       ),
        .dout       (clk_divmux_rstn            )
    );

    //use donttouch cell on clk output path!!!
  //assign clk_sync             = clk_divmux_rstn & clk_divmux ;
    CLKAND2V2_140P9T40R u_donttouch_clk_sync (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd),
  `endif
        .Z(clk_sync),   .A1(clk_divmux_rstn),   .A2(clk_divmux)
    );

    //======================================================
    // gpll_div128_out_duty / gpll_out_div128_phc begin

    always @(negedge load or negedge rstn_load) begin : gpll_div128_out_duty
        if(~rstn_load)
            load_out_div128_w   <= #C2Q 1'b0;
        else
            load_out_div128_w   <= #C2Q 1'b1;
    end

//  at0012_cell_clk_buf u_donttouch_ckbuf_load (
//`ifdef FC_PG_SIM
//      .vdd(vccd), .vss(vssd),
//`endif
//      .cout(load_out_div128),     .cin(load_out_div128_w)
//  );

/*  //20220913, jzhou, ECO, use shorter clk path
  //assign out_load             = load_out_div128_w | clk_out_int ;
    assign out_load             = load_out_div128_w | ckp ;

    always @(posedge out_load or negedge rstn_load) begin
        if(~rstn_load)
            q_load              <= #C2Q 3'b0;
        else
            q_load              <= #C2Q {1'b1, q_load[2:1]};
    end

    //rstn_load is aysnc to clk_out_int
    //add delay to make sure the resetn pulse width is enough
    assign rstn_load_w1         = mc1_load_en & rstn_sync & ~q_load[0];
    BUFFD1BWP20P90CPD u_donttouch_buff_rstn_load1 (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VPP(vccd), .VBB(vssd),
  `endif
        .I(rstn_load_w1), .Z(rstn_load_w2));

    BUFFD1BWP20P90CPD u_donttouch_buff_rstn_load2 (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VPP(vccd), .VBB(vssd),
  `endif
        .I(rstn_load_w2), .Z(rstn_load   ));

    //20220913, jzhou, ECO, use shorter clk path
  //always @(posedge clk_out_int or negedge rstn_sync) begin
    always @(posedge ckp         or negedge rstn_sync) begin
        if(~rstn_sync)
            q_div128            <= #C2Q 3'b0;
        else
            q_div128            <= #C2Q {1'b1, q_div128[2:1]};
    end

    assign sel_w                = q_div128[1] & ~q_div128[0] ;

    at0012_cell_clk_buf u_donttouch_ckbuf_sel (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(sel),     .cin(sel_w)
    );

    assign sel_load_w           = q_load[1]   & ~q_load[0] ;

    at0012_cell_clk_buf u_donttouch_ckbuf_sel_load (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(sel_load),     .cin(sel_load_w)
    );*/

    //20220915, remove those DFFs for generated clk, simplify clk path for PR
    always @(posedge clk_sync or negedge rstn_sync_div128) begin
        if(~rstn_sync_div128)
            load_sync           <= #C2Q 2'b0;
        else if(q_load==3'b111)
            load_sync           <= #C2Q 2'b0;
        else //async signal cross clk domain with dual DFF
            load_sync           <= #C2Q {load_out_div128_w, load_sync[1]};
    end

    //add additional 0.01ns delay to avoid glitch in sim
    always @(posedge clk_sync or negedge rstn_sync_div128) begin
        if(~rstn_sync_div128)
            q_load              <= #0.05 3'b0;
        else if(q_load==3'b111)
            q_load              <= #0.05 3'b0;
        else if(qeq0 && load_sync[0])
            q_load              <= #0.05 {1'b1, q_load[2:1]};
    end

    assign rstn_load            = mc1_load_en & rstn_sync & ~q_load[0];

    assign sel_load             = q_load[1]   & ~q_load[0] ;

    always @(posedge clk_sync or negedge rstn_sync_div128) begin
        if(~rstn_sync_div128)
            q_div128            <= #0.05 3'b0;
        else if(qeq0)
            q_div128            <= #0.05 {1'b1, q_div128[2:1]};
    end

    assign sel                  = q_div128[1] & ~q_div128[0] ;

    assign phc_en               = sel | sel_load ;

    assign phc_out              = sel       ? mc1_phc
                                : sel_load  ? mc1_phc_load
                                :             7'b0          ;

    assign phc_half_out         = sel       ? ((mc1_phc>>1)     + 7'b1)
                                : sel_load  ? ((mc1_phc_load>>1)+ 7'b1)
                                :             7'b0          ;

    // gpll_div128_out_duty / gpll_out_div128_phc end
    //======================================================


    //======================================================
    // gpll_div128_out_duty / gpll_div128_duty begin

    sync_dff u2_sync_dff (
        .clk        (clk_sync                   ),
        .rst_n      (rstn_sync                  ),
        .din        (1'b1                       ),
        .dout       (rstn_sync_div128           )
    );

        //+++++++++++++++++++++++++++++++++++++++++++
        // gpll_div128_out_duty / gpll_div128_duty / gpll_div128_cnt_duty begin

        always @(posedge clk_sync or negedge rstn_sync_div128) begin : _main_div
            if(~rstn_sync_div128) begin
                cnt_div128      <= #C2Q 7'b0;
                cnt_div128_h    <= #C2Q 7'b0;
            end
            else begin
                cnt_div128      <= #C2Q qeq0 ? load_full : (cnt_div128 - 7'b1) ;
                cnt_div128_h    <= #C2Q qeq0 ? load_half :  cnt_div128_h ;
            end
        end

        assign qeq0             = cnt_div128==7'b0 ;

        assign qne0             = ~qeq0 ;

        assign qnehalf          = cnt_div128!=cnt_div128_h ;

        assign divby1           = mc1_divc==7'b0 ;

        assign divby1oreven     = mc1_divc[0] | ~(|mc1_divc[6:1]) ;

        //20220915, remove those DFFs for generated clk, simplify clk path for PR
      /*always @(posedge phc_en or negedge rst_phc) begin
            if(~rst_phc)
                phc_sel         <= #C2Q 1'b0;
            else
                phc_sel         <= #C2Q 1'b1;
        end

        always @(posedge ck_rst or negedge rst_phc) begin
            if(~rst_phc)
                q_rstn          <= #C2Q 1'b1;
            else
                q_rstn          <= #C2Q qne0;
        end

        assign ck_rst           = clk_sync | ~phc_sel ;

        // add delay to make pulse wide enough
        // pulse min width is 80ps according to analog designer
        assign rst_phc_w1       = rstn_sync_div128 & q_rstn ;
    BUFFD1BWP20P90CPD u_donttouch_buff_rstn_phc3 (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VPP(vccd), .VBB(vssd),
  `endif
        .I(rst_phc_w1), .Z(rst_phc_w2));

    BUFFD1BWP20P90CPD u_donttouch_buff_rstn_phc4 (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VPP(vccd), .VBB(vssd),
  `endif
        .I(rst_phc_w2), .Z(rst_phc   ));*/

        assign phc_sel          = phc_en ;

        //add a little delay to avoid glitch
        //!!!!! in real PR, must make sure phc_gate_trg changes after clk_out_int
      //assign phc_gate_trg     = phc_sel ;
        BUFV1_140P9T40H u_donttouch_buff_phc_gate_trg0 (
      `ifdef FC_PG_SIM
            .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd),
      `endif
            .I(phc_sel),        .Z(phc_gate_trg0));

        BUFV1_140P9T40H u_donttouch_buff_phc_gate_trg1 (
      `ifdef FC_PG_SIM
            .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd),
      `endif
            .I(phc_gate_trg0),  .Z(phc_gate_trg));

        assign load_full        = phc_sel ? phc_out      : {mc1_divc[6:1], divby1oreven} ;

        assign load_half        = phc_sel ? phc_half_out :  mc1_duty ;

        // gpll_div128_out_duty / gpll_div128_duty / gpll_div128_cnt_duty end
        //+++++++++++++++++++++++++++++++++++++++++++

    assign dckp                 = ~(~(ckp & qnehalf) & qne0) ;

    always @(posedge clk_sync or negedge rstn_sync_div128) begin : _gen_ckp
        if(~rstn_sync_div128)
            ckp_w               <= #C2Q 1'b0;
        else
            ckp_w               <= #C2Q dckp;
    end

    at0012_cell_clk_buf u_donttouch_ckbuf (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(ckp),     .cin(ckp_w)
    );

    always @(negedge clk_sync or negedge rstn_sync_div128) begin : _gen_ckn
        if(~rstn_sync_div128)
            ckn_w               <= #C2Q 1'b0;
        else
            ckn_w               <= #C2Q ckp;
    end

    at0012_cell_clk_buf u_donttouch_ckbufn (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(ckn),     .cin(ckn_w)
    );

    assign eo                   = mc1_duty50_n | load_full[0] ;

    always @(posedge ckp or negedge rstn_sync_div128) begin
        if(~rstn_sync_div128) begin
            div_e               <= #C2Q 1'b0;
            q_divby1            <= #C2Q 1'b0;
        end
        else begin
            div_e               <= #C2Q eo;
            q_divby1            <= #C2Q divby1;
        end
    end

    assign divbyeven            = ~q_divby1 &  div_e ;

    assign divbyodd             = ~q_divby1 & ~div_e ;

        //+++++++++++++++++++++++++++++++++++++++++++
        // gpll_div128_out_duty / gpll_div128_duty / gpll_div128_omux_duty begin

        //use donttouch cell on clk output path!!!
      //assign clk_out_int      = divbyeven ? ckp
      //                        : divbyodd  ? (ckp | ckn)
      //                        :             clk_sync ;
      //CKOR2D2BWP20P90CPD u_donttouch_clk_or (
      `ifdef FC_PG_SIM
            CLKINV4_140P9T40R       u0_donttouch_clk_buf (.ZN(ckp_b), .I(ckp),                  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
            CLKINV4_140P9T40R       u1_donttouch_clk_buf (.ZN(ckn_b), .I(ckn),                  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
            CLKNAND2V2_140P9T40R    u_donttouch_clk_nand (.ZN(ck_or), .A1(ckp_b), .A2(ckn_b),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
            CLKINV4_140P9T40R       u0_donttouch_clk_buf (.ZN(ckp_b), .I(ckp)                   );
            CLKINV4_140P9T40R       u1_donttouch_clk_buf (.ZN(ckn_b), .I(ckn)                   );
            CLKNAND2V2_140P9T40R    u_donttouch_clk_nand (.ZN(ck_or), .A1(ckp_b), .A2(ckn_b)     );
      `endif

        al6100_gpll_cell_clk_mux u_donttouch_clk_out_int0 (
      `ifdef FC_PG_SIM
            .vdd(vccd), .vss(vssd),
      `endif
            .cout(clk_out_int1),    .in1(ck_or),    .in0(clk_sync),         .sel(divbyodd)
        );

        al6100_gpll_cell_clk_mux u_donttouch_clk_out_int1 (
      `ifdef FC_PG_SIM
            .vdd(vccd), .vss(vssd),
      `endif
            .cout(clk_out_int),     .in1(ckp),      .in0(clk_out_int1),     .sel(divbyeven)
        );

      //assign clk_int_early    = divby1    ? clk_sync
      //                        :             ckp      ;
    //  al6100_gpll_cell_clk_mux u_donttouch_clk_int_early (
    //`ifdef FC_PG_SIM
    //      .vdd(vccd), .vss(vssd),
    //`endif
    //      .cout(clk_int_early),   .in1(clk_sync), .in0(ckp),              .sel(divby1)
    //  );
        //20230427, jzhou, to meet 1/8 frac divide timing, remove divby1 path,
        //use only divbyN
        assign clk_int_early    = ckp_w;

        assign clk_div_by_one   = divby1 ;

        // gpll_div128_out_duty / gpll_div128_duty / gpll_div128_omux_duty end
        //+++++++++++++++++++++++++++++++++++++++++++

        //+++++++++++++++++++++++++++++++++++++++++++
        // gpll_div128_out_duty / gpll_div128_duty / gpll_out_phc_gate begin

      `ifdef FPGA_SIM
        assign ck2              = ~( clk_out_int | phc_gate_trg) ;
      `else
        `ifdef FC_PG_SIM
            CLKINV4_140P9T40R       u0_donttouch_ck2_inv (.ZN(clk_out_int_b),  .I(clk_out_int),                           .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
            INV3_140P9T40R          u1_donttouch_ck2_inv (.ZN(phc_gate_trg_b), .I(phc_gate_trg),                          .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
            CLKAND2V2_140P9T40R     u_donttouch_ck2_and  (.Z(ck2),             .A1(clk_out_int_b), .A2(phc_gate_trg_b),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        `else
            CLKINV4_140P9T40R       u0_donttouch_ck2_inv (.ZN(clk_out_int_b),  .I(clk_out_int)                                                                          );
            INV3_140P9T40R          u1_donttouch_ck2_inv (.ZN(phc_gate_trg_b), .I(phc_gate_trg)                                                                         );
            CLKAND2V2_140P9T40R     u_donttouch_ck2_and  (.Z(ck2),             .A1(clk_out_int_b), .A2(phc_gate_trg_b)                                                  );
        `endif
      `endif

        assign rstn_gate        = ~(~clk_out_int & phc_gate_trg) ;

        `ifdef FPGA_SIM
            always @(posedge ck2 or negedge rstn_gate or negedge rstn_sync_div128) begin
                if     (~rstn_gate) begin
                    gateout_pre <= #0.04 1'b0;
                    gateout     <= #0.04 1'b0;
                end
                else if(~rstn_sync_div128) begin
                    gateout_pre <= #0.04 1'b1;
                    gateout     <= #0.04 1'b1;
                end
                else begin
                    gateout_pre <= #0.04 1'b1;
                    gateout     <= #0.04 gateout_pre;
                end
            end
        `else
          `ifdef FC_PG_SIM
            DRSNQV2_140P9T40H   u0_donttouch_gate   (.Q(gateout_pre),   .D(1'b1       ),    .CK(ck2),   .RDN(rstn_gate),    .SDN(rstn_sync_div128), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
            DRSNQV2_140P9T40H   u1_donttouch_gate   (.Q(gateout    ),   .D(gateout_pre),    .CK(ck2),   .RDN(rstn_gate),    .SDN(rstn_sync_div128), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
          `else
            DRSNQV2_140P9T40H   u0_donttouch_gate   (.Q(gateout_pre),   .D(1'b1       ),    .CK(ck2),   .RDN(rstn_gate),    .SDN(rstn_sync_div128));
            DRSNQV2_140P9T40H   u1_donttouch_gate   (.Q(gateout    ),   .D(gateout_pre),    .CK(ck2),   .RDN(rstn_gate),    .SDN(rstn_sync_div128));
          `endif
        `endif

        assign phc_gate_out     = mc1_outgate_en ? gateout
                                :                  1'b1 ;

        // gpll_div128_out_duty / gpll_div128_duty / gpll_out_phc_gate end
        //+++++++++++++++++++++++++++++++++++++++++++

    //use donttouch cell on clk output path!!!
  //assign out                  = clk_out_int & phc_gate_out ;
    CLKAND2V2_140P9T40R u_donttouch_clk_gate (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd),
  `endif
        .Z(clk_omux),   .A1(clk_out_int),   .A2(phc_gate_out)
    );

    // gpll_div128_out_duty / gpll_div128_duty end
    //======================================================

    assign clk_int              = clk_omux ;

    assign out_int              = clk_omux ;

  //assign clk_omux             = mc1_divc_outmux ? refclk
  //                            :                   out     ;

endmodule

`timescale 1ns / 1ps

module gpll_out_rst ( en_div_rst_n, en_out_rst_n, vccd, vssd, phomux0,
    phomux, rst_div_n, rst_out_n );

    inout                               vccd, vssd;

    output                              en_out_rst_n;
    output reg                  [ 7: 0] en_div_rst_n;
    
    input                               phomux0,
                                        rst_out_n;
    input                       [ 1: 0] rst_div_n;
    input                       [ 7: 0] phomux;

    reg                         [ 1: 0] rstn_out2;

    wire                                phomux0_buf;
    wire                        [ 1: 0] rstn_div;
    wire                        [ 1: 0] rstn_out1;
    wire                        [ 7: 0] ph;

    assign phomux0_buf          = ~phomux0 ;

    sync_dff #(.RST_VAL(1'b0)) u_main_sync_dff (
        .clk        (phomux0_buf                ),
        .rst_n      (rst_out_n                  ),
        .din        (1'b1                       ),
        .dout       (en_out_rst_n               )
    );

    sync_dff #(.RST_VAL(1'b1)) u0_sync_dff (
        .clk        (phomux0_buf                ),
        .rst_n      (rst_out_n                  ),
        .din        (rst_div_n[0]               ),
        .dout       (rstn_div[0]                )
    );

    sync_dff #(.RST_VAL(1'b1)) u1_sync_dff (
        .clk        (phomux0_buf                ),
        .rst_n      (rst_out_n                  ),
        .din        (rst_div_n[1]               ),
        .dout       (rstn_div[1]                )
    );

    assign rstn_out1            = rstn_div & {2{en_out_rst_n}} ;

    always @(posedge phomux0_buf or negedge rstn_out1[1]) begin
        if(~rstn_out1[1])
            rstn_out2[1]        <= 1'b0;
        else
            rstn_out2[1]        <= rstn_out1[1];
    end

    always @(posedge phomux0_buf or negedge rstn_out1[0]) begin
        if(~rstn_out1[0])
            rstn_out2[0]        <= 1'b0;
        else
            rstn_out2[0]        <= rstn_out1[0];
    end

    assign ph                   = ~phomux ;

    genvar i;
    generate
        for(i=0; i<=3; i=i+1) begin
            always @(posedge ph[i+4] or negedge rstn_out1[1]) begin
                if(~rstn_out1[1])
                    en_div_rst_n[i+4]   <= 1'b0;
                else
                    en_div_rst_n[i+4]   <= rstn_out2[1];
            end

            always @(posedge ph[i]   or negedge rstn_out1[0]) begin
                if(~rstn_out1[0])
                    en_div_rst_n[i]     <= 1'b0;
                else
                    en_div_rst_n[i]     <= rstn_out2[0];
            end
        end
    endgenerate

endmodule

`timescale 1ns/1ps

module gpll_out_gate ( clko, clkob, en_out_sync, enable_sync, p_out, vccd, vssd,
clk, clk_enabled, div_en, en_pout, enable, pd, rstn, sel_clk, sel_enable_sync,
mc1_divc_outmux, refclk
);

    output                              clko;
    output                              clkob;
    output                              p_out;
    output                              en_out_sync;
    output                              enable_sync;

    input                               clk;
    input                               rstn;

    input                               sel_clk;
    input                               enable;
    input                               sel_enable_sync;
    input                               div_en;
    input                               clk_enabled;
    input                               pd;
    input                               en_pout;
    input                               mc1_divc_outmux;
    input                               refclk;

    inout                               vccd;
    inout                               vssd;

    parameter C2Q               = 0.04;

    wire                                rstn_buf;
    wire                                clkb;
    wire                                en_mux;
    wire                                clk1;
    wire                                ck_mux;

    assign clkb                 = ~clk ;

    assign rstn_buf             = rstn & div_en ;

    assign en_mux               = sel_enable_sync ? enable & clk_enabled
                                :                   enable ;

    //the following "enable_sync" from output path 0 will output to top to control path0~7 & main
    sync_dff u0_sync_dff (
        .clk        (clk                        ),
        .rst_n      (rstn_buf                   ),
        .din        (enable                     ),
        .dout       (enable_sync                )
    );

    sync_dff u1_sync_dff (
        .clk        (clkb                       ),
        .rst_n      (rstn_buf                   ),
        .din        (en_mux                     ),
        .dout       (en_out_sync                )
    );

    //make clk output path shorter by 1 stage mux instead of 2 stages
  //`ifdef FPGA_SIM
  //    assign ck_mux           = sel_clk ? clk
  //                            : pd      ? 1'b0
  //                            :           1'bz ;
  //`else
  //    al6100_gpll_cell_clk_mux u_donttouch_clko (
  //  `ifdef FC_PG_SIM
  //        .vdd(vccd), .vss(vssd),
  //  `endif
  //        .cout(ck_mux),     .in1(1'b0),    .in0(clk),         .sel(pd)
  //    );
  //`endif
    `ifdef FPGA_SIM
        assign ck_mux           = (mc1_divc_outmux | pd) ? (pd ? 1'b0 : refclk )
                                :                           clk;
    `else
        al6100_gpll_cell_clk_mux u_donttouch_clk1 (
      `ifdef FC_PG_SIM
            .vdd(vccd), .vss(vssd),
      `endif
          // 20221231, added mc1_divc_outmux to avoid possible glitch when pd==1 && refclk==1
          //.cout(clk1),       .in1(1'b0),    .in0(refclk),      .sel(                   pd)
            .cout(clk1),       .in1(1'b0),    .in0(refclk),      .sel(~mc1_divc_outmux | pd)
        );

        al6100_gpll_cell_clk_mux u_donttouch_clko (
      `ifdef FC_PG_SIM
            .vdd(vccd), .vss(vssd),
      `endif
            .cout(ck_mux),     .in1(clk1),    .in0(clk),         .sel( mc1_divc_outmux | pd)
        );
    `endif

    //add the following 2 ckbuf to match the delay
    //for clko & clkob
    at0012_cell_clk_buf u_donttouch_ckobuf (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(clko),    .cin(ck_mux)
    );

    CLKINV4_140P9T40R u_donttouch_ckobbuf (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd),
  `endif
        .ZN(clkob),     .I(ck_mux)
    );

    assign p_out                =  ck_mux & en_pout ;

endmodule

`timescale 1ns / 1ps 

module gpll_out_duty ( clk_int, clk_div_by_one, clk_int_early, en_out, enabled, out, out_int, outb,
     p_out, rstn_sync_out, vccd, vssd, clk_en, dclk0, dclk1, en_pout,
     enc, load, load_div2, mc1_div2_bypass_n, mc1_div2_phc, mc1_div_en,
     mc1_divc, mc1_divc_outmux, mc1_divc_premux, mc1_duty50_n,
     mc1_duty, mc1_enable_sync, mc1_load_div2_en, mc1_load_en,
     mc1_outgate_en, mc1_phc, mc1_phc_load, out_glitchless_en_n, pd,
     refclk, rstn, sel_clk, vco );

output  clk_int, clk_div_by_one, clk_int_early, en_out, enabled, out, out_int, outb, p_out,
     rstn_sync_out;

inout  vccd, vssd;

input  clk_en, dclk0, dclk1, en_pout, enc, load, load_div2,
     mc1_div2_bypass_n, mc1_div2_phc, mc1_div_en, mc1_divc_outmux,
     mc1_duty50_n, mc1_enable_sync, mc1_load_div2_en, mc1_load_en,
     mc1_outgate_en, out_glitchless_en_n, pd, refclk, rstn, sel_clk,
     vco;

input [6:0]  mc1_phc_load;
input [1:0]  mc1_divc_premux;
input [6:0]  mc1_phc;
input [6:0]  mc1_duty;
input [6:0]  mc1_divc;


//specify 
//    specparam CDS_LIBNAME  = "al7000_gpll";
//    specparam CDS_CELLNAME = "gpll_out_duty";
//    specparam CDS_VIEWNAME = "schematic";
//endspecify

wire        clkmux;

gpll_out_div_duty I0 ( .vssd(vssd), .vccd(vccd),
     .out_glitchless_en_n(out_glitchless_en_n),
     .rstn_sync_out(rstn_sync_out), .mc1_outgate_en(mc1_outgate_en),
     .mc1_load_div2_en(mc1_load_div2_en), .mc1_load_en(mc1_load_en),
     .mc1_phc_load(mc1_phc_load[6:0]), .clk_int(clk_int), .clk_div_by_one(clk_div_by_one), .clk_int_early(clk_int_early),
     .out_int(out_int), .mc1_div2_phc(mc1_div2_phc),
     .load_div2(load_div2), .clk_omux(clkmux),
     .mc1_div_en(mc1_div_en),
     .dclk0(dclk0), .dclk1(dclk1), .load(load),
     .mc1_div2_bypass_n(mc1_div2_bypass_n), .mc1_divc(mc1_divc[6:0]),
     .mc1_divc_premux(mc1_divc_premux[1:0]),
     .mc1_duty50_n(mc1_duty50_n), .mc1_duty(mc1_duty[6:0]),
     .mc1_phc(mc1_phc[6:0]), .refclk(refclk), .rstn(rstn), .vco(vco));

gpll_out_gate I2 ( .en_pout(en_pout), .div_en(mc1_div_en),
     .p_out(p_out), .clkob(outb), .vccd(vccd), .vssd(vssd), .clko(out),
     .mc1_divc_outmux(mc1_divc_outmux), .en_out_sync(en_out), .enable_sync(enabled), .clk(clkmux),
     .clk_enabled(clk_en), .enable(enc), .pd(pd), .rstn(rstn_sync_out),
     .sel_clk(sel_clk), .sel_enable_sync(mc1_enable_sync), .refclk(refclk));

endmodule

`timescale 1ns / 1ps

module gpll_out_en_stdby_ctrl ( pd_clk_main, pd_clk_path, pd_pll2io_n,
    sel_clk_main, sel_clk_path, vccd, vssd, clk_div, done_gwe,
    en_clk_main, en_clk_path, pib_en_pll2io_n, rst_n );
    
    inout                               vccd, vssd;

    output                              pd_clk_main,
                                        pd_pll2io_n,
                                        sel_clk_main;
    output                      [ 7: 0] pd_clk_path;
    output                      [ 7: 0] sel_clk_path;
    
    input                               clk_div,
                                        done_gwe,
                                        en_clk_main,
                                        pib_en_pll2io_n,
                                        rst_n;
    input                       [ 7: 0] en_clk_path;

    wire                                pll2io_en;
    wire                                en_clkout_main_n;
    wire                        [ 7: 0] en_clkout_path_n;
    wire                                clk_div_n;

    assign pll2io_en            = done_gwe & ~pib_en_pll2io_n ;

    //20230405, jzhou, add clk inv on the clk gating control signal's generating DFF,
    //                 to match original schematic
    CLKINV4_140P9T40R u_donttouch_ckinv (
  `ifdef FC_PG_SIM
        .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd),
  `endif
        .ZN(clk_div_n),     .I(clk_div)
    );

    sync_dff u0_sync_dff (
        .clk        (clk_div_n                  ),
        .rst_n      (rst_n                      ),
        .din        (pll2io_en                  ),
        .dout       (pd_pll2io_n                )
    );

    //======================================================
    // pll_out_en_stdby begin

    assign en_clkout_main_n     = ~en_clk_main ;

    assign en_clkout_path_n     = ~en_clk_path ;

    // pll_out_en_stdby end
    //======================================================

    assign pd_clk_main          = en_clkout_main_n ;

    assign pd_clk_path          = en_clkout_path_n ;

    //======================================================
    // pll_out_en_sel begin

    assign sel_clk_main         = en_clk_main ;

    assign sel_clk_path         = en_clk_path ;

    // pll_out_en_sel end
    //======================================================

endmodule

`timescale 1ns / 1ps

module gpll_out_en ( clkc_en, clkc_en_main, vccd, vssd, done_gwe,
    mc1_enclk, mc1_enclk_main, pib_enclk, pib_enclk_main
    );

    inout                               vccd, vssd;

    output                              clkc_en_main;
    output                      [ 7: 0] clkc_en;
    
    input                               done_gwe,
                                        mc1_enclk_main,
                                        pib_enclk_main;
    input                       [ 7: 0] pib_enclk;
    input                       [ 7: 0] mc1_enclk;

    genvar i;
    generate
        for(i=0; i<=7; i=i+1) begin
            assign clkc_en[i]   = mc1_enclk[i]
                                & ~(done_gwe & ~pib_enclk[i]) ;
        end
    endgenerate

    assign clkc_en_main         = mc1_enclk_main
                                & ~(done_gwe & ~pib_enclk_main) ;

endmodule

`timescale 1ns / 1ps

module gpll_out_main ( clk_int, en_out, enabled, out, outb, p_out, vccd,
    vssd, clk_divout, clk_en, en_pout, enc, mc1_clk_mux,
    mc1_enable_sync, pd, refclk, rstn_out, sel_clk );

    inout                               vccd, vssd;

    output                              clk_int,
                                        en_out,
                                        enabled,
                                        out,
                                        outb,
                                        p_out;

    input                               clk_divout,
                                        clk_en,
                                        en_pout,
                                        enc,
                                        mc1_clk_mux,
                                        mc1_enable_sync,
                                        pd,
                                        refclk,
                                        rstn_out,
                                        sel_clk;

    wire                                clkmux;

  //assign clkmux               = mc1_clk_mux ? refclk : clk_divout ;

    assign clk_int              = clk_divout ;

    gpll_out_gate I2 ( .en_pout(en_pout), .div_en(rstn_out), .p_out(p_out),
        .clkob(outb), .vccd(vccd), .vssd(vssd), .clko(out),
        .en_out_sync(en_out), .enable_sync(enabled), .clk(clk_divout),
        .clk_enabled(clk_en), .enable(enc), .pd(pd), .rstn(1'b1),
        .sel_clk(sel_clk), .sel_enable_sync(mc1_enable_sync), .mc1_divc_outmux(mc1_clk_mux), .refclk(refclk));

endmodule

//-----------------------------------------------------------------------------
// Project       : al6100
//-----------------------------------------------------------------------------
// File          : gpll_lockdet.v
// Author        :   jzhou
// Created       : 2021.09
// Last modified : 2021.09
//-----------------------------------------------------------------------------
// Description :
// PLL ref det, band calib & lockdet
//-----------------------------------------------------------------------------
// Copyright (c) 2023 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module gpll_lockdet ( int_lock, lock, sgcc_cal_done, sgcc_vco_band, vccd, vssd,
    ext_lock_en, mc1_cal_counter, done_gwe, rstlock_n,
    mc1_refclk_det_byp, mc1_refclk_det_div, /*mc1_vco_band, mc1_vco_cal_mode,*/
    mc1_gpll_lockdet, vreg_rdy, mc1_pi_delay,
    pfdfbk, pfdref, pib_lockdet_clr_n, pll_cal_rst_n, bandcal_rstn, bandcal1_rstn,
    scan_mode, scan_resetn, scan_enable, scan_clk, scan_in );

    inout                               vssd;
    inout                               vccd;

    output                              sgcc_cal_done;
    output                      [ 3: 0] sgcc_vco_band;
    output                              bandcal_rstn;
    output                              bandcal1_rstn;

    output                              lock;                   // use this pin as GPLL's scan_out
    output                              int_lock;

    input                               pll_cal_rst_n;          //from gpll_ctrl
    input                               vreg_rdy;               //from analog
    input                               pfdref;                 //for 6100, 10~200MHz
    input                               pfdfbk;
    input                       [ 2: 0] mc1_cal_counter;        //from reg, default 3'b0
                                                                //refcnt period
                                                                //[2:1] for last compare & lock det
                                                                //   11: 3200
                                                                //   10: 1600
                                                                //   01:  800
                                                                //   00:  400
                                                                //[0]   for initial count limit
                                                                //    1: count 200
                                                                //    0: count 100
  //input                       [ 3: 0] mc1_vco_band;           //from reg, default 4'b0
  //                                                            //manual setting or
  //                                                            //auto starting value
  //input                               mc1_vco_cal_mode;       //from reg, default 1'b0
  //                                                            //1: manual calib
  //                                                            //0: auto calib
    input                       [ 6: 0] mc1_gpll_lockdet;       //from reg, default 7'b0
                                                                //6   for 6100 fastsim_en
                                                                //    1:  fastsim enable
                                                                //    0:  fastsim disable
                                                                //5:4 cal_rst_n delay ctrl
                                                                //    11: 100M 1000 refclk cycle
                                                                //    10:  70M  700 refclk cycle
                                                                //    01:  40M  400 refclk cycle
                                                                //    00:  10M  200 refclk cycle
                                                                //3:0 lockdet_diff

    input                       [ 1: 0] mc1_pi_delay;           //from reg, default 2'b0
                                                                // delay control from vco mux PI power up to vco mux rstn deassert
                                                                //    11: 48us =2400 @50MHz refclk cycle
                                                                //    10: 36us =1800 @50MHz refclk cycle
                                                                //    01: 24us =1200 @50MHz refclk cycle
                                                                //    00: 12us = 600 @50MHz refclk cycle

    input                               ext_lock_en;
    input                               rstlock_n;
    input                               done_gwe;
    input                               pib_lockdet_clr_n;
    input                       [ 1: 0] mc1_refclk_det_div;     //from reg, default 2'b01
  //input                       [ 2: 0] mc1_lockdet_res_sel;
  //input                               mc1_lockdet_sen_sel;
  //input                               mc1_lockdet_sel;
    input                               mc1_refclk_det_byp;     //from reg, default 1'b0

    input                               scan_mode;
    input                               scan_resetn;
    input                               scan_enable;
    input                               scan_clk;

    input                               scan_in;                // from gpll_ssc
  //output                              scan_out = lock

    parameter C2Q               = 0.04;

//  parameter S_INIT            = 3'b000;
//  parameter S_STEPUP          = 3'b001;        // band step up, rough/fine count
//  parameter S_UPRESULT        = 3'b010;        // check result
//  parameter S_STEPDN          = 3'b011;        // band step down, fine count
//  parameter S_DNRESULT        = 3'b100;        // check result
//  parameter S_CALDONE         = 3'b101;

    parameter S_INIT            = 2'b00;
    parameter S_STEPUPDN        = 2'b01;         // band step up/dn, rough/fine count
    parameter S_RESULT          = 2'b10;         // check result
    parameter S_CALDONE         = 2'b11;

    reg                                 rstSncr1_n;        // 1st stage of synchronizer
    reg                                 rstSncr2_n;        // 2nd stage of synchronizer
    reg                                 rstSncf1_n;        // 1st stage of synchronizer
    reg                                 rstSncf2_n;        // 2nd stage of synchronizer
    reg                         [ 1: 0] calib_st;
    reg                         [ 1: 0] calib_st_next;
    reg                         [14: 0] refcnt;
    reg                         [15: 0] fbcnt;
    reg                         [ 4: 0] waitcnt;
    reg                                 refcntstart;
  //reg                                 finecalib;
  //reg                                 secondfine;
    reg                         [15: 0] deltabuf;        //delta buffer of 1st fine calib
    reg                         [ 3: 0] sg09_vco_band_pre;
    reg                                 fbup_pre;
    reg                                 first_calib;        //first calib cycle not trigger fine calib
    reg                                 fbcntdone;
    reg                                 refcntdone;
    reg                                 waitcntdone;
    reg                         [ 3: 0] sg09_vco_band;
    reg                         [ 9: 0] dly_cnt;
    reg                                 bandcal_rstn;
    reg                                 bandcal1_rstn;
    reg                                 sgcc_cal_done;
  //reg                                 sgcc_cal_done_t;
  //reg                                 sgcc_cal_done_r;
    reg                                 sgcc_cal_done_pre;
    reg                         [11: 0] pi_delay_cnt;

    wire                                rstSncr_n;        //ref clk domain sync rst_n
    wire                                rstSncf_n;        //fbk clk domain sync rst_n
    wire                                refcnt_done;
    wire                                fbcnt_done;
    wire                                fbup;            //fbclk freq should go up
    wire                                fbcntfull;
    wire                                fbcntdone_syncr;
    wire                                fbcntdone_pulser;
    wire                                refcntdone_syncf;
    wire                                refcntdone_pulsef;
    wire                                refcntstart_pulsef;
    wire                                ref_asyncrst_n;
    wire                                fbk_asyncrst_n;
    wire                        [15: 0] deltaf;            //delta absolute value
    wire                                cal_done_syncf;
    wire                                sg09_cal_done_syncf;
    wire                                fbcntdoner_d2;
    wire                                fbcntdone_syncr_pulse;
    wire                                sg09_cal_done;
    wire                        [ 9: 0] dly_cnt_done;
    wire                                calib_start;
    wire                        [ 1: 0] rstn_delay_ctrl;
    wire                                pi_delay_done;
    wire                                finecalib;
    wire                                secondfine;

    //for lockdet
    reg                         [14: 0] ld_refcnt;
    reg                         [15: 0] ld_fbcnt;
    reg                         [ 2: 0] lock_cnt;
    reg                                 lock_sticky;

    wire                                ref_gt_fb;        //ref cnt greater than fb cnt
    wire                        [15: 0] delta_cnt;        //cnt diff absolute value
    wire                                ldt_clr_n_pre;
    wire                                ext_lock_en_pulse;
    wire                                ldt_clr_n;
    wire                                ldt_start;
    wire                                fastsim_en;

    //for refclk det
    reg                         [ 3: 0] ck_div;
    reg                                 din;
    reg                                 detout;

    wire                                fb_clk;
    wire                                ref_clk;
    wire                                ckin;
    wire                                ckin_w;
    wire                                ckin_n;
    wire                                refclk_exist;
  //wire                                rstSncr_n_d2;

    //DFT
    reg                                 scan_out;

    wire                                s_fb_clk;
    wire                                s_ref_clk;
    wire                                s_ckin;
    wire                                s_rstlock_n;
    wire                                s_ckin_n;

    wire                                s_pfdref;
    wire                                s_pfdfbk;
    wire                                s_ref_asyncrst_n;
    wire                                s_fbk_asyncrst_n;
    wire                                s_rstSncr_n;
    wire                                s_rstSncf_n;

    wire                                mc1_vco_cal_mode;
    wire                        [ 3: 0] mc1_vco_band;

    //for 6100 gpll, no need to do band calib
    assign mc1_vco_cal_mode             = 1'b1;
    assign mc1_vco_band                 = 4'b0;
    assign finecalib                    = 1'b1;
    assign secondfine                   = 1'b1;

    assign s_fb_clk                     = scan_mode ? scan_clk    : fb_clk      ;
    assign s_ref_clk                    = scan_mode ? scan_clk    : ref_clk     ;
    assign s_ckin                       = scan_mode ? scan_clk    : ckin        ;
    assign s_rstlock_n                  = scan_mode ? scan_resetn : rstlock_n   ;
    assign s_ckin_n                     = scan_mode ? scan_resetn : ckin_n      ;

    assign s_pfdref                     = scan_mode ? scan_clk    : pfdref;
    assign s_pfdfbk                     = scan_mode ? scan_clk    : pfdfbk;
    assign s_ref_asyncrst_n             = scan_mode ? scan_resetn : ref_asyncrst_n;
    assign s_fbk_asyncrst_n             = scan_mode ? scan_resetn : fbk_asyncrst_n;
    assign s_rstSncr_n                  = scan_mode ? scan_resetn : rstSncr_n;
    assign s_rstSncf_n                  = scan_mode ? scan_resetn : rstSncf_n;

    //======================== pll_refclk_det begin
    //totally copy al006's schematic, do not care timing violations

    assign fb_clk               = ~mc1_refclk_det_byp & pfdfbk ;

    assign ref_clk              = ~mc1_refclk_det_byp & pfdref ;

    always @(posedge s_fb_clk or negedge s_rstlock_n) begin
        if(~s_rstlock_n)
            ck_div              <= #C2Q 4'b0;
        else
            ck_div              <= #C2Q ck_div + 4'b1;
    end

    assign ckin_w               = mc1_refclk_det_div==2'b11 ? ck_div[3]     //div16
                                : mc1_refclk_det_div==2'b10 ? ck_div[2]     //div8
                                : mc1_refclk_det_div==2'b01 ? ck_div[1]     //div4
                                :                             ck_div[0] ;   //div2

    at0012_cell_clk_buf u_donttouch_ckin_buf (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(ckin),     .cin(ckin_w)
    );

    assign #C2Q ckin_n          = ~ckin & rstlock_n ;

    always @(posedge s_ref_clk or negedge s_ckin_n) begin
        if(~s_ckin_n)
            din                 <= #C2Q 1'b0;
        else
            din                 <= #C2Q 1'b1;
    end

    always @(posedge s_ckin or negedge s_rstlock_n) begin
        if(~s_rstlock_n)
            detout              <= #C2Q 1'b0;
        else
            detout              <= #C2Q din;
    end

    assign refclk_exist         = mc1_refclk_det_byp | detout ;

    //======================== pll_refclk_det end

    //20210913, analog designer decided to not reset fbk divider when
    //switching band
  //assign fbk_rst_band_n   = (waitcnt == 5'b0) | (waitcnt[4] == 1'b1);     //waitcnt=1~15

    //sync rstn
//  assign ref_asyncrst_n    = pll_cal_rst_n;

    assign fbk_asyncrst_n       = pll_cal_rst_n  & vreg_rdy & rstlock_n & refclk_exist ;

    assign ref_asyncrst_n       = fbk_asyncrst_n & rstSncf_n ;    //make sure fb rstn released first

  //always @(posedge pfdref or negedge ref_asyncrst_n) begin
  //    if(~ref_asyncrst_n) 
  //        {rstSncr2_n, rstSncr1_n}    <= 2'b0;
  //    else
  //        {rstSncr2_n, rstSncr1_n}    <= {rstSncr1_n, 1'b1};
  //end
  //
  //assign rstSncr_n    = rstSncr2_n;
    sync_dff u_refrstn_gen (
        .clk        (s_pfdref                   ),
        .rst_n      (s_ref_asyncrst_n           ),
        .din        (1'b1                       ),
        .dout       (rstSncr_n                  )
    );

    //delay sync resetn additional 2 cycles to mux out vco_band with stable
    //manual value
  //sync_del #(.DEL_CYCLE(32'd2)) del_reset (                //delay 2 cycle
  //    .clk        (s_pfdref                   ),
  //    .rst_n      (s_rstSncr_n                ),
  //    .en         (1'b1                       ),
  //    .din        (s_rstSncr_n                ),
  //    .dout       (rstSncr_n_d2               )
  //);

  //always @(posedge pfdfbk or negedge pll_cal_rst_n) begin
  //    if(~pll_cal_rst_n) 
  //        {rstSncf2_n, rstSncf1_n}    <= 2'b0;
  //    else
  //        {rstSncf2_n, rstSncf1_n}    <= {rstSncf1_n, 1'b1};
  //end
  //
  //assign rstSncf_n    = rstSncf2_n;
    sync_dff u_fbkrstn_gen (
        .clk        (s_pfdfbk                   ),
        .rst_n      (s_fbk_asyncrst_n           ),
        .din        (1'b1                       ),
        .dout       (rstSncf_n                  )
    );

    assign rstn_delay_ctrl      = mc1_gpll_lockdet[5:4] ;

    //delay at least 10us, then start band calib
    //if use divided ref clk, assume max divided freq is 100MHz
    //counter bit width must be greater than 10us/10ns=1000=10bit
    //20201110, updated to be configurable
    always @(posedge s_pfdref or negedge s_rstSncr_n) begin : DLYCNT
        if(~s_rstSncr_n)
            dly_cnt             <= #C2Q 10'b0;
      //else if(dly_cnt != dly_cnt_done)
        else if(dly_cnt != 10'h3FF)             //stop when all 1
            dly_cnt             <= #C2Q dly_cnt + 10'b1;
    end

    assign fastsim_en           = mc1_gpll_lockdet[6];

//`ifdef PH1P_PLL_V2_FAST_SIM
//  assign dly_cnt_done         =                            10'h03F;
//`elsif SUPER_FAST_SIM
//  assign dly_cnt_done         =                            10'h003;
//`else                                                        //20220604, delay cnt change to 1/4
                                                             //20220605, delay cnt change follow ref freq
    assign dly_cnt_done         = fastsim_en               ? 10'h019
                                : rstn_delay_ctrl == 2'b11 ? 10'h3E7  //100M 1000   //15'h1FFF       //15'h7FFF
                                : rstn_delay_ctrl == 2'b10 ? 10'h2BB  // 70M  700   //15'h0FFF       //15'h3FFF
                                : rstn_delay_ctrl == 2'b01 ? 10'h18F  // 40M  400   //15'h07FF       //15'h1FFF
                                :                            10'h0C7; // 10M  200   //15'h03FF;      //15'h0FFF;
//`endif

    //this is a pulse
    assign calib_start          = dly_cnt == dly_cnt_done ;

    assign ldt_start            = calib_start;

    //calib FSM, working at s_pfdref domain
    always @(posedge s_pfdref or negedge s_rstSncr_n) begin
        if(~s_rstSncr_n)
            calib_st            <= #C2Q S_INIT;
        else if(mc1_vco_cal_mode)
            calib_st            <= #C2Q S_CALDONE;        //S_INIT;
        else if(calib_start)
            calib_st            <= #C2Q calib_st_next;
    end

    always @(*) begin : _10_calib_FSM
        calib_st_next        = calib_st;
        case(calib_st)
            S_INIT:
                calib_st_next    = S_STEPUPDN;

        //  S_STEPUP:
        //      if(refcntdone)
        //          calib_st_next    = S_UPRESULT;

        //  S_UPRESULT:
        //      if     (fbcntdone_syncr & finecalib)
        //          calib_st_next    = S_CALDONE;
        //      else if(fbcntdone_syncr & fbup)
        //          calib_st_next    = S_STEPUP;
        //      else if(fbcntdone_syncr & !fbup)
        //          calib_st_next    = S_STEPDN;

        //  S_STEPDN:
        //      if(refcntdone)
        //          calib_st_next    = S_DNRESULT;

        //  S_DNRESULT:
        //      if(fbcntdone_syncr)
        //          calib_st_next    = S_STEPUP;

            S_STEPUPDN:
                if(refcntdone)
                    calib_st_next    = S_RESULT;

            S_RESULT:
                if     (fbcntdone_syncr & finecalib & secondfine)
                    calib_st_next    = S_CALDONE;
                else if(fbcntdone_syncr)
                    calib_st_next    = S_STEPUPDN;

            S_CALDONE:
                calib_st_next    = S_CALDONE;
        endcase
    end // _10_calib_FSM

    assign sg09_cal_done        = ( calib_st == S_CALDONE | mc1_vco_cal_mode )
                                & pll_cal_rst_n;

  //assign sgcc_cal_done        = sg09_cal_done ;
    //make pfd/fracN/vcomux/ssc work 2 cycles after fbkdiv/output
    always @(posedge s_pfdref or negedge s_rstSncr_n) begin
        if(~s_rstSncr_n) begin
          //sgcc_cal_done_pre   <= #C2Q 1'b0;
            sgcc_cal_done       <= #C2Q 1'b0;
        end
      //else if(   sg09_cal_done & waitcnt==5'h1F & bandcal_rstn & ~sgcc_cal_done
      //        || mc1_vco_cal_mode ) begin
        else if(   pi_delay_done    ) begin
          //sgcc_cal_done_pre   <= #C2Q 1'b1;
          //sgcc_cal_done_pre   <= #C2Q bandcal_rstn;
            sgcc_cal_done       <= #C2Q 1'b1;
        end
    end

    //the delay cnt to deassert vco_mux rstn after vco_mux power up
    always @(posedge s_pfdref or negedge s_rstSncr_n) begin
        if(~s_rstSncr_n)
            pi_delay_cnt        <= #C2Q 12'b0;
        else if(pi_delay_cnt!=12'hFFF && waitcntdone)
            pi_delay_cnt        <= #C2Q pi_delay_cnt + 12'b1;
    end

    assign pi_delay_done        = fastsim_en            ? (pi_delay_cnt == 12'd18  )
                                : mc1_pi_delay == 2'b11 ? (pi_delay_cnt == 12'd2400)
                                : mc1_pi_delay == 2'b10 ? (pi_delay_cnt == 12'd1800)
                                : mc1_pi_delay == 2'b01 ? (pi_delay_cnt == 12'd1200)
                                :                         (pi_delay_cnt == 12'd600 ) ;

    //use pfdfbk negedge to sync refclk domain signal and drive out caldone
    //so that fbk mux btw integer/fracN divider will not generate glitch
  //always @(negedge s_pfdfbk or negedge s_rstSncf_n) begin
  //    if(~s_rstSncf_n) begin
  //        sgcc_cal_done_t     <= #C2Q 1'b0;
  //        sgcc_cal_done       <= #C2Q 1'b0;
  //    end
  //    else begin
  //        sgcc_cal_done_t     <= #C2Q sgcc_cal_done_r;
  //        sgcc_cal_done       <= #C2Q sgcc_cal_done_t;
  //    end
  //end

    // THE LockDet brief Sequence
    // fbcnt started anyway after reset
    // the first refcnt start trigger is ldt_start pulse
    // after the first trigger, refcntstart asserted, refcnt start counting
    // refcntdone assert --> refcntdone_syncf assert --> stop fbcnt
    //                   |                           |
    //                   |-> clear refcntstart       |
    //                   |-> stop  refcnt            |-> fbcntdone_syncr asserted  -----------------------------------> fbcntdoner_d2 asserted --> refcntstart asserted
    //                                                                             |                                                           |                      then refcnt start counting
    //                                                                             |                                                           |                      when limit reached, loop back
    //                                                                             |                                                           |                      to refcntdone assert
    //                                                                             |                                                           |
    //                                                                             |                                                           |-> refcntstart_pulsef to clear fbcnt
    //                                                                             |                                                                                  then fbcnt start counting
    //                                                                             |
    //                                                                             |-> fbcntdone_syncr_pulse --> clear refcntdone
    //                                                                                                       |-> clear refcnt
    //                                                                                                       |
    //                                                                                                       |-> lock gen decide

    always @(posedge s_pfdref or negedge s_rstSncr_n) begin
        if(~s_rstSncr_n)
            refcntstart         <= #C2Q 1'b0;
        else if(refcntdone)
            refcntstart         <= #C2Q 1'b0;    //clear  start toggle
    //  else if(fbcntdone_syncr           && calib_st != S_DNRESULT ||
    //      calib_st_next == S_STEPUP && calib_st == S_INIT        )
        //ref cnt start trigger
      //else if ( (waitcntdone   & ~sgcc_cal_done) ||               //during calib
      //          (fbcntdoner_d2 &  sgcc_cal_done)    )             //after  calib done
      //else if (fbcntdoner_d2 | ldt_start)
        else if (fbcntdoner_d2 | pi_delay_done)
            refcntstart         <= #C2Q 1'b1;    //assert start toggle
    end

    always @(posedge s_pfdref or negedge s_rstSncr_n) begin : REFCNT
        if(~s_rstSncr_n)
            refcnt              <= #C2Q 15'b0;
        else if((calib_st == S_RESULT)  && fbcntdone_syncr ||
                (calib_st == S_CALDONE) && fbcntdone_syncr_pulse)
            refcnt              <= #C2Q 15'b0;
        else if(~refcntdone && refcntstart)
            refcnt              <= #C2Q refcnt + 15'b1;
    end

    always @(posedge s_pfdref or negedge s_rstSncr_n) begin
        if(~s_rstSncr_n)
            refcntdone          <= #C2Q 1'b0;
        else if((calib_st == S_RESULT)  && fbcntdone_syncr        ||
                (calib_st == S_CALDONE) && fbcntdone_syncr_pulse)
            refcntdone          <= #C2Q 1'b0;
        else if(~refcntdone) begin
            if(fastsim_en)
                refcntdone      <= #C2Q                                                                      refcnt == 15'h007E;
              //refcntdone      <= #C2Q                        (finecalib | mc1_vco_cal_mode)              ? refcnt == 15'h007E
              //                :                                                                            refcnt == 15'h003E;
              //`elsif SUPER_FAST_SIM
              //refcntdone      <= #C2Q                        (finecalib | mc1_vco_cal_mode)              ? refcnt == 15'h0007
              //                :                                                                            refcnt == 15'h0004;
            else
              //refcntdone      <= #C2Q {mc1_cal_counter[2:1], (finecalib | mc1_vco_cal_mode) } == 3'b001  ? (refcnt == 15'h0FFE)    //  4096
              //                :       {mc1_cal_counter[2:1], (finecalib | mc1_vco_cal_mode) } == 3'b011  ? (refcnt == 15'h1FFE)    //  8192
              //                :       {mc1_cal_counter[2:1], (finecalib | mc1_vco_cal_mode) } == 3'b101  ? (refcnt == 15'h3FFE)    // 16384
              //                :       {mc1_cal_counter[2:1], (finecalib | mc1_vco_cal_mode) } == 3'b111  ? (refcnt == 15'h7FFE)    // 32768
              //                :       {mc1_cal_counter[2:1],  finecalib,  mc1_cal_counter[0] }== 4'b0000 ? (refcnt == 15'h01FE)    //   512
              //                :                                                                            (refcnt == 15'h03FE);   //  1024
              //20220604, jzhou, discussed with Xiaofeng, make lock work faster to within 300us(band cal + lock det, ref min freq is 10MHz)
              //          300us is eqal at least 3000 cycles for 10MHz refclk
              //refcntdone      <= #C2Q {mc1_cal_counter[2:1], (finecalib | mc1_vco_cal_mode) } == 3'b001  ? (refcnt == 15'h018F)    //   400
              //                :       {mc1_cal_counter[2:1], (finecalib | mc1_vco_cal_mode) } == 3'b011  ? (refcnt == 15'h031F)    //   800
              //                :       {mc1_cal_counter[2:1], (finecalib | mc1_vco_cal_mode) } == 3'b101  ? (refcnt == 15'h063F)    //  1600
              //                :       {mc1_cal_counter[2:1], (finecalib | mc1_vco_cal_mode) } == 3'b111  ? (refcnt == 15'h0C7F)    //  3200
              //                :       {                       finecalib,  mc1_cal_counter[0]} == 2'b00   ? (refcnt == 15'h0063)    //   100
              //                :                                                                            (refcnt == 15'h00C7);   //   200
                refcntdone      <= #C2Q  mc1_cal_counter[2:1]                                   == 2'b00   ? (refcnt == 15'h018F)    //   400
                                :        mc1_cal_counter[2:1]                                   == 2'b01   ? (refcnt == 15'h031F)    //   800
                                :        mc1_cal_counter[2:1]                                   == 2'b10   ? (refcnt == 15'h063F)    //  1600
                                :                                                                            (refcnt == 15'h0C7F);   //  3200
        end
    end


    //wait several cycles for new vco band to be stable
    always @(posedge s_pfdref or negedge s_rstSncr_n) begin
        if(~s_rstSncr_n)
            waitcnt             <= #C2Q 5'b0;
      //else if((calib_st == S_RESULT) && fbcntdone_syncr)
      //    waitcnt             <= #C2Q 5'b0;
      //else if((calib_st == S_STEPUPDN || calib_st == S_CALDONE) && ~waitcntdone)
        else if((calib_start            || waitcnt  != 5'b0     ) && ~waitcntdone)
            waitcnt             <= #C2Q waitcnt + 5'b1;
    end

    //when EN_TRANS_UNCERT sim option enabled, find a bug
    //that fbcnt not clear after refcnt started
    //so make waitcnt fixed larger value, 20201126
//  assign waitcntdone    = first_calib ? waitcnt == 4'b1111
//                        :               waitcnt == 4'b0111;
//  assign waitcntdone    =               waitcnt == 4'b1111;
    //20210324, change waitcntdone from wire to reg, to avoid CDC issue
    always @(posedge s_pfdref or negedge s_rstSncr_n) begin
        if(~s_rstSncr_n)
            waitcntdone         <= #C2Q 1'b0;
      //else if((calib_st == S_RESULT) && fbcntdone_syncr)
      //    waitcntdone         <= #C2Q 1'b0;
        else if(~waitcntdone)
            waitcntdone         <= #C2Q waitcnt == 5'b1_1110;
    end

    always @(posedge s_pfdref or negedge s_rstSncr_n) begin
        if(~s_rstSncr_n) begin
            bandcal_rstn        <= #C2Q 1'b1;   //default value must be 1, otherwise
                                                //no fbkclk, then "rstSncf_n"
                                                //always keep low
            bandcal1_rstn       <= #C2Q 1'b0;
        end
        //waitcnt=2~16
        else if(waitcnt==5'b0_0001)
            bandcal_rstn        <= #C2Q 1'b0;
        else if(waitcnt[4]==1'b1) begin
            bandcal_rstn        <= #C2Q 1'b1;
            bandcal1_rstn       <= #C2Q 1'b1;
        end
    end

  //always @(posedge s_pfdref or negedge s_rstSncr_n) begin : _20_band_gen
  //    if(~s_rstSncr_n) begin
  //        sg09_vco_band       <= #C2Q 4'b0;
  //        sg09_vco_band_pre   <= #C2Q 4'b0;
  //        finecalib           <= #C2Q 1'b0;
  //        secondfine          <= #C2Q 1'b0;
  //        fbup_pre            <= #C2Q 1'b0;
  //    end
  //    //when manual calib mode, or INIT state, set starting value from reg
  //    else if(calib_st == S_INIT || mc1_vco_cal_mode)
  //        sg09_vco_band       <= #C2Q mc1_vco_band;
  //    //deltabuf is the diff of first fine calib
  //    //if 1st fine calib diff is greater than 2nd, keep current value
  //    //else we need to bring back previous value
  //    //    assume fbup must be a reverse value of fbup_pre
  //    //    so if fbup is 1, means fbup_pre is 0, add 1 to current value
  //    //    OR we just buffer previous value
  //    else if(refcntdone & fbcntdone_syncr & calib_st_next == S_CALDONE
  //                                         & ~sg09_cal_done             ) //dont update band value during lockdet
  //        sg09_vco_band       <= #C2Q (deltabuf > deltaf) ? sg09_vco_band
  //                            :                             sg09_vco_band_pre;
  //            //              :        fbup               ? sg09_vco_band + 5'b1
  //            //              :                             sg09_vco_band - 5'b1;
  //    else if(refcntdone & fbcntdone_syncr & ~sg09_cal_done) begin        //dont update band value during lockdet
  //        fbup_pre            <= #C2Q fbup;
  //        secondfine          <= #C2Q finecalib;
  //        sg09_vco_band_pre   <= #C2Q sg09_vco_band;
  //        if(fbup)
  //            //overflow  protection added
  //            sg09_vco_band   <= #C2Q sg09_vco_band + ((&sg09_vco_band) ? 4'b0 : 4'b1);
  //        else
  //            //underflow protection added
  //            sg09_vco_band   <= #C2Q sg09_vco_band - ((|sg09_vco_band) ? 4'b1 : 4'b0);

  //        if(fbup ^ fbup_pre ||                           //direction reverse
  //           (sg09_vco_band == sg09_vco_band_pre) )       //overflow/underflow
  //            finecalib       <= #C2Q ~first_calib;
  //    end
  //end

  //assign sgcc_vco_band        = rstSncr_n_d2 ? sg09_vco_band
  //                            :                mc1_vco_band   ;
    assign sgcc_vco_band        =                mc1_vco_band   ;

    //first calib cycle does not trigger fine calib
  //always @(posedge s_pfdref or negedge s_rstSncr_n) begin
  //    if(~s_rstSncr_n)
  //        first_calib         <= #C2Q 1'b1;
  //    else if(refcntdone & fbcntdone_syncr)
  //        first_calib         <= #C2Q 1'b0;
  //end

    //deltabuf is the diff of first fine calib
  //always @(posedge s_pfdref or negedge s_rstSncr_n) begin
  //    if(~s_rstSncr_n)
  //        deltabuf            <= #C2Q 16'b0;
  //    else if(refcntdone & fbcntdone_syncr & finecalib & ~secondfine)
  //        deltabuf            <= #C2Q deltaf;
  //end

    st2p u1_ref2fb_st2p (
        .clk        (s_pfdfbk                   ),
        .rst_n      (s_rstSncf_n                ),
    //  .din        (refcntstart                ),
        .din        ((waitcntdone & ~sgcc_cal_done) ||      //during calib
                      fbcntdoner_d2 ),                      //after  calib done
        .dout       (refcntstart_pulsef         )           //pulse, to clr fbcnt
    );

    sync_dff u2_ref2fb_dff (
        .clk        (s_pfdfbk                   ),
        .rst_n      (s_rstSncf_n                ),
        .din        (refcntdone                 ),
        .dout       (refcntdone_syncf           )
    );

    sync_dff u3_fb2ref_dff (
        .clk        (s_pfdref                   ),
        .rst_n      (s_rstSncr_n                ),
        .din        (refcntdone_syncf           ),
                  //|fbcntdone                  ),    //when manual control, need to generate  a pulse
        .dout       (fbcntdone_syncr            )
    );

//    sync_dff u4_ref2fb_dff (
//      .clk        (s_pfdfbk                   ),
//      .rst_n      (s_rstSncf_n                ),
//      .in         (sg09_cal_done              ),
//      .out        (sg09_cal_done_syncf        )
//    );

    sync_del #(.DEL_CYCLE(32'd2)) u5_del_fbcntdoner (                //delay one cycle
        .clk        (s_pfdref                   ),
        .rst_n      (s_rstSncr_n                ),
        .en         (1'b1                       ),
        .din        (fbcntdone_syncr            ),
        .dout       (fbcntdoner_d2              )
    );

    pulse u6_pulse_fbcntdone (
        .clk        (s_pfdref                   ),
        .rst_n      (s_rstSncr_n                ),
        .din        (fbcntdone_syncr            ),
        .dout       (fbcntdone_syncr_pulse      )
    );

    assign ldt_clr_n_pre        = ~(~pib_lockdet_clr_n & done_gwe) ;

    sync_dff u7_ext2ref_dff (
        .clk        (s_pfdref                   ),
        .rst_n      (s_rstSncr_n                ),
        .din        (ldt_clr_n_pre              ),
        .dout       (ldt_clr_n                  )
    );

    st2p u8_ext2ref_st2p (
        .clk        (s_pfdref                   ),
        .rst_n      (s_rstSncr_n                ),
        .din        (ext_lock_en                ),
        .dout       (ext_lock_en_pulse          )
    );

    always @(posedge s_pfdfbk or negedge s_rstSncf_n) begin : FBCNT
        if(~s_rstSncf_n)
            fbcnt               <= #C2Q 16'b0;
        else if(refcntstart_pulsef)            // | mc1_vco_cal_mode)
            fbcnt               <= #C2Q 16'b0;
        else if(~refcntdone_syncf)                  //for auto   mode
             //&~fbcntdone)                         //for manual mode
            fbcnt               <= #C2Q fbcnt + 16'b1;
    end

//  always @(posedge s_pfdfbk or negedge s_rstSncf_n) begin
//      if(~s_rstSncf_n)
//          fbcntdone           <= #C2Q 1'b0;
//      else if(refcntstart_pulsef)
//          fbcntdone           <= #C2Q 1'b0;
//      else if(mc1_vco_cal_mode & ~fbcntdone)begin
//`ifdef PH1P_PLL_V2_FAST_SIM
//          fbcntdone           <= #C2Q (fbcnt == 16'h1FFE);
//`else
//          fbcntdone           <= #C2Q (fbcnt == 16'hFFFE);
//`endif
//      end
//  end

//    assign fbcntdone    = fbcntfull & mc1_vco_cal_mode;    //when manual control, need to generate  a pulse

    assign fbup                 = {1'b0, refcnt} > {fbcnt};

    assign deltaf               = fbup ? ({1'b0, refcnt} - fbcnt         )
                                       : (       fbcnt   - {1'b0, refcnt});

    //lockdet logic =========================================================
    always @(posedge s_pfdref or negedge s_rstSncr_n) begin : _30_lock_det
        if(~s_rstSncr_n)
            lock_cnt            <= #C2Q 3'b0;
        //use ldt_clr_n to reset lock_cnt, it's possible the first
        //lock_cnt will not cover a full lock det period, but I think it's OK
        //20220606, jzhou, also use "ext_lock_en" pos edge pulse to reset lock_cnt
        else if(~ldt_clr_n | ext_lock_en_pulse)
            lock_cnt            <= #C2Q 3'b0;
        else if(fbcntdone_syncr_pulse & sg09_cal_done) begin    //only when calib_done asserted, can lockdet start
            lock_cnt[2:1]       <= #C2Q lock_cnt[1:0];
        //  lock_cnt[0]         <= #C2Q (deltaf <= 16'd3);
            lock_cnt[0]         <= #C2Q (deltaf <= {12'b0, mc1_gpll_lockdet[3:0]});
        end
    end

  //assign lock                 = mc1_gpll_lockdet[6] ? fbup
  //                            :                       sg09_cal_done & (&lock_cnt);
    assign lock                 =                       sg09_cal_done & (&lock_cnt);

    always @(posedge s_pfdref or negedge s_rstSncr_n) begin
        if(~s_rstSncr_n)
            lock_sticky         <= #C2Q 1'b0;
      //else if(~ext_lock_en_sync)
      //make lock_sticky assert the same time as lock
        else if(fbcntdone_syncr_pulse & sg09_cal_done & ~lock_sticky)
            lock_sticky         <= #C2Q (&lock_cnt[1:0]) & (deltaf <= {12'b0, mc1_gpll_lockdet[3:0]});
    end

  //assign int_lock             = ext_lock_en_sync ? lock_sticky
  //assign int_lock             = ext_lock_en      ? lock_sticky
  //                            :                    lock ;
    assign int_lock             =                    lock_sticky ;

    //for DFT observability, XOR all output which are not observable
    //(only wire need, reg already observable)
  //always @(posedge scan_clk or negedge scan_resetn) begin
  //    if(~scan_resetn)
  //        scan_out        <= 1'b0;
  //    else
  //        scan_out        <= sgcc_cal_done ^ int_lock ;
  //end

endmodule

//-----------------------------------------------------------------------------
// Project       : al6100
//-----------------------------------------------------------------------------
// File          : gpll_fbdiv_dig.v
// Author        :   jzhou
// Created       : 2022.11
// Last modified : 2022.11
//-----------------------------------------------------------------------------
// Description :
// feed back clk divider, including FracN & SSC
//-----------------------------------------------------------------------------
// Copyright (c) 2023 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module gpll_fbdiv_dig ( 
    output              [ 7: 0] fb_divn_dig, 
    output              [ 5: 0] fb_pi_dig, 
    output              [ 2: 0] fracn_c_sum, 

    //debug
    output                      fracn_prbs_out,  
    output                      ssc_mod_clk, 
    output                      ssc_signal_bit, 

    // no loading
    output              [ 7: 0] fb_divn_probe, 
    output              [23: 0] fb_fracn_probe, 
    output              [29: 0] ssc_cnt,

    input                       fracn_rstn,             //to be sync
    input                       ck_dig, 
    input               [ 7: 0] fb_divn, 
    input               [27: 0] fb_fracn, 
    input                       fracn_dither_en, 
    input               [ 3: 0] fracn_dither_sel, 
    input                       fracn_en,               //to be sync
    input               [ 1: 0] fracn_prbs_sel,  

    input                       ssc_rstn,
    input                       ssc_dn_loop_mode, 
    input                       ssc_en, 
    input               [17: 0] ssc_freq_div, 
    input               [ 1: 0] ssc_lpf_sel, 
    input                       ssc_mode,  
    input               [23: 0] ssc_step,

    //scan mode
    input                       scan_mode,
    input                       scan_resetn,
    input                       scan_enable,
    input                       scan_clk,

    input                       scan_in,                // from axis2apb
    output                      scan_out,               // to   lockdet

    input                       vccd, 
    input                       vssd
);

    wire                        s_ck_dig;
    wire                        s_fracn_rstn;
    wire                        s_ssc_rstn;
    wire                [27: 0] fbdiv_fracn_out;

    assign s_ck_dig                     = scan_mode ? scan_clk    : ck_dig      ;
    assign s_fracn_rstn                 = scan_mode ? scan_resetn : fracn_rstn  ;
    assign s_ssc_rstn                   = scan_mode ? scan_resetn : ssc_rstn    ;

    assign fb_fracn_probe               = fbdiv_fracn_out[27:4];

gpll_fbdiv_dig_sdm x_al6100_gpll_fbdiv_dig_sdm ( 
    .fracn_dither_sel(fracn_dither_sel), .fracn_en(fracn_en), 
    .fracn_prbs_sel(fracn_prbs_sel), .sdm_clk(s_ck_dig), 
    .sdm_rstn(s_fracn_rstn), .vssd(vssd), .vccd(vccd), 
    .fb_divn_out(fb_divn_dig), .fracn_c_sum(fracn_c_sum), 
    .fb_fracn_in(fbdiv_fracn_out), .fracn_dither_en(fracn_dither_en), 
    .fracn_prbs_out(fracn_prbs_out), .fb_divn_in(fb_divn_probe), 
    .fb_pi_out(fb_pi_dig));

gpll_fbdiv_dig_ssc x_al6100_gpll_fbdiv_dig_ssc ( 
    .ssc_step(ssc_step), .ssc_signal_bit(ssc_signal_bit), 
    .fracn_en(fracn_en), /*.ssc_ext_freq_valid(fb_valid), */
    .ssc_ext_freq_fracn(fb_fracn), .ssc_lpf_sel(ssc_lpf_sel), 
    .ssc_cnt(ssc_cnt), .ssc_freq_div(ssc_freq_div), 
    .ssc_mode(ssc_mode), .ssc_rstn(s_ssc_rstn), .vccd(vccd), 
    .ssc_ext_freq_intn(fb_divn), .fbdiv_fracn_out(fbdiv_fracn_out), 
    .fbdiv_int_out(fb_divn_probe), .ssc_mod_clk(ssc_mod_clk), 
    .ssc_clk(s_ck_dig), .ssc_dn_loop_mode(ssc_dn_loop_mode), 
    .ssc_en(ssc_en), .scan_mode(scan_mode), .vssd(vssd));

endmodule

//-----------------------------------------------------------------------------
// Project       : al6100
//-----------------------------------------------------------------------------
// File          : gpll_fbdiv_dig_sdm.v
// Author        :   jzhou
// Created       : 2022.11
// Last modified : 2022.11
//-----------------------------------------------------------------------------
// Description :
// FracN divider
//-----------------------------------------------------------------------------
// Copyright (c) 2023 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module gpll_fbdiv_dig_sdm (
vccd, 
vssd, 

sdm_clk, 
sdm_rstn,

fb_divn_in,
fb_fracn_in,
fb_divn_out,
fb_pi_out, 

fracn_en,
fracn_dither_en, 
fracn_prbs_sel, 
fracn_dither_sel, 
fracn_prbs_out,
fracn_c_sum 
);

// IO list 
  input vssd;								//
  input vccd;								//

  input fracn_en;							// 	reset fracn
  input fracn_dither_en;					// 	reset dither

  input sdm_rstn;							// 	reset all block
  input sdm_clk;							// 	farcn clk

  input  [ 7:0] fb_divn_in;					//	divder-n pre-set
  input  [27:0]	fb_fracn_in;				//	6bit pi code 18bit SDM code

  input  [ 1:0] fracn_prbs_sel;				//	prbs select 7/15/23/31
  input  [ 3:0] fracn_dither_sel;			//	

  output [ 7:0] fb_divn_out;				//	divder-n real-time code
  output [ 5:0] fb_pi_out;					//	pi-code real-time code

  output [ 2:0] fracn_c_sum;				//	SDM real-time code
  output 		fracn_prbs_out;				//	for-example prbs7 2exp6/2exp7 -1 

// Signal list

    reg  [ 7:0] divn_reg;
    reg  [ 5:0] fb_pi_out;

    reg  [27:0] fracn_in;
    reg  [21:0] fracn_add1_r;
    reg         fracn_add1_r_c;
    reg  [21:0] fracn_add2_r;
    reg         fracn_add2_r_c;
    reg         fracn_add2_r_c_d1;
    reg  [ 2:0] fracn_c_sum;

    reg  [ 5:0] fracn_plus_mash;   //
    reg  [ 1:0] fracn_plus_mash_c;   		// -1, 0, 1
    reg  [ 1:0] fracn_plus_mash_c_d;

    reg  [ 5:0] fracn_acc;           		// accumulated frac
    reg         fracn_acc_c;
    reg  [ 5:0] fracn_acc_d;
    reg  [ 5:0] fracn_acc_d1;
    reg  [ 5:0] fracn_acc_d2;				//update in 2021/12/20 to add sync in fbdiv

    reg  [30:0] fracn_prbs_tap;

    reg  [ 5:0] fracn_in_msb_d1;
    reg  [ 5:0] fracn_in_msb_d2;

    wire [28:0] fracn_in_buffer;
    wire [ 5:0] fracn_in_msb;				//change from 64 [5:0]
    wire [21:0] fracn_in_lsb;				//change from    [17:0]
    wire [21:0] fracn_add1;
    wire        fracn_add1_c;
    wire [21:0] fracn_add2;
    wire        fracn_add2_c;

    wire [ 9:0] fracn_dither;
    wire        fracn_prbs_out;

	//=====================================================
	// dither adder to sdm code
	// highest bit is carry, if carry=1, means overflow, then do not add dither
    assign fracn_in_buffer              = {1'b0, fb_fracn_in[27:0]} + {19'b0, fracn_dither[9:0]};

	//=====================================================
	//reset logic
    always @(posedge sdm_clk or negedge sdm_rstn) begin
        if(~sdm_rstn)
            fracn_in        <= 28'b0;
        else if(fracn_dither_en && ~fracn_in_buffer[28])
            fracn_in        <= fracn_in_buffer[27:0];
        else
            fracn_in        <= fb_fracn_in;
    end

    assign fracn_in_msb                 = fracn_in[27:22];  // 6bits
    assign fracn_in_lsb                 = fracn_in[21: 0];  //22bits

    //======================================================
    // MASH11 begin
	//			1bit		22bit			1bit	 22bit        1bit     22bit
    assign {fracn_add1_c, fracn_add1}   = {1'b0, fracn_add1_r} + {1'b0, fracn_in_lsb};
	//
    always @(posedge sdm_clk or negedge sdm_rstn) begin
        if(~sdm_rstn) begin
            fracn_add1_r    <= 22'b0;
            fracn_add1_r_c  <=  1'b0;
        end
        else if(fracn_en) begin 
            {fracn_add1_r_c, fracn_add1_r}  <= {fracn_add1_c, fracn_add1};
        end
    end
	// 		  1bit		    22bit	 	   1bit		  22bit	 	   1bit		22bit	
    assign {fracn_add2_c, fracn_add2}   = {1'b0, fracn_add2_r} + {1'b0, fracn_add1};
	// 
    always @(posedge sdm_clk or negedge sdm_rstn) begin
        if(~sdm_rstn) begin
            fracn_add2_r    	<= 22'b0;
            fracn_add2_r_c  	<=  1'b0;
            fracn_add2_r_c_d1 	<=  1'b0;
        end
        else if(fracn_en) begin
            {fracn_add2_r_c, fracn_add2_r}  <= {fracn_add2_c, fracn_add2};
            fracn_add2_r_c_d1               <= fracn_add2_r_c;
        end
    end
	//
    always @(posedge sdm_clk or negedge sdm_rstn) begin : MASH11_GEN
        if(~sdm_rstn)
            fracn_c_sum     <= 3'b0;                        // this is the MASH11's output
        else if(fracn_en)                              		// can be and only be -1, 0, 1, 2
            fracn_c_sum     <= {2'b0, fracn_add1_r_c} +
                               {2'b0, fracn_add2_r_c} -
                               {2'b0, fracn_add2_r_c_d1}  ;
    end

    // MASH11 end
    //======================================================

    always @(posedge sdm_clk or negedge sdm_rstn) begin
        if(~sdm_rstn) begin
            fracn_in_msb_d1     <= 6'b0;
            fracn_in_msb_d2     <= 6'b0;
        end
        else if(fracn_en) begin
            fracn_in_msb_d1     <= fracn_in_msb;
            fracn_in_msb_d2     <= fracn_in_msb_d1;
        end
    end

    // first adder after MASH11
    always @(posedge sdm_clk or negedge sdm_rstn) begin
        if(~sdm_rstn) begin
            fracn_plus_mash      <= 6'b0;
            fracn_plus_mash_c    <= 2'b0;
            fracn_plus_mash_c_d  <= 2'b0;	
        end
        else if(fracn_en) begin
			// 2bits+6bits                                      6bits SDM    +       complement      3bits    
            {fracn_plus_mash_c, fracn_plus_mash}  <= {2'b0, fracn_in_msb_d2} + {{5{fracn_c_sum[2]}}, fracn_c_sum};
            fracn_plus_mash_c_d                   <= fracn_plus_mash_c;
        end
    end

    // second adder after MASH11(accumulator)
    // one more delay required by analog designer, frac_acc_d1
    always @(posedge sdm_clk or negedge sdm_rstn) begin 
        if(~sdm_rstn) begin
            fracn_acc            		<= 6'b0;
            fracn_acc_d          		<= 6'b0;
            fracn_acc_d1         		<= 6'b0;
            fracn_acc_d2         		<= 6'b0;
            fracn_acc_c          		<= 1'b0;
        end
        else if(fracn_en) begin
			//   6bits						   original         7bits=1bits+6bits
            {fracn_acc_c, fracn_acc}    <= {1'b0, fracn_acc} + {1'b0, fracn_plus_mash};
            fracn_acc_d                 <= fracn_acc;            //one additional cycle delay needed
            fracn_acc_d1                <= fracn_acc_d;
            fracn_acc_d2                <= fracn_acc_d1;
        end
    end

    // integer part generation
    always @(posedge sdm_clk or negedge sdm_rstn) begin 
        if(~sdm_rstn) begin
            divn_reg      <= 8'b0001_0000;
        end
        else if(fracn_en) begin
			// 8bits            // phase accumulation    complement                  6bit +    2bits   SDM
            divn_reg     <= fb_divn_in + {7'b0 , fracn_acc_c}  + {{6{fracn_plus_mash_c_d[1]}}, fracn_plus_mash_c_d};
        end
    end

    // bypass cpll_intn_reg
    assign fb_divn_out        =  fracn_en ? divn_reg : fb_divn_in;

    // fracn part gen
    always @(posedge sdm_clk or negedge sdm_rstn) begin
        if(~sdm_rstn) begin
            fb_pi_out   <= 6'b0;
        end
        else if(fracn_en) begin
		// 64 to 32 need change
            fb_pi_out   <= fracn_acc_d2[5:0];
        end
    end

    //dither gen
    assign fracn_dither            = fracn_dither_sel == 4'd9 ? {      fracn_prbs_out, 9'b0}
                                   : fracn_dither_sel == 4'd8 ? {1'b0, fracn_prbs_out, 8'b0}
                                   : fracn_dither_sel == 4'd7 ? {2'b0, fracn_prbs_out, 7'b0}
                                   : fracn_dither_sel == 4'd6 ? {3'b0, fracn_prbs_out, 6'b0}
                                   : fracn_dither_sel == 4'd5 ? {4'b0, fracn_prbs_out, 5'b0}
                                   : fracn_dither_sel == 4'd4 ? {5'b0, fracn_prbs_out, 4'b0}
                                   : fracn_dither_sel == 4'd3 ? {6'b0, fracn_prbs_out, 3'b0}
                                   : fracn_dither_sel == 4'd2 ? {7'b0, fracn_prbs_out, 2'b0}
                                   : fracn_dither_sel == 4'd1 ? {8'b0, fracn_prbs_out, 1'b0}
                                   : fracn_dither_sel == 4'd0 ? {9'b0, fracn_prbs_out      }
                                   :                            {9'b0, fracn_prbs_out      } ;

    //prbs7/15/23/31
    always @(posedge sdm_clk or negedge sdm_rstn) begin
        if(~sdm_rstn)
            fracn_prbs_tap            <= 31'b0;
        else if(fracn_dither_en) begin
            if     (fracn_prbs_sel==2'd0)
                fracn_prbs_tap            <= {fracn_prbs_tap[30: 7], fracn_prbs_tap[ 5:0], ~(fracn_prbs_tap[ 6]^fracn_prbs_tap[ 5])};  //prbs7
            else if(fracn_prbs_sel==2'd1)
                fracn_prbs_tap            <= {fracn_prbs_tap[30:15], fracn_prbs_tap[13:0], ~(fracn_prbs_tap[14]^fracn_prbs_tap[13])};  //prbs15
            else if(fracn_prbs_sel==2'd2)
                fracn_prbs_tap            <= {fracn_prbs_tap[30:23], fracn_prbs_tap[21:0], ~(fracn_prbs_tap[22]^fracn_prbs_tap[17])}; //prbs23
            else
                fracn_prbs_tap            <= {                       fracn_prbs_tap[29:0], ~(fracn_prbs_tap[30]^fracn_prbs_tap[27])}; //prbs31
        end
    end

    assign fracn_prbs_out               = fracn_prbs_sel==2'd0 ? ~fracn_prbs_tap[ 6]
                                        : fracn_prbs_sel==2'd1 ? ~fracn_prbs_tap[14]
                                        : fracn_prbs_sel==2'd2 ? ~fracn_prbs_tap[22]
                                        :                        ~fracn_prbs_tap[30] ;
endmodule

//-----------------------------------------------------------------------------
// Project       : al6100
//-----------------------------------------------------------------------------
// File          : gpll_fbdiv_dig_ssc.v
// Author        :   jzhou
// Created       : 2022.11
// Last modified : 2022.11
//-----------------------------------------------------------------------------
// Description :
// SSC top module, include SSC divider & lpf
//-----------------------------------------------------------------------------
// Copyright (c) 2023 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module gpll_fbdiv_dig_ssc (
    // IO list
    input               ssc_rstn,                       // sync rstn
    input               ssc_en,
    input               ssc_clk,
    input               ssc_mode,                       // 0:center       1:up-down spread
    input               ssc_dn_loop_mode,               // 0:up sperad    1:down spread
    input       [ 7: 0] ssc_ext_freq_intn,
    input       [27: 0] ssc_ext_freq_fracn,
  //input               ssc_ext_freq_valid,
    input       [23: 0] ssc_step,
    input       [17: 0] ssc_freq_div,
    input       [ 1: 0] ssc_lpf_sel,                    // 20220206, REUSE this pin, because dont want to add additional pins

    input               fracn_en,

    output              ssc_mod_clk,                    // for debug
    output              ssc_signal_bit,

    output reg  [29: 0] ssc_cnt,                        //need be tune
    output      [ 7: 0] fbdiv_int_out,
    output      [27: 0] fbdiv_fracn_out,

    input               scan_mode,

    input               vssd,
    input               vccd
);

//signal list
    reg                 ssc_mod_clk_div2_r;
    reg                 ssc_en_sync1;
    reg                 ssc_en_sync2;
    reg                 ssc_en_mod_sync;
    reg                 ssc_en_mod_sync_d1;
    reg                 signal_bit_center;
    reg     [ 7: 0]     fbdiv_int;
    reg     [ 7: 0]     fbdiv_int_d1;
    reg     [ 7: 0]     fbdiv_int_d2;
    reg     [ 7: 0]     fbdiv_int_d3;
    reg     [ 7: 0]     fbdiv_int_d4;
    reg     [ 7: 0]     fbdiv_int_d5;
    reg     [23: 0]     fbdiv_fracn;
  //reg     [ 2: 0]     ext_freq_valid_d;
  //reg     [ 7: 0]     ext_freq_intn;
    reg     [ 7: 0]     ext_freq_intn_d1;
    reg     [ 7: 0]     ext_freq_intn_d2;
    reg     [ 7: 0]     ext_freq_intn_d3;
    reg     [ 7: 0]     ext_freq_intn_d4;
    reg     [ 7: 0]     ext_freq_intn_d5;
  //reg     [23: 0]     ext_freq_fracn;

    wire    [ 7: 0]     ext_freq_intn;
    wire    [23: 0]     ext_freq_fracn;

    wire                ssc_mod_clk_div2;
    wire    [29: 0]     ssc_cnt_step;
    wire                signal_bit;

    wire    [31: 0]     int_fracn_cnt;          // 8 + 24 = 32
    wire    [ 7: 0]     fbdiv_int_lpf;          //
    wire    [23: 0]     fbdiv_fracn_lpf;        // 24

    //ssc_en sync logic
    always @(posedge ssc_clk or negedge ssc_rstn) begin
        if(~ssc_rstn) begin
            ssc_en_sync1        <= 1'b0;
            ssc_en_sync2        <= 1'b0;
        end
        else begin
            ssc_en_sync1        <= ssc_en;
            ssc_en_sync2        <= ssc_en_sync1;
        end
    end

    //ext fbk valid sync logic
  //always @(posedge ssc_clk or negedge ssc_rstn) begin
  //    if(~ssc_rstn)
  //        ext_freq_valid_d    <= 8'd8;
  //    else
  //        ext_freq_valid_d    <= {ext_freq_valid_d[1:0], ssc_ext_freq_valid};
  //end

    //buffer N.f when valid toggles
  //always @(posedge ssc_clk or negedge ssc_rstn) begin
  //    if(~ssc_rstn) begin
  //        ext_freq_intn   <= 8'd8;
  //        ext_freq_fracn  <=24'd0;
  //    end
  //    else if(ext_freq_valid_d[2] ^ ext_freq_valid_d[1]) begin
  //        ext_freq_intn   <= ssc_ext_freq_intn;
  //        ext_freq_fracn  <= ssc_ext_freq_fracn;
  //    end
  //end
    assign ext_freq_intn    = ssc_ext_freq_intn;
    assign ext_freq_fracn   = ssc_ext_freq_fracn[27: 4];

    //delay 3 cycles to match frac if sdm enabled
    //20230301, these delay DFFs are not necessary if ext div ratio is fixed value.
    //          this delay logic comes from serdes's CPLL logic.
    //          in CPLL, the ext div ratio comes from DPLL(tx) or cdr freq loop(rx),
    //          the ratio is always changing, so we need this delay
  //always @(posedge ssc_clk or negedge ssc_rstn) begin
  //    if(~ssc_rstn) begin
  //        ext_freq_intn_d1<= 8'd8;
  //        ext_freq_intn_d2<= 8'd8;
  //        ext_freq_intn_d3<= 8'd8;
  //        ext_freq_intn_d4<= 8'd8;
  //        ext_freq_intn_d5<= 8'd8;
  //    end
  //    else if(fracn_en) begin
  //        ext_freq_intn_d1<= ext_freq_intn   ;
  //        ext_freq_intn_d2<= ext_freq_intn_d1;
  //        ext_freq_intn_d3<= ext_freq_intn_d2;
  //        ext_freq_intn_d4<= ext_freq_intn_d3;
  //        ext_freq_intn_d5<= ext_freq_intn_d4;
  //    end
  //end

    //ssc modulate clk gen
    gpll_fbdiv_dig_ssc_div #(.SIZE(17)) u_gpll_divn (
        // Outputs
        .out                (ssc_mod_clk    ),
        // Inputs
        .rstn               (ssc_rstn       ),
        .clk                (ssc_clk        ),
        .div                (ssc_freq_div   ),
        .sel_out_sync       (1'b1           ),
        .scan_mode          (scan_mode      ),
        .vccd               (vccd           ),
        .vssd               (vssd           )
    );

    //div2 to make 50% duty
  //always @(posedge ssc_mod_clk or negedge ssc_rstn) begin
  //    if(~ssc_rstn) begin
  //        ssc_mod_clk_div2_r  <= 1'b0;
  //        ssc_en_mod_sync_d1  <= 1'b0;
  //    end
  //    else begin
  //        ssc_mod_clk_div2_r  <= ~ssc_mod_clk_div2_r;
  //        ssc_en_mod_sync_d1  <= ssc_en_mod_sync;
  //    end
  //end
    always @(posedge ssc_clk or negedge ssc_rstn) begin
        if(~ssc_rstn) begin
            ssc_mod_clk_div2_r  <= 1'b0;
            ssc_en_mod_sync_d1  <= 1'b0;
        end
        else if(ssc_mod_clk) begin
            ssc_mod_clk_div2_r  <= ~ssc_mod_clk_div2_r;
            ssc_en_mod_sync_d1  <=  ssc_en_mod_sync;
        end
    end


    assign ssc_mod_clk_div2 = ssc_mod_clk_div2_r;
//    at0012_cell_clk_buf u_donttouch_mod_clk_div2 (
//  `ifdef FC_PG_SIM
//        .vdd(vccd), .vss(vssd),
//  `endif
//        .cout(ssc_mod_clk_div2),     .cin(ssc_mod_clk_div2_r)
//    );


    //sync by ssc_mod clk n div from ref_clk
  //always @(negedge ssc_mod_clk_div2 or negedge ssc_rstn) begin
  //    if(~ssc_rstn) begin
  //        ssc_en_mod_sync     <= 1'b0;
  //    end
  //    else begin
  //        ssc_en_mod_sync     <= ssc_en_sync2;
  //    end
  //end
    always @(posedge ssc_clk or negedge ssc_rstn) begin
        if(~ssc_rstn) begin
            ssc_en_mod_sync     <= 1'b0;
        end
        else if(ssc_mod_clk & ssc_mod_clk_div2) begin
            ssc_en_mod_sync     <= ssc_en_sync2;
        end
    end

    //total 29bits for max +-3% freq-sweep 
    //  30bits                      1bit                  6bits+ 24bits
    assign ssc_cnt_step         = ssc_mod_clk_div2  ? { {6{1'b0}},  ssc_step}
                                                          //     ~ssc_range + 1
                                                    : ({{6{1'b1}}, ~ssc_step} + 30'b1) ;

    //first counter, will generate a triangle waveform
    always @(posedge ssc_clk or negedge ssc_rstn) begin
        if(~ssc_rstn) begin
            ssc_cnt             <= 30'b0;
        end
        else if(ssc_en_mod_sync && ssc_en_mod_sync_d1) begin  
        //wait until ssc_mod_clk_div2
            ssc_cnt             <= ssc_cnt + ssc_cnt_step;
        end
    end

    //signbit gen div4
  //always @(posedge ssc_mod_clk_div2 or negedge ssc_rstn) begin
  //    if(~ssc_rstn) begin
  //        signal_bit_center   <= 1'b0;
  //    end
  //    else if(ssc_en_mod_sync) begin
  //        signal_bit_center   <= ~signal_bit_center;     
  //    end
  //end
    always @(posedge ssc_clk or negedge ssc_rstn) begin
        if(~ssc_rstn) begin
            signal_bit_center   <= 1'b0;
        end
        else if(ssc_en_mod_sync && ssc_mod_clk && ~ssc_mod_clk_div2) begin
            signal_bit_center   <= ~signal_bit_center;     
        end
    end
 
    //signbit=1 means ssc_cnt is negative value
    assign signal_bit           = ssc_mode   ? ssc_dn_loop_mode : signal_bit_center;

    assign ssc_signal_bit       = signal_bit;
    //32bits for up-down spread
    assign int_fracn_cnt           = signal_bit ? ({{2{signal_bit}}, ~ssc_cnt[29:0]} + 32'b1) : { 2'b0 , ssc_cnt[29:0]} ;

    //third adder to add offset on user divider ratio
    always @(posedge ssc_clk or negedge ssc_rstn) begin
        if(~ssc_rstn) begin
            fbdiv_int           <=  8'b0100;
            fbdiv_int_d1        <=  8'b0100;
            fbdiv_int_d2        <=  8'b0100;
            fbdiv_int_d3        <=  8'b0100;
            fbdiv_int_d4        <=  8'b0100;
            fbdiv_int_d5        <=  8'b0100;
            fbdiv_fracn         <= 24'b0;

        end
        else if(ssc_en_mod_sync) begin
                //32bits                 8bits               24bits                   8bits          24bits
            {fbdiv_int, fbdiv_fracn} <= {ext_freq_intn[7:0], ext_freq_fracn[23:0]} + {fbdiv_int_lpf, fbdiv_fracn_lpf};
                        fbdiv_int_d1                     <= fbdiv_int;
                        fbdiv_int_d2                     <= fbdiv_int_d1;
                        fbdiv_int_d3                     <= fbdiv_int_d2;   // form match at0012_v2 cpll
                        fbdiv_int_d4                     <= fbdiv_int_d3;   // form match at0012_v2 cpll
                        fbdiv_int_d5                     <= fbdiv_int_d4;   // form match at0012_v2 cpll
        end
    end    

    // function bypass
    //20230301, delay DFFs are not necessary if ext div ratio is fixed value
  //assign fbdiv_int_out       = ssc_en_mod_sync_d1 ? fbdiv_int_d5                          : ext_freq_intn_d5    ;
    assign fbdiv_int_out       = ssc_en_mod_sync_d1 ? fbdiv_int_d5                          : ext_freq_intn       ;
    assign fbdiv_fracn_out     = ssc_en_mod_sync_d1 ? {fbdiv_fracn, ssc_ext_freq_fracn[3:0]}: ssc_ext_freq_fracn  ;

  //assign fbdiv_int_lpf[7:0]      = int_fracn_cnt[28:21];
  //assign fbdiv_fracn_lpf[20:0]   = int_fracn_cnt[20: 0];

    // ssc-lpf block
    gpll_fbdiv_dig_ssc_lpf u_gpll_ssc_lpf (
        // Outputs
        .fbdiv_intn_out        (fbdiv_int_lpf[7:0]      ),
        .fbdiv_fracn_out       (fbdiv_fracn_lpf[23:0]   ),
        // Inputs
        .fbdiv_intn_in         (int_fracn_cnt[31:24]    ),
        .fbdiv_fracn_in        (int_fracn_cnt[23: 0]    ),
        //AUTOINST
        // Inputs
        .ssc_rstn              (ssc_rstn                ),
        .ssc_en                (ssc_en                  ),
        .ssc_clk               (ssc_clk                 ),
        .ssc_en_mod_sync       (ssc_en_mod_sync         ),
        .ssc_en_mod_sync_d1    (ssc_en_mod_sync_d1      ),
        .ssc_lpf_sel           (ssc_lpf_sel[1:0]        )
    );

endmodule

//-----------------------------------------------------------------------------
// Project       : al6100
//-----------------------------------------------------------------------------
// File          : gpll_fbdiv_dig_ssc_div.v
// Author        :   jzhou
// Created       : 2022.11
// Last modified : 2022.11
//-----------------------------------------------------------------------------
// Description :
// SSC divider
//-----------------------------------------------------------------------------
// Copyright (c) 2023 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module gpll_fbdiv_dig_ssc_div #(
    parameter integer                   SIZE = 17
    ) (
    input                               rstn,           //async rstn
    input                               clk,
    input                   [ SIZE: 0]  div,
    input                               sel_out_sync,   //0: output is 50% duty,        support div by1
                                                        //1: output is not 50% duty,    not support div by1

    output                              out,            //divided clk

    input                               scan_mode,

    input                               vccd,
    input                               vssd
);

    reg                                 rstSnc1_n;     // 1st stage of synchronizer
    reg                                 rstSnc2_n;     // 2nd stage of synchronizer
    reg                     [ SIZE: 0]  q;
    reg                     [ SIZE: 0]  q_half;
    reg                                 ckp;
    reg                                 ckn;
    reg                                 divbyone;
    reg                                 div_e;

    wire                                rstn_sync;
    wire                    [ SIZE: 0]  div_half;
    wire                                divby1;
    wire                                divby1oreven;
    wire                                div0_mux;
    wire                    [ SIZE: 0]  qxor;
    wire                                qeq0;
    wire                                qne0;
    wire                                qnehalf;
    wire                    [ SIZE: 0]  qs;
    wire                                qlthalf;
    wire                                dckp;
    wire                                clkb;
    wire                                qn_divby1;
    wire                                div_o;
    wire                                divbyeven;
    wire                                divbyodd;
    wire                                mx;
    wire                                net19;
    wire                                s_rstn_sync;

    //resetn synchronizer
    always @(posedge clk or negedge rstn) begin
        if (~rstn) 
            {rstSnc2_n, rstSnc1_n}  <= 2'b0;
        else
            {rstSnc2_n, rstSnc1_n}  <= {rstSnc1_n, 1'b1};
    end

    assign rstn_sync                = rstSnc2_n;

    assign s_rstn_sync              = scan_mode ? rstn : rstn_sync ;

    //======================================================
    // pll_div128_cnt_fbk begin

    assign div_half                 = (div[SIZE:0] >> 1) + {{SIZE{1'b0}}, 1'b1};    // pll_div128_add_fbk
    assign divby1                   = div[SIZE:0]=={(SIZE+1){1'b0}};
    assign divby1oreven             = ~(|div[SIZE:1] & ~div[0]);
    assign div0_mux                 = sel_out_sync ? div[0] : divby1oreven;

    always @(posedge clk or negedge s_rstn_sync) begin
        if (~s_rstn_sync)
            q       <= {(SIZE+1){1'b0}};
        else
            q       <= qeq0 ? {div[SIZE:1], div0_mux} : qs;
    end

    always @(posedge clk or negedge s_rstn_sync) begin
        if (~s_rstn_sync)
            q_half  <= {(SIZE+1){1'b0}};
        else
          //q_half  <= qeq0 ? div_half : q_half;
            q_half  <= qeq0 ? div      : q_half;        //make output as a pulse
    end

    assign qxor                     = q ^ q_half;
    assign qs                       = q[SIZE:0] - {{SIZE{1'b0}}, 1'b1};             // pll_div128_sub_fbk
    assign qne0                     = |q[SIZE:0];                                   // pll_div128_zero_det_fbk
    assign qeq0                     = ~qne0;
    assign qnehalf                  = |qxor[SIZE:0];                                // pll_div128_zero_det_fbk

    // pll_div128_cnt_fbk end
    //======================================================

    assign clkb                     = ~clk;
    assign qlthalf                  = ~(ckp  & qnehalf);
    assign dckp                     = ~(qne0 & qlthalf);

    always @(posedge clk or negedge s_rstn_sync) begin
        if (~s_rstn_sync)
            ckp     <= 1'b0;
        else
            ckp     <= dckp;
    end

	assign out = ckp;
//	need be changed by digtial
//    at0012_cell_clk_buf u_donttouch_ssc_div (
// `ifdef FC_PG_SIM
//        .vdd(vccd),     .vss(vssd),
// `endif
//        .cout(out),     .cin(ckp)
//    );

    // pll_div128_omux_fbk end
    //======================================================

endmodule

//-----------------------------------------------------------------------------
// Project       : al6100
//-----------------------------------------------------------------------------
// File          : gpll_fbdiv_dig_ssc_lpf.v
// Author        :   jzhou
// Created       : 2022.11
// Last modified : 2022.11
//-----------------------------------------------------------------------------
// Description :
// SSC lpf
//-----------------------------------------------------------------------------
// Copyright (c) 2023 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module gpll_fbdiv_dig_ssc_lpf (
    output reg                  [ 7: 0] fbdiv_intn_out,
    output reg                  [23: 0] fbdiv_fracn_out,

    input                               ssc_rstn,           // sync rstn
    input                               ssc_en,
    input                               ssc_clk,
    input                               ssc_en_mod_sync,
    input                               ssc_en_mod_sync_d1,
    input                       [ 7: 0] fbdiv_intn_in,
    input                       [23: 0] fbdiv_fracn_in,
    input                       [ 1: 0] ssc_lpf_sel   
                                                            // gain select or bypass
                                                            // 2'b11, 1/128
                                                            // 2'b10, 1/64
                                                            // 2'b01, 1/32
                                                            // 2'b00, bypass
);

    wire                        [38: 0] fbdiv_sum;          // never overflow/underflow
    wire                        [38: 0] fbdiv_out;
    wire                        [38: 0] fbdiv_in;
    wire                        [38: 0] fbdiv_out_shift;
    wire                        [38: 0] fbdiv_in_shift;

    wire                        [20: 0] fbdiv_sum_lsb_w;    // MSB is sign //  need be changed

    reg                         [17: 0] fbdiv_sum_lsb;      // 18bit sdm
    reg                         [ 2: 0] fbdiv_sum_lsb_c;

    reg                         [38:18] fbdiv_out_msb_buf;
    reg                         [38:18] fbdiv_out_shift_msb_buf;
    reg                         [38:18] fbdiv_in_shift_msb_buf;

  //         39bit                      8bit              24bit        7bit
    assign fbdiv_out        = {      fbdiv_intn_out, fbdiv_fracn_out,  7'b0};
  //         39bit                      8bit              24bit        7bit
    assign fbdiv_in         = {      fbdiv_intn_in,  fbdiv_fracn_in,   7'b0};
  //         39bit
    assign fbdiv_out_shift  = (ssc_lpf_sel==2'b11) ? {{7{fbdiv_out[38]}}, fbdiv_out[38: 7]} :
                              (ssc_lpf_sel==2'b10) ? {{6{fbdiv_out[38]}}, fbdiv_out[38: 6]} :
                                                     {{5{fbdiv_out[38]}}, fbdiv_out[38: 5]} ;
  //         39bit
    assign fbdiv_in_shift   = (ssc_lpf_sel==2'b11) ? {{7{fbdiv_in[38]}},  fbdiv_in[38: 7]} :
                              (ssc_lpf_sel==2'b10) ? {{6{fbdiv_in[38]}},  fbdiv_in[38: 6]} :
                                                     {{5{fbdiv_in[38]}},  fbdiv_in[38: 5]} ;

    //2 stage pipeline adder
    assign fbdiv_sum_lsb_w  = {3'b0,fbdiv_out[17:0]}            //lsb no changed 18bit sdm
                            - {3'b0,fbdiv_out_shift[17:0]}
                            + {3'b0,fbdiv_in_shift[17:0] };

    always @(posedge ssc_clk or negedge ssc_rstn) begin
        if(~ssc_rstn) begin
            fbdiv_sum_lsb           <= 18'b0;
            fbdiv_sum_lsb_c         <=  3'b0;
            fbdiv_out_msb_buf       <= 21'b0;
            fbdiv_out_shift_msb_buf <= 21'b0;
            fbdiv_in_shift_msb_buf  <= 21'b0;
        end
        else if(~ssc_en_mod_sync_d1) begin
            fbdiv_sum_lsb           <= fbdiv_out[17: 0];
            fbdiv_sum_lsb_c         <=  3'b0;
            fbdiv_out_msb_buf       <= fbdiv_out[38:18];
            fbdiv_out_shift_msb_buf <= fbdiv_out_shift[38:18];
            fbdiv_in_shift_msb_buf  <= fbdiv_in_shift[38:18];
        end
        else begin
            fbdiv_sum_lsb           <= fbdiv_sum_lsb_w[17: 0];
            fbdiv_sum_lsb_c         <= fbdiv_sum_lsb_w[20:18];
            fbdiv_out_msb_buf       <= fbdiv_out[38:18];
            fbdiv_out_shift_msb_buf <= fbdiv_out_shift[38:18];
            fbdiv_in_shift_msb_buf  <= fbdiv_in_shift[38:18];
        end
    end

    // 39bit                    21bit               21bit                     21bit                      18bit                  + 3bit
    assign fbdiv_sum        = {(fbdiv_out_msb_buf - fbdiv_out_shift_msb_buf + fbdiv_in_shift_msb_buf + {{18{fbdiv_sum_lsb_c[2]}}, fbdiv_sum_lsb_c}),    //MSB 21bit=7+8+6
                                fbdiv_sum_lsb} ;                                                                                                        //LSB 18bit

    always @(posedge ssc_clk or negedge ssc_rstn) begin
        if(~ssc_rstn) begin
            fbdiv_intn_out   <=  8'd8;
            fbdiv_fracn_out  <= 24'd0;
        end
        else if(ssc_lpf_sel==2'b00 | ~ssc_en_mod_sync_d1) begin
            fbdiv_intn_out   <= fbdiv_intn_in  ;
            fbdiv_fracn_out  <= fbdiv_fracn_in;
        end
        else begin
            fbdiv_intn_out   <= fbdiv_sum[38:31] ;
            fbdiv_fracn_out  <= fbdiv_sum[30: 7] ;
        end
    end

endmodule

`timescale 1ns/1ps

module gpll_vco_mux_div_ctrl ( clk_out, vccd, vssd, clk0_div_by_one, clk, clk_div,
mc1_frac, mc1_frac_en, pll_rst_n, phsel );

    input                               pll_rst_n;          //sync rstn, to be sync with clk_div

    input                               clk_div;            //divider input clk, this should be sync with clk[7:0]
                                                            //with small latency to clk[0]

    input                       [ 7: 0] clk;                //8 phase input clock
                                                            //the expected phases are(45 degree each)
                                                            //                      ________
                                                            //ph[7]_________________|       |_____
                                                            //                 _______        ______
                                                            //ph[4]___________|       |_______|
                                                            //             _______        ______
                                                            //ph[2]________|      |_______|
                                                            //         _______        ________
                                                            //ph[0]____|      |_______|       |___

    input                               clk0_div_by_one;
    input                       [ 2: 0] mc1_frac;           // fractional part
    input                               mc1_frac_en;
    input                       [ 2: 0] phsel;              // static initial fine phase select

    output                              clk_out;
    inout                               vssd;
    inout                               vccd;

    reg                         [ 2: 0] phs1;
    reg                         [ 2: 0] phs1_d;

    wire                                in_rstn;
    wire                        [ 2: 0] phs0_init;
    wire                        [ 2: 0] phs0_rstn;
    wire                        [ 2: 0] phs0_setn;
    wire                        [ 2: 0] adder0;
    wire                        [ 7: 0] d_z;
    wire                                clk_selb;
    wire                                clk_sel;
    wire                        [ 2: 0] phs0_w;
    wire                        [ 2: 0] phs1_w;
    wire                        [ 7: 0] ph_now_enc;
    wire                        [ 7: 0] ph_now_rstn;
    wire                        [ 7: 0] ph_now_setn;
    wire                        [ 7: 0] en_enc;
    wire                        [ 7: 0] en_rstn;
    wire                        [ 7: 0] en_setn;
    wire                                clk_out1;
    wire                                clk_selb1;
    wire                        [ 7: 0] clk_or;
    wire                                pll_rstSnc_n;

  `ifdef FPGA_SIM
    reg                         [ 2: 0] phs0;
    reg                         [ 2: 0] phs0_d;
    reg                         [ 7: 0] ph_now;
    reg                         [ 7: 0] ph_now_pre;
    reg                         [ 7: 0] en;
  `else
    wire                        [ 2: 0] phs0;
    wire                        [ 2: 0] phs0_d;
    wire                        [ 7: 0] ph_now;
    wire                        [ 7: 0] ph_now_pre;
    wire                        [ 7: 0] en;
  `endif

    //20220708, add resetn sync
    sync_dff u_syncrstn_gen (
        .clk        (clk_div                    ),
        .rst_n      (pll_rst_n                  ),
        .din        (1'b1                       ),
        .dout       (pll_rstSnc_n               )
    );

  //assign in_rstn              = pll_rst_n    & mc1_frac_en;
    assign in_rstn              = pll_rstSnc_n & mc1_frac_en;

    //======================================================
    // gpll_vco_mux_adder begin

    //20220811, change to use initial phase[5] for frac=4/5/6/7
    //          if frac=6/7 use phase[6]/phase[7], there can be setup/hold
    //          timing issue for certain VCO freq
    //          because clk_selb will sample clk_out's DFF
  //assign phs0_init            = (mc1_frac[2:1]==2'b11) ? 3'd5 : mc1_frac ;    //only 6/7 need to use phase 5 as initial phase
    assign phs0_init            = (mc1_frac[2]  ==1'b1 ) ? 3'd5 : mc1_frac ;

    assign phs0_rstn            = {3{in_rstn}} |  phs0_init;

    assign phs0_setn            = {3{in_rstn}} | ~phs0_init;

    assign adder0               = phs0[2:0] + mc1_frac[2:0];

  `ifdef FPGA_SIM
    genvar i;
    generate for (i=0; i<=2; i=i+1) begin
        always @(posedge clk_div or negedge phs0_rstn[i] or negedge phs0_setn[i]) begin
            if     (~phs0_rstn[i])
                phs0[i]         <= #0.04 1'b0;
            else if(~phs0_setn[i])
                phs0[i]         <= #0.04 1'b1;
            else
                phs0[i]         <= #0.04 adder0[i];
        end
    end
    endgenerate
  `else
      `ifdef FC_PG_SIM
        DRSNQV2_140P9T40H   u0_donttouch_dff    (.Q(phs0[0]),   .D(adder0[0]),  .CK(clk_div),   .RDN(phs0_rstn[0]), .SDN(phs0_setn[0]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u1_donttouch_dff    (.Q(phs0[1]),   .D(adder0[1]),  .CK(clk_div),   .RDN(phs0_rstn[1]), .SDN(phs0_setn[1]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u2_donttouch_dff    (.Q(phs0[2]),   .D(adder0[2]),  .CK(clk_div),   .RDN(phs0_rstn[2]), .SDN(phs0_setn[2]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV2_140P9T40H   u0_donttouch_dff    (.Q(phs0[0]),   .D(adder0[0]),  .CK(clk_div),   .RDN(phs0_rstn[0]), .SDN(phs0_setn[0]));
        DRSNQV2_140P9T40H   u1_donttouch_dff    (.Q(phs0[1]),   .D(adder0[1]),  .CK(clk_div),   .RDN(phs0_rstn[1]), .SDN(phs0_setn[1]));
        DRSNQV2_140P9T40H   u2_donttouch_dff    (.Q(phs0[2]),   .D(adder0[2]),  .CK(clk_div),   .RDN(phs0_rstn[2]), .SDN(phs0_setn[2]));
      `endif
  `endif

    always @(posedge clk_div or negedge in_rstn) begin
        if(~in_rstn)
            phs1                <= #0.04 3'b0;
        else
            phs1                <= #0.04 phs1[2:0] + mc1_frac[2:0];
    end

    // gpll_vco_mux_adder end
    //======================================================

    //20220811, change back, because OR gate will increase delay, DC
    //optimization only keeps the OR gate for clk_or[0] and [4]
    //clk skew is big btw [0]/[4] and other clk phases
  //assign clk_or               =              clk[7:0]  | {3'b0, clk[5], 3'b0, clk[1]} & {8{mc1_frac==3'd4}};
    assign clk_or               =              clk[7:0]  ;

  //assign d_z                  = ~{clk[0],    clk[7:1]} & {8{mc1_frac_en}};
    assign d_z                  = ~{        clk_or[7:0]} & {8{mc1_frac_en}};

//`ifdef FPGA_SIM
//`else
//    `ifdef FC_PG_SIM
//    `else
//    `endif
//`endif

    //clk_selb gen
  `ifdef FPGA_SIM
    assign clk_selb             = ph_now==8'h80 ? d_z[7]
                                : ph_now==8'h40 ? d_z[6]
                                : ph_now==8'h20 ? d_z[5]
                                : ph_now==8'h10 ? d_z[4]
                                : ph_now==8'h08 ? d_z[3]
                                : ph_now==8'h04 ? d_z[2]
                                : ph_now==8'h02 ? d_z[1]
                                :                 d_z[0] ;
  `else
      `ifdef FC_PG_SIM
        TBUFV8_140P9T40H    u7_donttouch_buft   (.Z(clk_selb ),     .I(d_z[7]),    .OE(ph_now[7]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u6_donttouch_buft   (.Z(clk_selb ),     .I(d_z[6]),    .OE(ph_now[6]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u5_donttouch_buft   (.Z(clk_selb ),     .I(d_z[5]),    .OE(ph_now[5]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u4_donttouch_buft   (.Z(clk_selb ),     .I(d_z[4]),    .OE(ph_now[4]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u3_donttouch_buft   (.Z(clk_selb ),     .I(d_z[3]),    .OE(ph_now[3]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u2_donttouch_buft   (.Z(clk_selb ),     .I(d_z[2]),    .OE(ph_now[2]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u1_donttouch_buft   (.Z(clk_selb ),     .I(d_z[1]),    .OE(ph_now[1]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u0_donttouch_buft   (.Z(clk_selb ),     .I(d_z[0]),    .OE(ph_now[0]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      //CKBD4BWP20P90CPD    u_donttouch_buft    (.Z(clk_selb),      .I(clk_selb1),                 .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        TBUFV8_140P9T40H    u7_donttouch_buft   (.Z(clk_selb ),     .I(d_z[7]),    .OE(ph_now[7]));
        TBUFV8_140P9T40H    u6_donttouch_buft   (.Z(clk_selb ),     .I(d_z[6]),    .OE(ph_now[6]));
        TBUFV8_140P9T40H    u5_donttouch_buft   (.Z(clk_selb ),     .I(d_z[5]),    .OE(ph_now[5]));
        TBUFV8_140P9T40H    u4_donttouch_buft   (.Z(clk_selb ),     .I(d_z[4]),    .OE(ph_now[4]));
        TBUFV8_140P9T40H    u3_donttouch_buft   (.Z(clk_selb ),     .I(d_z[3]),    .OE(ph_now[3]));
        TBUFV8_140P9T40H    u2_donttouch_buft   (.Z(clk_selb ),     .I(d_z[2]),    .OE(ph_now[2]));
        TBUFV8_140P9T40H    u1_donttouch_buft   (.Z(clk_selb ),     .I(d_z[1]),    .OE(ph_now[1]));
        TBUFV8_140P9T40H    u0_donttouch_buft   (.Z(clk_selb ),     .I(d_z[0]),    .OE(ph_now[0]));
      //CKBD4BWP20P90CPD    u_donttouch_buft    (.Z(clk_selb),      .I(clk_selb1)                );
      `endif
  `endif
    //use analog lib to replace std cell
  //gpll_vco_mux_bufft_d8 u_gpll_vco_mux_bufft_d8 (.dout(clk_selb), .din(d_z),     .en(ph_now),    .vccd(vccd), .vssd(vssd));

    assign clk_sel              = ~clk_selb;

    always @(posedge clk_selb or negedge in_rstn) begin
        if(~in_rstn) begin
          //phs0_d              <= 3'b0;
            phs1_d              <= #0.04 3'b0;
        end
        else begin
          //phs0_d              <= phs0;
            phs1_d              <= #0.04 phs1;
        end
    end

    //phs0_d gen
  `ifdef FPGA_SIM
    genvar m;
    generate for (m=0; m<=2; m=m+1) begin
        always @(posedge clk_selb or negedge phs0_rstn[m] or negedge phs0_setn[m]) begin
            if     (~phs0_rstn[m])
                phs0_d[m]       <= #0.04 1'b0;
            else if(~phs0_setn[m])
                phs0_d[m]       <= #0.04 1'b1;
            else
                phs0_d[m]       <= #0.04 phs0[m];
        end
    end
    endgenerate
  `else
      `ifdef FC_PG_SIM
        DRSNQV2_140P9T40H   u0_donttouch_phs0_d (.Q(phs0_d[0]), .D(phs0[0]),    .CK(clk_selb),  .RDN(phs0_rstn[0]), .SDN(phs0_setn[0]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u1_donttouch_phs0_d (.Q(phs0_d[1]), .D(phs0[1]),    .CK(clk_selb),  .RDN(phs0_rstn[1]), .SDN(phs0_setn[1]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u2_donttouch_phs0_d (.Q(phs0_d[2]), .D(phs0[2]),    .CK(clk_selb),  .RDN(phs0_rstn[2]), .SDN(phs0_setn[2]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV2_140P9T40H   u0_donttouch_phs0_d (.Q(phs0_d[0]), .D(phs0[0]),    .CK(clk_selb),  .RDN(phs0_rstn[0]), .SDN(phs0_setn[0]));
        DRSNQV2_140P9T40H   u1_donttouch_phs0_d (.Q(phs0_d[1]), .D(phs0[1]),    .CK(clk_selb),  .RDN(phs0_rstn[1]), .SDN(phs0_setn[1]));
        DRSNQV2_140P9T40H   u2_donttouch_phs0_d (.Q(phs0_d[2]), .D(phs0[2]),    .CK(clk_selb),  .RDN(phs0_rstn[2]), .SDN(phs0_setn[2]));
      `endif
  `endif

    // ph_now gen
    assign phs0_w               = clk0_div_by_one ? phs0 : phs0_d;

    assign ph_now_enc           = phs0_w==3'd7 ? 8'h80
                                : phs0_w==3'd6 ? 8'h40
                                : phs0_w==3'd5 ? 8'h20
                                : phs0_w==3'd4 ? 8'h10
                                : phs0_w==3'd3 ? 8'h08
                                : phs0_w==3'd2 ? 8'h04
                                : phs0_w==3'd1 ? 8'h02
                                :                8'h01 ;

    assign ph_now_rstn          = {8{in_rstn}} |  ph_now_enc;

    assign ph_now_setn          = {8{in_rstn}} | ~ph_now_enc;

  `ifdef FPGA_SIM
    genvar j;
    generate for (j=0; j<=7; j=j+1) begin
        always @(posedge clk_selb or negedge ph_now_rstn[j] or negedge ph_now_setn[j]) begin
      //always @(posedge clk_sel  or negedge ph_now_rstn[j] or negedge ph_now_setn[j]) begin
            if     (~ph_now_rstn[j])
                ph_now_pre[j]   <= #0.04 1'b0;
            else if(~ph_now_setn[j])
                ph_now_pre[j]   <= #0.04 1'b1;
            else
                ph_now_pre[j]   <= #0.04 ph_now_enc[j];
        end
    end
    endgenerate
  `else
      `ifdef FC_PG_SIM
        DRSNQV2_140P9T40H   u0_donttouch_ph_pre (.Q(ph_now_pre[0]), .D(ph_now_enc[0]),  .CK(clk_selb),  .RDN(ph_now_rstn[0]),   .SDN(ph_now_setn[0]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u1_donttouch_ph_pre (.Q(ph_now_pre[1]), .D(ph_now_enc[1]),  .CK(clk_selb),  .RDN(ph_now_rstn[1]),   .SDN(ph_now_setn[1]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u2_donttouch_ph_pre (.Q(ph_now_pre[2]), .D(ph_now_enc[2]),  .CK(clk_selb),  .RDN(ph_now_rstn[2]),   .SDN(ph_now_setn[2]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u3_donttouch_ph_pre (.Q(ph_now_pre[3]), .D(ph_now_enc[3]),  .CK(clk_selb),  .RDN(ph_now_rstn[3]),   .SDN(ph_now_setn[3]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u4_donttouch_ph_pre (.Q(ph_now_pre[4]), .D(ph_now_enc[4]),  .CK(clk_selb),  .RDN(ph_now_rstn[4]),   .SDN(ph_now_setn[4]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u5_donttouch_ph_pre (.Q(ph_now_pre[5]), .D(ph_now_enc[5]),  .CK(clk_selb),  .RDN(ph_now_rstn[5]),   .SDN(ph_now_setn[5]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u6_donttouch_ph_pre (.Q(ph_now_pre[6]), .D(ph_now_enc[6]),  .CK(clk_selb),  .RDN(ph_now_rstn[6]),   .SDN(ph_now_setn[6]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u7_donttouch_ph_pre (.Q(ph_now_pre[7]), .D(ph_now_enc[7]),  .CK(clk_selb),  .RDN(ph_now_rstn[7]),   .SDN(ph_now_setn[7]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV2_140P9T40H   u0_donttouch_ph_pre (.Q(ph_now_pre[0]), .D(ph_now_enc[0]),  .CK(clk_selb),  .RDN(ph_now_rstn[0]),   .SDN(ph_now_setn[0]));
        DRSNQV2_140P9T40H   u1_donttouch_ph_pre (.Q(ph_now_pre[1]), .D(ph_now_enc[1]),  .CK(clk_selb),  .RDN(ph_now_rstn[1]),   .SDN(ph_now_setn[1]));
        DRSNQV2_140P9T40H   u2_donttouch_ph_pre (.Q(ph_now_pre[2]), .D(ph_now_enc[2]),  .CK(clk_selb),  .RDN(ph_now_rstn[2]),   .SDN(ph_now_setn[2]));
        DRSNQV2_140P9T40H   u3_donttouch_ph_pre (.Q(ph_now_pre[3]), .D(ph_now_enc[3]),  .CK(clk_selb),  .RDN(ph_now_rstn[3]),   .SDN(ph_now_setn[3]));
        DRSNQV2_140P9T40H   u4_donttouch_ph_pre (.Q(ph_now_pre[4]), .D(ph_now_enc[4]),  .CK(clk_selb),  .RDN(ph_now_rstn[4]),   .SDN(ph_now_setn[4]));
        DRSNQV2_140P9T40H   u5_donttouch_ph_pre (.Q(ph_now_pre[5]), .D(ph_now_enc[5]),  .CK(clk_selb),  .RDN(ph_now_rstn[5]),   .SDN(ph_now_setn[5]));
        DRSNQV2_140P9T40H   u6_donttouch_ph_pre (.Q(ph_now_pre[6]), .D(ph_now_enc[6]),  .CK(clk_selb),  .RDN(ph_now_rstn[6]),   .SDN(ph_now_setn[6]));
        DRSNQV2_140P9T40H   u7_donttouch_ph_pre (.Q(ph_now_pre[7]), .D(ph_now_enc[7]),  .CK(clk_selb),  .RDN(ph_now_rstn[7]),   .SDN(ph_now_setn[7]));
      `endif
  `endif

  `ifdef FPGA_SIM
    genvar l;
    generate for (l=0; l<=7; l=l+1) begin
        always @(posedge clk_sel  or negedge ph_now_rstn[l] or negedge ph_now_setn[l]) begin
      //always @(posedge clk_selb or negedge ph_now_rstn[l] or negedge ph_now_setn[l]) begin
            if     (~ph_now_rstn[l])
                ph_now[l]       <= #0.04 1'b0;
            else if(~ph_now_setn[l])
                ph_now[l]       <= #0.04 1'b1;
            else
                ph_now[l]       <= #0.04 ph_now_pre[l];
        end
    end
    endgenerate
  `else
      `ifdef FC_PG_SIM
        DRSNQV2_140P9T40H   u0_donttouch_ph_now (.Q(ph_now[0]), .D(ph_now_pre[0]),  .CK(clk_sel ),  .RDN(ph_now_rstn[0]),   .SDN(ph_now_setn[0]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u1_donttouch_ph_now (.Q(ph_now[1]), .D(ph_now_pre[1]),  .CK(clk_sel ),  .RDN(ph_now_rstn[1]),   .SDN(ph_now_setn[1]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u2_donttouch_ph_now (.Q(ph_now[2]), .D(ph_now_pre[2]),  .CK(clk_sel ),  .RDN(ph_now_rstn[2]),   .SDN(ph_now_setn[2]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u3_donttouch_ph_now (.Q(ph_now[3]), .D(ph_now_pre[3]),  .CK(clk_sel ),  .RDN(ph_now_rstn[3]),   .SDN(ph_now_setn[3]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u4_donttouch_ph_now (.Q(ph_now[4]), .D(ph_now_pre[4]),  .CK(clk_sel ),  .RDN(ph_now_rstn[4]),   .SDN(ph_now_setn[4]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u5_donttouch_ph_now (.Q(ph_now[5]), .D(ph_now_pre[5]),  .CK(clk_sel ),  .RDN(ph_now_rstn[5]),   .SDN(ph_now_setn[5]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u6_donttouch_ph_now (.Q(ph_now[6]), .D(ph_now_pre[6]),  .CK(clk_sel ),  .RDN(ph_now_rstn[6]),   .SDN(ph_now_setn[6]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u7_donttouch_ph_now (.Q(ph_now[7]), .D(ph_now_pre[7]),  .CK(clk_sel ),  .RDN(ph_now_rstn[7]),   .SDN(ph_now_setn[7]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV2_140P9T40H   u0_donttouch_ph_now (.Q(ph_now[0]), .D(ph_now_pre[0]),  .CK(clk_sel ),  .RDN(ph_now_rstn[0]),   .SDN(ph_now_setn[0]));
        DRSNQV2_140P9T40H   u1_donttouch_ph_now (.Q(ph_now[1]), .D(ph_now_pre[1]),  .CK(clk_sel ),  .RDN(ph_now_rstn[1]),   .SDN(ph_now_setn[1]));
        DRSNQV2_140P9T40H   u2_donttouch_ph_now (.Q(ph_now[2]), .D(ph_now_pre[2]),  .CK(clk_sel ),  .RDN(ph_now_rstn[2]),   .SDN(ph_now_setn[2]));
        DRSNQV2_140P9T40H   u3_donttouch_ph_now (.Q(ph_now[3]), .D(ph_now_pre[3]),  .CK(clk_sel ),  .RDN(ph_now_rstn[3]),   .SDN(ph_now_setn[3]));
        DRSNQV2_140P9T40H   u4_donttouch_ph_now (.Q(ph_now[4]), .D(ph_now_pre[4]),  .CK(clk_sel ),  .RDN(ph_now_rstn[4]),   .SDN(ph_now_setn[4]));
        DRSNQV2_140P9T40H   u5_donttouch_ph_now (.Q(ph_now[5]), .D(ph_now_pre[5]),  .CK(clk_sel ),  .RDN(ph_now_rstn[5]),   .SDN(ph_now_setn[5]));
        DRSNQV2_140P9T40H   u6_donttouch_ph_now (.Q(ph_now[6]), .D(ph_now_pre[6]),  .CK(clk_sel ),  .RDN(ph_now_rstn[6]),   .SDN(ph_now_setn[6]));
        DRSNQV2_140P9T40H   u7_donttouch_ph_now (.Q(ph_now[7]), .D(ph_now_pre[7]),  .CK(clk_sel ),  .RDN(ph_now_rstn[7]),   .SDN(ph_now_setn[7]));
      `endif
  `endif

    //clk out en gen
    assign phs1_w               = (clk0_div_by_one ? phs1 : phs1_d)
                                | phsel ;                               // static initial fine phase select

    assign en_enc               = phs1_w==3'd7 ? 8'h80
                                : phs1_w==3'd6 ? 8'h40
                                : phs1_w==3'd5 ? 8'h20
                                : phs1_w==3'd4 ? 8'h10
                                : phs1_w==3'd3 ? 8'h08
                                : phs1_w==3'd2 ? 8'h04
                                : phs1_w==3'd1 ? 8'h02
                                :                8'h01 ;

    assign en_rstn              = {8{in_rstn}} |  en_enc;

    assign en_setn              = {8{in_rstn}} | ~en_enc;

  `ifdef FPGA_SIM
    genvar k;
    generate for (k=0; k<=7; k=k+1) begin
        always @(posedge clk_selb or negedge en_rstn[k] or negedge en_setn[k]) begin
            if     (~en_rstn[k])
                en[k]           <= #0.04 1'b0;
            else if(~en_setn[k])
                en[k]           <= #0.04 1'b1;
            else
                en[k]           <= #0.04 en_enc[k];
        end
    end
    endgenerate
  `else
      `ifdef FC_PG_SIM
        DRSNQV2_140P9T40H   u0_donttouch_en     (.Q(en[0]), .D(en_enc[0]),  .CK(clk_selb),  .RDN(en_rstn[0]),   .SDN(en_setn[0]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u1_donttouch_en     (.Q(en[1]), .D(en_enc[1]),  .CK(clk_selb),  .RDN(en_rstn[1]),   .SDN(en_setn[1]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u2_donttouch_en     (.Q(en[2]), .D(en_enc[2]),  .CK(clk_selb),  .RDN(en_rstn[2]),   .SDN(en_setn[2]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u3_donttouch_en     (.Q(en[3]), .D(en_enc[3]),  .CK(clk_selb),  .RDN(en_rstn[3]),   .SDN(en_setn[3]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u4_donttouch_en     (.Q(en[4]), .D(en_enc[4]),  .CK(clk_selb),  .RDN(en_rstn[4]),   .SDN(en_setn[4]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u5_donttouch_en     (.Q(en[5]), .D(en_enc[5]),  .CK(clk_selb),  .RDN(en_rstn[5]),   .SDN(en_setn[5]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u6_donttouch_en     (.Q(en[6]), .D(en_enc[6]),  .CK(clk_selb),  .RDN(en_rstn[6]),   .SDN(en_setn[6]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u7_donttouch_en     (.Q(en[7]), .D(en_enc[7]),  .CK(clk_selb),  .RDN(en_rstn[7]),   .SDN(en_setn[7]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV2_140P9T40H   u0_donttouch_en     (.Q(en[0]), .D(en_enc[0]),  .CK(clk_selb),  .RDN(en_rstn[0]),   .SDN(en_setn[0]));
        DRSNQV2_140P9T40H   u1_donttouch_en     (.Q(en[1]), .D(en_enc[1]),  .CK(clk_selb),  .RDN(en_rstn[1]),   .SDN(en_setn[1]));
        DRSNQV2_140P9T40H   u2_donttouch_en     (.Q(en[2]), .D(en_enc[2]),  .CK(clk_selb),  .RDN(en_rstn[2]),   .SDN(en_setn[2]));
        DRSNQV2_140P9T40H   u3_donttouch_en     (.Q(en[3]), .D(en_enc[3]),  .CK(clk_selb),  .RDN(en_rstn[3]),   .SDN(en_setn[3]));
        DRSNQV2_140P9T40H   u4_donttouch_en     (.Q(en[4]), .D(en_enc[4]),  .CK(clk_selb),  .RDN(en_rstn[4]),   .SDN(en_setn[4]));
        DRSNQV2_140P9T40H   u5_donttouch_en     (.Q(en[5]), .D(en_enc[5]),  .CK(clk_selb),  .RDN(en_rstn[5]),   .SDN(en_setn[5]));
        DRSNQV2_140P9T40H   u6_donttouch_en     (.Q(en[6]), .D(en_enc[6]),  .CK(clk_selb),  .RDN(en_rstn[6]),   .SDN(en_setn[6]));
        DRSNQV2_140P9T40H   u7_donttouch_en     (.Q(en[7]), .D(en_enc[7]),  .CK(clk_selb),  .RDN(en_rstn[7]),   .SDN(en_setn[7]));
      `endif
  `endif

    //clk_out gen
  `ifdef FPGA_SIM
    assign clk_out              = en==8'h80 ? clk_or[7]
                                : en==8'h40 ? clk_or[6]
                                : en==8'h20 ? clk_or[5]
                                : en==8'h10 ? clk_or[4]
                                : en==8'h08 ? clk_or[3]
                                : en==8'h04 ? clk_or[2]
                                : en==8'h02 ? clk_or[1]
                                :             clk_or[0] ;
  `else
      `ifdef FC_PG_SIM
        TBUFV8_140P9T40H    u7_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[7]),  .OE(en[7]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u6_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[6]),  .OE(en[6]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u5_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[5]),  .OE(en[5]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u4_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[4]),  .OE(en[4]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u3_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[3]),  .OE(en[3]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u2_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[2]),  .OE(en[2]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u1_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[1]),  .OE(en[1]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u0_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[0]),  .OE(en[0]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        CLKBUFV4_140P9T40H  u_donttouch_buft_out    (.Z(clk_out),   .I(clk_out1),               .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        TBUFV8_140P9T40H    u7_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[7]),  .OE(en[7]));
        TBUFV8_140P9T40H    u6_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[6]),  .OE(en[6]));
        TBUFV8_140P9T40H    u5_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[5]),  .OE(en[5]));
        TBUFV8_140P9T40H    u4_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[4]),  .OE(en[4]));
        TBUFV8_140P9T40H    u3_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[3]),  .OE(en[3]));
        TBUFV8_140P9T40H    u2_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[2]),  .OE(en[2]));
        TBUFV8_140P9T40H    u1_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[1]),  .OE(en[1]));
        TBUFV8_140P9T40H    u0_donttouch_buft_out   (.Z(clk_out1),  .I(clk_or[0]),  .OE(en[0]));
        CLKBUFV4_140P9T40H  u_donttouch_buft_out    (.Z(clk_out),   .I(clk_out1)              );
      `endif
  `endif
    //use analog lib to replace std cell
  //gpll_vco_mux_bufft_d6 u_gpll_vco_mux_bufft_d6   (.dout(clk_out), .din(clk),   .en(en),    .vccd(vccd), .vssd(vssd));
  //gpll_vco_mux_bufft_d6 u_gpll_vco_mux_bufft_d6   (.dout(clk_out), .din(clk_or),.en(en),    .vccd(vccd), .vssd(vssd));

endmodule

`timescale 1ns/1ps

module gpll_vco_mux_phs ( clk_out, phasedone, vccd, vssd, clk, direction, dyn_ph_shift_en,
mc1_phs, pll_rst_n, rotate, scanclk );

    output                              clk_out;
    output                              phasedone;

    input                               pll_rst_n;
    input                       [ 7: 0] clk;                //8 phase input clock
                                                            //the expected phases are(45 degree each)
                                                            //         _______        ________
                                                            //ph[7]____|      |_______|       |___
                                                            //             _______        ______
                                                            //ph[5]________|      |_______|
                                                            //                 _______        ______
                                                            //ph[3]___________|       |_______|
                                                            //                    ________
                                                            //ph[1]_______________|       |_____

    input                               scanclk;
    input                               direction;
    input                               rotate;
    input                               dyn_ph_shift_en;
    input                       [ 2: 0] mc1_phs;

    inout                               vssd;
    inout                               vccd;

    reg                                 rot_det;
    reg                                 rot_sync;
    reg                                 rot_sync_d1;
    reg                                 rot_sync_d2;
    reg                                 dir_sync;
    reg                                 done;
    reg                         [ 2: 0] qd;
    reg                                 phasedone;

    wire                                done_dly1;
    wire                                done_dly2;
    wire                                rst_int_n;
    wire                        [ 7: 0] d_z;
    wire                                clk_selb;
    wire                                clk_sel;
    wire                                scanclk_int;
    wire                                scanclk_intb;
    wire                        [ 2: 0] phs_next;
    wire                        [ 2: 0] phs_rstn;
    wire                        [ 2: 0] phs_setn;
    wire                        [ 7: 0] en_enc;
    wire                        [ 7: 0] en_rstn;
    wire                        [ 7: 0] en_setn;
    wire                                clk_out1;
    wire                                clk_sel1;

  `ifdef FPGA_SIM
    reg                                 done_dly;
    reg                         [ 7: 0] ph_now;
    reg                         [ 7: 0] en;
    reg                         [ 2: 0] phs;
  `else
    wire                                done_dly;
    wire                        [ 7: 0] ph_now;
    wire                        [ 7: 0] en;
    wire                        [ 2: 0] phs;
  `endif

    always @(posedge rotate or negedge rst_int_n) begin
        if(~rst_int_n)
            rot_det             <= #0.04 1'b0;
        else
          //rot_det             <= #0.04 1'b1;
            rot_det             <= #0.04 dyn_ph_shift_en;
    end

    always @(posedge scanclk or negedge rst_int_n) begin
        if(~rst_int_n)
            rot_sync            <= #0.04 1'b0;
        else
            rot_sync            <= #0.04 rot_det;
    end

    always @(posedge scanclk or negedge rst_int_n) begin
        if(~rst_int_n)
            dir_sync            <= #0.04 1'b0;
        else
            dir_sync            <= #0.04 direction;
    end

  `ifdef FPGA_SIM
    always @(*) begin
        done_dly             = #0.08 done;  // add delay to make done pulse wide enough
                                            // pulse min width is 80ps according to analog designer
    end
  `else
      `ifdef FC_PG_SIM
        BUFV1_140P9T40H u1_donttouch_buf  (.Z(done_dly1), .I(done     ),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        BUFV1_140P9T40H u2_donttouch_buf  (.Z(done_dly2), .I(done_dly1),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        BUFV1_140P9T40H u3_donttouch_buf  (.Z(done_dly),  .I(done_dly2),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        BUFV1_140P9T40H u1_donttouch_buf  (.Z(done_dly1), .I(done     ));
        BUFV1_140P9T40H u2_donttouch_buf  (.Z(done_dly2), .I(done_dly1));
        BUFV1_140P9T40H u3_donttouch_buf  (.Z(done_dly),  .I(done_dly2));
      `endif
  `endif

    assign rst_int_n            = pll_rst_n & ~done_dly;

    assign d_z                  = ~{clk[6:0], clk[7]} & {8{rot_sync & dyn_ph_shift_en}};

    //clk_sel gen
  `ifdef FPGA_SIM
    assign clk_selb             = ph_now==8'h80 ? d_z[7]
                                : ph_now==8'h40 ? d_z[6]
                                : ph_now==8'h20 ? d_z[5]
                                : ph_now==8'h10 ? d_z[4]
                                : ph_now==8'h08 ? d_z[3]
                                : ph_now==8'h04 ? d_z[2]
                                : ph_now==8'h02 ? d_z[1]
                                :                 d_z[0] ;
  `else
      `ifdef FC_PG_SIM
        TBUFV8_140P9T40H    u7_donttouch_buft   (.Z(clk_selb),  .I(d_z[7]),   .OE(ph_now[7]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u6_donttouch_buft   (.Z(clk_selb),  .I(d_z[6]),   .OE(ph_now[6]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u5_donttouch_buft   (.Z(clk_selb),  .I(d_z[5]),   .OE(ph_now[5]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u4_donttouch_buft   (.Z(clk_selb),  .I(d_z[4]),   .OE(ph_now[4]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u3_donttouch_buft   (.Z(clk_selb),  .I(d_z[3]),   .OE(ph_now[3]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u2_donttouch_buft   (.Z(clk_selb),  .I(d_z[2]),   .OE(ph_now[2]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u1_donttouch_buft   (.Z(clk_selb),  .I(d_z[1]),   .OE(ph_now[1]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u0_donttouch_buft   (.Z(clk_selb),  .I(d_z[0]),   .OE(ph_now[0]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      //CKBD4BWP20P90CPD    u_donttouch_buft    (.Z(clk_selb),  .I(clk_sel1),                 .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        TBUFV8_140P9T40H    u7_donttouch_buft   (.Z(clk_selb),  .I(d_z[7]),   .OE(ph_now[7]));
        TBUFV8_140P9T40H    u6_donttouch_buft   (.Z(clk_selb),  .I(d_z[6]),   .OE(ph_now[6]));
        TBUFV8_140P9T40H    u5_donttouch_buft   (.Z(clk_selb),  .I(d_z[5]),   .OE(ph_now[5]));
        TBUFV8_140P9T40H    u4_donttouch_buft   (.Z(clk_selb),  .I(d_z[4]),   .OE(ph_now[4]));
        TBUFV8_140P9T40H    u3_donttouch_buft   (.Z(clk_selb),  .I(d_z[3]),   .OE(ph_now[3]));
        TBUFV8_140P9T40H    u2_donttouch_buft   (.Z(clk_selb),  .I(d_z[2]),   .OE(ph_now[2]));
        TBUFV8_140P9T40H    u1_donttouch_buft   (.Z(clk_selb),  .I(d_z[1]),   .OE(ph_now[1]));
        TBUFV8_140P9T40H    u0_donttouch_buft   (.Z(clk_selb),  .I(d_z[0]),   .OE(ph_now[0]));
      //CKBD4BWP20P90CPD    u_donttouch_buft    (.Z(clk_selb),  .I(clk_sel1)                );
      `endif
  `endif
    //use analog lib to replace std cell
  //gpll_vco_mux_bufft_d8 u_gpll_vco_mux_bufft_d8 (.dout(clk_selb), .din(d_z), .en(ph_now),    .vccd(vccd), .vssd(vssd));

    assign clk_sel              = ~clk_selb;

    //20220923, jzhou, ECO, use negedge to avoid setup/hold violation btw rot_sync_d1 & rot_sync_d2
    //                      because clk_selb is gated clk, it could be a very
    //                      short pulse
  //always @(posedge clk_selb or negedge rst_int_n) begin
    always @(negedge clk_selb or negedge rst_int_n) begin
        if(~rst_int_n)
            rot_sync_d1         <= #0.04 1'b0;
        else
            rot_sync_d1         <= #0.04 rot_sync;
    end

    always @(negedge clk_selb or negedge rst_int_n) begin
        if(~rst_int_n)
            rot_sync_d2         <= #0.04 1'b0;
        else
            rot_sync_d2         <= #0.04 rot_sync_d1;
    end

    assign scanclk_int          = rot_sync_d2 & clk_selb;

    always @(posedge scanclk_int or negedge rst_int_n) begin
        if(~rst_int_n)
            qd                  <= #0.04 3'b0;
        else
            qd                  <= #0.04 {rot_sync, qd[2:1]};
    end

    always @(negedge scanclk_int or negedge rst_int_n) begin
        if(~rst_int_n)
            done                <= #0.04 1'b0;
        else
            done                <= #0.04 qd[0];
    end

  //assign phasedone            = ~qd[2];
  //always @(negedge scanclk_int or negedge pll_rst_n) begin
    always @(posedge scanclk_int or negedge pll_rst_n) begin //use posedge to give more timing margin
                                                             //and clk_selb always have glitch when switching phase
        if(~pll_rst_n)
            phasedone           <= #0.04 1'b0;
        else if(qd==3'b110)
            phasedone           <= #0.04 ~phasedone;
    end

    assign phs_rstn             = {3{pll_rst_n}} |  mc1_phs;

    assign phs_setn             = {3{pll_rst_n}} | ~mc1_phs;

    assign phs_next             = (~qd[1] & qd[2]) ? (dir_sync ? (phs - 3'b1) : (phs + 3'b1))   //dir=0, inc; dir=1, dec
                                                   : phs ;

  `ifdef FPGA_SIM
    genvar i;
    generate for (i=0; i<=2; i=i+1) begin
        always @(posedge scanclk_int or negedge phs_rstn[i] or negedge phs_setn[i]) begin
            if     (~phs_rstn[i])
                phs[i]          <= #0.04 1'b0;
            else if(~phs_setn[i])
                phs[i]          <= #0.04 1'b1;
            else
                phs[i]          <= #0.04 phs_next[i];
        end
    end
    endgenerate
  `else
      `ifdef FC_PG_SIM
        DRSNQV2_140P9T40H   u0_donttouch_phs    (.Q(phs[0]),    .D(phs_next[0]),    .CK(scanclk_int),   .RDN(phs_rstn[0]),  .SDN(phs_setn[0]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u1_donttouch_phs    (.Q(phs[1]),    .D(phs_next[1]),    .CK(scanclk_int),   .RDN(phs_rstn[1]),  .SDN(phs_setn[1]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u2_donttouch_phs    (.Q(phs[2]),    .D(phs_next[2]),    .CK(scanclk_int),   .RDN(phs_rstn[2]),  .SDN(phs_setn[2]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV2_140P9T40H   u0_donttouch_phs    (.Q(phs[0]),    .D(phs_next[0]),    .CK(scanclk_int),   .RDN(phs_rstn[0]),  .SDN(phs_setn[0]));
        DRSNQV2_140P9T40H   u1_donttouch_phs    (.Q(phs[1]),    .D(phs_next[1]),    .CK(scanclk_int),   .RDN(phs_rstn[1]),  .SDN(phs_setn[1]));
        DRSNQV2_140P9T40H   u2_donttouch_phs    (.Q(phs[2]),    .D(phs_next[2]),    .CK(scanclk_int),   .RDN(phs_rstn[2]),  .SDN(phs_setn[2]));
      `endif
  `endif

    //clk out en gen
    assign en_enc               = phs==3'd7 ? 8'h80
                                : phs==3'd6 ? 8'h40
                                : phs==3'd5 ? 8'h20
                                : phs==3'd4 ? 8'h10
                                : phs==3'd3 ? 8'h08
                                : phs==3'd2 ? 8'h04
                                : phs==3'd1 ? 8'h02
                                :             8'h01 ;

    assign en_rstn              = {8{pll_rst_n}} |  en_enc;

    assign en_setn              = {8{pll_rst_n}} | ~en_enc;

  `ifdef FPGA_SIM
    genvar k;
    generate for (k=0; k<=7; k=k+1) begin
        always @(negedge clk_sel or negedge en_rstn[k] or negedge en_setn[k]) begin
            if     (~en_rstn[k])
                en[k]           <= #0.04 1'b0;
            else if(~en_setn[k])
                en[k]           <= #0.04 1'b1;
            else
                en[k]           <= #0.04 en_enc[k];
        end
    end
    endgenerate
  `else
      `ifdef FC_PG_SIM
        DRSNQV2_140P9T40H   u0_donttouch_en     (.Q(en[0]), .D(en_enc[0]),  .CK(clk_selb),  .RDN(en_rstn[0]),   .SDN(en_setn[0]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u1_donttouch_en     (.Q(en[1]), .D(en_enc[1]),  .CK(clk_selb),  .RDN(en_rstn[1]),   .SDN(en_setn[1]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u2_donttouch_en     (.Q(en[2]), .D(en_enc[2]),  .CK(clk_selb),  .RDN(en_rstn[2]),   .SDN(en_setn[2]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u3_donttouch_en     (.Q(en[3]), .D(en_enc[3]),  .CK(clk_selb),  .RDN(en_rstn[3]),   .SDN(en_setn[3]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u4_donttouch_en     (.Q(en[4]), .D(en_enc[4]),  .CK(clk_selb),  .RDN(en_rstn[4]),   .SDN(en_setn[4]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u5_donttouch_en     (.Q(en[5]), .D(en_enc[5]),  .CK(clk_selb),  .RDN(en_rstn[5]),   .SDN(en_setn[5]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u6_donttouch_en     (.Q(en[6]), .D(en_enc[6]),  .CK(clk_selb),  .RDN(en_rstn[6]),   .SDN(en_setn[6]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u7_donttouch_en     (.Q(en[7]), .D(en_enc[7]),  .CK(clk_selb),  .RDN(en_rstn[7]),   .SDN(en_setn[7]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV2_140P9T40H   u0_donttouch_en     (.Q(en[0]), .D(en_enc[0]),  .CK(clk_selb),  .RDN(en_rstn[0]),   .SDN(en_setn[0]));
        DRSNQV2_140P9T40H   u1_donttouch_en     (.Q(en[1]), .D(en_enc[1]),  .CK(clk_selb),  .RDN(en_rstn[1]),   .SDN(en_setn[1]));
        DRSNQV2_140P9T40H   u2_donttouch_en     (.Q(en[2]), .D(en_enc[2]),  .CK(clk_selb),  .RDN(en_rstn[2]),   .SDN(en_setn[2]));
        DRSNQV2_140P9T40H   u3_donttouch_en     (.Q(en[3]), .D(en_enc[3]),  .CK(clk_selb),  .RDN(en_rstn[3]),   .SDN(en_setn[3]));
        DRSNQV2_140P9T40H   u4_donttouch_en     (.Q(en[4]), .D(en_enc[4]),  .CK(clk_selb),  .RDN(en_rstn[4]),   .SDN(en_setn[4]));
        DRSNQV2_140P9T40H   u5_donttouch_en     (.Q(en[5]), .D(en_enc[5]),  .CK(clk_selb),  .RDN(en_rstn[5]),   .SDN(en_setn[5]));
        DRSNQV2_140P9T40H   u6_donttouch_en     (.Q(en[6]), .D(en_enc[6]),  .CK(clk_selb),  .RDN(en_rstn[6]),   .SDN(en_setn[6]));
        DRSNQV2_140P9T40H   u7_donttouch_en     (.Q(en[7]), .D(en_enc[7]),  .CK(clk_selb),  .RDN(en_rstn[7]),   .SDN(en_setn[7]));
      `endif
  `endif

    //clk_out gen
  `ifdef FPGA_SIM
    assign clk_out              = en==8'h80 ? clk[7]
                                : en==8'h40 ? clk[6]
                                : en==8'h20 ? clk[5]
                                : en==8'h10 ? clk[4]
                                : en==8'h08 ? clk[3]
                                : en==8'h04 ? clk[2]
                                : en==8'h02 ? clk[1]
                                :             clk[0] ;
  `else
      `ifdef FC_PG_SIM
        TBUFV8_140P9T40H    u7_donttouch_buft_out   (.Z(clk_out1),  .I(clk[7]),   .OE(en[7]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u6_donttouch_buft_out   (.Z(clk_out1),  .I(clk[6]),   .OE(en[6]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u5_donttouch_buft_out   (.Z(clk_out1),  .I(clk[5]),   .OE(en[5]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u4_donttouch_buft_out   (.Z(clk_out1),  .I(clk[4]),   .OE(en[4]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u3_donttouch_buft_out   (.Z(clk_out1),  .I(clk[3]),   .OE(en[3]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u2_donttouch_buft_out   (.Z(clk_out1),  .I(clk[2]),   .OE(en[2]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u1_donttouch_buft_out   (.Z(clk_out1),  .I(clk[1]),   .OE(en[1]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    u0_donttouch_buft_out   (.Z(clk_out1),  .I(clk[0]),   .OE(en[0]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        CLKBUFV4_140P9T40H  u_donttouch_buft_out    (.Z(clk_out ),  .I(clk_out1),             .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        TBUFV8_140P9T40H    u7_donttouch_buft_out   (.Z(clk_out1),  .I(clk[7]),   .OE(en[7]));
        TBUFV8_140P9T40H    u6_donttouch_buft_out   (.Z(clk_out1),  .I(clk[6]),   .OE(en[6]));
        TBUFV8_140P9T40H    u5_donttouch_buft_out   (.Z(clk_out1),  .I(clk[5]),   .OE(en[5]));
        TBUFV8_140P9T40H    u4_donttouch_buft_out   (.Z(clk_out1),  .I(clk[4]),   .OE(en[4]));
        TBUFV8_140P9T40H    u3_donttouch_buft_out   (.Z(clk_out1),  .I(clk[3]),   .OE(en[3]));
        TBUFV8_140P9T40H    u2_donttouch_buft_out   (.Z(clk_out1),  .I(clk[2]),   .OE(en[2]));
        TBUFV8_140P9T40H    u1_donttouch_buft_out   (.Z(clk_out1),  .I(clk[1]),   .OE(en[1]));
        TBUFV8_140P9T40H    u0_donttouch_buft_out   (.Z(clk_out1),  .I(clk[0]),   .OE(en[0]));
        CLKBUFV4_140P9T40H  u_donttouch_buft_out    (.Z(clk_out ),  .I(clk_out1)            );
      `endif
  `endif
    //use analog lib to replace std cell
  //gpll_vco_mux_bufft_d6 u_gpll_vco_mux_bufft_d6   (.dout(clk_out), .din(clk),   .en(en),    .vccd(vccd), .vssd(vssd));

    // ph_now gen
  `ifdef FPGA_SIM
    genvar l;
    generate for (l=0; l<=7; l=l+1) begin
        always @(posedge clk_sel  or negedge en_rstn[l] or negedge en_setn[l]) begin
            if     (~en_rstn[l])
                ph_now[l]       <= #0.04 1'b0;
            else if(~en_setn[l])
                ph_now[l]       <= #0.04 1'b1;
            else
                ph_now[l]       <= #0.04 en[l];
        end
    end
    endgenerate
  `else
      `ifdef FC_PG_SIM
        DRSNQV2_140P9T40H   u0_donttouch_ph_now (.Q(ph_now[0]), .D(en[0]),  .CK(clk_sel),   .RDN(en_rstn[0]),   .SDN(en_setn[0]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u1_donttouch_ph_now (.Q(ph_now[1]), .D(en[1]),  .CK(clk_sel),   .RDN(en_rstn[1]),   .SDN(en_setn[1]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u2_donttouch_ph_now (.Q(ph_now[2]), .D(en[2]),  .CK(clk_sel),   .RDN(en_rstn[2]),   .SDN(en_setn[2]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u3_donttouch_ph_now (.Q(ph_now[3]), .D(en[3]),  .CK(clk_sel),   .RDN(en_rstn[3]),   .SDN(en_setn[3]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u4_donttouch_ph_now (.Q(ph_now[4]), .D(en[4]),  .CK(clk_sel),   .RDN(en_rstn[4]),   .SDN(en_setn[4]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u5_donttouch_ph_now (.Q(ph_now[5]), .D(en[5]),  .CK(clk_sel),   .RDN(en_rstn[5]),   .SDN(en_setn[5]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u6_donttouch_ph_now (.Q(ph_now[6]), .D(en[6]),  .CK(clk_sel),   .RDN(en_rstn[6]),   .SDN(en_setn[6]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u7_donttouch_ph_now (.Q(ph_now[7]), .D(en[7]),  .CK(clk_sel),   .RDN(en_rstn[7]),   .SDN(en_setn[7]),   .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV2_140P9T40H   u0_donttouch_ph_now (.Q(ph_now[0]), .D(en[0]),  .CK(clk_sel),   .RDN(en_rstn[0]),   .SDN(en_setn[0]));
        DRSNQV2_140P9T40H   u1_donttouch_ph_now (.Q(ph_now[1]), .D(en[1]),  .CK(clk_sel),   .RDN(en_rstn[1]),   .SDN(en_setn[1]));
        DRSNQV2_140P9T40H   u2_donttouch_ph_now (.Q(ph_now[2]), .D(en[2]),  .CK(clk_sel),   .RDN(en_rstn[2]),   .SDN(en_setn[2]));
        DRSNQV2_140P9T40H   u3_donttouch_ph_now (.Q(ph_now[3]), .D(en[3]),  .CK(clk_sel),   .RDN(en_rstn[3]),   .SDN(en_setn[3]));
        DRSNQV2_140P9T40H   u4_donttouch_ph_now (.Q(ph_now[4]), .D(en[4]),  .CK(clk_sel),   .RDN(en_rstn[4]),   .SDN(en_setn[4]));
        DRSNQV2_140P9T40H   u5_donttouch_ph_now (.Q(ph_now[5]), .D(en[5]),  .CK(clk_sel),   .RDN(en_rstn[5]),   .SDN(en_setn[5]));
        DRSNQV2_140P9T40H   u6_donttouch_ph_now (.Q(ph_now[6]), .D(en[6]),  .CK(clk_sel),   .RDN(en_rstn[6]),   .SDN(en_setn[6]));
        DRSNQV2_140P9T40H   u7_donttouch_ph_now (.Q(ph_now[7]), .D(en[7]),  .CK(clk_sel),   .RDN(en_rstn[7]),   .SDN(en_setn[7]));
      `endif
  `endif

endmodule

`timescale 1ns/1ps

module gpll_vco_mux_pi_ctrl ( phasedone, phc, pi_enable, vccd, vssd, clk0_div,
clk_pi, direction, mc1_frac, mc1_pi_frac_mode, mc1_pi_phshift_en, phsel_0, pll_rst_n,
rotate, scanclk );

    output                      [ 6: 0] phc;
    output                              pi_enable;
    output                              phasedone;

    input                               clk0_div;
    input                               clk_pi;
    input                               pll_rst_n;

    input                               scanclk;
    input                               direction;
    input                               rotate;
    input                               mc1_pi_frac_mode;
    input                       [ 6: 0] mc1_frac;
    input                       [ 6: 0] phsel_0;
    input                               mc1_pi_phshift_en;

    inout                               vssd;
    inout                               vccd;

    parameter C2Q               = 0.04;

    reg                                 rot_det;
    reg                                 rot_sync;
    reg                                 dir_sync;
    reg                         [ 3: 0] qd;
    reg                                 done;
    reg                         [ 1: 0] pll_rst_n_sync;
    reg                                 phasedone;

  `ifdef FPGA_SIM
    reg                         [ 6: 0] phc;
  `else
    wire                        [ 6: 0] phc;
  `endif

    wire                                rst_int_n;
    wire                                rot_clk;
    wire                                rot_clk_b;
    wire                        [ 6: 0] setn;
    wire                        [ 6: 0] rstn;
    wire                        [ 6: 0] phc_w;
    wire                        [ 6: 0] phc_next;
    wire                        [ 6: 0] frac;
    wire                                phc_w_sel;
    wire                                done_dly;
    wire                                done_dly1;
    wire                                done_dly2;

    always @(posedge rotate or negedge rst_int_n) begin
        if(~rst_int_n)
            rot_det             <= #C2Q 1'b0;
        else
          //rot_det             <= #C2Q 1'b1;
            rot_det             <= #C2Q mc1_pi_phshift_en;
    end

    always @(posedge scanclk or negedge rst_int_n) begin
        if(~rst_int_n)
            rot_sync            <= #C2Q 1'b0;
        else
            rot_sync            <= #C2Q rot_det;
    end

    always @(posedge scanclk or negedge rst_int_n) begin
        if(~rst_int_n)
            dir_sync            <= #C2Q 1'b0;
        else
            dir_sync            <= #C2Q direction;
    end

    assign rot_clk              = mc1_pi_frac_mode ? clk0_div
                                                   : clk_pi & mc1_pi_phshift_en;

    assign rot_clk_b            = ~rot_clk;

    //external async rstn synchronizer
    always @(posedge rot_clk or negedge pll_rst_n) begin
        if(~pll_rst_n)
            pll_rst_n_sync      <= #C2Q 2'b0;
        else
            pll_rst_n_sync      <= #C2Q {pll_rst_n_sync[0], 1'b1};
    end

    assign pi_enable            = mc1_pi_frac_mode | mc1_pi_phshift_en;

    //sync external control
    always @(posedge rot_clk or negedge rst_int_n) begin
        if(~rst_int_n)
            qd                  <= #C2Q 4'b0;
        else
            qd                  <= #C2Q {rot_sync, qd[3:1]};
    end

  //always @(posedge rot_clk_b or negedge rst_int_n) begin
    always @(posedge rot_clk_b or negedge pll_rst_n_sync[1]) begin
        if(~pll_rst_n_sync[1])
            done                <= #C2Q 1'b0;
        else
            done                <= #C2Q qd[0];
    end

  `ifdef FPGA_SIM
    assign done_dly             = done;     // add delay to make done pulse wide enough
                                            // pulse min width is 80ps according to analog designer
  `else
      `ifdef FC_PG_SIM
        BUFV1_140P9T40H u1_donttouch_buf  (.Z(done_dly1), .I(done     ),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        BUFV1_140P9T40H u2_donttouch_buf  (.Z(done_dly2), .I(done_dly1),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        BUFV1_140P9T40H u3_donttouch_buf  (.Z(done_dly),  .I(done_dly2),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        BUFV1_140P9T40H u1_donttouch_buf  (.Z(done_dly1), .I(done     ));
        BUFV1_140P9T40H u2_donttouch_buf  (.Z(done_dly2), .I(done_dly1));
        BUFV1_140P9T40H u3_donttouch_buf  (.Z(done_dly),  .I(done_dly2));
      `endif
  `endif

  //assign phasedone            = ~qd[2];
  //always @(posedge rot_clk_b or negedge pll_rst_n_sync[1]) begin
    always @(posedge rot_clk   or negedge pll_rst_n_sync[1]) begin  //use posedge to give more timing margin
        if(~pll_rst_n_sync[1])
            phasedone           <= #C2Q 1'b0;
        else if(qd[1] & ~done)
            phasedone           <= #C2Q ~phasedone;
    end

    assign rst_int_n            = pll_rst_n_sync[1] & ~done_dly;

    assign rstn                 = {7{pll_rst_n_sync[1]}} |  phsel_0;

    assign setn                 = {7{pll_rst_n_sync[1]}} | ~phsel_0;

    assign phc_w_sel            = mc1_pi_frac_mode | (qd[2] & ~qd[1]);

    assign frac                 = mc1_pi_frac_mode ? mc1_frac
                                : dir_sync         ? 7'b000_0001        // +1 phase dn
                                :                    7'b111_1111;       // -1 phase up

    assign phc_next             = phc + frac;

    assign phc_w                = phc_w_sel ? phc_next : phc;

  `ifdef FPGA_SIM
    genvar i;
    generate for (i=0; i<=2; i=i+1) begin
        always @(posedge rot_clk or negedge rstn[i] or negedge setn[i]) begin
            if     (~rstn[i])
                phc[i]          <= #C2Q 1'b0;
            else if(~setn[i])
                phc[i]          <= #C2Q 1'b1;
            else
                phc[i]          <= #C2Q phc_w[i];
        end
    end
    endgenerate
  `else
      `ifdef FC_PG_SIM
        DRSNQV2_140P9T40H   u0_donttouch_dff    (.Q(phc[0]),    .D(phc_w[0]),   .CK(rot_clk),   .RDN(rstn[0]),  .SDN(setn[0]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u1_donttouch_dff    (.Q(phc[1]),    .D(phc_w[1]),   .CK(rot_clk),   .RDN(rstn[1]),  .SDN(setn[1]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u2_donttouch_dff    (.Q(phc[2]),    .D(phc_w[2]),   .CK(rot_clk),   .RDN(rstn[2]),  .SDN(setn[2]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u3_donttouch_dff    (.Q(phc[3]),    .D(phc_w[3]),   .CK(rot_clk),   .RDN(rstn[3]),  .SDN(setn[3]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u4_donttouch_dff    (.Q(phc[4]),    .D(phc_w[4]),   .CK(rot_clk),   .RDN(rstn[4]),  .SDN(setn[4]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u5_donttouch_dff    (.Q(phc[5]),    .D(phc_w[5]),   .CK(rot_clk),   .RDN(rstn[5]),  .SDN(setn[5]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV2_140P9T40H   u6_donttouch_dff    (.Q(phc[6]),    .D(phc_w[6]),   .CK(rot_clk),   .RDN(rstn[6]),  .SDN(setn[6]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV2_140P9T40H   u0_donttouch_dff    (.Q(phc[0]),    .D(phc_w[0]),   .CK(rot_clk),   .RDN(rstn[0]),  .SDN(setn[0]));
        DRSNQV2_140P9T40H   u1_donttouch_dff    (.Q(phc[1]),    .D(phc_w[1]),   .CK(rot_clk),   .RDN(rstn[1]),  .SDN(setn[1]));
        DRSNQV2_140P9T40H   u2_donttouch_dff    (.Q(phc[2]),    .D(phc_w[2]),   .CK(rot_clk),   .RDN(rstn[2]),  .SDN(setn[2]));
        DRSNQV2_140P9T40H   u3_donttouch_dff    (.Q(phc[3]),    .D(phc_w[3]),   .CK(rot_clk),   .RDN(rstn[3]),  .SDN(setn[3]));
        DRSNQV2_140P9T40H   u4_donttouch_dff    (.Q(phc[4]),    .D(phc_w[4]),   .CK(rot_clk),   .RDN(rstn[4]),  .SDN(setn[4]));
        DRSNQV2_140P9T40H   u5_donttouch_dff    (.Q(phc[5]),    .D(phc_w[5]),   .CK(rot_clk),   .RDN(rstn[5]),  .SDN(setn[5]));
        DRSNQV2_140P9T40H   u6_donttouch_dff    (.Q(phc[6]),    .D(phc_w[6]),   .CK(rot_clk),   .RDN(rstn[6]),  .SDN(setn[6]));
      `endif
  `endif

endmodule

`timescale 1ns/1ps

module gpll_vco_mux_buf ( phin_0, phin_1, phin_2, phin_3, phin_4, phin_5, phin_6,
phin_7, phomux0, phomux, vco_phase, vccd, vssd, en_clk, mc1_phomux_sel,
phin );

    output                      [ 7: 0] phin_7;         // to vco_mux_phs
    output                      [ 7: 0] phin_6;         // to vco_mux_phs
    output                      [ 7: 0] phin_5;         // to vco_mux_phs
    output                      [ 7: 0] phin_4;         // to vco_mux_phs
    output                      [ 7: 0] phin_3;         // to vco_mux_phs
    output                      [ 7: 0] phin_2;         // to vco_mux_phs
    output                      [ 7: 0] phin_1;         // to vco_mux_phs
    output                      [ 7: 0] phin_0;         // to vco_mux_div_ctrl

    output                      [ 7: 0] phomux;         // to output
    output                              phomux0;        // to output
    output                      [ 7: 0] vco_phase;      // to PI

    input                       [ 7: 0] phin;           // from PLL
    input                       [ 7: 0] en_clk;
    input                       [ 7: 0] mc1_phomux_sel;

    inout                               vssd;
    inout                               vccd;

// Buses in the design
wire  [7:0]  vco_phase;
wire  [7:0]  phomux;
wire  [7:0]  phin_0;
wire  [7:0]  phin_1;
wire  [7:0]  phin_2;
wire  [7:0]  phin_3;
wire  [7:0]  phin_4;
wire  [7:0]  phin_5;
wire  [7:0]  phin_6;
wire  [7:0]  phin_7;
wire  [7:0]  vco_pho_buf;
wire  [7:0]  vco_pho;
wire  [0:7]  net0204;
wire        net344;
wire        net342;
wire        net343;
wire        net345;
wire        net340;
wire        net338;
wire        net339;
wire        net341;
wire        net0202;
wire        net0174;
wire        net0175;
wire        net0176;
wire        net0121;

//`ifdef FPGA_SIM
    assign phin_7               = phin | {8{~en_clk[7]}};
    assign phin_6               = phin | {8{~en_clk[6]}};
    assign phin_5               = phin | {8{~en_clk[5]}};
    assign phin_4               = phin | {8{~en_clk[4]}};
    assign phin_3               = phin | {8{~en_clk[3]}};
    assign phin_2               = phin | {8{~en_clk[2]}};
    assign phin_1               = phin | {8{~en_clk[1]}};
    assign phin_0               = phin | {8{~en_clk[0]}};

    assign phomux[7]            = mc1_phomux_sel[7] ? phin[7] : phin[3];
    assign phomux[6]            = mc1_phomux_sel[6] ? phin[7] : phin[3];
    assign phomux[5]            = mc1_phomux_sel[5] ? phin[7] : phin[3];
    assign phomux[4]            = mc1_phomux_sel[4] ? phin[7] : phin[3];
    assign phomux[3]            = mc1_phomux_sel[3] ? phin[7] : phin[3];
    assign phomux[2]            = mc1_phomux_sel[2] ? phin[7] : phin[3];
    assign phomux[1]            = mc1_phomux_sel[1] ? phin[7] : phin[3];
    assign phomux[0]            = mc1_phomux_sel[0] ? phin[7] : phin[3];

    assign phomux0              = phin[0];

    assign vco_phase            = phin_0;

endmodule

`timescale 1ns / 1ps 

module gpll_vco_mux ( ck_mux_out, phasedone, phc, phomux0, phomux,
     pi_enable, vco_phase, vccd, vssd, ck0_div, ck0_div_by_one,
     ck_pi, direction, en_clk, mc1_clk0_frac_en, mc1_dyn_ph_shift_en,
     mc1_frac, mc1_phomux_sel, mc1_pi_frac_mode, mc1_pi_phshift_en,
     phin, phsel_0, phsel_1, phsel_2, phsel_3, phsel_4, phsel_5,
     phsel_6, phsel_7, pllrst_n, rotate, scanclk, mc1_pi_sel );

output  phomux0, pi_enable;

inout  vccd, vssd;

input  ck0_div, ck0_div_by_one, ck_pi, mc1_clk0_frac_en,
     mc1_dyn_ph_shift_en, mc1_pi_frac_mode, mc1_pi_phshift_en,
     pllrst_n;

output [6:0]  phc;
output [7:0]  vco_phase;
output [7:0]  phasedone;
output [7:0]  phomux;
output [7:0]  ck_mux_out;

input [7:0]  mc1_pi_sel;
input [7:0]  en_clk;
input [7:0]  phin;
input [6:0]  mc1_frac;
input [6:0]  phsel_0;
input [2:0]  phsel_1;
input [2:0]  phsel_2;
input [2:0]  phsel_3;
input [2:0]  phsel_7;
input [2:0]  phsel_6;
input [2:0]  phsel_5;
input [2:0]  phsel_4;
input [7:0]  mc1_phomux_sel;
input [7:0]  direction;
input [7:0]  scanclk;
input [7:0]  rotate;

// Buses in the design

wire  [7:0]  phin_0;

wire  [7:0]  phin_2;

wire  [7:0]  phin_4;

wire  [7:0]  phin_7;

wire  [7:0]  phin_6;

wire  [7:0]  phin_3;

wire  [7:0]  phin_5;

wire  [7:0]  phin_1;

wire  [7:0]  clk_out;


wire  [7:0]  phin_1_swap;
wire  [7:0]  phin_2_swap;
wire  [7:0]  phin_3_swap;
wire  [7:0]  phin_4_swap;
wire  [7:0]  phin_5_swap;
wire  [7:0]  phin_6_swap;
wire  [7:0]  phin_7_swap;

assign phin_1_swap  = {phin_1[0], phin_1[1], phin_1[2], phin_1[3], phin_1[4], phin_1[5], phin_1[6], phin_1[7]};
assign phin_2_swap  = {phin_2[0], phin_2[1], phin_2[2], phin_2[3], phin_2[4], phin_2[5], phin_2[6], phin_2[7]};
assign phin_3_swap  = {phin_3[0], phin_3[1], phin_3[2], phin_3[3], phin_3[4], phin_3[5], phin_3[6], phin_3[7]};
assign phin_4_swap  = {phin_4[0], phin_4[1], phin_4[2], phin_4[3], phin_4[4], phin_4[5], phin_4[6], phin_4[7]};
assign phin_5_swap  = {phin_5[0], phin_5[1], phin_5[2], phin_5[3], phin_5[4], phin_5[5], phin_5[6], phin_5[7]};
assign phin_6_swap  = {phin_6[0], phin_6[1], phin_6[2], phin_6[3], phin_6[4], phin_6[5], phin_6[6], phin_6[7]};
assign phin_7_swap  = {phin_7[0], phin_7[1], phin_7[2], phin_7[3], phin_7[4], phin_7[5], phin_7[6], phin_7[7]};

gpll_vco_mux_pi_ctrl I0 ( .phasedone(phasedone[0]),
     .direction(direction[0]), .rotate(rotate[0]),
     .scanclk(scanclk[0]), .pll_rst_n(pllrst_n), .vccd(vccd),
     .vssd(vssd), .phc(phc[6:0]), .pi_enable(pi_enable),
     .clk0_div(ck0_div), .clk_pi(ck_pi), .mc1_frac(mc1_frac[6:0]),
     .mc1_pi_frac_mode(mc1_pi_frac_mode),
     .mc1_pi_phshift_en(mc1_pi_phshift_en), .phsel_0(phsel_0[6:0]));
gpll_vco_mux_div_ctrl I2 ( .clk(phin_0[7:0]), .vssd(vssd), .vccd(vccd),
     .clk_out(clk_out[0]), .clk0_div_by_one(ck0_div_by_one),
     .clk_div(ck0_div), .mc1_frac(mc1_frac[6:4]),
     .mc1_frac_en(mc1_clk0_frac_en), .pll_rst_n(pllrst_n), .phsel(phsel_0[6:4]));
gpll_vco_mux_phs I4_7_ ( .vccd(vccd), .vssd(vssd),
     .clk_out(clk_out[7]), .phasedone(phasedone[7]), .clk(phin_7_swap[7:0]),
     .direction(direction[7]), .dyn_ph_shift_en(mc1_dyn_ph_shift_en),
     .mc1_phs(phsel_7[2:0]), .pll_rst_n(pllrst_n), .rotate(rotate[7]),
     .scanclk(scanclk[7]));
gpll_vco_mux_phs I4_6_ ( .vccd(vccd), .vssd(vssd),
     .clk_out(clk_out[6]), .phasedone(phasedone[6]), .clk(phin_6_swap[7:0]),
     .direction(direction[6]), .dyn_ph_shift_en(mc1_dyn_ph_shift_en),
     .mc1_phs(phsel_6[2:0]), .pll_rst_n(pllrst_n), .rotate(rotate[6]),
     .scanclk(scanclk[6]));
gpll_vco_mux_phs I4_5_ ( .vccd(vccd), .vssd(vssd),
     .clk_out(clk_out[5]), .phasedone(phasedone[5]), .clk(phin_5_swap[7:0]),
     .direction(direction[5]), .dyn_ph_shift_en(mc1_dyn_ph_shift_en),
     .mc1_phs(phsel_5[2:0]), .pll_rst_n(pllrst_n), .rotate(rotate[5]),
     .scanclk(scanclk[5]));
gpll_vco_mux_phs I4_4_ ( .vccd(vccd), .vssd(vssd),
     .clk_out(clk_out[4]), .phasedone(phasedone[4]), .clk(phin_4_swap[7:0]),
     .direction(direction[4]), .dyn_ph_shift_en(mc1_dyn_ph_shift_en),
     .mc1_phs(phsel_4[2:0]), .pll_rst_n(pllrst_n), .rotate(rotate[4]),
     .scanclk(scanclk[4]));
gpll_vco_mux_phs I4_3_ ( .vccd(vccd), .vssd(vssd),
     .clk_out(clk_out[3]), .phasedone(phasedone[3]), .clk(phin_3_swap[7:0]),
     .direction(direction[3]), .dyn_ph_shift_en(mc1_dyn_ph_shift_en),
     .mc1_phs(phsel_3[2:0]), .pll_rst_n(pllrst_n), .rotate(rotate[3]),
     .scanclk(scanclk[3]));
gpll_vco_mux_phs I4_2_ ( .vccd(vccd), .vssd(vssd),
     .clk_out(clk_out[2]), .phasedone(phasedone[2]), .clk(phin_2_swap[7:0]),
     .direction(direction[2]), .dyn_ph_shift_en(mc1_dyn_ph_shift_en),
     .mc1_phs(phsel_2[2:0]), .pll_rst_n(pllrst_n), .rotate(rotate[2]),
     .scanclk(scanclk[2]));
gpll_vco_mux_phs I4_1_ ( .vccd(vccd), .vssd(vssd),
     .clk_out(clk_out[1]), .phasedone(phasedone[1]), .clk(phin_1_swap[7:0]),
     .direction(direction[1]), .dyn_ph_shift_en(mc1_dyn_ph_shift_en),
     .mc1_phs(phsel_1[2:0]), .pll_rst_n(pllrst_n), .rotate(rotate[1]),
     .scanclk(scanclk[1]));
gpll_vco_mux_buf I5 ( .vco_phase(vco_phase[7:0]), .vccd(vccd),
     .vssd(vssd), .phin_0(phin_0[7:0]), .phin_1(phin_1[7:0]),
     .phin_2(phin_2[7:0]), .phin_3(phin_3[7:0]), .phin_4(phin_4[7:0]),
     .phin_5(phin_5[7:0]), .phin_6(phin_6[7:0]), .phin_7(phin_7[7:0]),
     .phomux0(phomux0), .phomux(phomux[7:0]), .en_clk(en_clk[7:0]),
     .mc1_phomux_sel(mc1_phomux_sel[7:0]), .phin(phin[7:0]));

    al6100_gpll_cell_clk_mux u_donttouch_clk_mux2[7:0] (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(ck_mux_out),  .in1(ck_pi),   .in0(clk_out),  .sel(mc1_pi_sel)
    );

endmodule

// -----------------------------------------------------------------
//                 Copyright (c) 2023 COMPANY: Anlogic
//                       ALL RIGHTS RESERVED
// -----------------------------------------------------------------
// Filename      : axis2apb_gpll.v
// Author        : yyliu
// Created On    : 2022-10-24
// Last Modified : 
// -----------------------------------------------------------------
// Description: decode axis package, and write/read data to/from apb4
//              slave(serdes)
//
//  2022-10-24: initial version
//
// -----------------------------------------------------------------

`timescale 1ns/1ps

module axis2apb_gpll #(
    parameter            TOW      = 9,  //TIMEOUT width
    parameter            TIMEOUT  = 9'h1ff,
    parameter            LENW     = 19,
    parameter            MAX_LEN  = 19'd2,  // physram - 16385, cr - 2, pll - 2, eram - 1028
    parameter            PADDRW   = 32,  //apb addr width
    parameter            PDATAW   = 32   //apb data width
)(
    `ifdef FC_PG_SIM
    input                           vccd,
    input                           vssd,
    `endif

    //scan mode
    input                           test_mode,
  //input                           scan_mode,
    input                           scan_resetn,
    input                           scan_enable,
    input                           scan_clk,

  //input                           scan_in,                // from outside, use drp_pll_rd
    output                          scan_out,               // to   fbdiv

    input  [11:0]                   map_i,      
    input                           axis_clk_i,  //2M~200M
    input                           axis_rst_n_i,
    // connect to config master tx if
    input                           s_rvalid_i,
    input  [31:0]                   s_rdata_i,
    input                           s_rlast_i,
    output wire                     s_rready_o,  //always 1
    // connect to config master rx if
    input                           s_tready_i,
    output wire                     s_tvalid_o,
    output wire [31:0]              s_tdata_o,
    output wire                     s_tlast_o,
    output wire                     s_tuser_o,
    // cascade to next module
  //output wire                     m_axis_clk_o,
  //output wire                     m_axis_rst_n_o,
    output wire                     m_tvalid_o,
    output wire [31:0]              m_tdata_o,
    output wire                     m_tlast_o,  
    input                           m_tready_i,  //always 1
    output wire                     m_rready_o,
    input                           m_rvalid_i,
    input  [31:0]                   m_rdata_i,
    input                           m_rlast_i,
    input                           m_tuser_i,  //cascade error
    // pib if
  //input                           apb4_pclk,
  //input                           apb4_preset,  //active high
  //input                           apb4_psel,
  //input                           apb4_penable,
  //input                           apb4_pwrite,
  //input  [PADDRW-1:0]             apb4_paddr,
  //input  [PDATAW-1:0]             apb4_pwdata,
  //input  [((PDATAW>>3)-1):0]      apb4_pstrobe,  //apb4
  //input  [2:0]                    apb4_pprot,  //apb4
  //output wire [PDATAW-1:0]        apb4_prdata,
  //output wire                     apb4_pready,
  //output wire                     apb4_pslverr,
    // apb4 if
  //output wire                     pclk_o,
  //output wire                     prst_n_o,
  //output wire                     psel_o,
  //output wire                     penable_o,
  //output wire                     pwrite_o,
  //output wire [PADDRW-1:0]        paddr_o,
  //output wire [PDATAW-1:0]        pwdata_o,
  //output wire [((PDATAW>>3)-1):0] pstrb_o,  //apb4
  //output wire [2:0]               pprot_o,  //apb4
  //input  [PDATAW-1:0]             prdata_i,
  //input                           pready_i,
  //input                           pslverr_i,

  //output [13:0]                   sram_addr_config_o, 
  //output [31:0]                   sram_wr_data_config_o,
  //output                          sram_wr_en_config_o,
  //output                          sram_rd_en_config_o,

    // phy signals
  //output wire                     irst_por_ba,
  //output wire                     irst_apb4_presetn,
  //output wire [3:0]               irst_rx_ln_ba,
  //output wire [3:0]               irst_tx_ln_ba,
  //output wire [3:0]               ictl_rx_state_req_ln,
  //input       [3:0]               octl_rx_state_ack_ln,
  //output wire [3:0]               ictl_tx_state_req_ln,
  //input       [3:0]               octl_tx_state_ack_ln,
  //output wire                     ictl_bscan_rx_ac_term_nt,
  //output wire                     ictl_bscan_rx_dc_term_nt,
  //output wire [2:0]               ictl_bscan_rx_vbias_nt,
  //output wire [1:0]               ictl_bscan_rx_vhyst_nt,
  //output wire                     ictl_bscan_mode_enable,
  //output wire                     ictl_pclk_state_req,
  //input                           octl_pclk_state_ack,
  //output wire                     ictl_ref_ls_ena_a,
  //output wire                     ictl_bscan_ena_a,
  //output wire                     phy_reg_por_rst_n,
  //output wire                     phy_reg_por_en,
  //output wire                     phy_jtag_bypass_en,
  //output wire                     phy_bscan_bypass_en,

  //output wire                     cfg_n205_jtag_sel,
  //output wire                     cfg_creg_jtag_sel,
  //output wire                     cfg_n205_src_sel,
  //output wire                     cfg_creg_src_sel,
  //output wire                     cfg_reg_jtag_sel,
  //output wire                     cfg_core_bypass,
  //output wire                     core_sram_init_done,
  //output wire                     pib_sel,

    input                           drp_clk,                // To xpll_slave of pll_slave.v
    input [7:0]                     drp_pll_addr,           // To xpll_slave of pll_slave.v
    input                           drp_pll_rd,             // To xpll_slave of pll_slave.v
    input                           drp_pll_sel,            // To xpll_slave of pll_slave.v
    input [7:0]                     drp_pll_wdata,          // To xpll_slave of pll_slave.v
    input                           drp_pll_wr,             // To xpll_slave of pll_slave.v
    input                           drp_rst_n,              // To xpll_slave of pll_slave.v
    output                          drp_pll_err,            // From xpll_slave of pll_slave.v
    output [7:0]                    drp_pll_rdata,          // From xpll_slave of pll_slave.v
    output                          drp_pll_rdy,            // From xpll_slave of pll_slave.v

    output [31: 0]                  pll_cfg_o,              // From xpll_slave of pll_slave.v
    output                          mc1_fastloop_cfg,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_bias_icfg,          // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_cal_counter,        // To xpll of gpll_top.v
    output                          mc1_clk0_frac_en,       // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_cp_dlysel,          // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_cp_refsel,          // To xpll of gpll_top.v
    output                          mc1_dig_pd,             // To xpll of gpll_top.v
    output [ 5: 0]                  mc1_dig_sel,            // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_div2_bypass_n,      // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_div2_phc,           // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_div_en,             // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc0,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc1,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc2,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc3,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc4,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc5,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc6,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc7,              // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_divc_outmux,        // To xpll of gpll_top.v
    output                          mc1_divc_outmux_main,   // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux0,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux1,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux2,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux3,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux4,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux5,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux6,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux7,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divcrst_en,         // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_divrst_ph_sel,      // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty0,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty1,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty2,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty3,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty4,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty5,              // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_duty50_n,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty6,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty7,              // To xpll of gpll_top.v
    output                          mc1_dyn_ph_shift_en,    // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc0,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc1,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc2,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc3,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc4,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc5,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc6,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc7,           // To xpll of gpll_top.v
    output                          mc1_dyn_source,         // To xpll of gpll_top.v
    output                          mc1_enable_sync,        // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_enclk,              // To xpll of gpll_top.v
    output                          mc1_enclk_main,         // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_fastlock_sel,       // To xpll of gpll_top.v
    output [27: 0]                  mc1_fbfracn_sel,        // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_fbk_div,            // To xpll of gpll_top.v
    output [ 3: 0]                  mc1_fbk_sel,            // To xpll of gpll_top.v
    output [ 3: 0]                  mc1_fbk_sel_wakeup,     // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_frac,               // To xpll of gpll_top.v
    output                          mc1_fracn_dither_en,    // To xpll of gpll_top.v
    output [ 3: 0]                  mc1_fracn_dither_sel,   // To xpll of gpll_top.v
    output                          mc1_fracn_en,           // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_fracn_prbs_sel,     // To xpll of gpll_top.v
  //output                          mc1_freq_lock,          // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_gpll_lockdet,       // To xpll of gpll_top.v
    output [ 4: 0]                  mc1_icp_banch,          // To xpll of gpll_top.v
    output [ 4: 0]                  mc1_icp_bias,           // To xpll of gpll_top.v
    output                          mc1_intfb,              // To xpll of gpll_top.v
    output [ 3: 0]                  mc1_kvco_sel,           // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_load_div2_en,       // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_load_en,            // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_lpf_r1_sel,         // To xpll of gpll_top.v
    output                          mc1_mrst_en,            // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_outgate_en,         // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_outputpi_capsel,    // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_outputpi_icfg,      // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc0,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc1,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc2,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc3,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc4,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc5,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc6,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc7,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phic0,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic1,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic2,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic3,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic4,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic5,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic6,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic7,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_pi_capsel,          // To xpll of gpll_top.v
    output                          mc1_pi_frac_mode,       // To xpll of gpll_top.v
    output [ 3: 0]                  mc1_pi_icfg,            // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_pi_out_sel,         // To xpll of gpll_top.v
    output                          mc1_pi_phi_en,          // To xpll of gpll_top.v
    output                          mc1_pllpdn,             // To xpll of gpll_top.v
    output                          mc1_pllrst_en,          // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_ref_div,            // To xpll of gpll_top.v
    output                          mc1_refclk_det_byp,     // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_refclk_det_div,     // To xpll of gpll_top.v
    output                          mc1_refclk_out_en,      // To xpll of gpll_top.v
    output                          mc1_ssc_dn_loop_mode,   // To xpll of gpll_top.v
    output                          mc1_ssc_en,             // To xpll of gpll_top.v
    output [17: 0]                  mc1_ssc_freq_div,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_ssc_lpf_sel,        // To xpll of gpll_top.v
    output                          mc1_ssc_mode,           // To xpll of gpll_top.v
    output                          mc1_ssc_reset,          // To xpll of gpll_top.v
    output [23: 0]                  mc1_ssc_step,           // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_syn_sel,            // To xpll of gpll_top.v
    output                          mc1_tda_en,             // To xpll of gpll_top.v
    output                          mc1_test_en,            // To xpll of gpll_top.v
  //output                          mc1_toggle_fb_valid,    // To xpll of gpll_top.v
  //output [ 3: 0]                  mc1_vco_band,           // To xpll of gpll_top.v
  //output                          mc1_vco_cal_mode,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_vctrl_sel,          // To xpll of gpll_top.v
    output [ 3: 0]                  mc1_ref_sel,            // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_pi_delay,           // To xpll of gpll_top.v

    input                           wakeup_mux_dly20_i
  //output wire                     axis_wakeup_o,
  //output wire                     tie0,
  //output wire                     tie1
);

    /*AUTOWIRE*/

    //--------------------------------------------------------------------
    wire                            wr_en;
    wire [31:0]                     wr_data;  //32-bit data
    wire [31:0]                     addr;  //32-bit addr
    wire                            rd_en;
    wire                            axis_rd_valid;
    wire [31:0]                     axis_rd_data;  //32-bit data
    wire                            axis_slave_err;  //axis_slave error

    wire [1:0]                      op_mode;  //2'b11 for phy_regfile, 2'b00 for apb slave
    wire                            phy_wr_en;
    wire                            phy_rd_en;
    wire                            reg_wr_en;
    wire                            reg_rd_en;

    wire                            phy_rd_valid;
    wire [31:0]                     phy_rd_data;
    wire [31:0]                     reg_rd_data;

    wire [15:0]                     apb_wr_timeout_val;
    wire                            broadcast_wr_en;
    wire                            axis_psel;
    wire                            axis_penable;
    wire                            axis_pwrite;
    wire [PADDRW-1:0]               axis_paddr;
    wire [PDATAW-1:0]               axis_pwdata;
    wire [((PDATAW>>3)-1):0]        axis_pstrb;  //apb4
    wire [2:0]                      axis_pprot;  //apb4
    wire [PDATAW-1:0]               axis_prdata;
    wire                            axis_pready;
    wire                            axis_pslverr;
    wire                            axis_apb_err;  //apb_master error
    //--------------------------------------------------------------------

    wire                            s_axis_clk_i;
    wire                            s_axis_rst_n_i;
    wire                            s_drp_clk;
    wire                            s_drp_rst_n;
    wire                            s_wakeup_mux_dly;

    assign s_axis_clk_i             = test_mode ? scan_clk    : axis_clk_i          ;
    assign s_axis_rst_n_i           = test_mode ? scan_resetn : axis_rst_n_i        ;

    assign s_drp_clk                = test_mode ? scan_clk    : drp_clk             ;
    assign s_drp_rst_n              = test_mode ? scan_resetn : drp_rst_n           ;

    assign s_wakeup_mux_dly         = test_mode ? 1'b0        : wakeup_mux_dly20_i  ;

  //assign  tie0 = 1'b0;
  //assign  tie1 = 1'b1;


    //--------------------------------------------------------------------
    //--------------axis slave mux----------------------------------------
    //--------------------------------------------------------------------
    axis_slave #(
        .TOW(TOW),
        .TIMEOUT(TIMEOUT),
        .LENW(LENW),
        .MAX_LEN(MAX_LEN),
        .ADDRW(32),
        .DATAW(32)
    ) U_phy_axis (
        `ifdef PG_FC_SIM
        .VDD(vccd),
        .VSS(vssd),
        `endif          
        .map_i(map_i),
        .broadcast_wr_en(1'b0),         //broadcast_wr_en),  //i TBD
        .axis_clk_i(s_axis_clk_i),
        .axis_rst_n_i(s_axis_rst_n_i),
        //config axis if
        .s_rvalid_i(s_rvalid_i),
        .s_rdata_i(s_rdata_i),
        .s_rlast_i(s_rlast_i),
        .s_rready_o(s_rready_o),
        .s_tready_i(s_tready_i),
        .s_tvalid_o(s_tvalid_o),
        .s_tdata_o(s_tdata_o),
        .s_tlast_o(s_tlast_o),
        .s_tuser_o(axis_slave_err),
        //cascade if
        //.m_down_clk_o(m_axis_clk_o),
        //.m_down_rst_n_o(m_axis_rst_n_o),
        .m_down_tvalid_o(m_tvalid_o),
        .m_down_tdata_o(m_tdata_o),
        .m_down_tlast_o(m_tlast_o),
        .m_down_tready_i(m_tready_i),
        .m_down_rready_o(m_rready_o),
        .m_down_rvalid_i(m_rvalid_i),
        .m_down_rdata_i(m_rdata_i),
        .m_down_rlast_i(m_rlast_i),
        .m_down_tuser_i(m_tuser_i),
        //local if
        .wr_en(wr_en),  //o
        .wr_data(wr_data),  //o
        .addr(addr),  //o
        .rd_en(rd_en),  //o
        .rd_valid(axis_rd_valid),  //i
        .rd_data(axis_rd_data)  //i
    );
    //--------------------------------------------------------------------

    assign  op_mode = addr[31:30];
  //assign  phy_wr_en = wr_en & (op_mode == 2'b00);  //2'b00 for apb slave
  //assign  phy_rd_en = rd_en & (op_mode == 2'b00);  //2'b00 for apb slave
    assign  reg_wr_en = wr_en & (op_mode == 2'b11);  //2'b11 for regfile
    assign  reg_rd_en = rd_en & (op_mode == 2'b11);  //2'b11 for regfile

    //--------------physram----------------------
  //assign  sram_addr_config_o    = addr[13:0] ; 
  //assign  sram_wr_data_config_o = wr_data[31:0];
  //assign  sram_wr_en_config_o   = wr_en & (op_mode == 2'b01); //TBD
  //assign  sram_rd_en_config_o   = rd_en & (op_mode == 2'b01); //TBD

    assign  s_tuser_o = axis_slave_err ;


    //--------------------------------------------------------------------
    //--------------PLL regfile-------------------------------------------
    //--------------------------------------------------------------------
    /*  pll_slave AUTO_TEMPLATE (
        .axis_wr_en                 (reg_wr_en),  //i
        .axis_wr_data               (wr_data),  //i
        .axis_addr                  (addr),  //i
        .axis_rd_en                 (reg_rd_en),  //i
        .rd_valid                   (axis_rd_valid),  //o
        .rd_data                    (axis_rd_data),  //o
        .wakeup_mux_dly             (s_wakeup_mux_dly),
        .scan_mode                  (test_mode),
        ); */
    pll_slave xpll_slave (
`ifdef FC_PG_SIM
        .VDD                        (vccd),
        .VSS                        (vssd),
`endif
    /*AUTOINST*/
                          // Outputs
                          .rd_valid             (axis_rd_valid), // Templated
                          .rd_data              (axis_rd_data),  // Templated
                          .drp_pll_rdata        (drp_pll_rdata[7:0]),
                          .drp_pll_err          (drp_pll_err),
                          .drp_pll_rdy          (drp_pll_rdy),
                          .pll_cfg_o            (pll_cfg_o),
                          .mc1_fastloop_cfg     (mc1_fastloop_cfg),
                          .mc1_test_en          (mc1_test_en),
                          .mc1_dig_sel          (mc1_dig_sel[5:0]),
                          .mc1_refclk_out_en    (mc1_refclk_out_en),
                          .mc1_divc_outmux_main (mc1_divc_outmux_main),
                          .mc1_enclk_main       (mc1_enclk_main),
                          .mc1_enable_sync      (mc1_enable_sync),
                          .mc1_cp_dlysel        (mc1_cp_dlysel[2:0]),
                          .mc1_cp_refsel        (mc1_cp_refsel[2:0]),
                          .mc1_icp_banch        (mc1_icp_banch[4:0]),
                          .mc1_fastlock_sel     (mc1_fastlock_sel[2:0]),
                          .mc1_icp_bias         (mc1_icp_bias[4:0]),
                          .mc1_bias_icfg        (mc1_bias_icfg[1:0]),
                          .mc1_lpf_r1_sel       (mc1_lpf_r1_sel[1:0]),
                          .mc1_vctrl_sel        (mc1_vctrl_sel[1:0]),
                          .mc1_tda_en           (mc1_tda_en),
                          .mc1_pi_capsel        (mc1_pi_capsel[2:0]),
                          .mc1_pi_icfg          (mc1_pi_icfg[3:0]),
                        //.mc1_vco_band         (mc1_vco_band[3:0]),
                          .mc1_cal_counter      (mc1_cal_counter[2:0]),
                          .mc1_refclk_det_byp   (mc1_refclk_det_byp),
                          .mc1_refclk_det_div   (mc1_refclk_det_div[1:0]),
                        //.mc1_vco_cal_mode     (mc1_vco_cal_mode),
                          .mc1_gpll_lockdet     (mc1_gpll_lockdet[6:0]),
                          .mc1_clk0_frac_en     (mc1_clk0_frac_en),
                          .mc1_frac             (mc1_frac[6:0]),
                          .mc1_pi_out_sel       (mc1_pi_out_sel[7:0]),
                          .mc1_pi_frac_mode     (mc1_pi_frac_mode),
                          .mc1_outputpi_capsel  (mc1_outputpi_capsel[2:0]),
                          .mc1_outputpi_icfg    (mc1_outputpi_icfg[2:0]),
                          .mc1_divc_outmux      (mc1_divc_outmux[7:0]),
                          .mc1_divc_premux0     (mc1_divc_premux0[1:0]),
                          .mc1_divc_premux1     (mc1_divc_premux1[1:0]),
                          .mc1_divc_premux2     (mc1_divc_premux2[1:0]),
                          .mc1_divc_premux3     (mc1_divc_premux3[1:0]),
                          .mc1_divc_premux4     (mc1_divc_premux4[1:0]),
                          .mc1_divc_premux5     (mc1_divc_premux5[1:0]),
                          .mc1_divc_premux6     (mc1_divc_premux6[1:0]),
                          .mc1_divc_premux7     (mc1_divc_premux7[1:0]),
                          .mc1_divc0            (mc1_divc0[6:0]),
                          .mc1_divc1            (mc1_divc1[6:0]),
                          .mc1_divc2            (mc1_divc2[6:0]),
                          .mc1_divc3            (mc1_divc3[6:0]),
                          .mc1_divc4            (mc1_divc4[6:0]),
                          .mc1_divc5            (mc1_divc5[6:0]),
                          .mc1_divc6            (mc1_divc6[6:0]),
                          .mc1_divc7            (mc1_divc7[6:0]),
                          .mc1_phc0             (mc1_phc0[6:0]),
                          .mc1_phc1             (mc1_phc1[6:0]),
                          .mc1_phc2             (mc1_phc2[6:0]),
                          .mc1_phc3             (mc1_phc3[6:0]),
                          .mc1_phc4             (mc1_phc4[6:0]),
                          .mc1_phc5             (mc1_phc5[6:0]),
                          .mc1_phc6             (mc1_phc6[6:0]),
                          .mc1_phc7             (mc1_phc7[6:0]),
                          .mc1_dyn_phc0         (mc1_dyn_phc0[6:0]),
                          .mc1_dyn_phc1         (mc1_dyn_phc1[6:0]),
                          .mc1_dyn_phc2         (mc1_dyn_phc2[6:0]),
                          .mc1_dyn_phc3         (mc1_dyn_phc3[6:0]),
                          .mc1_dyn_phc4         (mc1_dyn_phc4[6:0]),
                          .mc1_dyn_phc5         (mc1_dyn_phc5[6:0]),
                          .mc1_dyn_phc6         (mc1_dyn_phc6[6:0]),
                          .mc1_dyn_phc7         (mc1_dyn_phc7[6:0]),
                          .mc1_duty0            (mc1_duty0[6:0]),
                          .mc1_duty1            (mc1_duty1[6:0]),
                          .mc1_duty2            (mc1_duty2[6:0]),
                          .mc1_duty3            (mc1_duty3[6:0]),
                          .mc1_duty4            (mc1_duty4[6:0]),
                          .mc1_duty5            (mc1_duty5[6:0]),
                          .mc1_duty6            (mc1_duty6[6:0]),
                          .mc1_duty7            (mc1_duty7[6:0]),
                          .mc1_load_en          (mc1_load_en[7:0]),
                          .mc1_load_div2_en     (mc1_load_div2_en[7:0]),
                          .mc1_div2_phc         (mc1_div2_phc[7:0]),
                          .mc1_duty50_n         (mc1_duty50_n[7:0]),
                          .mc1_enclk            (mc1_enclk[7:0]),
                          .mc1_outgate_en       (mc1_outgate_en[7:0]),
                          .mc1_div2_bypass_n    (mc1_div2_bypass_n[7:0]),
                          .mc1_div_en           (mc1_div_en[7:0]),
                          .mc1_ssc_dn_loop_mode (mc1_ssc_dn_loop_mode),
                          .mc1_ssc_lpf_sel      (mc1_ssc_lpf_sel[1:0]),
                          .mc1_ssc_mode         (mc1_ssc_mode),
                          .mc1_ssc_en           (mc1_ssc_en),
                          .mc1_ssc_freq_div     (mc1_ssc_freq_div[17:0]),
                          .mc1_ssc_step         (mc1_ssc_step[23:0]),
                          .mc1_fbk_div          (mc1_fbk_div[7:0]),
                          .mc1_fracn_dither_sel (mc1_fracn_dither_sel[3:0]),
                          .mc1_fracn_prbs_sel   (mc1_fracn_prbs_sel[1:0]),
                          .mc1_fracn_dither_en  (mc1_fracn_dither_en),
                          .mc1_fracn_en         (mc1_fracn_en),
                          .mc1_fbfracn_sel      (mc1_fbfracn_sel[27:0]),
                          .mc1_dyn_source       (mc1_dyn_source),
                          .mc1_syn_sel          (mc1_syn_sel[2:0]),
                          .mc1_phic7            (mc1_phic7[2:0]),
                          .mc1_dyn_ph_shift_en  (mc1_dyn_ph_shift_en),
                          .mc1_phic6            (mc1_phic6[2:0]),
                          .mc1_phic5            (mc1_phic5[2:0]),
                          .mc1_phic4            (mc1_phic4[2:0]),
                          .mc1_phic3            (mc1_phic3[2:0]),
                          .mc1_phic2            (mc1_phic2[2:0]),
                          .mc1_phic1            (mc1_phic1[2:0]),
                          .mc1_pi_phi_en        (mc1_pi_phi_en),
                          .mc1_phic0            (mc1_phic0[6:0]),
                          .mc1_kvco_sel         (mc1_kvco_sel[3:0]),
                          .mc1_intfb            (mc1_intfb),
                          .mc1_ref_sel          (mc1_ref_sel[3:0]),
                          .mc1_fbk_sel_wakeup   (mc1_fbk_sel_wakeup[3:0]),
                          .mc1_fbk_sel          (mc1_fbk_sel[3:0]),
                          .mc1_ref_div          (mc1_ref_div[7:0]),
                          .mc1_divrst_ph_sel    (mc1_divrst_ph_sel[7:0]),
                          .mc1_divcrst_en       (mc1_divcrst_en[1:0]),
                          .mc1_pllpdn           (mc1_pllpdn),
                          .mc1_dig_pd           (mc1_dig_pd),
                          .mc1_mrst_en          (mc1_mrst_en),
                          .mc1_pllrst_en        (mc1_pllrst_en),
                          .mc1_ssc_reset        (mc1_ssc_reset),
                          .mc1_pi_delay         (mc1_pi_delay),
                          // Inputs
                          .scan_mode            (test_mode),
                          .axis_clk_i           (s_axis_clk_i),
                          .axis_rst_n_i         (s_axis_rst_n_i),
                          .axis_wr_en           (reg_wr_en),     // Templated
                          .axis_wr_data         (wr_data),       // Templated
                          .axis_addr            (addr),          // Templated
                          .axis_rd_en           (reg_rd_en),     // Templated
                          .drp_clk              (s_drp_clk),
                          .drp_rst_n            (s_drp_rst_n),
                          .drp_pll_wr           (drp_pll_wr),
                          .drp_pll_rd           (drp_pll_rd),
                          .drp_pll_addr         (drp_pll_addr[7:0]),
                          .drp_pll_wdata        (drp_pll_wdata[7:0]),
                          .drp_pll_sel          (drp_pll_sel),
                          .wakeup_mux_dly       (s_wakeup_mux_dly)); // Templated
    //--------------------------------------------------------------------

    //selection between apb_master and regfile
  //assign  axis_rd_valid = reg_rd_valid;
  //assign  axis_rd_data  = reg_rd_data;


    //--------------------------------------------------------------------
    //--------------mux between pib and axis------------------------------
    //--------------------------------------------------------------------
  //wire tiel_pib_sel = 1'b0; //move signal selection outside of this module 

  //assign  psel_o      = tiel_pib_sel ? apb4_psel          : axis_psel;
  //assign  penable_o   = tiel_pib_sel ? apb4_penable       : axis_penable;
  //assign  pwrite_o    = tiel_pib_sel ? apb4_pwrite        : axis_pwrite;
  //assign  paddr_o     = tiel_pib_sel ? apb4_paddr         : axis_paddr;
  //assign  pwdata_o    = tiel_pib_sel ? apb4_pwdata        : axis_pwdata;
  //assign  pstrb_o     = tiel_pib_sel ? apb4_pstrobe       : axis_pstrb;  //apb4
  //assign  pprot_o     = tiel_pib_sel ? apb4_pprot         : axis_pprot;  //apb4

  //assign  apb4_prdata = tiel_pib_sel ? prdata_i           : {(PDATAW){1'b0}};
  //assign  apb4_pready = tiel_pib_sel ? pready_i           : 1'b0;
  //assign  apb4_pslverr= tiel_pib_sel ? pslverr_i          : 1'b0;

  //assign  axis_prdata = tiel_pib_sel ? {(PDATAW){1'b0}}   : prdata_i;
  //assign  axis_pready = tiel_pib_sel ? 1'b0               : pready_i;
  //assign  axis_pslverr= tiel_pib_sel ? 1'b0               : pslverr_i;

  //assign  prst_n_o    = axis_rst_n_i;
  //assign  pclk_o      = axis_clk_i;

  //assign  axis_wakeup_o = pib_sel | test_mode;

endmodule

//-----------------------------------------------------------------------------

// Title         : pll_slave
// Project       : al006
//-----------------------------------------------------------------------------
// File          : pll_slave.v
// Author        :   <jqzhou@R730A>
// Created       : 09.04.2019
// Last modified : 09.04.2019
//-----------------------------------------------------------------------------
// Description :
// bridge between apb and PLL interface from PCIe
//-----------------------------------------------------------------------------
// Copyright (c) 2019 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------
// Modification history :
// 09.04.2019 : created
//-----------------------------------------------------------------------------

`timescale 1ns/1ps

module pll_slave (
`ifdef FC_PG_SIM 
    input                           VDD,
    input                           VSS,
`endif
    //axis_slave interface
    input                           axis_clk_i,
    input                           axis_rst_n_i,

    input                           axis_wr_en,
    input       [31:0]              axis_wr_data,       //32-bit data
    input       [31:0]              axis_addr,          //32-bit address
    input                           axis_rd_en,
    output reg                      rd_valid,
    output wire [31:0]              rd_data,    //32-bit data

    //DRP side
    input                           drp_clk,
    input                           drp_rst_n,
    input                           drp_pll_wr,
    input                           drp_pll_rd,
    input       [ 7:0]              drp_pll_addr,
    input       [ 7:0]              drp_pll_wdata,
    input                           drp_pll_sel,
    output      [ 7:0]              drp_pll_rdata,
    output reg                      drp_pll_err,
    output reg                      drp_pll_rdy,
   
    //reg output
    output [31: 0]                  pll_cfg_o,

  //output                          mc1_toggle_fb_valid,    // To xpll of gpll_top.v
    output                          mc1_test_en,            // To xpll of gpll_top.v
    output                          mc1_fastloop_cfg,       // To xpll of gpll_top.v
    output [ 5: 0]                  mc1_dig_sel,            // To xpll of gpll_top.v

    output                          mc1_refclk_out_en,      // To xpll of gpll_top.v
    output                          mc1_divc_outmux_main,   // To xpll of gpll_top.v
    output                          mc1_enclk_main,         // To xpll of gpll_top.v
    output                          mc1_enable_sync,        // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_cp_dlysel,          // To xpll of gpll_top.v

    output [ 2: 0]                  mc1_cp_refsel,          // To xpll of gpll_top.v
    output [ 4: 0]                  mc1_icp_banch,          // To xpll of gpll_top.v

    output [ 2: 0]                  mc1_fastlock_sel,       // To xpll of gpll_top.v
    output [ 4: 0]                  mc1_icp_bias,           // To xpll of gpll_top.v

  //output                          mc1_freq_lock,          // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_pi_delay,           // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_bias_icfg,          // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_lpf_r1_sel,         // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_vctrl_sel,          // To xpll of gpll_top.v

    output                          mc1_tda_en,             // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_pi_capsel,          // To xpll of gpll_top.v
    output [ 3: 0]                  mc1_pi_icfg,            // To xpll of gpll_top.v

  //output [ 3: 0]                  mc1_vco_band,           // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_cal_counter,        // To xpll of gpll_top.v
    output                          mc1_refclk_det_byp,     // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_refclk_det_div,     // To xpll of gpll_top.v
  //output                          mc1_vco_cal_mode,       // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_gpll_lockdet,       // To xpll of gpll_top.v

    output                          mc1_clk0_frac_en,       // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_frac,               // To xpll of gpll_top.v
    output [ 7: 0]                  mc1_pi_out_sel,         // To xpll of gpll_top.v
    output                          mc1_pi_frac_mode,       // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_outputpi_capsel,    // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_outputpi_icfg,      // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_divc_outmux,        // To xpll of gpll_top.v

    output [ 1: 0]                  mc1_divc_premux0,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux1,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux2,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux3,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux4,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux5,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux6,       // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_divc_premux7,       // To xpll of gpll_top.v

    output [ 6: 0]                  mc1_divc0,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc1,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc2,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc3,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc4,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc5,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc6,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_divc7,              // To xpll of gpll_top.v

    output [ 6: 0]                  mc1_phc0,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc1,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc2,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc3,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc4,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc5,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc6,               // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phc7,               // To xpll of gpll_top.v

    output [ 6: 0]                  mc1_dyn_phc0,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc1,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc2,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc3,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc4,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc5,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc6,           // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_dyn_phc7,           // To xpll of gpll_top.v

    output [ 6: 0]                  mc1_duty0,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty1,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty2,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty3,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty4,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty5,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty6,              // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_duty7,              // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_load_en,            // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_load_div2_en,       // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_div2_phc,           // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_duty50_n,           // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_enclk,              // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_outgate_en,         // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_div2_bypass_n,      // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_div_en,             // To xpll of gpll_top.v

    output                          mc1_ssc_dn_loop_mode,   // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_ssc_lpf_sel,        // To xpll of gpll_top.v
    output                          mc1_ssc_mode,           // To xpll of gpll_top.v
    output                          mc1_ssc_en,             // To xpll of gpll_top.v

    output [17: 0]                  mc1_ssc_freq_div,       // To xpll of gpll_top.v

    output [23: 0]                  mc1_ssc_step,           // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_fbk_div,            // To xpll of gpll_top.v

    output [ 3: 0]                  mc1_fracn_dither_sel,   // To xpll of gpll_top.v
    output [ 1: 0]                  mc1_fracn_prbs_sel,     // To xpll of gpll_top.v
    output                          mc1_fracn_dither_en,    // To xpll of gpll_top.v
    output                          mc1_fracn_en,           // To xpll of gpll_top.v

    output [27: 0]                  mc1_fbfracn_sel,        // To xpll of gpll_top.v

    output                          mc1_dyn_source,         // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_syn_sel,            // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic7,              // To xpll of gpll_top.v

    output                          mc1_dyn_ph_shift_en,    // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic6,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic5,              // To xpll of gpll_top.v

    output [ 2: 0]                  mc1_phic4,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic3,              // To xpll of gpll_top.v

    output [ 2: 0]                  mc1_phic2,              // To xpll of gpll_top.v
    output [ 2: 0]                  mc1_phic1,              // To xpll of gpll_top.v

    output                          mc1_pi_phi_en,          // To xpll of gpll_top.v
    output [ 6: 0]                  mc1_phic0,              // To xpll of gpll_top.v

    output [ 3: 0]                  mc1_kvco_sel,           // To xpll of gpll_top.v

    output                          mc1_intfb,              // To xpll of gpll_top.v
    output [ 3: 0]                  mc1_ref_sel,            // To xpll of gpll_top.v

    output [ 3: 0]                  mc1_fbk_sel_wakeup,     // To xpll of gpll_top.v
    output [ 3: 0]                  mc1_fbk_sel,            // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_ref_div,            // To xpll of gpll_top.v

    output [ 7: 0]                  mc1_divrst_ph_sel,      // To xpll of gpll_top.v

    output [ 1: 0]                  mc1_divcrst_en,         // To xpll of gpll_top.v

    output                          mc1_pllpdn,             // To xpll of gpll_top.v
    output                          mc1_dig_pd,             // To xpll of gpll_top.v
    output                          mc1_mrst_en,            // To xpll of gpll_top.v
    output                          mc1_pllrst_en,          // To xpll of gpll_top.v
    output                          mc1_ssc_reset,          // To xpll of gpll_top.v

    //During CFGPLL time  1:APB bus  0: DRP bus
    input                           wakeup_mux_dly,         //Notice default value is 1'b1

    input                           scan_mode
    );
   
    parameter cfg_addr0     =                 8'h0;
    parameter cfg_addr1     = cfg_addr0     + 8'h1;
    parameter cfg_addr2     = cfg_addr1     + 8'h1;
    parameter cfg_addr3     = cfg_addr2     + 8'h1;
    parameter cfg_addr4     = cfg_addr3     + 8'h1;
    parameter cfg_addr5     = cfg_addr4     + 8'h1;
    parameter cfg_addr6     = cfg_addr5     + 8'h1;
    parameter cfg_addr7     = cfg_addr6     + 8'h1;
    parameter cfg_addr8     = cfg_addr7     + 8'h1;
    parameter cfg_addr9     = cfg_addr8     + 8'h1;
    parameter cfg_addr10    = cfg_addr9     + 8'h1;
    parameter cfg_addr11    = cfg_addr10    + 8'h1;
    parameter cfg_addr12    = cfg_addr11    + 8'h1;
    parameter cfg_addr13    = cfg_addr12    + 8'h1;
    parameter cfg_addr14    = cfg_addr13    + 8'h1;
    parameter cfg_addr15    = cfg_addr14    + 8'h1;
    parameter cfg_addr16    = cfg_addr15    + 8'h1;
    parameter cfg_addr17    = cfg_addr16    + 8'h1;
    parameter cfg_addr18    = cfg_addr17    + 8'h1;
    parameter cfg_addr19    = cfg_addr18    + 8'h1;
    parameter cfg_addr20    = cfg_addr19    + 8'h1;
    parameter cfg_addr21    = cfg_addr20    + 8'h1;
    parameter cfg_addr22    = cfg_addr21    + 8'h1;
    parameter cfg_addr23    = cfg_addr22    + 8'h1;
    parameter cfg_addr24    = cfg_addr23    + 8'h1;
    parameter cfg_addr25    = cfg_addr24    + 8'h1;
    parameter cfg_addr26    = cfg_addr25    + 8'h1;
    parameter cfg_addr27    = cfg_addr26    + 8'h1;
    parameter cfg_addr28    = cfg_addr27    + 8'h1;
    parameter cfg_addr29    = cfg_addr28    + 8'h1;
    parameter cfg_addr30    = cfg_addr29    + 8'h1;
    parameter cfg_addr31    = cfg_addr30    + 8'h1;
    parameter cfg_addr32    = cfg_addr31    + 8'h1;
    parameter cfg_addr33    = cfg_addr32    + 8'h1;
    parameter cfg_addr34    = cfg_addr33    + 8'h1;
    parameter cfg_addr35    = cfg_addr34    + 8'h1;
    parameter cfg_addr36    = cfg_addr35    + 8'h1;
    parameter cfg_addr37    = cfg_addr36    + 8'h1;
    parameter cfg_addr38    = cfg_addr37    + 8'h1;
    parameter cfg_addr39    = cfg_addr38    + 8'h1;
    parameter cfg_addr40    = cfg_addr39    + 8'h1;
    parameter cfg_addr41    = cfg_addr40    + 8'h1;
    parameter cfg_addr42    = cfg_addr41    + 8'h1;
    parameter cfg_addr43    = cfg_addr42    + 8'h1;
    parameter cfg_addr44    = cfg_addr43    + 8'h1;
    parameter cfg_addr45    = cfg_addr44    + 8'h1;
    parameter cfg_addr46    = cfg_addr45    + 8'h1;
    parameter cfg_addr47    = cfg_addr46    + 8'h1;
    parameter cfg_addr48    = cfg_addr47    + 8'h1;
    parameter cfg_addr49    = cfg_addr48    + 8'h1;
    parameter cfg_addr50    = cfg_addr49    + 8'h1;
    parameter cfg_addr51    = cfg_addr50    + 8'h1;
    parameter cfg_addr52    = cfg_addr51    + 8'h1;
    parameter cfg_addr53    = cfg_addr52    + 8'h1;
    parameter cfg_addr54    = cfg_addr53    + 8'h1;
    parameter cfg_addr55    = cfg_addr54    + 8'h1;
    parameter cfg_addr56    = cfg_addr55    + 8'h1;
    parameter cfg_addr57    = cfg_addr56    + 8'h1;
    parameter cfg_addr58    = cfg_addr57    + 8'h1;
    parameter cfg_addr59    = cfg_addr58    + 8'h1;
    parameter cfg_addr60    = cfg_addr59    + 8'h1;
    parameter cfg_addr61    = cfg_addr60    + 8'h1;
    parameter cfg_addr62    = cfg_addr61    + 8'h1;
    parameter cfg_addr63    = cfg_addr62    + 8'h1;
    parameter cfg_addr64    = cfg_addr63    + 8'h1;
    parameter cfg_addr65    = cfg_addr64    + 8'h1;
    parameter cfg_addr66    = cfg_addr65    + 8'h1;
    parameter cfg_addr67    = cfg_addr66    + 8'h1;
    parameter cfg_addr68    = cfg_addr67    + 8'h1;
    parameter cfg_addr69    = cfg_addr68    + 8'h1;
    parameter cfg_addr70    = cfg_addr69    + 8'h1;
    parameter cfg_addr71    = cfg_addr70    + 8'h1;
    parameter cfg_addr72    = cfg_addr71    + 8'h1;
    parameter cfg_addr73    = cfg_addr72    + 8'h1;
    parameter cfg_addr74    = cfg_addr73    + 8'h1;
    parameter cfg_addr75    = cfg_addr74    + 8'h1;
    parameter cfg_addr76    = cfg_addr75    + 8'h1;
    parameter cfg_addr77    = cfg_addr76    + 8'h1;
    parameter cfg_addr78    = cfg_addr77    + 8'h1;
    parameter cfg_addr79    = cfg_addr78    + 8'h1;
    parameter cfg_addr80    = cfg_addr79    + 8'h1;
    parameter cfg_addr81    = cfg_addr80    + 8'h1;
    parameter cfg_addr82    = cfg_addr81    + 8'h1;

    parameter C2Q           = 0.04;

    /*AUTOWIRE*/
    /*AUTOREG*/
    reg             pslverr_reg, pready_reg;
   


    reg         [7:0]           rdata;
    wire                        clk;
    reg         [1:0]           sync_prst_n;
    reg                         pready_s;
    wire        [7:0]           wdata;
    wire                        sel_rst_n;
    wire        [7:0]           addr;
    wire                        wr_en;
    wire                        rd_en;
    wire      [663:0]           pll_cfg;
   
    assign addr  = wakeup_mux_dly ? drp_pll_addr             : axis_addr[9:2]   ;
    assign wr_en = wakeup_mux_dly ? drp_pll_wr & drp_pll_sel : axis_wr_en  ;
    assign rd_en = wakeup_mux_dly ? drp_pll_rd & drp_pll_sel : axis_rd_en  ;
   
 //9T  
`ifndef FC_PG_SIM   al6100_gpll_cell_clk_mux dont_touch_ckmux1(.in0(axis_clk_i),   .in1(drp_clk),   .sel(wakeup_mux_dly), .cout(clk));
`else               al6100_gpll_cell_clk_mux dont_touch_ckmux1(.in0(axis_clk_i),   .in1(drp_clk),   .sel(wakeup_mux_dly), .cout(clk),        .vdd(VDD), .vss(VSS)); `endif
 //7T 
 //CKMUX2D0BWP7T40P140 clk_mux(.I0(drp_clk),.I1(pclk),.S(~wakeup_mux_dly),.Z(clk));
`ifndef FC_PG_SIM   al6100_gpll_cell_clk_mux dont_touch_ckmux2(.in0(axis_rst_n_i), .in1(drp_rst_n), .sel(wakeup_mux_dly), .cout(sel_rst_n));
`else               al6100_gpll_cell_clk_mux dont_touch_ckmux2(.in0(axis_rst_n_i), .in1(drp_rst_n), .sel(wakeup_mux_dly), .cout(sel_rst_n),  .vdd(VDD), .vss(VSS)); `endif

    assign drp_pll_rdata    = rdata;
  //assign prdata           = psel ? {8'b0,rdata} : prdata_down;
    assign rd_data          = {24'b0, rdata};
    assign wdata            = wakeup_mux_dly ? drp_pll_wdata : axis_wr_data[7:0];

    //sync rst_n
    always @ (posedge clk or negedge sel_rst_n ) begin //fixme
        if(~sel_rst_n)
            sync_prst_n     <= #C2Q 0;
        else begin
            sync_prst_n[0]  <= #C2Q 1'b1;
            sync_prst_n[1]  <= #C2Q sync_prst_n[0];
        end
    end

    wire  rst_n             = scan_mode ? sel_rst_n : sync_prst_n[1];

    always @ (posedge clk or negedge rst_n ) begin
        if(~rst_n)
            drp_pll_err     <= #C2Q 0;
      //else if(~~wakeup_mux_dly && ((drp_pll_wr|drp_pll_rd) & drp_pll_sel ) && ((drp_pll_addr >`CFGPLL79_ADDR)))//select DRP, judge by address
        else if( wakeup_mux_dly  && ((drp_pll_wr|drp_pll_rd) & drp_pll_sel ) && ((drp_pll_addr >cfg_addr79)))//select DRP, judge by address
            drp_pll_err     <= #C2Q 1'b1;    
        else if(~wakeup_mux_dly  && ((drp_pll_wr|drp_pll_rd) & drp_pll_sel))//select wrong
            drp_pll_err     <= #C2Q 1'b1;    
        else 
            drp_pll_err     <= #C2Q 0;
    end

/*  always @ (posedge clk or negedge rst_n ) begin
        if(~rst_n) 
            pslverr_reg     <= 0;
        else if(~wakeup_mux_dly && (psel && penable) && ((paddr>`CFGPLL79_ADDR) ))//select APB, judge by address
            pslverr_reg     <= 1;
      //else if(~~wakeup_mux_dly && (psel && penable))
//      else if(wakeup_mux_dly && (psel && penable))
//          pslverr_reg     <= 1;
        else 
            pslverr_reg     <= 0;
    end*/

 //  assign pready = (psel && penable && pwrite) | (psel && penable && ~pwrite && pready_s);

    always @ (posedge clk or negedge rst_n ) begin
        if(~rst_n)
            rd_valid        <= #C2Q 0;
        else if(rd_en)
            rd_valid        <= #C2Q 1'b1;
        else
            rd_valid        <= #C2Q 0;
    end

    always @ (posedge clk or negedge rst_n ) begin
        if(~rst_n)
            drp_pll_rdy     <= #C2Q 0;
        else if(drp_pll_rd & drp_pll_sel)
            drp_pll_rdy     <= #C2Q 1'b1;
        else
            drp_pll_rdy     <= #C2Q 0;
    end

 //assign             pready  = psel ? pready_reg  : pready_down;
 //assign             pslverr = psel ? pslverr_reg : pslverr_down;
   

// wire wr_en_GLB_ADDR      = wr_en && (addr==`GLB_ADDR);
   wire wr_en_cfg_addr0     = wr_en && (addr==cfg_addr0);
   wire wr_en_cfg_addr1     = wr_en && (addr==cfg_addr1);
   wire wr_en_cfg_addr2     = wr_en && (addr==cfg_addr2);
   wire wr_en_cfg_addr3     = wr_en && (addr==cfg_addr3);
   wire wr_en_cfg_addr4     = wr_en && (addr==cfg_addr4);
   wire wr_en_cfg_addr5     = wr_en && (addr==cfg_addr5);
   wire wr_en_cfg_addr6     = wr_en && (addr==cfg_addr6);
   wire wr_en_cfg_addr7     = wr_en && (addr==cfg_addr7);
   wire wr_en_cfg_addr8     = wr_en && (addr==cfg_addr8);
   wire wr_en_cfg_addr9     = wr_en && (addr==cfg_addr9);
   wire wr_en_cfg_addr10    = wr_en && (addr==cfg_addr10);
   wire wr_en_cfg_addr11    = wr_en && (addr==cfg_addr11);
   wire wr_en_cfg_addr12    = wr_en && (addr==cfg_addr12);
   wire wr_en_cfg_addr13    = wr_en && (addr==cfg_addr13);
   wire wr_en_cfg_addr14    = wr_en && (addr==cfg_addr14);
   wire wr_en_cfg_addr15    = wr_en && (addr==cfg_addr15);
   wire wr_en_cfg_addr16    = wr_en && (addr==cfg_addr16);
   wire wr_en_cfg_addr17    = wr_en && (addr==cfg_addr17);
   wire wr_en_cfg_addr18    = wr_en && (addr==cfg_addr18);
   wire wr_en_cfg_addr19    = wr_en && (addr==cfg_addr19);
   wire wr_en_cfg_addr20    = wr_en && (addr==cfg_addr20);
   wire wr_en_cfg_addr21    = wr_en && (addr==cfg_addr21);
   wire wr_en_cfg_addr22    = wr_en && (addr==cfg_addr22);
   wire wr_en_cfg_addr23    = wr_en && (addr==cfg_addr23);
   wire wr_en_cfg_addr24    = wr_en && (addr==cfg_addr24);
   wire wr_en_cfg_addr25    = wr_en && (addr==cfg_addr25);
   wire wr_en_cfg_addr26    = wr_en && (addr==cfg_addr26);
   wire wr_en_cfg_addr27    = wr_en && (addr==cfg_addr27);
   wire wr_en_cfg_addr28    = wr_en && (addr==cfg_addr28);
   wire wr_en_cfg_addr29    = wr_en && (addr==cfg_addr29);
   wire wr_en_cfg_addr30    = wr_en && (addr==cfg_addr30);
   wire wr_en_cfg_addr31    = wr_en && (addr==cfg_addr31);
   wire wr_en_cfg_addr32    = wr_en && (addr==cfg_addr32);
   wire wr_en_cfg_addr33    = wr_en && (addr==cfg_addr33);
   wire wr_en_cfg_addr34    = wr_en && (addr==cfg_addr34);
   wire wr_en_cfg_addr35    = wr_en && (addr==cfg_addr35);
   wire wr_en_cfg_addr36    = wr_en && (addr==cfg_addr36);
   wire wr_en_cfg_addr37    = wr_en && (addr==cfg_addr37);
   wire wr_en_cfg_addr38    = wr_en && (addr==cfg_addr38);
   wire wr_en_cfg_addr39    = wr_en && (addr==cfg_addr39);
   wire wr_en_cfg_addr40    = wr_en && (addr==cfg_addr40);
   wire wr_en_cfg_addr41    = wr_en && (addr==cfg_addr41);
   wire wr_en_cfg_addr42    = wr_en && (addr==cfg_addr42);
   wire wr_en_cfg_addr43    = wr_en && (addr==cfg_addr43);
   wire wr_en_cfg_addr44    = wr_en && (addr==cfg_addr44);
   wire wr_en_cfg_addr45    = wr_en && (addr==cfg_addr45);
   wire wr_en_cfg_addr46    = wr_en && (addr==cfg_addr46);
   wire wr_en_cfg_addr47    = wr_en && (addr==cfg_addr47);
   wire wr_en_cfg_addr48    = wr_en && (addr==cfg_addr48);
   wire wr_en_cfg_addr49    = wr_en && (addr==cfg_addr49);
   wire wr_en_cfg_addr50    = wr_en && (addr==cfg_addr50);
   wire wr_en_cfg_addr51    = wr_en && (addr==cfg_addr51);
   wire wr_en_cfg_addr52    = wr_en && (addr==cfg_addr52);
   wire wr_en_cfg_addr53    = wr_en && (addr==cfg_addr53);
   wire wr_en_cfg_addr54    = wr_en && (addr==cfg_addr54);
   wire wr_en_cfg_addr55    = wr_en && (addr==cfg_addr55);
   wire wr_en_cfg_addr56    = wr_en && (addr==cfg_addr56);
   wire wr_en_cfg_addr57    = wr_en && (addr==cfg_addr57);
   wire wr_en_cfg_addr58    = wr_en && (addr==cfg_addr58);
   wire wr_en_cfg_addr59    = wr_en && (addr==cfg_addr59);
   wire wr_en_cfg_addr60    = wr_en && (addr==cfg_addr60);
   wire wr_en_cfg_addr61    = wr_en && (addr==cfg_addr61);
   wire wr_en_cfg_addr62    = wr_en && (addr==cfg_addr62);
   wire wr_en_cfg_addr63    = wr_en && (addr==cfg_addr63);
   wire wr_en_cfg_addr64    = wr_en && (addr==cfg_addr64);
   wire wr_en_cfg_addr65    = wr_en && (addr==cfg_addr65);
   wire wr_en_cfg_addr66    = wr_en && (addr==cfg_addr66);
   wire wr_en_cfg_addr67    = wr_en && (addr==cfg_addr67);
   wire wr_en_cfg_addr68    = wr_en && (addr==cfg_addr68);
   wire wr_en_cfg_addr69    = wr_en && (addr==cfg_addr69);
   wire wr_en_cfg_addr70    = wr_en && (addr==cfg_addr70);
   wire wr_en_cfg_addr71    = wr_en && (addr==cfg_addr71);
   wire wr_en_cfg_addr72    = wr_en && (addr==cfg_addr72);
   wire wr_en_cfg_addr73    = wr_en && (addr==cfg_addr73);
   wire wr_en_cfg_addr74    = wr_en && (addr==cfg_addr74);
   wire wr_en_cfg_addr75    = wr_en && (addr==cfg_addr75);
   wire wr_en_cfg_addr76    = wr_en && (addr==cfg_addr76);
   wire wr_en_cfg_addr77    = wr_en && (addr==cfg_addr77);
   wire wr_en_cfg_addr78    = wr_en && (addr==cfg_addr78);
   wire wr_en_cfg_addr79    = wr_en && (addr==cfg_addr79);
   wire wr_en_cfg_addr80    = wr_en && (addr==cfg_addr80);
   wire wr_en_cfg_addr81    = wr_en && (addr==cfg_addr81);
   wire wr_en_cfg_addr82    = wr_en && (addr==cfg_addr82);

 
`define IMP_REG_RW(reg_name, reg_addr, bit_start, bit_end, rst_val) \
wire [bit_end-bit_start:0] nxt_``reg_name; \
reg  [bit_end-bit_start:0] reg_name; \
assign reg_name``_o = reg_name; \
assign nxt_``reg_name = wr_en_``reg_addr ? wdata[bit_end:bit_start] : reg_name; \
always@(posedge clk or negedge rst_n) \
begin \
  if(~rst_n)    reg_name <= #C2Q rst_val; \
  else          reg_name <= #C2Q nxt_``reg_name; \
end



   
//GLB_reg
//`IMP_REG_RW(standby,        GLB_ADDR,  0,  0, 1'b0)
//`IMP_REG_RW(local_rst,      GLB_ADDR,  2,  2, 1'b0)

`undef IMP_REG_RW

`define IMP_REG_RW_W_SYNC_RST(reg_name, reg_addr,bit_start,  bit_end, rst_val) \
wire [bit_end-bit_start:0] nxt_``reg_name; \
reg  [bit_end-bit_start:0] reg_name; \
assign nxt_``reg_name = wr_en_``reg_addr ? wdata[bit_end:bit_start] : reg_name; \
always@(posedge clk or negedge rst_n) \
begin \
  if(~rst_n)    reg_name <= #C2Q rst_val; \
  else          reg_name <= #C2Q nxt_``reg_name; \
end


//CFGPLL_reg
`IMP_REG_RW_W_SYNC_RST(cfg0,           cfg_addr0,      0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg1,           cfg_addr1,      0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg2,           cfg_addr2,      0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg3,           cfg_addr3,      0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg4,           cfg_addr4,      0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg5,           cfg_addr5,      0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg6,           cfg_addr6,      0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg7,           cfg_addr7,      0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg8,           cfg_addr8,      0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg9,           cfg_addr9,      0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg10,          cfg_addr10,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg11,          cfg_addr11,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg12,          cfg_addr12,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg13,          cfg_addr13,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg14,          cfg_addr14,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg15,          cfg_addr15,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg16,          cfg_addr16,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg17,          cfg_addr17,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg18,          cfg_addr18,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg19,          cfg_addr19,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg20,          cfg_addr20,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg21,          cfg_addr21,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg22,          cfg_addr22,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg23,          cfg_addr23,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg24,          cfg_addr24,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg25,          cfg_addr25,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg26,          cfg_addr26,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg27,          cfg_addr27,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg28,          cfg_addr28,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg29,          cfg_addr29,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg30,          cfg_addr30,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg31,          cfg_addr31,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg32,          cfg_addr32,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg33,          cfg_addr33,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg34,          cfg_addr34,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg35,          cfg_addr35,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg36,          cfg_addr36,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg37,          cfg_addr37,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg38,          cfg_addr38,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg39,          cfg_addr39,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg40,          cfg_addr40,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg41,          cfg_addr41,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg42,          cfg_addr42,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg43,          cfg_addr43,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg44,          cfg_addr44,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg45,          cfg_addr45,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg46,          cfg_addr46,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg47,          cfg_addr47,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg48,          cfg_addr48,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg49,          cfg_addr49,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg50,          cfg_addr50,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg51,          cfg_addr51,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg52,          cfg_addr52,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg53,          cfg_addr53,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg54,          cfg_addr54,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg55,          cfg_addr55,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg56,          cfg_addr56,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg57,          cfg_addr57,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg58,          cfg_addr58,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg59,          cfg_addr59,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg60,          cfg_addr60,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg61,          cfg_addr61,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg62,          cfg_addr62,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg63,          cfg_addr63,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg64,          cfg_addr64,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg65,          cfg_addr65,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg66,          cfg_addr66,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg67,          cfg_addr67,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg68,          cfg_addr68,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg69,          cfg_addr69,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg70,          cfg_addr70,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg71,          cfg_addr71,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg72,          cfg_addr72,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg73,          cfg_addr73,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg74,          cfg_addr74,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg75,          cfg_addr75,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg76,          cfg_addr76,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg77,          cfg_addr77,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg78,          cfg_addr78,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg79,          cfg_addr79,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg80,          cfg_addr80,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg81,          cfg_addr81,     0, 7, 8'b0)
`IMP_REG_RW_W_SYNC_RST(cfg82,          cfg_addr82,     0, 7, 8'b0)


`undef IMP_REG_RW_W_SYNC_RST

  
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) 
            rdata <= #C2Q 8'b0;
        else if(rd_en) begin
            case(addr)
                cfg_addr0 :     rdata <= #C2Q cfg0;
                cfg_addr1 :     rdata <= #C2Q cfg1;
                cfg_addr2 :     rdata <= #C2Q cfg2;
                cfg_addr3 :     rdata <= #C2Q cfg3;
                cfg_addr4 :     rdata <= #C2Q cfg4;
                cfg_addr5 :     rdata <= #C2Q cfg5;
                cfg_addr6 :     rdata <= #C2Q cfg6;
                cfg_addr7 :     rdata <= #C2Q cfg7;
                cfg_addr8 :     rdata <= #C2Q cfg8;
                cfg_addr9 :     rdata <= #C2Q cfg9;
                cfg_addr10:     rdata <= #C2Q cfg10;
                cfg_addr11:     rdata <= #C2Q cfg11;
                cfg_addr12:     rdata <= #C2Q cfg12;
                cfg_addr13:     rdata <= #C2Q cfg13;
                cfg_addr14:     rdata <= #C2Q cfg14;
                cfg_addr15:     rdata <= #C2Q cfg15;
                cfg_addr16:     rdata <= #C2Q cfg16;
                cfg_addr17:     rdata <= #C2Q cfg17;
                cfg_addr18:     rdata <= #C2Q cfg18;
                cfg_addr19:     rdata <= #C2Q cfg19;
                cfg_addr20:     rdata <= #C2Q cfg20;
                cfg_addr21:     rdata <= #C2Q cfg21;
                cfg_addr22:     rdata <= #C2Q cfg22;
                cfg_addr23:     rdata <= #C2Q cfg23;
                cfg_addr24:     rdata <= #C2Q cfg24;
                cfg_addr25:     rdata <= #C2Q cfg25;
                cfg_addr26:     rdata <= #C2Q cfg26;
                cfg_addr27:     rdata <= #C2Q cfg27;
                cfg_addr28:     rdata <= #C2Q cfg28;
                cfg_addr29:     rdata <= #C2Q cfg29;
                cfg_addr30:     rdata <= #C2Q cfg30;
                cfg_addr31:     rdata <= #C2Q cfg31;
                cfg_addr32:     rdata <= #C2Q cfg32;
                cfg_addr33:     rdata <= #C2Q cfg33;
                cfg_addr34:     rdata <= #C2Q cfg34;
                cfg_addr35:     rdata <= #C2Q cfg35;
                cfg_addr36:     rdata <= #C2Q cfg36;
                cfg_addr37:     rdata <= #C2Q cfg37;
                cfg_addr38:     rdata <= #C2Q cfg38;
                cfg_addr39:     rdata <= #C2Q cfg39;
                cfg_addr40:     rdata <= #C2Q cfg40;
                cfg_addr41:     rdata <= #C2Q cfg41;
                cfg_addr42:     rdata <= #C2Q cfg42;
                cfg_addr43:     rdata <= #C2Q cfg43;
                cfg_addr44:     rdata <= #C2Q cfg44;
                cfg_addr45:     rdata <= #C2Q cfg45;
                cfg_addr46:     rdata <= #C2Q cfg46;
                cfg_addr47:     rdata <= #C2Q cfg47;
                cfg_addr48:     rdata <= #C2Q cfg48;
                cfg_addr49:     rdata <= #C2Q cfg49;
                cfg_addr50:     rdata <= #C2Q cfg50;
                cfg_addr51:     rdata <= #C2Q cfg51;
                cfg_addr52:     rdata <= #C2Q cfg52;
                cfg_addr53:     rdata <= #C2Q cfg53;
                cfg_addr54:     rdata <= #C2Q cfg54;
                cfg_addr55:     rdata <= #C2Q cfg55;
                cfg_addr56:     rdata <= #C2Q cfg56;
                cfg_addr57:     rdata <= #C2Q cfg57;
                cfg_addr58:     rdata <= #C2Q cfg58;
                cfg_addr59:     rdata <= #C2Q cfg59;
                cfg_addr60:     rdata <= #C2Q cfg60;
                cfg_addr61:     rdata <= #C2Q cfg61;
                cfg_addr62:     rdata <= #C2Q cfg62;
                cfg_addr63:     rdata <= #C2Q cfg63;
                cfg_addr64:     rdata <= #C2Q cfg64;
                cfg_addr65:     rdata <= #C2Q cfg65;
                cfg_addr66:     rdata <= #C2Q cfg66;
                cfg_addr67:     rdata <= #C2Q cfg67;
                cfg_addr68:     rdata <= #C2Q cfg68;
                cfg_addr69:     rdata <= #C2Q cfg69;
                cfg_addr70:     rdata <= #C2Q cfg70;
                cfg_addr71:     rdata <= #C2Q cfg71;
                cfg_addr72:     rdata <= #C2Q cfg72;
                cfg_addr73:     rdata <= #C2Q cfg73;
                cfg_addr74:     rdata <= #C2Q cfg74;
                cfg_addr75:     rdata <= #C2Q cfg75;
                cfg_addr76:     rdata <= #C2Q cfg76;
                cfg_addr77:     rdata <= #C2Q cfg77;
                cfg_addr78:     rdata <= #C2Q cfg78;
                cfg_addr79:     rdata <= #C2Q cfg79;
                cfg_addr80:     rdata <= #C2Q cfg80;
                cfg_addr81:     rdata <= #C2Q cfg81;
                cfg_addr82:     rdata <= #C2Q cfg82;
                default:        rdata <= #C2Q 8'b0;    //fix lint issue, all case not covered
            endcase
        end
    end

    //reg location assignment
    assign pll_cfg_o[31:24]             = pll_cfg[cfg_addr82*8 + 7 : cfg_addr82*8 + 0];

    assign pll_cfg_o[23:16]             = pll_cfg[cfg_addr81*8 + 7 : cfg_addr81*8 + 0];

    assign pll_cfg_o[15: 8]             = pll_cfg[cfg_addr80*8 + 7 : cfg_addr80*8 + 0];

    assign pll_cfg_o[ 7: 0]             = pll_cfg[cfg_addr79*8 + 7 : cfg_addr79*8 + 0];

    assign mc1_test_en                  = pll_cfg[cfg_addr78*8 + 7];
    assign mc1_fastloop_cfg             = pll_cfg[cfg_addr78*8 + 6];
    assign mc1_dig_sel                  = pll_cfg[cfg_addr78*8 + 5 : cfg_addr78*8 + 0];

    assign mc1_refclk_out_en            = pll_cfg[cfg_addr77*8 + 7];
    assign mc1_divc_outmux_main         = pll_cfg[cfg_addr77*8 + 6];
    assign mc1_enclk_main               = pll_cfg[cfg_addr77*8 + 5];
    assign mc1_enable_sync              = pll_cfg[cfg_addr77*8 + 4];
    assign mc1_cp_dlysel                = pll_cfg[cfg_addr77*8 + 2 : cfg_addr77*8 + 0];

    assign mc1_cp_refsel                = pll_cfg[cfg_addr76*8 + 7 : cfg_addr76*8 + 5];
    assign mc1_icp_banch                = pll_cfg[cfg_addr76*8 + 4 : cfg_addr76*8 + 0];

    assign mc1_fastlock_sel             = pll_cfg[cfg_addr75*8 + 7 : cfg_addr75*8 + 5];
    assign mc1_icp_bias                 = pll_cfg[cfg_addr75*8 + 4 : cfg_addr75*8 + 0];

  //assign mc1_freq_lock                = pll_cfg[cfg_addr74*8 + 6];
    assign mc1_pi_delay                 = pll_cfg[cfg_addr74*8 + 7 : cfg_addr74*8 + 6];
    assign mc1_bias_icfg                = pll_cfg[cfg_addr74*8 + 5 : cfg_addr74*8 + 4];
    assign mc1_lpf_r1_sel               = pll_cfg[cfg_addr74*8 + 3 : cfg_addr74*8 + 2];
    assign mc1_vctrl_sel                = pll_cfg[cfg_addr74*8 + 1 : cfg_addr74*8 + 0];

    assign mc1_tda_en                   = pll_cfg[cfg_addr73*8 + 7];
    assign mc1_pi_capsel                = pll_cfg[cfg_addr73*8 + 6 : cfg_addr73*8 + 4];
    assign mc1_pi_icfg                  = pll_cfg[cfg_addr73*8 + 3 : cfg_addr73*8 + 0];

  //assign mc1_vco_band                 = pll_cfg[cfg_addr72*8 + 3 : cfg_addr72*8 + 0];

    assign mc1_cal_counter              = pll_cfg[cfg_addr71*8 + 6 : cfg_addr71*8 + 4];
    assign mc1_refclk_det_byp           = pll_cfg[cfg_addr71*8 + 2];
    assign mc1_refclk_det_div           = pll_cfg[cfg_addr71*8 + 1 : cfg_addr71*8 + 0];

  //assign mc1_vco_cal_mode             = pll_cfg[cfg_addr70*8 + 7];
    assign mc1_gpll_lockdet             = pll_cfg[cfg_addr70*8 + 6 : cfg_addr70*8 + 0];

    assign mc1_clk0_frac_en             = pll_cfg[cfg_addr69*8 + 7];
    assign mc1_frac                     = pll_cfg[cfg_addr69*8 + 6 : cfg_addr69*8 + 0];

    assign mc1_pi_out_sel               = pll_cfg[cfg_addr68*8 + 7 : cfg_addr68*8 + 0];

    assign mc1_pi_frac_mode             = pll_cfg[cfg_addr67*8 + 7];
    assign mc1_outputpi_capsel          = pll_cfg[cfg_addr67*8 + 6 : cfg_addr67*8 + 4];
    assign mc1_outputpi_icfg            = pll_cfg[cfg_addr67*8 + 2 : cfg_addr67*8 + 0];

    assign mc1_divc_outmux              = pll_cfg[cfg_addr66*8 + 7 : cfg_addr66*8 + 0];

    assign mc1_divc_premux7[1]          = pll_cfg[cfg_addr65*8 + 7];                        //========= 7
    assign mc1_divc7                    = pll_cfg[cfg_addr65*8 + 6 : cfg_addr65*8 + 0];

    assign mc1_divc_premux7[0]          = pll_cfg[cfg_addr64*8 + 7];
    assign mc1_phc7                     = pll_cfg[cfg_addr64*8 + 6 : cfg_addr64*8 + 0];

    assign mc1_dyn_phc7                 = pll_cfg[cfg_addr63*8 + 6 : cfg_addr63*8 + 0];

    assign mc1_duty7                    = pll_cfg[cfg_addr62*8 + 6 : cfg_addr62*8 + 0];     //========= 7

    assign mc1_divc_premux6[1]          = pll_cfg[cfg_addr61*8 + 7];                        //========= 6
    assign mc1_divc6                    = pll_cfg[cfg_addr61*8 + 6 : cfg_addr61*8 + 0];

    assign mc1_divc_premux6[0]          = pll_cfg[cfg_addr60*8 + 7];
    assign mc1_phc6                     = pll_cfg[cfg_addr60*8 + 6 : cfg_addr60*8 + 0];

    assign mc1_dyn_phc6                 = pll_cfg[cfg_addr59*8 + 6 : cfg_addr59*8 + 0];

    assign mc1_duty6                    = pll_cfg[cfg_addr58*8 + 6 : cfg_addr58*8 + 0];     //========= 6

    assign mc1_divc_premux5[1]          = pll_cfg[cfg_addr57*8 + 7];                        //========= 5
    assign mc1_divc5                    = pll_cfg[cfg_addr57*8 + 6 : cfg_addr57*8 + 0];

    assign mc1_divc_premux5[0]          = pll_cfg[cfg_addr56*8 + 7];
    assign mc1_phc5                     = pll_cfg[cfg_addr56*8 + 6 : cfg_addr56*8 + 0];

    assign mc1_dyn_phc5                 = pll_cfg[cfg_addr55*8 + 6 : cfg_addr55*8 + 0];

    assign mc1_duty5                    = pll_cfg[cfg_addr54*8 + 6 : cfg_addr54*8 + 0];     //========= 5

    assign mc1_divc_premux4[1]          = pll_cfg[cfg_addr53*8 + 7];                        //========= 4
    assign mc1_divc4                    = pll_cfg[cfg_addr53*8 + 6 : cfg_addr53*8 + 0];

    assign mc1_divc_premux4[0]          = pll_cfg[cfg_addr52*8 + 7];
    assign mc1_phc4                     = pll_cfg[cfg_addr52*8 + 6 : cfg_addr52*8 + 0];

    assign mc1_dyn_phc4                 = pll_cfg[cfg_addr51*8 + 6 : cfg_addr51*8 + 0];

    assign mc1_duty4                    = pll_cfg[cfg_addr50*8 + 6 : cfg_addr50*8 + 0];     //========= 4

    assign mc1_divc_premux3[1]          = pll_cfg[cfg_addr49*8 + 7];                        //========= 3
    assign mc1_divc3                    = pll_cfg[cfg_addr49*8 + 6 : cfg_addr49*8 + 0];

    assign mc1_divc_premux3[0]          = pll_cfg[cfg_addr48*8 + 7];
    assign mc1_phc3                     = pll_cfg[cfg_addr48*8 + 6 : cfg_addr48*8 + 0];

    assign mc1_dyn_phc3                 = pll_cfg[cfg_addr47*8 + 6 : cfg_addr47*8 + 0];

    assign mc1_duty3                    = pll_cfg[cfg_addr46*8 + 6 : cfg_addr46*8 + 0];     //========= 3

    assign mc1_divc_premux2[1]          = pll_cfg[cfg_addr45*8 + 7];                        //========= 2
    assign mc1_divc2                    = pll_cfg[cfg_addr45*8 + 6 : cfg_addr45*8 + 0];

    assign mc1_divc_premux2[0]          = pll_cfg[cfg_addr44*8 + 7];
    assign mc1_phc2                     = pll_cfg[cfg_addr44*8 + 6 : cfg_addr44*8 + 0];

    assign mc1_dyn_phc2                 = pll_cfg[cfg_addr43*8 + 6 : cfg_addr43*8 + 0];

    assign mc1_duty2                    = pll_cfg[cfg_addr42*8 + 6 : cfg_addr42*8 + 0];     //========= 2

    assign mc1_divc_premux1[1]          = pll_cfg[cfg_addr41*8 + 7];                        //========= 1
    assign mc1_divc1                    = pll_cfg[cfg_addr41*8 + 6 : cfg_addr41*8 + 0];

    assign mc1_divc_premux1[0]          = pll_cfg[cfg_addr40*8 + 7];
    assign mc1_phc1                     = pll_cfg[cfg_addr40*8 + 6 : cfg_addr40*8 + 0];

    assign mc1_dyn_phc1                 = pll_cfg[cfg_addr39*8 + 6 : cfg_addr39*8 + 0];

    assign mc1_duty1                    = pll_cfg[cfg_addr38*8 + 6 : cfg_addr38*8 + 0];     //========= 1

    assign mc1_divc_premux0[1]          = pll_cfg[cfg_addr37*8 + 7];                        //========= 0
    assign mc1_divc0                    = pll_cfg[cfg_addr37*8 + 6 : cfg_addr37*8 + 0];

    assign mc1_divc_premux0[0]          = pll_cfg[cfg_addr36*8 + 7];
    assign mc1_phc0                     = pll_cfg[cfg_addr36*8 + 6 : cfg_addr36*8 + 0];

    assign mc1_dyn_phc0                 = pll_cfg[cfg_addr35*8 + 6 : cfg_addr35*8 + 0];

    assign mc1_duty0                    = pll_cfg[cfg_addr34*8 + 6 : cfg_addr34*8 + 0];     //========= 0

    assign mc1_load_en                  = pll_cfg[cfg_addr33*8 + 7 : cfg_addr33*8 + 0];

    assign mc1_load_div2_en             = pll_cfg[cfg_addr32*8 + 7 : cfg_addr32*8 + 0];

    assign mc1_div2_phc                 = pll_cfg[cfg_addr31*8 + 7 : cfg_addr31*8 + 0];

    assign mc1_duty50_n                 = pll_cfg[cfg_addr30*8 + 7 : cfg_addr30*8 + 0];

    assign mc1_enclk                    = pll_cfg[cfg_addr29*8 + 7 : cfg_addr29*8 + 0];

    assign mc1_outgate_en               = pll_cfg[cfg_addr28*8 + 7 : cfg_addr28*8 + 0];

    assign mc1_div2_bypass_n            = pll_cfg[cfg_addr27*8 + 7 : cfg_addr27*8 + 0];

    assign mc1_div_en                   = pll_cfg[cfg_addr26*8 + 7 : cfg_addr26*8 + 0];

    assign mc1_ssc_dn_loop_mode         = pll_cfg[cfg_addr25*8 + 4];
    assign mc1_ssc_lpf_sel              = pll_cfg[cfg_addr25*8 + 3 : cfg_addr25*8 + 2];
    assign mc1_ssc_mode                 = pll_cfg[cfg_addr25*8 + 1];
    assign mc1_ssc_en                   = pll_cfg[cfg_addr25*8 + 0];

    assign mc1_ssc_freq_div[17:16]      = pll_cfg[cfg_addr24*8 + 1 : cfg_addr24*8 + 0];

    assign mc1_ssc_freq_div[15: 8]      = pll_cfg[cfg_addr23*8 + 7 : cfg_addr23*8 + 0];

    assign mc1_ssc_freq_div[ 7: 0]      = pll_cfg[cfg_addr22*8 + 7 : cfg_addr22*8 + 0];

    assign mc1_ssc_step[23:16]          = pll_cfg[cfg_addr21*8 + 7 : cfg_addr21*8 + 0];

    assign mc1_ssc_step[15: 8]          = pll_cfg[cfg_addr20*8 + 7 : cfg_addr20*8 + 0];

    assign mc1_ssc_step[ 7: 0]          = pll_cfg[cfg_addr19*8 + 7 : cfg_addr19*8 + 0];

    assign mc1_fbk_div                  = pll_cfg[cfg_addr18*8 + 7 : cfg_addr18*8 + 0];

    assign mc1_fracn_dither_sel         = pll_cfg[cfg_addr17*8 + 7 : cfg_addr17*8 + 4];
    assign mc1_fracn_prbs_sel           = pll_cfg[cfg_addr17*8 + 3 : cfg_addr17*8 + 2];
    assign mc1_fracn_dither_en          = pll_cfg[cfg_addr17*8 + 1];
    assign mc1_fracn_en                 = pll_cfg[cfg_addr17*8 + 0];

    assign mc1_fbfracn_sel[27:24]       = pll_cfg[cfg_addr16*8 + 3 : cfg_addr16*8 + 0];

    assign mc1_fbfracn_sel[23:16]       = pll_cfg[cfg_addr15*8 + 7 : cfg_addr15*8 + 0];

    assign mc1_fbfracn_sel[15: 8]       = pll_cfg[cfg_addr14*8 + 7 : cfg_addr14*8 + 0];

    assign mc1_fbfracn_sel[ 7: 0]       = pll_cfg[cfg_addr13*8 + 7 : cfg_addr13*8 + 0];

    assign mc1_dyn_source               = pll_cfg[cfg_addr12*8 + 7];
    assign mc1_syn_sel                  = pll_cfg[cfg_addr12*8 + 6 : cfg_addr12*8 + 4];
    assign mc1_phic7                    = pll_cfg[cfg_addr12*8 + 2 : cfg_addr12*8 + 0];

    assign mc1_dyn_ph_shift_en          = pll_cfg[cfg_addr11*8 + 7];
    assign mc1_phic6                    = pll_cfg[cfg_addr11*8 + 6 : cfg_addr11*8 + 4];
    assign mc1_phic5                    = pll_cfg[cfg_addr11*8 + 2 : cfg_addr11*8 + 0];

    assign mc1_phic4                    = pll_cfg[cfg_addr10*8 + 6 : cfg_addr10*8 + 4];
    assign mc1_phic3                    = pll_cfg[cfg_addr10*8 + 2 : cfg_addr10*8 + 0];

    assign mc1_phic2                    = pll_cfg[cfg_addr9*8 + 6 : cfg_addr9*8 + 4];
    assign mc1_phic1                    = pll_cfg[cfg_addr9*8 + 2 : cfg_addr9*8 + 0];

    assign mc1_pi_phi_en                = pll_cfg[cfg_addr8*8 + 7];
    assign mc1_phic0                    = pll_cfg[cfg_addr8*8 + 6 : cfg_addr8*8 + 0];

    assign mc1_kvco_sel                 = pll_cfg[cfg_addr7*8 + 3 : cfg_addr7*8 + 0];

    assign mc1_intfb                    = pll_cfg[cfg_addr6*8 + 4];
    assign mc1_ref_sel                  = pll_cfg[cfg_addr6*8 + 3 : cfg_addr6*8 + 0];

                                      //= pll_cfg[cfg_addr6*8 + 0];===== used in 6110/6120

    assign mc1_fbk_sel_wakeup           = pll_cfg[cfg_addr5*8 + 7 : cfg_addr5*8 + 4];
    assign mc1_fbk_sel                  = pll_cfg[cfg_addr5*8 + 3 : cfg_addr5*8 + 0];

    assign mc1_ref_div                  = pll_cfg[cfg_addr4*8 + 7 : cfg_addr4*8 + 0];

                                      //= pll_cfg[cfg_addr3*8 + 0];

    assign mc1_divrst_ph_sel            = pll_cfg[cfg_addr2*8 + 7 : cfg_addr2*8 + 0];

    assign mc1_divcrst_en               = pll_cfg[cfg_addr1*8 + 1 : cfg_addr1*8 + 0];

    assign mc1_pllpdn                   = pll_cfg[cfg_addr0*8 + 5];
    assign mc1_dig_pd                   = pll_cfg[cfg_addr0*8 + 4];
    assign mc1_mrst_en                  = pll_cfg[cfg_addr0*8 + 3];
    assign mc1_pllrst_en                = pll_cfg[cfg_addr0*8 + 2];
    assign mc1_ssc_reset                = pll_cfg[cfg_addr0*8 + 1];

    assign pll_cfg   = {                                                 cfg82, cfg81, cfg80,
                        cfg79, cfg78, cfg77, cfg76, cfg75, cfg74, cfg73, cfg72, cfg71, cfg70,
                        cfg69, cfg68, cfg67, cfg66, cfg65, cfg64, cfg63, cfg62, cfg61, cfg60,
                        cfg59, cfg58, cfg57, cfg56, cfg55, cfg54, cfg53, cfg52, cfg51, cfg50,
                        cfg49, cfg48, cfg47, cfg46, cfg45, cfg44, cfg43, cfg42, cfg41, cfg40,
                        cfg39, cfg38, cfg37, cfg36, cfg35, cfg34, cfg33, cfg32, cfg31, cfg30,
                        cfg29, cfg28, cfg27, cfg26, cfg25, cfg24, cfg23, cfg22, cfg21, cfg20,
                        cfg19, cfg18, cfg17, cfg16, cfg15, cfg14, cfg13, cfg12, cfg11, cfg10,
                        cfg9,  cfg8,  cfg7,  cfg6,  cfg5,  cfg4,  cfg3,  cfg2,  cfg1,  cfg0 };

endmodule // pll_slave
// Local Variables:
// verilog-library-directories:("." "../rtl")
// End:
////////////////////////////////////////////////////////////////////////////////////////////////////
// Title		:
// Project		:	AL6100
//--------------------------------------------------------------------------------------------------
// File			:	axis_slave.v
// Author		:	Wang MingFei
// E-mail		:	mingfei.wang@anlogic.com
// Version		:	0.1
// Date			:	2020-04-xx
//--------------------------------------------------------------------------------------------------
// Description	:first: transmit write&read command ,and then generate" wr_en ,wr_addr ,wr_data,rd_en,rd_data'
//               second:count all err: 1.map_error  2.length error  3.actual len error  4.timeout error
//                                     5.cascade error  6.broadcast map address read
//
//
////////////////////////////////////////////////////////////////////////////////////////////////////

`ifndef AXIS_SLAVE_v
    `define AXIS_SLAVE_v

`timescale 1ns/1ps

module axis_slave #(
    parameter            TOW      = 9,  //TIMEOUT width
    parameter            TIMEOUT  = {(TOW){1'b1}},
    parameter            LENW     = 18,
    parameter            MAX_LEN  = {(LENW){1'b0}},  // physram - 16385, cr - 2, pll - 2, eram - 1028		
    parameter            ADDRW    = 32,  //local addr width
    parameter            DATAW    = 32   //local data width
)(
    `ifdef PG_FC_SIM
    inout                           VDD,
    inout                           VSS,
    `endif		
    input  [11:0]                   map_i,
    input                           broadcast_wr_en,  //enable broadcast write
    // clk & reset from config master 	
    input                           axis_clk_i,
    input                           axis_rst_n_i,
    // connect to config master tx if
    input                           s_rvalid_i,
    input  [31:0]                   s_rdata_i,
    input                           s_rlast_i,
    output                          s_rready_o,  //always 1
    // connect to config master rx if
    input                           s_tready_i,
    output wire                     s_tvalid_o,
    //output wire [DATAW-1:0]         s_tdata_o,
    output wire [31:0]              s_tdata_o,
    output wire                     s_tlast_o,
    output wire                     s_tuser_o,  //all err: 1.map_error 2.length error 3.actual len error 4.timeout error 5.cascade error 6.broadcast map address read
    // connect to down tx if
    //output wire                     m_down_clk_o,
    //output wire                     m_down_rst_n_o,
    output wire                     m_down_tvalid_o,
    output wire [31:0]              m_down_tdata_o,
    output wire                     m_down_tlast_o,
    input                           m_down_tready_i,  // always 1 not use
    // connect to down rx if
    output                          m_down_rready_o,
    input                           m_down_rvalid_i,
    //input  [DATAW-1:0]              m_down_rdata_i,
    input  [31:0]                   m_down_rdata_i,
    input                           m_down_rlast_i,
    input                           m_down_tuser_i,

    // only local if
    output reg                      wr_en,
    output reg  [DATAW-1:0]         wr_data,
    output reg  [ADDRW-1:0]         addr,	
    output reg                      rd_en,
    input                           rd_valid,
    input  [DATAW-1:0]              rd_data
);

    //--------------------------------------------------------------------
    localparam                      BROADCAST_MAP     = 12'h4ff;  //broadcast map address

    localparam                      RMAP   = 2'b00;
    localparam                      RADDR  = 2'b01;
    localparam                      RDATA  = 2'b10;
    localparam                      TIDLE  = 2'b00;
    localparam                      TDATA  = 2'b01;  //for extension

    reg  [1:0]                      next_rx_sta;
    reg  [1:0]                      rx_sta;
    reg                             chk_once_flag;  //only get the len/map_i when it's first period
    reg  [1:0]                      rx_sta_1d;
    reg                             rw_ind;  // 0 - write, 1 - read
    reg  [LENW-1:0]                 rw_len;
    reg                             map_hit;	
    reg  [LENW-1:0]                 cnt_len;
    reg                             wr_en_pre;
    reg  [DATAW-1:0]                wr_data_pre;	
    reg  [ADDRW-1:0]                wr_addr;
    reg                             rd_en_pre;		
    reg	 [ADDRW-1:0]                rd_addr;

    reg                             match_len_err;  //local error: actual length error
    reg                             map_err;  //local write error: map_error or max_length error
    reg                             broadcast_map_rd_err;  //local error: read operation in broadcast map address
    reg                             time_out;  //local read error: timeout error
    reg                             latch_rw_ind;
    reg  [LENW-1:0]                 latch_rw_len;	
    //reg                             latch_map_hit;
    reg                             rcmd_end;	
    reg  [LENW-1:0]                 cnt_rcmd;
    reg  [1:0]                      tx_sta;
    reg  [1:0]                      next_tx_sta;
    reg                             rdata_end;
    reg  [TOW-1:0]                  wait_cnt;  //to judge time_out error
    reg  [LENW-1:0]                 cnt_rd;  //master rd data out counter

    reg                             s_tvalid_pre;
    //reg  [DATAW-1:0]                s_tdata_pre;
    reg  [31:0]                     s_tdata_pre;
    reg                             s_tlast_pre;
    reg                             s_tuser_pre;
    //--------------------------------------------------------------------


    //--------------------------------------------------------------------
    //------------PART 1 . COMMON CMD-------------------------------------
    //--------------------------------------------------------------------
    assign  s_rready_o = 1'b1;  //always ready
    //assign  m_down_clk_o = axis_clk_i;
    //assign  m_down_rst_n_o = axis_rst_n_i; 

    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            rx_sta <= 2'd0;
        else
            rx_sta <= next_rx_sta;
    end

    //only once get the len/map_i when it's first period
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            chk_once_flag <= 1'd0;
        else if((s_rvalid_i == 1'b1)&&(s_rlast_i == 1'b1))
            chk_once_flag <= 1'b0;	
        else if(s_rvalid_i == 1'b1)
            chk_once_flag <= 1'b1;
        else
            ;
    end

    //delay 1 cycle
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            rx_sta_1d <= 2'd0;
        else if(s_rvalid_i == 1'b1)
            rx_sta_1d <= rx_sta;
        else
            ;
    end

    //slave rx FSM
    //command state
    always @ ( * ) begin
        case(rx_sta)
        RMAP : begin
            if((s_rvalid_i == 1'b1) && (s_rdata_i[LENW+11:12] <= MAX_LEN) &&
              //private map address and broadcast map address
              ((s_rdata_i[11:0] == map_i) || ((broadcast_wr_en == 1'b1) && (s_rdata_i[11:0] == BROADCAST_MAP))) && 
              (s_rlast_i == 1'b0) && (chk_once_flag == 1'b0))
                next_rx_sta = RADDR;
            else
                next_rx_sta = RMAP;
        end

        RADDR : begin
            if((s_rvalid_i == 1'b1) && (s_rlast_i == 1'b0) && (rw_ind == 1'b0))
                next_rx_sta = RDATA;
            else if((s_rvalid_i == 1'b1) && (s_rlast_i == 1'b1) && (rw_ind == 1'b1))
                next_rx_sta = RMAP;
            else
                next_rx_sta = RADDR;
        end

        RDATA : begin
            if((s_rvalid_i == 1'b1) && (s_rlast_i == 1'b1) && (rw_ind == 1'b0))
                next_rx_sta = RMAP;
            else
                next_rx_sta = RDATA;
        end

        default : begin
            next_rx_sta = RMAP;
        end
        endcase
    end

    //get length, write or read operation
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 ) begin
            map_hit <= 1'b0;
            rw_ind  <= 1'b0;
            rw_len  <= {(LENW){1'b0}};
        end
        else if ((rx_sta == RMAP)&&(s_rvalid_i == 1'b1)&&
                  (s_rlast_i == 1'b0)&&(chk_once_flag == 1'b0)) begin
            //private map address and broadcast map address
            if(((s_rdata_i[11:0] == map_i) || ((broadcast_wr_en == 1'b1) && (s_rdata_i[11:0] == BROADCAST_MAP)))&&
                (s_rdata_i[LENW+11:12] <= MAX_LEN)) begin
                map_hit <= 1'b1;
                rw_ind  <= s_rdata_i[31];
                rw_len  <= s_rdata_i[11+LENW:12];	
            end
            else begin
            map_hit <= 1'b0;
            rw_ind  <= 1'b0;
            rw_len  <= {(LENW){1'b0}};	
            end
        end
        else
            ;
    end

    assign  m_down_tvalid_o = s_rvalid_i;
    assign  m_down_tdata_o = s_rdata_i;
    assign  m_down_tlast_o = s_rlast_i;


    //--------------------------------------------------------------------
    //------------PART 2 . WRITE------------------------------------------
    //--------------------------------------------------------------------
    //-------------write addr & data -------------------------------------
    //generate write enable and get the data
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 ) begin
            wr_en_pre   <= 1'b0;
            wr_data_pre <= {(DATAW){1'b0}};
        end
        else if ((rx_sta == RDATA)&&(rw_ind == 1'b0)&&(s_rvalid_i == 1'b1)) begin
            wr_en_pre   <= 1'b1;
            wr_data_pre <= s_rdata_i[DATAW-1:0];
        end
        else begin
            wr_en_pre <= 1'b0;
        end
    end

    //get the addr,and then increasing the addr according to the s_rvalid_i 
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            wr_addr <= {(ADDRW){1'b0}};
        else if ((rx_sta == RADDR)&&(rx_sta_1d == RMAP)&&(s_rvalid_i == 1'b1))
            wr_addr <= s_rdata_i[ADDRW-1:0];	
        else if (wr_en_pre == 1'b1)
            wr_addr <= wr_addr + 1'b1;
        else
            ;
    end

    //generate map_err which include commond err,len err when it's first period
    //length err when matching map_i
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            map_err <= 1'b0;
        else if ((s_rvalid_i == 1'b1)&&(s_rlast_i == 1'b1))
            map_err <= 1'b0;		
        else if ((rx_sta == RMAP)&&(s_rvalid_i == 1'b1)&&
                 (s_rlast_i == 1'b0) && (chk_once_flag == 1'b0)&&
                 //private map address and broadcast map address
                 ((s_rdata_i[11:0] == map_i) || ((broadcast_wr_en == 1'b1) && (s_rdata_i[11:0] == BROADCAST_MAP)))&&
                 (s_rdata_i[LENW+11:12] > MAX_LEN))
            map_err <= 1'b1;	
        else
            ;
    end

    //generate broadcast_map_rd_err
    //error when read operation occurs in broadcast map address, only 1 cycle
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            broadcast_map_rd_err <= 1'b0;
        else if ((rx_sta == RMAP)&&(s_rvalid_i == 1'b1)&&
                 (s_rlast_i == 1'b0) && (chk_once_flag == 1'b0)&&
                 //broadcast map address
                 ((broadcast_wr_en == 1'b1) && (s_rdata_i[11:0] == BROADCAST_MAP))&&
                 //read operation
                 (s_rdata_i[31] == 1'b1))
            broadcast_map_rd_err <= 1'b1;	
        else
            broadcast_map_rd_err <= 1'b0;	
    end

    //caculate the actual length 
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            cnt_len <= {(LENW){1'b0}};
        else if ((s_rvalid_i == 1'b1)&&(s_rlast_i == 1'b1))
            cnt_len <= {(LENW){1'b0}};
        else if(s_rvalid_i == 1'b1)
            cnt_len <= cnt_len + 1'b1;
        else
            ;
    end

    //compare the actual length with the rw_len that transmitted
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            match_len_err <= 1'd0;
        else if ((s_rvalid_i == 1'b1)&&(s_rlast_i == 1'b1)&&(map_hit == 1'b1)&&
                  (rw_ind == 1'b0)&&(cnt_len != rw_len)) 
                   //(((rw_ind == 1'b0)&&(cnt_len != rw_len)) ||
                   //((rw_ind == 1'b1)&&(cnt_len != 'd1))))
            match_len_err <= 1'd1;
        else
            match_len_err <= 1'd0;
    end


    //--------------------------------------------------------------------
    //------------PART 3 . read command-----------------------------------
    //--------------------------------------------------------------------
    //------------------read back data------------------------------------
    //latch read operation when the "RADDR " first period 
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 ) begin
            latch_rw_ind  <= 1'b0;
            //latch_map_hit <= 1'b0;
            latch_rw_len  <= {(LENW){1'b0}};
        end
        else if ((s_rvalid_i == 1'b1)&&(chk_once_flag == 1'b0))	begin
            latch_rw_ind  <= 1'b0;
            //latch_map_hit <= 1'b0;
            latch_rw_len  <= {(LENW){1'b0}};
        end
        else if ((rx_sta == RADDR)&&(rx_sta_1d == RMAP)&&(s_rvalid_i == 1'b1)) begin
            latch_rw_ind  <= rw_ind;
            //latch_map_hit <= map_hit;
            latch_rw_len  <= rw_len;
        end
    end

    //1. when len = 'd1,next cycle rcmd_end will be high
    //2. when len > 'd1,will be high when the count of read command equal latch_rw_len
    //3. next times reading, update rcmd_end and become low
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            rcmd_end   <= 1'b0;
        else if ((s_rvalid_i == 1'b1)&&(chk_once_flag == 1'b0))		
            rcmd_end   <= 1'd0;
        //else if ((latch_rw_ind == 1'b1)&&(s_tready_i == 1'b1)&&(latch_rw_len == 'd1)) //when len == 1'b1
        //    rcmd_end   <= 1'b1;
        else if((rd_en_pre == 1'b1)&&(cnt_rcmd >= (latch_rw_len - 'd1 ))&&( (|latch_rw_len) == 1'b1)) //when len > 1'b1
            rcmd_end   <= 1'b1;
        else
            ;
    end

    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            rd_en_pre <= 1'b0;
        else if ((latch_rw_ind == 1'b1)&&(s_tready_i == 1'b1)&&(rcmd_end == 1'b0))
            rd_en_pre <= 1'b1;
        else
            rd_en_pre <= 1'b0;
    end

    // count the rcmd
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 ) 
            cnt_rcmd <= {(LENW){1'b0}};
        else if (rcmd_end == 1'b1)
            cnt_rcmd <= {(LENW){1'b0}};
        else if ((rd_en_pre == 1'b1)&&(rcmd_end == 1'b0))
            cnt_rcmd <= cnt_rcmd + 1'b1;
        else
            ;
    end

    //1.latch the initial addr when the "RADDR " first period
    //2.and then increase the read addr 
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            rd_addr <=  {(ADDRW){1'b0}};
        else if ((rx_sta == RADDR)&&(rx_sta_1d == RMAP)&&(s_rvalid_i == 1'b1))
            rd_addr <= s_rdata_i[ADDRW-1:0];
        else if ((rd_en_pre == 1'b1)&&(rcmd_end == 1'b0))
            rd_addr <= rd_addr + 1'b1;
        else
            ;
    end

    //--------------------------------------------------------------------
    //--------------part4. read data--------------------------------------
    //--------------------------------------------------------------------
    //slave tx FSM
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            tx_sta <= 2'd0;
        else
            tx_sta <= next_tx_sta;
    end

    always @ ( * ) begin
        case(tx_sta)
        TIDLE : begin
            if((s_tready_i == 1'b1)&& (latch_rw_ind == 1'b1)&&(rdata_end == 1'b0))
                next_tx_sta = TDATA;
            else
                next_tx_sta = TIDLE;
        end

        TDATA : begin
            if(wait_cnt >= TIMEOUT) 
                next_tx_sta = TIDLE;
            //else if((rd_valid == 1'b1) && (cnt_rd == (latch_rw_len - 1)))
            else if(rdata_end == 1'b1)
                next_tx_sta = TIDLE;
            else
                next_tx_sta = TDATA;
        end

        default : begin
            next_tx_sta = TIDLE; 
        end
        endcase
    end

    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
       if( axis_rst_n_i == 1'b0 ) begin
           s_tvalid_pre <= 1'd0;
           //s_tdata_pre  <= {(DATAW){1'b0}};
           s_tdata_pre  <= 32'b0;
           s_tlast_pre  <= 1'd0;
           time_out     <= 1'd0;	
       end	
       else if (tx_sta == TDATA) begin
           if(wait_cnt >= TIMEOUT) begin
               s_tvalid_pre <= 1'd0;
               //s_tdata_pre  <= {(DATAW){1'b0}}; 
               s_tdata_pre  <= 32'b0;
               s_tlast_pre  <= 1'd0;
               time_out     <= 1'd1;	
           end
           else begin
               s_tvalid_pre <= rd_valid;
               //s_tdata_pre  <= rd_data;
               s_tdata_pre  <= {{(32-DATAW){1'b0}},rd_data};  //merge into 32-bit, high bits is 'd0
               s_tlast_pre  <= rd_valid & (cnt_rd == (latch_rw_len - 1));
               time_out     <= 1'b0;  // monitor only timeout
           end
       end
       else// if (tx_sta == TIDLE)
       begin
           s_tvalid_pre <= 1'd0;
           //s_tdata_pre  <= {(DATAW){1'b0}}; 
           //s_tdata_pre  <= 32'b0; 
           s_tlast_pre  <= 1'd0;
           time_out     <= 1'd0;
       end		
    end

    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
       if( axis_rst_n_i == 1'b0 )
           s_tuser_pre <= 1'd0;
       //else
       //    s_tuser_pre <= time_out | map_err | match_len_err | broadcast_map_rd_err;
       else if(time_out | map_err | match_len_err | broadcast_map_rd_err)
           s_tuser_pre <= 1'b1;
       else
           ;
    end

    //1. when len >= 'd1,will be high when the count of read command equal latch_rw_len
    //2.next times reading, update rcmd_end and become low
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            rdata_end <= 1'b0;
        else if ((s_rvalid_i == 1'b1)&&(chk_once_flag == 1'b0))			
            rdata_end <= 1'b0;
        else if((tx_sta == TDATA)&&(rd_valid == 1'b1)&&(cnt_rd == (latch_rw_len - 1)))
            rdata_end <= 1'b1;
        else
            ;
    end

    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            cnt_rd <= {(LENW){1'b0}};
        else if (tx_sta == TDATA) begin
            if(rd_valid)
                cnt_rd <= cnt_rd + 1'b1;
            else
                ;
        end
        else// if (tx_sta == TIDLE)
            cnt_rd <= {(LENW){1'b0}};
    end

    //use to judge time_out error
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
       if( axis_rst_n_i == 1'b0 )
           wait_cnt <= {(TOW){1'b0}};
       else if (tx_sta == TDATA) begin
           if(rd_valid)
               wait_cnt <= {(TOW){1'b0}};
           else if(wait_cnt < TIMEOUT)
               wait_cnt <= wait_cnt + 1'b1;
           else
               ;
       end
           else // if (tx_sta == TIDLE)
               wait_cnt <= {(TOW){1'b0}};
    end


    //--------------------------------------------------------------------
    //--------------part5. count err--------------------------------------
    //--------------------------------------------------------------------
    assign  m_down_rready_o = s_tready_i;  //latch_map_hit ? 1'b0 : s_tready_i; 
    assign  s_tvalid_o = s_tvalid_pre | m_down_rvalid_i;  //map_hit ? s_tvalid_pre : m_down_rvalid_i;
    assign  s_tdata_o = map_hit ? s_tdata_pre : m_down_rdata_i; 
    assign  s_tlast_o = s_tlast_pre | m_down_rlast_i;
    //assign  s_tuser_o = map_hit ? s_tuser_pre : m_down_tuser_i;
    assign  s_tuser_o = s_tuser_pre | m_down_tuser_i;


    //--------------------------------------------------------------------
    //--------------part6.combine addr------------------------------------
    //--------------------------------------------------------------------
    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            addr <= {(ADDRW){1'b0}};
        else if (wr_en_pre == 1'b1)
            addr <= wr_addr;
        else if ((rd_en_pre == 1'b1)&&(rcmd_end == 1'b0))
            addr <= rd_addr;
        else
            ;
    end

    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 ) begin
            wr_en <= 1'd0;
            rd_en <= 1'd0;
        end
        else begin
            wr_en <= wr_en_pre;
            rd_en <= rd_en_pre & (~rcmd_end);
        end	
    end

    always @(posedge axis_clk_i or negedge axis_rst_n_i) begin
        if( axis_rst_n_i == 1'b0 )
            wr_data <= {(DATAW){1'b0}};
        else if (wr_en_pre == 1'b1)
            wr_data <= wr_data_pre;
        else
            ;
    end
    //--------------------------------------------------------------------


endmodule

`endif
`timescale 1ns/1ps

module gpll_pi_dec_top (

    output wire             [15: 0] pi_ctrl0,
    output wire             [15: 0] pi_ctrl1,
    output wire             [15: 0] pi_ctrl2,
    output wire             [15: 0] pi_ctrl3,

    output                  [ 3: 0] ph,             // 4 selected phase clk
    output                          ck_early,       // one of the above 4 clk
    output                          ck_late,        // one of the above 4 clk

    input                           resetn,
    input                           ckin,
    input                           en,
    input                   [ 6: 0] dpher,
    input                   [ 7: 0] ph_in,          //8 phase vco clk in

    inout                           vccd,
    inout                           vssd
);

    reg                     [ 3: 0] ph_sel_int;
    reg                     [ 3: 0] pi_ctrl_sel_int;
    reg                     [15: 0] o;
    reg                     [15: 0] ob;
    reg                             rstSnc2_n, rstSnc1_n;
    reg                     [ 3: 0] ck_early_sel;
    reg                     [ 3: 0] ck_late_sel;
  `ifdef FPGA_SIM
    reg                     [ 3: 0] ph_sel;
  `else
    wire                    [ 3: 0] ph_sel;
  `endif

    wire                    [ 3: 0] pi_ctrl_sel;
    wire                    [15: 0] pi_ctrl;
    wire                    [15: 0] pi_ctrlb;
    wire                            purstn;                 //en and resetn
    wire                            rstb;
    wire                    [ 3: 0] ph_rstb;
    wire                    [ 3: 0] ph_setb;
    wire                            ck_early1;
    wire                            ck_late1;
    wire                    [ 3: 0] ph_buf1;
    wire                    [ 3: 0] ph_buf2;

    always @(*) begin
        case(dpher[6:4])
            3'd0:       ph_sel_int          = 4'b1000;
            3'd1:       ph_sel_int          = 4'b0000;
            3'd2:       ph_sel_int          = 4'b0001;
            3'd3:       ph_sel_int          = 4'b0011;
            3'd4:       ph_sel_int          = 4'b0111;
            3'd5:       ph_sel_int          = 4'b1111;
            3'd6:       ph_sel_int          = 4'b1110;
            3'd7:       ph_sel_int          = 4'b1100;
            default:    ph_sel_int          = 4'b1000;
        endcase
    end

    always @(*) begin
        case(dpher[6:4])
            3'd0:       pi_ctrl_sel_int     = 4'b1100;
            3'd1:       pi_ctrl_sel_int     = 4'b1001;
            3'd2:       pi_ctrl_sel_int     = 4'b0011;
            3'd3:       pi_ctrl_sel_int     = 4'b0110;
            3'd4:       pi_ctrl_sel_int     = 4'b1100;
            3'd5:       pi_ctrl_sel_int     = 4'b1001;
            3'd6:       pi_ctrl_sel_int     = 4'b0011;
            3'd7:       pi_ctrl_sel_int     = 4'b0110;
            default:    pi_ctrl_sel_int     = 4'b1100;
        endcase
    end

    always @(*) begin
        case(dpher[4:0])
            5'd0:       o                   = 16'b0000_0000_0000_0000;
            5'd1:       o                   = 16'b0000_0000_0000_0001;
            5'd2:       o                   = 16'b0000_0000_0000_0011;
            5'd3:       o                   = 16'b0000_0000_0000_0111;
            5'd4:       o                   = 16'b0000_0000_0000_1111;
            5'd5:       o                   = 16'b0000_0000_0001_1111;
            5'd6:       o                   = 16'b0000_0000_0011_1111;
            5'd7:       o                   = 16'b0000_0000_0111_1111;
            5'd8:       o                   = 16'b0000_0000_1111_1111;
            5'd9:       o                   = 16'b0000_0001_1111_1111;
            5'd10:      o                   = 16'b0000_0011_1111_1111;
            5'd11:      o                   = 16'b0000_0111_1111_1111;
            5'd12:      o                   = 16'b0000_1111_1111_1111;
            5'd13:      o                   = 16'b0001_1111_1111_1111;
            5'd14:      o                   = 16'b0011_1111_1111_1111;
            5'd15:      o                   = 16'b0111_1111_1111_1111;
            5'd16:      o                   = 16'b1111_1111_1111_1111;
            5'd17:      o                   = 16'b0111_1111_1111_1111;
            5'd18:      o                   = 16'b0011_1111_1111_1111;
            5'd19:      o                   = 16'b0001_1111_1111_1111;
            5'd20:      o                   = 16'b0000_1111_1111_1111;
            5'd21:      o                   = 16'b0000_0111_1111_1111;
            5'd22:      o                   = 16'b0000_0011_1111_1111;
            5'd23:      o                   = 16'b0000_0001_1111_1111;
            5'd24:      o                   = 16'b0000_0000_1111_1111;
            5'd25:      o                   = 16'b0000_0000_0111_1111;
            5'd26:      o                   = 16'b0000_0000_0011_1111;
            5'd27:      o                   = 16'b0000_0000_0001_1111;
            5'd28:      o                   = 16'b0000_0000_0000_1111;
            5'd29:      o                   = 16'b0000_0000_0000_0111;
            5'd30:      o                   = 16'b0000_0000_0000_0011;
            5'd31:      o                   = 16'b0000_0000_0000_0001;
            default:    o                   = 16'b0000_0000_0000_0000;
        endcase
    end

  //always @(*) begin
  //    case(dpher[4:0])
  //        5'd0:       ob                  = 16'b1111_1111_1111_1111;
  //        5'd1:       ob                  = 16'b1111_1111_1111_1110;
  //        5'd2:       ob                  = 16'b1111_1111_1111_1100;
  //        5'd3:       ob                  = 16'b1111_1111_1111_1000;
  //        5'd4:       ob                  = 16'b1111_1111_1111_0000;
  //        5'd5:       ob                  = 16'b1111_1111_1110_0000;
  //        5'd6:       ob                  = 16'b1111_1111_1100_0000;
  //        5'd7:       ob                  = 16'b1111_1111_1000_0000;
  //        5'd8:       ob                  = 16'b1111_1111_0000_0000;
  //        5'd9:       ob                  = 16'b1111_1110_0000_0000;
  //        5'd10:      ob                  = 16'b1111_1100_0000_0000;
  //        5'd11:      ob                  = 16'b1111_1000_0000_0000;
  //        5'd12:      ob                  = 16'b1111_0000_0000_0000;
  //        5'd13:      ob                  = 16'b1110_0000_0000_0000;
  //        5'd14:      ob                  = 16'b1100_0000_0000_0000;
  //        5'd15:      ob                  = 16'b1000_0000_0000_0000;
  //        5'd16:      ob                  = 16'b0000_0000_0000_0000;
  //        5'd17:      ob                  = 16'b1000_0000_0000_0000;
  //        5'd18:      ob                  = 16'b1100_0000_0000_0000;
  //        5'd19:      ob                  = 16'b1110_0000_0000_0000;
  //        5'd20:      ob                  = 16'b1111_0000_0000_0000;
  //        5'd21:      ob                  = 16'b1111_1000_0000_0000;
  //        5'd22:      ob                  = 16'b1111_1100_0000_0000;
  //        5'd23:      ob                  = 16'b1111_1110_0000_0000;
  //        5'd24:      ob                  = 16'b1111_1111_0000_0000;
  //        5'd25:      ob                  = 16'b1111_1111_1000_0000;
  //        5'd26:      ob                  = 16'b1111_1111_1100_0000;
  //        5'd27:      ob                  = 16'b1111_1111_1110_0000;
  //        5'd28:      ob                  = 16'b1111_1111_1111_0000;
  //        5'd29:      ob                  = 16'b1111_1111_1111_1000;
  //        5'd30:      ob                  = 16'b1111_1111_1111_1100;
  //        5'd31:      ob                  = 16'b1111_1111_1111_1110;
  //        default:    ob                  = 16'b1111_1111_1111_1111;
  //    endcase
  //end

    assign purstn       = en & resetn;

    //sync resetn
    //this is different than original schematic
    always @(posedge ckin or negedge purstn) begin
        if (~purstn) 
            {rstSnc2_n, rstSnc1_n}  <= 2'b0;
        else
            {rstSnc2_n, rstSnc1_n}  <= {rstSnc1_n, 1'b1};
    end

    assign rstb         = rstSnc2_n;

    always @(posedge ckin or negedge rstb) begin
        if (~rstb) begin
          //pi_ctrl_sel             <=  4'b0011;
            ck_early_sel            <=  4'b0001;
            ck_late_sel             <=  4'b0010;
        end
        else begin
          //pi_ctrl_sel             <= ~pi_ctrl_sel_int;
            ck_early_sel            <= ~pi_ctrl_sel_int & {~pi_ctrl_sel_int[0], ~pi_ctrl_sel_int[3:1]};
            ck_late_sel             <= ~pi_ctrl_sel_int & {~pi_ctrl_sel_int[2:0], ~pi_ctrl_sel_int[3]};
        end
    end

    // do not want DC to optimize the logic, so that PR tool can match delay
  `ifdef FC_PG_SIM
    DSNQV4_140P9T40H u_donttouch_pi_ctrl_sel_0 ( .D(~pi_ctrl_sel_int[0]), .CK(ckin), .SDN(rstb), .Q(pi_ctrl_sel[0]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd) );
    DSNQV4_140P9T40H u_donttouch_pi_ctrl_sel_1 ( .D(~pi_ctrl_sel_int[1]), .CK(ckin), .SDN(rstb), .Q(pi_ctrl_sel[1]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd) );
    DRNQV4_140P9T40H u_donttouch_pi_ctrl_sel_2 ( .D(~pi_ctrl_sel_int[2]), .CK(ckin), .RDN(rstb), .Q(pi_ctrl_sel[2]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd) );
    DRNQV4_140P9T40H u_donttouch_pi_ctrl_sel_3 ( .D(~pi_ctrl_sel_int[3]), .CK(ckin), .RDN(rstb), .Q(pi_ctrl_sel[3]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd) );
  `else
    DSNQV4_140P9T40H u_donttouch_pi_ctrl_sel_0 ( .D(~pi_ctrl_sel_int[0]), .CK(ckin), .SDN(rstb), .Q(pi_ctrl_sel[0])                         );
    DSNQV4_140P9T40H u_donttouch_pi_ctrl_sel_1 ( .D(~pi_ctrl_sel_int[1]), .CK(ckin), .SDN(rstb), .Q(pi_ctrl_sel[1])                         );
    DRNQV4_140P9T40H u_donttouch_pi_ctrl_sel_2 ( .D(~pi_ctrl_sel_int[2]), .CK(ckin), .RDN(rstb), .Q(pi_ctrl_sel[2])                         );
    DRNQV4_140P9T40H u_donttouch_pi_ctrl_sel_3 ( .D(~pi_ctrl_sel_int[3]), .CK(ckin), .RDN(rstb), .Q(pi_ctrl_sel[3])                         );
  `endif

    //20220901, jzhou, use std cell to implement rst value, to avoid glitch in
    //                 pi clk output
    assign ph_rstb      = {4{rstb}} | ~ph_sel_int;
    assign ph_setb      = {4{rstb}} |  ph_sel_int;
  `ifdef FPGA_SIM
    genvar i;
    generate for (i=0; i<=2; i=i+1) begin
        always @(posedge ckin or negedge ph_rstb[i] or negedge ph_setb[i]) begin
            if (~ph_rstb[i])
                ph_sel[i]               <=  1'b0;
            if (~ph_setb[i])
                ph_sel[i]               <=  1'b1;
            else
                ph_sel[i]               <= ~ph_sel_int[i];
        end
    end
    endgenerate
  `else
      `ifdef FC_PG_SIM
        DRSNQV1_140P9T40H   u0_donttouch_ph_sel (.Q(ph_sel[0]),    .D(~ph_sel_int[0]),   .CK(ckin),   .RDN(ph_rstb[0]),  .SDN(ph_setb[0]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV1_140P9T40H   u1_donttouch_ph_sel (.Q(ph_sel[1]),    .D(~ph_sel_int[1]),   .CK(ckin),   .RDN(ph_rstb[1]),  .SDN(ph_setb[1]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV1_140P9T40H   u2_donttouch_ph_sel (.Q(ph_sel[2]),    .D(~ph_sel_int[2]),   .CK(ckin),   .RDN(ph_rstb[2]),  .SDN(ph_setb[2]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        DRSNQV1_140P9T40H   u3_donttouch_ph_sel (.Q(ph_sel[3]),    .D(~ph_sel_int[3]),   .CK(ckin),   .RDN(ph_rstb[3]),  .SDN(ph_setb[3]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        DRSNQV1_140P9T40H   u0_donttouch_ph_sel (.Q(ph_sel[0]),    .D(~ph_sel_int[0]),   .CK(ckin),   .RDN(ph_rstb[0]),  .SDN(ph_setb[0]));
        DRSNQV1_140P9T40H   u1_donttouch_ph_sel (.Q(ph_sel[1]),    .D(~ph_sel_int[1]),   .CK(ckin),   .RDN(ph_rstb[1]),  .SDN(ph_setb[1]));
        DRSNQV1_140P9T40H   u2_donttouch_ph_sel (.Q(ph_sel[2]),    .D(~ph_sel_int[2]),   .CK(ckin),   .RDN(ph_rstb[2]),  .SDN(ph_setb[2]));
        DRSNQV1_140P9T40H   u3_donttouch_ph_sel (.Q(ph_sel[3]),    .D(~ph_sel_int[3]),   .CK(ckin),   .RDN(ph_rstb[3]),  .SDN(ph_setb[3]));
      `endif
  `endif

  //always @(posedge ckin or negedge rstb) begin
  //    if (~rstb) begin
  //        pi_ctrl                 <= 16'hFFFF;
  //        pi_ctrlb                <= 16'h0000;
  //    end
  //    else begin
  //        pi_ctrl                 <= ~o;
  //        pi_ctrlb                <=  o;
  //    end
  //end

  //assign pi_ctrlb     = ~pi_ctrl;

  //assign pi_ctrl0     = pi_ctrl  & {16{pi_ctrl_sel[0]}};

  //assign pi_ctrl1     = pi_ctrlb & {16{pi_ctrl_sel[1]}};

  //assign pi_ctrl2     = pi_ctrl  & {16{pi_ctrl_sel[2]}};

  //assign pi_ctrl3     = pi_ctrlb & {16{pi_ctrl_sel[3]}};

    // do not want DC to optimize the logic, so that PR tool can match delay
    genvar i0to15;
    generate
        //instance
        for(i0to15=0; i0to15<=15; i0to15=i0to15+1) begin : gen0to15
          `ifdef FC_PG_SIM
            DSNQV2_140P9T40H u_donttouch_pi_ctrl  ( .D(~o[i0to15]), .CK(ckin), .SDN(rstb), .Q(pi_ctrl[i0to15]),       .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd) );
            DRNQV2_140P9T40H u_donttouch_pi_ctrlb ( .D( o[i0to15]), .CK(ckin), .RDN(rstb), .Q(pi_ctrlb[i0to15]),      .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd) );

            AND2V8_140P9T40H u_donttouch_pi_ctrl0 ( .A1(pi_ctrl[i0to15]),  .A2(pi_ctrl_sel[0]), .Z(pi_ctrl0[i0to15]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd) );
            AND2V8_140P9T40H u_donttouch_pi_ctrl1 ( .A1(pi_ctrlb[i0to15]), .A2(pi_ctrl_sel[1]), .Z(pi_ctrl1[i0to15]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd) );
            AND2V8_140P9T40H u_donttouch_pi_ctrl2 ( .A1(pi_ctrl[i0to15]),  .A2(pi_ctrl_sel[2]), .Z(pi_ctrl2[i0to15]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd) );
            AND2V8_140P9T40H u_donttouch_pi_ctrl3 ( .A1(pi_ctrlb[i0to15]), .A2(pi_ctrl_sel[3]), .Z(pi_ctrl3[i0to15]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd) );
          `else
            DSNQV2_140P9T40H u_donttouch_pi_ctrl  ( .D(~o[i0to15]), .CK(ckin), .SDN(rstb), .Q(pi_ctrl[i0to15])                               );
            DRNQV2_140P9T40H u_donttouch_pi_ctrlb ( .D( o[i0to15]), .CK(ckin), .RDN(rstb), .Q(pi_ctrlb[i0to15])                              );

            AND2V8_140P9T40H u_donttouch_pi_ctrl0 ( .A1(pi_ctrl[i0to15]),  .A2(pi_ctrl_sel[0]), .Z(pi_ctrl0[i0to15])                         );
            AND2V8_140P9T40H u_donttouch_pi_ctrl1 ( .A1(pi_ctrlb[i0to15]), .A2(pi_ctrl_sel[1]), .Z(pi_ctrl1[i0to15])                         );
            AND2V8_140P9T40H u_donttouch_pi_ctrl2 ( .A1(pi_ctrl[i0to15]),  .A2(pi_ctrl_sel[2]), .Z(pi_ctrl2[i0to15])                         );
            AND2V8_140P9T40H u_donttouch_pi_ctrl3 ( .A1(pi_ctrlb[i0to15]), .A2(pi_ctrl_sel[3]), .Z(pi_ctrl3[i0to15])                         );
          `endif
        end //for
    endgenerate

    //clk output mux
    al6100_gpll_cell_clk_mux u_donttouch_clk_divmux0 (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(ph_buf1[0]),      .in1(ph_in[0]),  .in0(ph_in[4]),     .sel(ph_sel[0])
    );

    al6100_gpll_cell_clk_mux u_donttouch_clk_divmux1 (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(ph_buf1[1]),      .in1(ph_in[1]),  .in0(ph_in[5]),     .sel(ph_sel[1])
    );

    al6100_gpll_cell_clk_mux u_donttouch_clk_divmux2 (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(ph_buf1[2]),      .in1(ph_in[2]),  .in0(ph_in[6]),     .sel(ph_sel[2])
    );

    al6100_gpll_cell_clk_mux u_donttouch_clk_divmux3 (
  `ifdef FC_PG_SIM
        .vdd(vccd), .vss(vssd),
  `endif
        .cout(ph_buf1[3]),      .in1(ph_in[3]),  .in0(ph_in[7]),     .sel(ph_sel[3])
    );

  `ifdef FPGA_SIM
    assign ck_early             = ck_early_sel==4'b1000 ? ph_buf1[3]
                                : ck_early_sel==4'b0100 ? ph_buf1[2]
                                : ck_early_sel==4'b0010 ? ph_buf1[1]
                                :                         ph_buf1[0] ;
  `else
      `ifdef FC_PG_SIM
        TBUFV8_140P9T40H    ue3_donttouch_buft_out   (.Z(ck_early1),  .I(ph_buf1[3]),   .OE(ck_early_sel[3]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    ue2_donttouch_buft_out   (.Z(ck_early1),  .I(ph_buf1[2]),   .OE(ck_early_sel[2]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    ue1_donttouch_buft_out   (.Z(ck_early1),  .I(ph_buf1[1]),   .OE(ck_early_sel[1]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    ue0_donttouch_buft_out   (.Z(ck_early1),  .I(ph_buf1[0]),   .OE(ck_early_sel[0]), .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        CLKBUFV4_140P9T40H  ue_donttouch_buft_out    (.Z(ck_early ),  .I(ck_early1),                          .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        TBUFV8_140P9T40H    ue3_donttouch_buft_out   (.Z(ck_early1),  .I(ph_buf1[3]),   .OE(ck_early_sel[3]));
        TBUFV8_140P9T40H    ue2_donttouch_buft_out   (.Z(ck_early1),  .I(ph_buf1[2]),   .OE(ck_early_sel[2]));
        TBUFV8_140P9T40H    ue1_donttouch_buft_out   (.Z(ck_early1),  .I(ph_buf1[1]),   .OE(ck_early_sel[1]));
        TBUFV8_140P9T40H    ue0_donttouch_buft_out   (.Z(ck_early1),  .I(ph_buf1[0]),   .OE(ck_early_sel[0]));
        CLKBUFV4_140P9T40H  ue_donttouch_buft_out    (.Z(ck_early ),  .I(ck_early1)                         );
      `endif
  `endif

  `ifdef FPGA_SIM
    assign ck_late              = ck_late_sel==4'b1000 ?  ph_buf1[3]
                                : ck_late_sel==4'b0100 ?  ph_buf1[2]
                                : ck_late_sel==4'b0010 ?  ph_buf1[1]
                                :                         ph_buf1[0] ;
  `else
      `ifdef FC_PG_SIM
        TBUFV8_140P9T40H    ul3_donttouch_buft_out   (.Z(ck_late1),   .I(ph_buf1[3]),   .OE(ck_late_sel[3]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    ul2_donttouch_buft_out   (.Z(ck_late1),   .I(ph_buf1[2]),   .OE(ck_late_sel[2]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    ul1_donttouch_buft_out   (.Z(ck_late1),   .I(ph_buf1[1]),   .OE(ck_late_sel[1]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        TBUFV8_140P9T40H    ul0_donttouch_buft_out   (.Z(ck_late1),   .I(ph_buf1[0]),   .OE(ck_late_sel[0]),  .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
        CLKBUFV4_140P9T40H  ul_donttouch_buft_out    (.Z(ck_late ),   .I(ck_late1),                           .VDD(vccd), .VSS(vssd), .VNW(vccd), .VPW(vssd));
      `else
        TBUFV8_140P9T40H    ul3_donttouch_buft_out   (.Z(ck_late1),   .I(ph_buf1[3]),   .OE(ck_late_sel[3]) );
        TBUFV8_140P9T40H    ul2_donttouch_buft_out   (.Z(ck_late1),   .I(ph_buf1[2]),   .OE(ck_late_sel[2]) );
        TBUFV8_140P9T40H    ul1_donttouch_buft_out   (.Z(ck_late1),   .I(ph_buf1[1]),   .OE(ck_late_sel[1]) );
        TBUFV8_140P9T40H    ul0_donttouch_buft_out   (.Z(ck_late1),   .I(ph_buf1[0]),   .OE(ck_late_sel[0]) );
        CLKBUFV4_140P9T40H  ul_donttouch_buft_out    (.Z(ck_late ),   .I(ck_late1)                          );
      `endif
  `endif

    //20230106, add 1 level clk buffer to match delay with ck_early & ck_late
//`ifdef FC_PG_SIM
//  at0012_cell_clk_buf u13_donttouch_ckbuf          (.cout(ph_buf2[3]),    .cin(ph_buf1[3]),   .vdd(vccd),     .vss(vssd));
//  at0012_cell_clk_buf u12_donttouch_ckbuf          (.cout(ph_buf2[2]),    .cin(ph_buf1[2]),   .vdd(vccd),     .vss(vssd));
//  at0012_cell_clk_buf u11_donttouch_ckbuf          (.cout(ph_buf2[1]),    .cin(ph_buf1[1]),   .vdd(vccd),     .vss(vssd));
//  at0012_cell_clk_buf u10_donttouch_ckbuf          (.cout(ph_buf2[0]),    .cin(ph_buf1[0]),   .vdd(vccd),     .vss(vssd));
//`else
//  at0012_cell_clk_buf u13_donttouch_ckbuf          (.cout(ph_buf2[3]),    .cin(ph_buf1[3])                              );
//  at0012_cell_clk_buf u12_donttouch_ckbuf          (.cout(ph_buf2[2]),    .cin(ph_buf1[2])                              );
//  at0012_cell_clk_buf u11_donttouch_ckbuf          (.cout(ph_buf2[1]),    .cin(ph_buf1[1])                              );
//  at0012_cell_clk_buf u10_donttouch_ckbuf          (.cout(ph_buf2[0]),    .cin(ph_buf1[0])                              );
//`endif

  `ifdef FC_PG_SIM
    at0012_cell_clk_buf u23_donttouch_ckbuf          (.cout(ph[3]),         .cin(ph_buf1[3]),   .vdd(vccd),     .vss(vssd));
    at0012_cell_clk_buf u22_donttouch_ckbuf          (.cout(ph[2]),         .cin(ph_buf1[2]),   .vdd(vccd),     .vss(vssd));
    at0012_cell_clk_buf u21_donttouch_ckbuf          (.cout(ph[1]),         .cin(ph_buf1[1]),   .vdd(vccd),     .vss(vssd));
    at0012_cell_clk_buf u20_donttouch_ckbuf          (.cout(ph[0]),         .cin(ph_buf1[0]),   .vdd(vccd),     .vss(vssd));
  `else
    at0012_cell_clk_buf u23_donttouch_ckbuf          (.cout(ph[3]),         .cin(ph_buf1[3])                              );
    at0012_cell_clk_buf u22_donttouch_ckbuf          (.cout(ph[2]),         .cin(ph_buf1[2])                              );
    at0012_cell_clk_buf u21_donttouch_ckbuf          (.cout(ph[1]),         .cin(ph_buf1[1])                              );
    at0012_cell_clk_buf u20_donttouch_ckbuf          (.cout(ph[0]),         .cin(ph_buf1[0])                              );
  `endif

endmodule

// ----------------------------------------------------------------------------------
// Module    : sync_dff
//
// Purpose   : 2 dff synchronizer
//
// To use    : sync_dff #(.SIZE(1'b0), .RST_VAL(1'b0)) u_sync_dff_name (.clk(clk), .rst_n(rst_nn]), .din(din), .dout(dout));
//-----------------------------------------------------------------------------
// Copyright (c) 2021 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module sync_dff
#(
    parameter [31:0] SIZE    = 32'd1,
    parameter        RST_VAL = 1'd0
)
(
    input                               clk,        // clock domain to synchronize
    input                               rst_n,      // reset
    input                   [SIZE-1: 0] din,        // input data

    output reg              [SIZE-1: 0] dout        // synchronized data
);

    parameter C2Q               = 0.04;

    // ------------------------------------------------------------------------------
    // Reg & Wire definition
    // ------------------------------------------------------------------------------
    reg                     [SIZE-1: 0] temp_meta;       // transient data


    // ------------------------------------------------------------------------------
    // Logic starts
    // ------------------------------------------------------------------------------

  `ifndef EN_TRANS_UNCERT
    always @(posedge clk or negedge rst_n) begin
       if (!rst_n) begin
          temp_meta             <= #C2Q {(SIZE){RST_VAL}};
          dout                  <= #C2Q {(SIZE){RST_VAL}};
       end //if
       else begin
          temp_meta             <= #C2Q din;
          dout                  <= #C2Q temp_meta;
       end //else
    end //always
  `else
  //-- if enabled to emulate real hardware where depending on sampling clock full synchronization
  //-- can take from 2 to 3 clock cycles to propagate input signal

    reg                         [ 1: 0] sync_dff_st;
    reg                                 skip_trans;
    reg                     [SIZE-1: 0] in_d;

    parameter [1:0]       IDLE  = 2'd0,
                          DELAY = 2'd1,
                          FINAL = 2'd2;


    always @(posedge clk or negedge rst_n) begin
       if (!rst_n)
          skip_trans            <= #C2Q 0;
       else
          skip_trans            <= #C2Q $random;
    end

    always @(posedge clk or negedge rst_n) begin
       if (!rst_n)
          in_d                  <= #C2Q 0;
       else
          in_d                  <= #C2Q din;
    end
    wire in_changed = (|(in_d ^ din));

    always @(posedge clk or negedge rst_n) begin
       if (!rst_n) begin
          temp_meta             <= #C2Q {(SIZE){RST_VAL}};
          sync_dff_st           <= #C2Q IDLE;
       end //if
       else begin
          case (sync_dff_st)
            // waiting for signal to propagate
            // --------------------------------------------------
            IDLE: begin
               //-- due to transient uncertanty in real chip sometimes 1dff does not propagate
               //-- input on 1st clock
               if (in_changed && skip_trans)
                  sync_dff_st   <= #C2Q DELAY;
               else
                  temp_meta     <= #C2Q din;
            end //IDLE
    
            // assign after 1 clock delay
            // --------------------------------------------------
            DELAY: begin
               temp_meta        <= #C2Q in_d;
               sync_dff_st      <= #C2Q IDLE;
            end //DELAY
    
            default: begin
               temp_meta        <= #C2Q 0;
               sync_dff_st      <= #C2Q IDLE;
            end
          endcase
       end //else
    end //always

    always @(posedge clk or negedge rst_n) begin
       if (!rst_n)
          dout                  <= #C2Q {(SIZE){RST_VAL}};
       else
          dout                  <= #C2Q temp_meta;
    end

  `endif

endmodule //sync_dff

// ----------------------------------------------------------------------------------
// Module    : st2p.v
//
// Hierarchy : common
//
// Purpose   : synchronized toggle to pulse conversion
//
// To use    : st2p #(.PULSE(2'b00)) u_st2p(.clk(), .rst_n(), .din(), .dout());
// ----------------------------------------------------------------------------------
// Copyright (c) 2021 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module st2p
#(
    parameter [1:0] PULSE = 2'b00		//pulse type    2'b00: rise edge  2'b01: fall edge  2'b10: both edge
)
(
    input                               clk,          // clock
    input                               rst_n,        // reset
    input                               din,           // input data

    output                              dout           // result
);

    parameter C2Q               = 0.04;

    // ------------------------------------------------------------------------------
    // Reg & Wire definition
    // ------------------------------------------------------------------------------
    reg                         [ 2: 0] temp;      // Delayed input data
    
    // ------------------------------------------------------------------------------
    // Logic starts
    // ------------------------------------------------------------------------------


`ifndef EN_TRANS_UNCERT
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         temp                   <= #C2Q 3'b000;
      end
      else begin
         temp[0]                <= #C2Q din;
         temp[1]                <= #C2Q temp[0];
         temp[2]                <= #C2Q temp[1];
      end
    end

   // toggle output if posedge has been detected
    generate
     if(PULSE==2'b00)
       assign dout              =  temp[1] & ~temp[2]; // rise edge
     else if(PULSE==2'b01)
       assign dout              = ~temp[1] &  temp[2]; // faill edge
     else
       assign dout              =  temp[1] ^  temp[2]; // toggle detect
    endgenerate
`else
   //-- synchronize input
   sync_dff u_sync_st2 (.clk(clk), .rst_n(rst_n), .din(din), .dout(in_dd));
   //-- delay
   sync_del u_del_st2  (.clk(clk), .rst_n(rst_n), .en(1'b1),.din(in_dd), .dout(in_ddd));
   //-- find difference
 //assign dout = (|(in_dd ^ in_ddd));
    generate
     if(PULSE==2'b00)
       assign dout              =  in_dd & ~in_ddd; // rise edge
     else if(PULSE==2'b01)
       assign dout              = ~in_dd &  in_ddd; // faill edge
     else
       assign dout              =  in_dd ^  in_ddd; // toggle detect
    endgenerate
`endif

endmodule
// ----------------------------------------------------------------------------------
// Module    : sync_del.v
//
// Purpose   : 1 clock delay
//
// To use    : sync_del #(.SIZE(1'b0), .RST_VAL(1'b0), .DEL_CYCLE(1'b1))
//                       u_del_name (.clk(clk), .rst_n(rst_n), .en(1'b1), .din(din), .dout(dout));
//    don't need to specify SIZE, RST_VAL & DEl_CYCLE if desired values match default
// ----------------------------------------------------------------------------------
// Copyright (c) 2021 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module sync_del
#(
    parameter [31:0] SIZE      = 32'd1,
    parameter        RST_VAL   = 1'd0,
    parameter [31:0] DEL_CYCLE = 32'd1
)
(
    input                               clk,
    input                               rst_n,       // Clock and Reset input
    input                               en,          // Module enable
    input                   [SIZE-1: 0] din,         //

    output                  [SIZE-1: 0] dout         //
);

    parameter C2Q               = 0.04;

    // ------------------------------------------------------------------------------
    // Reg & Wire definition
    // ------------------------------------------------------------------------------
    reg                     [SIZE-1: 0] data_dly [DEL_CYCLE-1:0];
    integer                             i;


    // ------------------------------------------------------------------------------
    // Logic starts
    // ------------------------------------------------------------------------------

    //-- Shift data
    always @(posedge clk or negedge rst_n) begin
       if (!rst_n) begin
          for (i=0; i<DEL_CYCLE; i=i+1) begin
              data_dly[i]       <= #C2Q {(SIZE){RST_VAL}};
          end
       end
       else begin
          if (en) begin
             data_dly[0]        <= #C2Q din;

             for (i=1; i<DEL_CYCLE; i=i+1) begin
                data_dly[i]     <= #C2Q data_dly[i-1];
             end
          end
       end
    end //always

    assign dout                 = data_dly[DEL_CYCLE-1];

endmodule

// Module    : pulse
//
// Hierarchy : common part, instantiated on multiple levels
//
// Purpose   : One clock pulse generation logic
//
// To use    : pulse #(.LEVEL(1'b0)) u_pulse(.clk(), .rst_n(), .din(), .dout());
// ----------------------------------------------------------------------------------
// Copyright (c) 2021 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module pulse (
    clk,                      // from
    rst_n,                    // from
    din,                      // from

    dout                      // to
);

    parameter C2Q               = 0.04;

    //Overrided parameter value during model instatiation
    //----------------------------------------------------
    parameter  [31:0] SIZE = 1;
    
    //Overwrite parameter value during model inst.
    //----------------------------------------------------
    parameter  [ 0:0] LEVEL = 0;           // rise edge
    
    // ------------------------------------------------------------------------------
    // Input & Output definition
    // ------------------------------------------------------------------------------
    input                               clk;            // clock domain to synchronize
    input                               rst_n;          // reset
    input                   [SIZE-1: 0] din;            // input data
    
    output                  [SIZE-1: 0] dout;           // synchronized data
    
    // ------------------------------------------------------------------------------
    // Reg & Wire definition
    // ------------------------------------------------------------------------------
  //reg                     [SIZE-1: 0] dout;           //
    reg                     [SIZE-1: 0] in_d;           // Delayed input data
    
    
    // ------------------------------------------------------------------------------
    // Logic starts
    // ------------------------------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
       if (!rst_n)
          in_d                  <= #C2Q 0;
       else
          in_d                  <= #C2Q din;
    end //always

    generate
      if(LEVEL==1'b0)
        assign dout             =  din & ~in_d; // rise edge
      else
        assign dout             = ~din &  in_d; // faill edge
    endgenerate

//  always @(posedge clk or negedge rst_n) begin
//     if (!rst_n)
//        dout  <= 0;
//     else begin
//        //lint_checking CONSTC off
//        if (LEVEL == 1)          // high 1 clock pulse
//        //lint_checking CONSTC on
//            dout  <= (din & ~in_d);
//        else                     // low 1 clock pulse
//           dout  <= (~din & in_d);
//     end
//  end //always

endmodule
//-----------------------------------------------------------------------------
// Project       : at0012v1
//-----------------------------------------------------------------------------
// File          : at0012_cell_clk_buf.v
// Author        :   jzhou
// Created       : 2021.04
// Last modified : 2021.04
//-----------------------------------------------------------------------------
// Description :
// clk buf cell for synthesis
//-----------------------------------------------------------------------------
// Copyright (c) 2021 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module at0012_cell_clk_buf (
`ifdef PG_FC_SIM
    inout                               vdd,
    inout                               vss,
`endif
    input                               cin,
    output                              cout
);

    wire                                cout1;

    `ifdef FPGA_SIM
        assign cout         = cin;
    `else
        `ifdef PG_FC_SIM
            CLKINV4_140P9T40R u0_donttouch_clk_inv (.ZN(cout1), .I(cin),   .VDD(vdd), .VSS(vss), .VNW(vdd), .VPW(vss));
            CLKINV4_140P9T40R u1_donttouch_clk_inv (.ZN(cout),  .I(cout1), .VDD(vdd), .VSS(vss), .VNW(vdd), .VPW(vss));
        `else
            CLKINV4_140P9T40R u0_donttouch_clk_inv (.ZN(cout1), .I(cin));
            CLKINV4_140P9T40R u1_donttouch_clk_inv (.ZN(cout),  .I(cout1));
        `endif
    `endif

endmodule

//-----------------------------------------------------------------------------
// Project       : al6100
//-----------------------------------------------------------------------------
// File          : al6100_gpll_cell_clk_mux.v
// Author        :   jzhou
// Created       : 2021.04
// Last modified : 2021.04
//-----------------------------------------------------------------------------
// Description :
// clk mux cell for synthesis
//-----------------------------------------------------------------------------
// Copyright (c) 2023 by anlogic This model is the confidential and
// proprietary property of anlogic and the possession or use of this
// file requires a written license from anlogic.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module al6100_gpll_cell_clk_mux (
`ifdef PG_FC_SIM
    inout                               vdd,
    inout                               vss,
`endif
    input                               in0,
    input                               in1,
    input                               sel,
    output                              cout
);

    //select signal is static, do not care timing, so use HVT
    wire                                selb;

    wire                                in0t;   //temp signal
    wire                                in1t;   //temp signal

    `ifdef FPGA_SIM
        assign cout          = sel ? in1 : in0;
    `else
        `ifdef PG_FC_SIM
            INV2_140P9T40H       u_donttouch_inv       (.ZN(selb), .I(sel),                 .VDD(vdd), .VSS(vss), .VNW(vdd), .VPW(vss));
            CLKNAND2V2_140P9T40R u_donttouch_clk_nand1 (.ZN(in1t), .A1(sel),  .A2(in1),     .VDD(vdd), .VSS(vss), .VNW(vdd), .VPW(vss));
            CLKNAND2V2_140P9T40R u_donttouch_clk_nand2 (.ZN(in0t), .A1(selb), .A2(in0),     .VDD(vdd), .VSS(vss), .VNW(vdd), .VPW(vss));
            CLKNAND2V2_140P9T40R u_donttouch_clk_nand3 (.ZN(cout), .A1(in0t), .A2(in1t),    .VDD(vdd), .VSS(vss), .VNW(vdd), .VPW(vss));

          //CLKMUX2V8_140P9T40R u_donttouch_ckmux2(.I0(in0), .I1(in1), .S(sel), .Z(cout), .VDD(vdd), .VSS(vss), .VNW(vdd), .VPW(vss));
        `else
            INV2_140P9T40H       u_donttouch_inv       (.ZN(selb), .I(sel)                  );
            CLKNAND2V2_140P9T40R u_donttouch_clk_nand1 (.ZN(in1t), .A1(sel),  .A2(in1)      );
            CLKNAND2V2_140P9T40R u_donttouch_clk_nand2 (.ZN(in0t), .A1(selb), .A2(in0)      );
            CLKNAND2V2_140P9T40R u_donttouch_clk_nand3 (.ZN(cout), .A1(in0t), .A2(in1t)     );

          //CLKMUX2V8_140P9T40R u_donttouch_ckmux2(.I0(in0), .I1(in1), .S(sel), .Z(cout));
        `endif
    `endif

endmodule

`timescale 1ns / 10fs

module gpll_ana_core ( 
    output              cko_000, 
    output              cko_045, 
    output              cko_090, 
    output              cko_135, 
    output              cko_180, 
    output              cko_225, 
    output              cko_270, 
    output              cko_315,
    
    output wire         fast_lock, 
    
    output wire         ibp_30u_pi,     // no need to model these output
    output wire         ibp_100u_pi, 
    output wire         vcca_vreg_cp, 
    output              vctrl_idle , 
    output wire         vdd_ico, 
    
    input wire          sg09_gpll_ref_clkn, 
    input wire          sg09_gpll_ref_clkp, 
    input wire          sg09_gpll_fbk_clkn, 
    input wire          sg09_gpll_fbk_clkp,
    
    input wire          freq_lock,
    input               fastloop_cfg,
    
    input       [2:0]   sg09_gpll_cp_dlysel, 
    input wire  [2:0]   sg09_gpll_cp_refsel, 
    input       [2:0]   sg09_gpll_fastlock_sel,  
    input wire  [4:0]   sg09_gpll_icp_banch, 
    input wire  [4:0]   sg09_gpll_icp_bias, 
    input       [1:0]   sg09_gpll_initial_vctrl, 
    input wire  [1:0]   sg09_gpll_lpf_r1_sel,   
    input wire          sg09_gpll_tda_en,  
    
    input wire  [3:0]   vco_band,
    
    input               sg09_gpll_pfd_cp_en,
    input               sg09_gpll_rstn ,
    input               sg09_gpll_vco_en,
    
    input               sg18_poc,           // =0, normal work
    input       [2:0]   ibn_10u_poly,       // gpll internally generated power, no need to check in dig model
    input               ibn_10u_ptat,       // gpll external input power,          need to check, 1=power up
    input               ibp_10u_poly,       // gpll internally generated power,    need to check, 1=power up
    input               vccaux, 
    input               vccd ,  
//  input               vreg_0p9, 
    input               vreg_0p9_d2c,
    input               vreg_0p9_pfd,
    input               vreg_1p2, 
    input               vssa
);

    wire                pwr_rdy, pfd_rstn, vco_en;

    wire                pfd_ref_clk, pfd_fbk_clk;
    wire                ff_rst;

    reg                 refclk_rdy;
    reg                 up, dn;
    reg                 internal_ck;

    reg                 pll_clk_045_reg;
    reg                 pll_clk_090_reg;
    reg                 pll_clk_135_reg;
    reg                 pll_clk_225_reg;
    reg                 pll_clk_270_reg;
    reg                 pll_clk_315_reg;

    reg                 minus100M;
    reg                 plus100M;
    reg         [ 2: 0] refcnt;

    real                reftr, refprd;
    real                fbktr, fbkprd;
    real                phsdif, phsdif_ratio;
    real                uprise, upprd;
    real                dnrise, dnprd;
    real                integral, proportional;
    real                vctl, to;
    real                kphi, filt_i, filt_p;
    real                vcoperiod;

  //assign pwr_rdy      = vccaux & vccd & (~vssa) & vreg_0p9                    & vreg_1p2 & ibp_10u_poly & ibn_10u_ptat & (~sg18_poc);
    assign pwr_rdy      = vccaux & vccd & (~vssa) & vreg_0p9_d2c & vreg_0p9_pfd & vreg_1p2 & ibp_10u_poly & ibn_10u_ptat & (~sg18_poc);

    assign pfd_rstn     = pwr_rdy & sg09_gpll_pfd_cp_en & sg09_gpll_rstn ;

    assign vco_en       = pwr_rdy & sg09_gpll_vco_en  /*& sg09_gpll_rstn*/ ;

    assign pfd_ref_clk  = sg09_gpll_ref_clkp;

    assign pfd_fbk_clk  = sg09_gpll_fbk_clkp;

    initial begin
        phsdif_ratio = 0;
        refprd       = 1;
        fbkprd       = 0;
        refcnt       = 3'b0;
        forever begin
            @(posedge pfd_ref_clk);
            reftr            = $realtime;
            refcnt           = refcnt + pfd_rstn;
            @(posedge pfd_ref_clk);
            refprd           = $realtime - reftr;
            refcnt           = refcnt + pfd_rstn;

            phsdif           = fbkprd - refprd;
            phsdif_ratio     = (fbkprd/refprd)*100;
        end
    end

    initial begin
        forever begin
            @(posedge pfd_fbk_clk);
            fbktr            = $realtime;
            @(posedge pfd_fbk_clk);
            fbkprd           = $realtime - fbktr;

            phsdif           = fbkprd - refprd;
            phsdif_ratio     = (fbkprd/refprd)*100;
        end
    end

    always @(posedge pfd_ref_clk or negedge pwr_rdy)begin
        if (~pwr_rdy)
            refclk_rdy  <= 1'b0;
        else
            refclk_rdy  <= 1'b1;
    end

  //assign ff_rstx      = up & dn;
    assign ff_rst       = up & dn;
  //assign #0.01 ff_rst = ff_rstx;  //must not delay this rst, will cause wrong behaviour
  
    always @(posedge pfd_ref_clk or posedge ff_rst or negedge refclk_rdy or negedge pfd_rstn) begin
          if (ff_rst | ~refclk_rdy | ~pfd_rstn)     up <= 1'b0;
          else                                      up <= 1'b1;
    end
  
    always @(posedge pfd_fbk_clk or posedge ff_rst or negedge refclk_rdy or negedge pfd_rstn) begin
          if (ff_rst | ~refclk_rdy | ~pfd_rstn)     dn <= 1'b0;
          else                                      dn <= 1'b1;
    end

    always @(posedge ff_rst) begin
        if (ff_rst)
            refcnt  <= 3'b0;
    end

    initial begin
        internal_ck   = 1'b0;
        proportional  = 0.0;
        integral      = 0.0;
      //to            = 0.66667;        // initially 1.5GHz
      //vcoperiod     = 0.66667;
      //to            =66.66667;        // initially 15MHz
      //vcoperiod     =66.66667;
        to            = 2.00000;        // initially 500MHz
        vcoperiod     = 2.00000;

      //filt_i        = 0.00005;
      //filt_p        = 0.00023;
      //filt_i        = 0.0005;
      //filt_p        = 0.023;
      //kphi          = 3.5;            //  3.5Ghz/v
        //20220607, jzhou, refclk input to PFD range from 10MHz~100MHz,
        //originally refclk input is around 500MHz
        //decrease the loop parameter 25 times
      //filt_i        = 0.0005/5;
        filt_i        = 0.003/5; //0.0005/5;  //20220616, enlarge Ki value
                                              //otherwise vco_period has glitch in
                                              //SSC mode
        filt_p        = 0.023/5;
        kphi          = 3.5/5;          //  3.5Ghz/v
    end
  
    always @(up) begin
        if(up)
            uprise  <= $realtime;
        else if(uprise!=0)
            upprd   <= $realtime - uprise;
    end
  
    always @(dn) begin
        if(dn)
            dnrise  <= $realtime;
        else if(dnrise!=0)
            dnprd   <= $realtime - dnrise;
    end

  //always @( up or dn or refclk_rdy or upprd or dnprd or pfd_rstn) begin
    always @(             refclk_rdy or upprd or dnprd or pfd_rstn) begin
        if (~refclk_rdy | ~pfd_rstn) begin
            integral        = 0;
            proportional    = 0;
            vctl            = 0;
            upprd           = 0;
            dnprd           = 0;
        end
      //else if ( kphi*(filt_p*upprd+filt_p*upprd) < to &&      //at the beginning, do not fill in integral/proportional if it's a very big value
        else if ( (phsdif > 0.00001 || phsdif <-0.00001)        //keeps adjust vco if 1. period(freq) diff is bigger than 5ps
               || (upprd  > 0.00001 || dnprd  > 0.00001) )      //or 2. phase diff is bigger than 5ps
            begin
                if (upprd != 0) begin
                    integral         = integral + filt_i*upprd;
                    proportional     = filt_p*upprd;
                    upprd            = 0;
                end
                //integral should always be a positive value, because initial
                //freq is 500MHz, while working range is 800M~2G
                else if (dnprd != 0)begin
                    if( (integral - filt_i*dnprd)>0 ) begin
                        integral     = integral - filt_i*dnprd;
                        proportional = -filt_p*dnprd;
                    end
                    dnprd            = 0;
                end
                vctl = integral + proportional;
            end
    end

    always @(pfd_rstn or vctl) begin : VCO_PERIOD
        if(~pfd_rstn) begin
            vcoperiod       = to;
            minus100M       = 1'b0;
            plus100M        = 1'b0;
        end
        else if ( 1+to*vctl*kphi >0 ) begin         //period must be a positive value
          if ((1/to + vctl*kphi) < 2.6 &&                   //frequency must be less    than 2.6GHz
              (1/to + vctl*kphi) > 0.5) begin               //frequency must be greater than 500MHz(the initial value)
                vcoperiod       = 1/(1/to + vctl*kphi);
                minus100M       = 1'b0;
                plus100M        = 1'b0;
          end
          else if((1/to + vctl*kphi) < 0.5 && (1/vcoperiod - 0.1) > 0.5) begin
                vcoperiod       = 1/(1/vcoperiod - 0.1);    //decrease 100MHz when lower than above low range
                minus100M       = 1'b1;                     //but should not be lower than 500MHz(the initial value) after decrease
                plus100M        = 1'b0;
          end
          else if((1/to + vctl*kphi) > 2.6 && (1/vcoperiod + 0.1) < 2.6) begin
                vcoperiod       = 1/(1/vcoperiod + 0.1);    //increase 100MHz when higher than above high range
                minus100M       = 1'b0;                     //but should not be higher than 2.6GHz after increase
                plus100M        = 1'b1;
          end
        end
      //else                                        //if period is negative, clear integral
      //        integral        = 0;
    end

    //when fbclk is a lot slower than refclk
    //increase vco freq faster
  //always @(refcnt) begin
  //    if(refcnt==3'b111) begin
  //            vcoperiod       = 1/(1/vcoperiod + 0.1);    //increase 100MHz
  //            plus100M        = 1'b1;
  //    end
  //end

  //always@ (internal_ck or negedge vco_en) begin //or negedge refclk_rdy
    always@ (internal_ck or         vco_en) begin //or negedge refclk_rdy
        if(~vco_en)
            internal_ck     <= 1'b0;
        else
            internal_ck     <= #(vcoperiod/2) ~internal_ck;
    end

    always @* begin
        pll_clk_045_reg     <= #(vcoperiod/8*1)      internal_ck;
        pll_clk_090_reg     <= #(vcoperiod/8*2)      internal_ck;
        pll_clk_135_reg     <= #(vcoperiod/8*3)      internal_ck;
        pll_clk_225_reg     <= #(vcoperiod/8*1)     ~internal_ck;
        pll_clk_270_reg     <= #(vcoperiod/8*2)     ~internal_ck;
        pll_clk_315_reg     <= #(vcoperiod/8*3)     ~internal_ck;
    end

    //20220516, analog design will keep output to 0(not X) when power down
    assign cko_000          =  vco_en ?      internal_ck        :   1'b0;
    assign cko_045          =  vco_en ?      pll_clk_045_reg    :   1'b0;
    assign cko_090          =  vco_en ?      pll_clk_090_reg    :   1'b0;
    assign cko_135          =  vco_en ?      pll_clk_135_reg    :   1'b0;
    assign cko_180          =  vco_en ?     ~internal_ck        :   1'b0;
    assign cko_225          =  vco_en ?      pll_clk_225_reg    :   1'b0;
    assign cko_270          =  vco_en ?      pll_clk_270_reg    :   1'b0;
    assign cko_315          =  vco_en ?      pll_clk_315_reg    :   1'b0;

endmodule

//systemVerilog HDL for "al6100_pll", "gpll_ouput_pi_top" "systemVerilog"

`timescale 1ps/100fs

module gpll_ouput_pi_top ( ckout, pi_out, ck_early, ck_filter, ck_late, ibn_5u,
ibn_100u_poly, ibn_100u_vco, isource_vco_en, mc1_phshift_en, mc1_pi_capsel,
ph, pi_ctrl0, pi_ctrl1, pi_ctrl2, pi_ctrl3, vbg_rdy, vccd, vssa );

  input  [15:0] pi_ctrl0;
  input  [15:0] pi_ctrl1;
  input  [15:0] pi_ctrl2;
  input  [15:0] pi_ctrl3;
  input  [3:0] ph;
  input ck_early;
  input ck_late;

  output ckout;
  output pi_out;

  input ck_filter;
  input  [2:0] mc1_pi_capsel;
  input mc1_phshift_en;

  input vccd;
  input vssa;
  input  [1:0] ibn_5u;
  input ibn_100u_poly;
  input ibn_100u_vco;
  input vbg_rdy;
  input isource_vco_en;

    reg             clkout_reg  = 1'b0;
    reg             ckout       = 1'b0;
    wire            en = mc1_phshift_en & vccd & ~vssa & vbg_rdy;
    real            time1;
    real            period;
    real            phase_step;
    real            delay;
    real            delay_d;
    integer         pi_ctrl0_sum;
    integer         pi_ctrl1_sum;
    integer         pi_ctrl2_sum;
    integer         pi_ctrl3_sum;
    reg   [ 3: 0]   ph_ctrl_sel;
    reg             ck_early_gen;
    reg   [ 3: 0]   ck_early_sel;

    //glitch filtered
    wire  [15: 0]   pi_ctrl0_gf;
    wire  [15: 0]   pi_ctrl1_gf;
    wire  [15: 0]   pi_ctrl2_gf;
    wire  [15: 0]   pi_ctrl3_gf;
    wire  [ 3: 0]   ph_ctrl_sel_shift;
    wire  [ 3: 0]   ph_ctrl_sel_shift_and;
    wire            ph_ctrl_sel_2bit_high;
    wire            ph_or;

    real            delay_pre;
    reg    [ 2: 0]  ph_pre;
   
    always @ (posedge ph[0]) begin
        period      <= $realtime - time1;
        time1       <= $realtime;
    end

    //to filter the toggle for post PR sim
  //assign #30 pi_ctrl0_gf = pi_ctrl0;
  //assign #30 pi_ctrl1_gf = pi_ctrl1;
  //assign #30 pi_ctrl2_gf = pi_ctrl2;
  //assign #30 pi_ctrl3_gf = pi_ctrl3;
  //           
  //assign #60 ph_sel_gf   = ph_sel;    //delay more to make it change after above 4 signals
                                        //so that clk selection and delay can match
  
    always @ * begin
        pi_ctrl0_sum    = pi_ctrl0[ 0]    + pi_ctrl0[ 1]    + pi_ctrl0[ 2]    + pi_ctrl0[ 3]
                        + pi_ctrl0[ 4]    + pi_ctrl0[ 5]    + pi_ctrl0[ 6]    + pi_ctrl0[ 7]
                        + pi_ctrl0[ 8]    + pi_ctrl0[ 9]    + pi_ctrl0[10]    + pi_ctrl0[11]
                        + pi_ctrl0[12]    + pi_ctrl0[13]    + pi_ctrl0[14]    + pi_ctrl0[15];
        ph_ctrl_sel[0]  = (pi_ctrl0_sum>0);

        pi_ctrl1_sum    = pi_ctrl1[ 0]    + pi_ctrl1[ 1]    + pi_ctrl1[ 2]    + pi_ctrl1[ 3]
                        + pi_ctrl1[ 4]    + pi_ctrl1[ 5]    + pi_ctrl1[ 6]    + pi_ctrl1[ 7]
                        + pi_ctrl1[ 8]    + pi_ctrl1[ 9]    + pi_ctrl1[10]    + pi_ctrl1[11]
                        + pi_ctrl1[12]    + pi_ctrl1[13]    + pi_ctrl1[14]    + pi_ctrl1[15];
        ph_ctrl_sel[1]  = (pi_ctrl1_sum>0);

        pi_ctrl2_sum    = pi_ctrl2[ 0]    + pi_ctrl2[ 1]    + pi_ctrl2[ 2]    + pi_ctrl2[ 3]
                        + pi_ctrl2[ 4]    + pi_ctrl2[ 5]    + pi_ctrl2[ 6]    + pi_ctrl2[ 7]
                        + pi_ctrl2[ 8]    + pi_ctrl2[ 9]    + pi_ctrl2[10]    + pi_ctrl2[11]
                        + pi_ctrl2[12]    + pi_ctrl2[13]    + pi_ctrl2[14]    + pi_ctrl2[15];
        ph_ctrl_sel[2]  = (pi_ctrl2_sum>0);

        pi_ctrl3_sum    = pi_ctrl3[ 0]    + pi_ctrl3[ 1]    + pi_ctrl3[ 2]    + pi_ctrl3[ 3]
                        + pi_ctrl3[ 4]    + pi_ctrl3[ 5]    + pi_ctrl3[ 6]    + pi_ctrl3[ 7]
                        + pi_ctrl3[ 8]    + pi_ctrl3[ 9]    + pi_ctrl3[10]    + pi_ctrl3[11]
                        + pi_ctrl3[12]    + pi_ctrl3[13]    + pi_ctrl3[14]    + pi_ctrl3[15];
        ph_ctrl_sel[3]  = (pi_ctrl3_sum>0);
    end

    //rotate right shift
    assign ph_ctrl_sel_shift    = {ph_ctrl_sel[0], ph_ctrl_sel[3:1]};

    //find the only one high bit to calculate delay
    assign ph_ctrl_sel_shift_and= ph_ctrl_sel_shift & ph_ctrl_sel;

    assign ph_ctrl_sel_2bit_high= |(ph_ctrl_sel_shift_and);
  
    always @ * begin
        //initial value may be very big, ignore that
        if(period<10000) begin //10ns
            phase_step  = period / 128;
            delay       = ph_ctrl_sel_2bit_high ?
                                ((16 - ph_ctrl_sel_shift_and[3]*pi_ctrl3_sum - ph_ctrl_sel_shift_and[2]*pi_ctrl2_sum - 
                                       ph_ctrl_sel_shift_and[1]*pi_ctrl1_sum - ph_ctrl_sel_shift_and[0]*pi_ctrl0_sum ) * phase_step)
                        :       0;
        end
    end
  
  //always @ (negedge ck_early) begin
  //    delay_d     <= delay;
  //end

  //always @ (ck_early) begin
  //    clkout_reg  <= # (delay_d) ck_early ;
  //end

    assign ph_or    = ph[3] | ph[2] | ph[1] | ph[0] ;

    always @(negedge ph_or) begin
        ck_early_sel<= #1   ph_ctrl_sel_2bit_high ? ph_ctrl_sel_shift_and : ph_ctrl_sel ;
    end

    always @(ph)
        ck_early_gen<= #1 ck_early_sel == 4'b1000 ? ph[3] :
                          ck_early_sel == 4'b0100 ? ph[2] :
                          ck_early_sel == 4'b0010 ? ph[1] :
                                                    ph[0] ;
  
    always @ (negedge ph_or) begin
        delay_d     <= delay;
    end

    always @(ck_early_gen) begin
        clkout_reg  <= # (delay_d) ck_early_gen ;
    end

    always @ * begin
        ckout       <= en ? clkout_reg : 1'b1 ;
    end

endmodule


//lvt.v
primitive udp_dff (out, in, clk, clr_, set_, NOTIFIER);
   output out;  
   input  in, clk, clr_, set_, NOTIFIER;
   reg    out;

   table

// in  clk  clr_   set_  NOT  : Qt : Qt+1
//
   0  r   ?   1   ?   : ?  :  0  ; // clock in 0
   1  r   1   ?   ?   : ?  :  1  ; // clock in 1
   1  *   1   ?   ?   : 1  :  1  ; // reduce pessimism
   0  *   ?   1   ?   : 0  :  0  ; // reduce pessimism
   ?  f   ?   ?   ?   : ?  :  -  ; // no changes on negedge clk
   *  b   ?   ?   ?   : ?  :  -  ; // no changes when in switches
   ?  ?   ?   0   ?   : ?  :  1  ; // set output
   ?  b   1   *   ?   : 1  :  1  ; // cover all transistions on set_
   1  x   1   *   ?   : 1  :  1  ; // cover all transistions on set_
   ?  ?   0   1   ?   : ?  :  0  ; // reset output
   ?  b   *   1   ?   : 0  :  0  ; // cover all transistions on clr_
   0  x   *   1   ?   : 0  :  0  ; // cover all transistions on clr_
   ?  ?   ?   ?   *   : ?  :  x  ; // any NOTIFIER changed

   endtable
endprimitive // udp_dff

primitive udp_mux2 (out, in0, in1, sel);
   output out;  
   input  in0, in1, sel;

   table

// in0 in1  sel :  out
//
   1  ?   0  :  1 ;
   0  ?   0  :  0 ;
   ?  1   1  :  1 ;
   ?  0   1  :  0 ;
   0  0   x  :  0 ;
   1  1   x  :  1 ;

   endtable
endprimitive // udp_mux2

module BUFV1_140P9T40H ( Z, I); 
input I;
output Z;

 
    buf I0(Z, I); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc I --> Z 
	 (I => Z) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine


`celldefine
module TBUFV8_140P9T40H ( Z, I, OE); 
input I, OE;
output Z;

 
  bufif1 I0(Z, I, OE); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc I --> Z 
	 (I => Z) = (1.0,1.0); 
 
	// arc OE --> Z 
	 (OE => Z) = (1.0,1.0,1.0,1.0,1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

`celldefine
module DRSNQV2_140P9T40H (D, RDN, SDN, CK, Q); 
  input D, RDN, SDN, CK;

  output Q;
  reg NOTIFIER;

wire ENABLE_D_AND_SDN;
wire ENABLE_NOT_D_AND_RDN;

  buf   XX0 (xSN,SDN);
  buf   XX1 (xRN,RDN);
  buf     IC (clk,CK);
  udp_dff I0 (n0,D, clk, xRN, xSN, NOTIFIER);
  buf     I1 (Q, n0);

  assign ENABLE_D_AND_SDN = ( D & SDN )? 1'b1:1'b0;
  assign ENABLE_NOT_D_AND_RDN = ( !D & RDN ) ? 1'b1:1'b0;

  `ifdef functional // functional //

  `else // functional //
    and SMC_I6(ENABLE_RDN_AND_SDN,RDN,SDN);

    buf SMC_I7(ENABLE_SDN,SDN);

    buf SMC_I8(ENABLE_RDN,RDN);


  specify


	// arc CK --> Q
	(posedge CK => (Q : D))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

        $width(negedge CK,1.0,0,NOTIFIER);

        $width(posedge CK,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN_AND_SDN == 1'b1),
            negedge D &&& (ENABLE_RDN_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN_AND_SDN == 1'b1),
            posedge D &&& (ENABLE_RDN_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);



        $setuphold(posedge CK &&& (ENABLE_D_AND_SDN == 1'b1),
            posedge RDN &&& (ENABLE_D_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);


        $width(negedge RDN,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_NOT_D_AND_RDN == 1'b1),
            posedge SDN &&& (ENABLE_NOT_D_AND_RDN == 1'b1), 1.0, 1.0, NOTIFIER);


        $setuphold(posedge RDN, posedge SDN, 1.0, 1.0, NOTIFIER);


        $width(negedge SDN,1.0,0,NOTIFIER);


  endspecify

  `endif // functional //
endmodule
`endcelldefine

`celldefine
module CLKBUFV4_140P9T40H ( Z, I); 
input I;
output Z;

 
    buf SMC_I0(Z, I); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc I --> Z 
	 (I => Z) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

`celldefine
module CLKINV2_140P9T40H ( ZN, I); 
input I;
output ZN;

 
    not SMC_I0 (ZN, I); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 	// arc I --> ZN
	 (I => ZN) = (1.0,1.0);
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

`celldefine
module INV2_140P9T40H ( ZN, I); 
input I;
output ZN;

 
    not I0(ZN, I); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc I --> ZN 
	 (I => ZN) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

`celldefine
module DRSNQV1_140P9T40H (D, RDN, SDN, CK, Q); 
  input D, RDN, SDN, CK;

  output Q;
  reg NOTIFIER;

wire ENABLE_D_AND_SDN;
wire ENABLE_NOT_D_AND_RDN;

  buf   XX0 (xSN,SDN);
  buf   XX1 (xRN,RDN);
  buf     IC (clk,CK);
  udp_dff I0 (n0,D, clk, xRN, xSN, NOTIFIER);
  buf     I1 (Q, n0);

  assign ENABLE_D_AND_SDN = ( D & SDN )? 1'b1:1'b0;
  assign ENABLE_NOT_D_AND_RDN = ( !D & RDN ) ? 1'b1:1'b0;

  `ifdef functional // functional //

  `else // functional //
    and SMC_I6(ENABLE_RDN_AND_SDN,RDN,SDN);

    buf SMC_I7(ENABLE_SDN,SDN);

    buf SMC_I8(ENABLE_RDN,RDN);


  specify


	// arc CK --> Q
	(posedge CK => (Q : D))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

        $width(negedge CK,1.0,0,NOTIFIER);

        $width(posedge CK,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN_AND_SDN == 1'b1),
            negedge D &&& (ENABLE_RDN_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN_AND_SDN == 1'b1),
            posedge D &&& (ENABLE_RDN_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);



        $setuphold(posedge CK &&& (ENABLE_D_AND_SDN == 1'b1),
            posedge RDN &&& (ENABLE_D_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);


        $width(negedge RDN,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_NOT_D_AND_RDN == 1'b1),
            posedge SDN &&& (ENABLE_NOT_D_AND_RDN == 1'b1), 1.0, 1.0, NOTIFIER);


        $setuphold(posedge RDN, posedge SDN, 1.0, 1.0, NOTIFIER);


        $width(negedge SDN,1.0,0,NOTIFIER);


  endspecify

  `endif // functional //
endmodule
`endcelldefine

//hvt.v
`celldefine
module DSNQV4_140P9T40H (D, SDN, CK, Q); 
  input D, SDN, CK;

  output Q;
  reg NOTIFIER;
  supply1 xRN;

wire ENABLE_NOT_D;

  buf   XX0 (xSN,SDN);
  buf     IC (clk,CK);
  udp_dff I0 (n0,D, clk, xRN, xSN, NOTIFIER);
  buf     I1 (Q, n0);

  
  assign ENABLE_NOT_D= (!D) ? 1'b1:1'b0;



  `ifdef functional // functional //

  `else // functional //
    buf SMC_I5(ENABLE_SDN,SDN);


  specify


	// arc CK --> Q
	(posedge CK => (Q : D))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);



        $width(negedge CK,1.0,0,NOTIFIER);

        $width(posedge CK,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_SDN == 1'b1),
            negedge D &&& (ENABLE_SDN == 1'b1), 1.0, 1.0, NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_SDN == 1'b1),
            posedge D &&& (ENABLE_SDN == 1'b1), 1.0, 1.0, NOTIFIER);



        $setuphold(posedge CK &&& (ENABLE_NOT_D == 1'b1), posedge SDN &&& (ENABLE_NOT_D == 1'b1), 1.0, 1.0, NOTIFIER);


        $width(negedge SDN,1.0,0,NOTIFIER);


  endspecify

  `endif // functional //
endmodule
`endcelldefine

`celldefine
module DRNQV4_140P9T40H (D, RDN, CK, Q); 
  input D, RDN, CK;

  output Q;
  reg NOTIFIER;
  supply1 xSN;

wire ENABLE_D;

  buf   XX0 (xRN,RDN);
  buf     IC (clk,CK);
  udp_dff I0 (n0,D, clk, xRN, xSN, NOTIFIER);
  buf     I1 (Q, n0);

  assign ENABLE_D= (D) ? 1'b1:1'b0;



  `ifdef functional // functional //

  `else // functional //
    buf SMC_I5(ENABLE_RDN,RDN);


  specify


	// arc CK --> Q
	(posedge CK => (Q : D))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

        $width(negedge CK,1.0,0,NOTIFIER);

        $width(posedge CK,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN == 1'b1),
            negedge D &&& (ENABLE_RDN == 1'b1), 1.0, 1.0, NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN == 1'b1),
            posedge D &&& (ENABLE_RDN == 1'b1), 1.0, 1.0, NOTIFIER);



        $setuphold(posedge CK &&& (ENABLE_D == 1'b1), posedge RDN &&& (ENABLE_D == 1'b1), 1.0, 1.0, NOTIFIER);


        $width(negedge RDN,1.0,0,NOTIFIER);


  endspecify

  `endif // functional //
endmodule
`endcelldefine

//====================== hvt.v ==================================//
`celldefine
module DSNQV2_140P9T40H (D, SDN, CK, Q); 
  input D, SDN, CK;

  output Q;
  reg NOTIFIER;
  supply1 xRN;

wire ENABLE_NOT_D;

  buf   XX0 (xSN,SDN);
  buf     IC (clk,CK);
  udp_dff I0 (n0,D, clk, xRN, xSN, NOTIFIER);
  buf     I1 (Q, n0);

  
  assign ENABLE_NOT_D= (!D) ? 1'b1:1'b0;



  `ifdef functional // functional //

  `else // functional //
    buf SMC_I5(ENABLE_SDN,SDN);


  specify


	// arc CK --> Q
	(posedge CK => (Q : D))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);



        $width(negedge CK,1.0,0,NOTIFIER);

        $width(posedge CK,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_SDN == 1'b1),
            negedge D &&& (ENABLE_SDN == 1'b1), 1.0, 1.0, NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_SDN == 1'b1),
            posedge D &&& (ENABLE_SDN == 1'b1), 1.0, 1.0, NOTIFIER);



        $setuphold(posedge CK &&& (ENABLE_NOT_D == 1'b1), posedge SDN &&& (ENABLE_NOT_D == 1'b1), 1.0, 1.0, NOTIFIER);


        $width(negedge SDN,1.0,0,NOTIFIER);


  endspecify

  `endif // functional //
endmodule
`endcelldefine

`celldefine
module AND2V8_140P9T40H ( Z, A1, A2); 
input A1, A2;
output Z;

 
    and SMC_I0(Z, A1, A2); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc A1 --> Z 
	 (A1 => Z) = (1.0,1.0); 
 
	// arc A2 --> Z 
	 (A2 => Z) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

`celldefine
module DRNQV2_140P9T40H (D, RDN, CK, Q); 
  input D, RDN, CK;

  output Q;
  reg NOTIFIER;
  supply1 xSN;

wire ENABLE_D;

  buf   XX0 (xRN,RDN);
  buf     IC (clk,CK);
  udp_dff I0 (n0,D, clk, xRN, xSN, NOTIFIER);
  buf     I1 (Q, n0);

  assign ENABLE_D= (D) ? 1'b1:1'b0;



  `ifdef functional // functional //

  `else // functional //
    buf SMC_I5(ENABLE_RDN,RDN);


  specify


	// arc CK --> Q
	(posedge CK => (Q : D))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

        $width(negedge CK,1.0,0,NOTIFIER);

        $width(posedge CK,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN == 1'b1),
            negedge D &&& (ENABLE_RDN == 1'b1), 1.0, 1.0, NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN == 1'b1),
            posedge D &&& (ENABLE_RDN == 1'b1), 1.0, 1.0, NOTIFIER);



        $setuphold(posedge CK &&& (ENABLE_D == 1'b1), posedge RDN &&& (ENABLE_D == 1'b1), 1.0, 1.0, NOTIFIER);


        $width(negedge RDN,1.0,0,NOTIFIER);


  endspecify

  `endif // functional //
endmodule
`endcelldefine


//====================== rvt.v ==================================//
module CLKINV4_140P9T40R ( ZN, I); 
input I;
output ZN;

 
    not SMC_I0 (ZN, I); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 	// arc I --> ZN
	 (I => ZN) = (1.0,1.0);
 
 
  endspecify 
  `endif // functional // 
endmodule
`endcelldefine

`celldefine
module CLKNAND2V2_140P9T40R ( ZN, A1, A2); 
input A1, A2;
output ZN;

 
    nand SMC_I0 (ZN, A1, A2); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc A1 --> ZN 
	 (A1 => ZN) = (1.0,1.0); 
 
	// arc A2 --> ZN 
	 (A2 => ZN) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

`celldefine
module CLKAND2V2_140P9T40R ( Z, A1, A2); 
input A1, A2;
output Z;

 
    and SMC_I0(Z, A1, A2); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc A1 --> Z 
	 (A1 => Z) = (1.0,1.0); 
 
	// arc A2 --> Z 
	 (A2 => Z) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

`celldefine
module DRSNQV2_140P9T40R (D, RDN, SDN, CK, Q); 
  input D, RDN, SDN, CK;

  output Q;
  reg NOTIFIER;

wire ENABLE_D_AND_SDN;
wire ENABLE_NOT_D_AND_RDN;

  buf   XX0 (xSN,SDN);
  buf   XX1 (xRN,RDN);
  buf     IC (clk,CK);
  udp_dff I0 (n0,D, clk, xRN, xSN, NOTIFIER);
  buf     I1 (Q, n0);

  assign ENABLE_D_AND_SDN = ( D & SDN )? 1'b1:1'b0;
  assign ENABLE_NOT_D_AND_RDN = ( !D & RDN ) ? 1'b1:1'b0;

  `ifdef functional // functional //

  `else // functional //
    and SMC_I6(ENABLE_RDN_AND_SDN,RDN,SDN);

    buf SMC_I7(ENABLE_SDN,SDN);

    buf SMC_I8(ENABLE_RDN,RDN);


  specify


	// arc CK --> Q
	(posedge CK => (Q : D))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1)
	// arc RDN --> Q
	(negedge RDN => (Q : 1'b0))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1 && RDN==1'b0)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b0 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b0 && D==1'b1 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b0 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

	if(CK==1'b1 && D==1'b1 && RDN==1'b1)
	// arc SDN --> Q
	(negedge SDN => (Q : 1'b1))  = (1.0,1.0);

        $width(negedge CK,1.0,0,NOTIFIER);

        $width(posedge CK,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN_AND_SDN == 1'b1),
            negedge D &&& (ENABLE_RDN_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_RDN_AND_SDN == 1'b1),
            posedge D &&& (ENABLE_RDN_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);



        $setuphold(posedge CK &&& (ENABLE_D_AND_SDN == 1'b1),
            posedge RDN &&& (ENABLE_D_AND_SDN == 1'b1), 1.0, 1.0, NOTIFIER);


        $width(negedge RDN,1.0,0,NOTIFIER);

        $setuphold(posedge CK &&& (ENABLE_NOT_D_AND_RDN == 1'b1),
            posedge SDN &&& (ENABLE_NOT_D_AND_RDN == 1'b1), 1.0, 1.0, NOTIFIER);


        $setuphold(posedge RDN, posedge SDN, 1.0, 1.0, NOTIFIER);


        $width(negedge SDN,1.0,0,NOTIFIER);


  endspecify

  `endif // functional //
endmodule
`endcelldefine

`celldefine
module CLKINV3_140P9T40R ( ZN, I); 
input I;
output ZN;

 
    not SMC_I0 (ZN, I); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 	// arc I --> ZN
	 (I => ZN) = (1.0,1.0);
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

module INV3_140P9T40R ( ZN, I); 
input I;
output ZN;

 
    not I0(ZN, I); 
 
 
  `ifdef functional // functional // 
 
  `else // functional // 
 
  specify 
 
 
	// arc I --> ZN 
	 (I => ZN) = (1.0,1.0); 
 
 
  endspecify 
 
  `endif // functional // 
endmodule
`endcelldefine

`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "Anlogic"
`pragma protect encrypt_agent_info = "Anlogic Encryption Tool anlogic_2019"
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
su4MlKU8+402CR6LDS9cxwTZKAbsI23atz+mD9jtwCUG7eacE+xXQkUYzN0yJjpg
FFAj5jbDdCzvJvxmkkIGXG8s1C/fENg6HHyaaITD11bUqngugvF+okTDH7FAqFB5
YcKHb8Vlz1iGqKMJ3RZGyeFvWPNf6wusp0y+o8Zh3j4=
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
f52n19Q4urMvPA1qKx/AvVPCfJ0yZuzrsm98WHnkcOQlG/glV16QDR7S37iyPxbK
qJ6Mq4qZS8TFMon9XwQ5mamrKQ2wYYqeX1G9oi3C8D/wETXUNLVWLbJGs57SByCP
eMsvjeZ4BAgumHa+5qZA/ByP+5ynklqMFAOXYRoArX4=
`pragma protect key_keyowner = "Cadence Design Systems.", key_keyname = "CDS_RSA_KEY_VER_1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
pTJ+eXstmGdQcwTO/QGESBpnJ7eRVHKjZvnAOtjDi/AC7c0RzAGnWaRBPSm/UqND
2TpgsuvccOorAUHyIhor3qkv8jtWIr3y9W36nRj4JEO9ijXdvhJXpOQ0+vgo/Tbg
rr3+x9jIzDf4T7CUSpuIqsQW1Fdg7vweZ12PaKHSTU/JTvbSca8jO7tOPwV5KUg3
cutVLwqPAK7sCeAf72D1+eBArtDqZgGSht+D7UxxYrv8RmXUsCGbpO/j8F48U++U
rXTNWYNTJMq0w1/VpcESphLsb8b2TqhkoomVtTmG7YcunwKJpsKaKTl6l48EQvHD
J4DLqYP+wYbFrcnEyEewZg==
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
ZvfzAf7PRkuRm6nsiXQV6BdDpJobl4DYrcQzc86UOyrt/gUme+6RKKiIUiggiGnx
YRvC9KUC4xQI12YYNCPT1rMkcbc3QFfoSbLaVElJDxrf9FahbvTuy/efU/5aIEsa
RBKnW012FMo3+OlUcoKdNOD5K11yix0Y1iIuP0s+xF8=
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
Mq9t6Xrtikv4COKcSVZ3ZshBLHqoVAYuf0jbOug5+ExESnVQkpWhHqHpk9+wI2rg
3/9ZTT8FD4KJVL0+RRUB1UxCVUsCOqDa2+zg1V4Hk0m2ZEBH8Kw4rIT+Y3kBaDWz
wQ5YekxLURcV34ut6OmK7AT5k7UHM2gwt0NSqphPsF0gkGGM1AY8BdLS0T7r/L8j
vnB4ld5WCHGFeLa98WfUte5AiT0TK7XYVf6Dm3HRBziFq9H3oasVOyXvPXvw9BN5
MO37YZq2r2EzGnULbpbUJV9jmpFdgFxNajhKOs5fXSn/Ku/6KbpR6Ty+UKH4ZSUV
9w+dZZBBSQABuSqj0RoDcw==
`pragma protect key_keyowner = "Univista", key_keyname = "UV-ENC-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
d2lnGYQDieLPRG+78shxbu3QjfNQDUwoe8TYcHXlDthRQgqRCTTGtfNi0HPFs/zh
iaCLIbHbkdc5jWR2W0IXvxJ/OqLBK765y+MvasdyxnAAjn9u4e6SvBpRvjnbUwZT
byEhK5VtRAygzKFgg10UP9kWEmgf3gY3uB3LsilDqkg1xW1LpMCZBW80SNkwpDGy
hTHkLC9pt1MR/BNZiEKy6X0p0nuDQXdBZW8GBg5Mx8SH7nQia/n/2czlE31680lJ
opneOj5gWawQHxg4GEd6YMiqYoPKwWTXH79KFfVFuge8OSevh1nylBWqUMnP89Hs
uDqv1GxFTlUVmR5hQ0ddKw==
`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 48)
`pragma protect data_block
x8CRoYDY1tGjhtOIgQ9QdhJG7AyClCYRNVYsYgZuuXzlxwgg9X7WDtYnFu8Fp13u
`pragma protect end_protected

