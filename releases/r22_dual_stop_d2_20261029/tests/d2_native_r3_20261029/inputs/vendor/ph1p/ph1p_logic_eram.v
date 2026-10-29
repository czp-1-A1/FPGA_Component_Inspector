//------------------------------------------------------------------------------
//  Copyright (c) 2011-2025 Anlogic, Inc.
//  All Right Reserved.
//------------------------------------------------------------------------------

////////////////////////////////////////////////////////////////////////////////
//
//  Vendor      : Anlogic
//  Version     : 0.21
//  Description : Anlogic Functional Simulation Model for < Logic/Physical > IP
//                PH1P_LOGIC_ERAM
//  Filename    : ph1p_logic_eram.v
//
////////////////////////////////////////////////////////////////////////////////
//
//  Revision    :
//    2026-06-21 - 0.21- GS.JI - fix jira:AL90-2841.
//    2026-03-03 - 0.20- GS.JI - Add BYTE_A/BYTE_B parameter checking.
//    2025-01-06 - 0.19- GS.JI - Add CLKMODE behaviour.
//    2024-12-25 - 0.18- GS.JI - Fix eram rst behaviour.
//    2024-10-12 - 0.17- GS.JI - Change generate block to always block.
//    2024-09-02 - 0.16- GS.JI - Fix rav-9302 error.
//    2024-07-16 - 0.15- GS.JI - Fix mem_do* use deassign.
//    2024-07-05 - 0.14- GS.JI - Fix eram doa* behaviour.
//    2024-03-26 - 0.13- GS.JI - Fix init_memory 'b0 to 'bx.
//    2024-01-26 - 0.12- GS.JI - Fix do* output in async mode behaviour same with phy_eram.
//    2024-01-10 - 0.11- GS.JI - Fix rstb trigger edge.
//    2022-10-26 - 0.1 - GS.JI - Initial version.
//
///////////////////////////////////////////////////////////////////////////////

//*****************************************************************************
//  
//  Detailed   :
//  hardware   input/output is dia,dia_extra;doa,doa_extra; dib*
//  logic      input/output is only dia;doa dib*/dob* 
//             ce(logic) == cs(phy) 
//             be(logic), hardware on addra[1:0]/addrb[1:0]
//*****************************************************************************

`timescale 1 ps / 1 ps

module PH1P_LOGIC_ERAM (
  dia,
  addra, cea, ocea, clka, wea, rsta, bea,
  dib,
  addrb, ceb, oceb, clkb, web, rstb, beb,
  ecc_sbiterrinj, ecc_dbiterrinj,
  doa,
  dob,
  ecc_sbiterr,
  ecc_dbiterr
  );
  // 1kx9
  parameter DATA_WIDTH_A = 20;                                              //  [Template:Data width of port A.   ]
  parameter DATA_WIDTH_B = DATA_WIDTH_A;                                    //  [Template:Data width of port B.   ]
  parameter ADDR_WIDTH_A = 10;                                              //  [Template:Address width of port A.]
  parameter ADDR_WIDTH_B = ADDR_WIDTH_A;                                    //  [Template:Address width of port B.]
  parameter DATA_DEPTH_A = 2 ** ADDR_WIDTH_A;                               //  [Template:Data depth of port A.   ]
  parameter DATA_DEPTH_B = 2 ** ADDR_WIDTH_B;                               //  [Template:Data depth of port B.   ]
  parameter BYTE_ENABLE = 0;                                                //  [Template:Byte enable.]
  parameter BYTE_A = BYTE_ENABLE == 0 ? 1 : DATA_WIDTH_A / BYTE_ENABLE;     // 
  parameter BYTE_B = BYTE_ENABLE == 0 ? 1 : DATA_WIDTH_B / BYTE_ENABLE;     // 
  output  ecc_sbiterr;                                                      //                                      [Template:ECC single-bit error flag signal.]
  output  ecc_dbiterr;                                                      //                                      [Template:ECC double-bit error flag signal.]
  output  [DATA_WIDTH_A-1:0] doa;                                           //                                      [Template:Port A reads data.]
  output  [DATA_WIDTH_B-1:0] dob;                                           //                                      [Template:Port B reads data.]
  input   [DATA_WIDTH_A-1:0] dia;                                           // DEFAULT := (others => '0')           [Template:Port A writes data.]
  input   [DATA_WIDTH_B-1:0] dib;                                           // DEFAULT := (others => '0')           [Template:Port B writes data.]
  input   ecc_sbiterrinj, ecc_dbiterrinj;                                   // DEFAULT := '0'
  input   cea;                                                              // DEFAULT := '0'                       [Template:Port A select enable.]
  input   ocea;                                                             // DEFAULT := '0'                       [Template:Output port A select enable.]
  input   clka;                                                             // DEFAULT := '0'                       [Template:Clock A signal.]
  input   wea;                                                              // DEFAULT := '0'                       [Template:Port A write enable signal.]
  input   rsta;                                                             // DEFAULT := '0'                       [Template:Port A reset signal.]
  input   ceb;                                                              // DEFAULT := '0'                       [Template:Port B select enable.]
  input   oceb;                                                             // DEFAULT := '0'                       [Template:Output port B select enable.]
  input   clkb;                                                             // DEFAULT := '0'                       [Template:Clock B signal.]
  input   web;                                                              // DEFAULT := '0'                       [Template:Port B write enable signal.]
  input   rstb;                                                             // DEFAULT := '0'                       [Template:Port B reset signal.]
  input [BYTE_A - 1 : 0] bea;                                               // DEFAULT := (others => '0')           [Template:A Port byte enable, highly effective.]
  input [BYTE_B - 1 : 0] beb;                                               // DEFAULT := (others => '0')           [Template:B Port byte enable, highly effective.]
  input   [ADDR_WIDTH_A-1:0] addra;                                         // DEFAULT := (others => '0')           [Template:Port A writes the address.]
  input   [ADDR_WIDTH_B-1:0] addrb;                                         // DEFAULT := (others => '0')           [Template:Port B writes the address.]
  parameter MODE = "DP";                     //  "DP", "SP", "PDPW", "FIFO".                    [Template:ERAM mode setting.             ]
  parameter REGMODE_A = "NOREG";             //  "NOREG", "OUTREG".                             [Template:Output register mode of port A.]
  parameter REGMODE_B = "NOREG";             //  "NOREG", "OUTREG".                             [Template:Output register mode of port B.]
  parameter WRITEMODE_A = "NORMAL";          //  "NORMAL", "READBEFOREWRITE", "WRITETHROUGH".   [Template:Write data mode of port A.     ]
  parameter WRITEMODE_B = "NORMAL";          //  "NORMAL", "READBEFOREWRITE", "WRITETHROUGH".   [Template:Write data mode of port B.     ]
  parameter RESETMODE_A = "ASYNC";           //  "SYNC", "ASYNC".                               [Template:Reset mode of port A.  ]
  parameter RESETMODE_B = "ASYNC";           //  "SYNC", "ASYNC".                               [Template:Reset mode of port A.  ]
  parameter OREGSET_A = "SET";               //  "SET", "RESET".                                [Template:A Port is set or reset.]
  parameter OREGSET_B = "SET";               //  "SET", "RESET".                                [Template:B Port is set or reset.]
  parameter SSROVERCE = "ENABLE";            //  "DISABLE", "ENABLE".                           [Template:Synchronous reset has a higher priority than CE enable.]
  parameter ECC_DECODE = "DISABLE";          //  "DISABLE", "ENABLE".                           [Template:ECC decode was enabled.]
  parameter ECC_ENCODE = "DISABLE";          //  "DISABLE", "ENABLE".                           [Template:ECC encode was enabled.]
  parameter ASYNC_RESET_RELEASE_A = "SYNC";  //  "SYNC", "ASYNC".                               [Template:A Port reset mode.     ]
  parameter ASYNC_RESET_RELEASE_B = "SYNC";  //  "SYNC", "ASYNC".                               [Template:B Port reset mode.     ]
  parameter CLKMODE = "ASYNC";               //  "ASYNC", "SYNC".                               [Template:Clock mode.            ]
  parameter DEBUGGABLE = "NO";               //  "YES", "NO".                                   [Template:Debug enable, only in SP mode.]
  parameter PACKABLE = "NO";                 //  "YES", "NO".                                   [Template:Pack enable. ]
  parameter FORCE_KEEP = "OFF";              //  "ON", "OFF".                                   [Template:Mandatory compilation retention enable.]
  parameter INIT_FILE = "NONE";              //                                                 [Template:Initial value file(.dat or .dath).  ]
  parameter FILL_ALL = "NONE";               //                                                 [Template:"NONE" or some binary string like "0101", not wider than the wider port.]
  parameter IMPLEMENT = "20K";               //  "20K", "20K(FAST)".                            [Template:Implementation model.]

`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "Anlogic"
`pragma protect encrypt_agent_info = "Anlogic Encryption Tool anlogic_2019"
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
v80WghpEkEoFbyT5uma34zUtYWziJ77P5AM1Azh6jhnehA+L/8iS5cujcIE3hGTI
vqDrd3Sm6cZtNGAcsu6SLGDU2AKtMQjJliw0KCIPxf0K/sbhVifR2t2u5o/pX0jq
9wUZ3511yyqB66edzOk5VOL5AlBTc7cfX7dg3S9kiRw=
`pragma protect key_keyowner = "Synopsys", key_keyname = "SNPS-VCS-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
MwNeF39De+ASjeEXmlM1IEf9ZGX9txwdmvP9DvGD6H3aLsIUK2zE/909tKpnM47s
Umpo1GfrqlF7boBEQiWfYxaGVMnofGyA9WyTcpR1n2I2beEvKejESvjadw/NQgqJ
8iD2f0H37ZRSu6i4GqU6AHZlqVV/pvoX7+3O8UXUO6M=
`pragma protect key_keyowner = "Cadence Design Systems.", key_keyname = "CDS_RSA_KEY_VER_1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
aOL5IsBaQHyEFubab2ZS1d9LFPGDa+FT3O+vOBHXUe24spmndAVR89eKX3GrPo0a
R+5QVxD5ZKzEiupqcEbn/uh7C7ALGIyjcKZ1OEuyZ/2fEFpjO1/hw3RDC6DmJ6BR
eMPcTlVA92X0RPyLtO3lN/8FdJLy2DPyksYKs72VWQk+D/3ICjnWmoqnqiM9VdJ3
zW+NIu1fXHZQaeczpUNNVwSyK2vVHc1MVcfjUK3igO3HFDxCoy8fQJJ2NYHPEI1I
I9f6ribIMRvS16UMAwhlWSHjz9dIZNYy4whqzg/+W6uKwSLA3M5d7hJBoLB5Rfes
/1CTrUWJVnbmZp+IMIyuOg==
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 128)
`pragma protect key_block
VoVU7HxfQeTfe/QRR5LBioZq3JwkHGFU0XnEoyqgj43cMJmrKopGTA0M0Y7zsA21
nrVQzdJHGY8HAPDFnICwbUj8Mo/10TjIP0Jv2MUGMCCJh8acPeCAhXlsAl4sRlAs
O6KSwFm6FWV7SvluuzUrkp+tOhGlz3d+nLVc3JqdR0s=
`pragma protect key_keyowner = "Mentor Graphics Corporation", key_keyname = "MGC-VERIF-SIM-RSA-2"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
g8F8iNZHjFC4h8Mi+S953Qf3+/FSuRHuSY1FFcmcs3kpcTaFqVdMOaZyOfb9CxeO
KXcTtAH1L8UTJmVLR+Z+d5mRGtTGxSSBVFMTMtszB0Avccc8blD2sRWxC6W1BwRh
Rul/OFDUpfSv5p/NV9GzcMIm2nubl811j4MaJvL7SyPVlSYAzAj3M2eWf9D5YnGU
CFgHRRBz4CX0VOrNZVaLrV3hVe59BEnAK9/WXtLeYKZIeYHlHYCGSCqcoGDanbUG
1sb68L1mlE8wV108P6N8TAhzMDaVt9uhEnCUjD1cdyUQAngR9nVzezsE+c4NOB5w
oP+PB68QmsuAmQle2pW/AA==
`pragma protect key_keyowner = "Univista", key_keyname = "UV-ENC-RSA-1"
`pragma protect key_method = "rsa"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 256)
`pragma protect key_block
e6TgyMbDYMeeiGh2wFXGbFDMT5JtRUqid6BwjiGHOuxUH7SAnD0Lsx+xiNkOai+C
wJ5/SPklGjuDool/j2oBMIuqoIkMjOlps0DnKSdOXbyBCKWmB8e38UxoMdzbFKMc
K/3l9WqM4toMiODDbM8EF5yIn/7lcMaQ89CXR3eNOkTO/H0PeE5hrI/VAqvIKRrh
zZV1kn6mqQkr7Rbr/2JH02xdM4JZaAqeOU32zUh1GUR8h2eiZjbb+xMaG8P5qBtD
+wcZHX92QDZahBm6kZ/F++AFCSDHbhQ0+D/6PdKoDS8RioMPyAuTpoDbqB9m63+Z
EPotX1Xp0OhXS/uhELVAdg==
`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 64, bytes = 23552)
`pragma protect data_block
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
`pragma protect end_protected     
endmodule  
