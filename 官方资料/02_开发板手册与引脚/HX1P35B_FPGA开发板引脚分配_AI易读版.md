# HX1P35B FPGA开发板引脚分配（AI易读格式）

## 文档用途

本文档整理HX1P35B开发板硬件资源、FPGA引脚映射信息，方便AI模型进行检索、问答和代码辅助。

## 原始资料整理内容

HX1P35B开发板引脚分配汇总

HX1P35B开发板引脚分配汇总

一、核心FPGA芯片

二、4组独立LED发光管

三、40芯GPIO扩展口J2

四、40芯GPIO扩展口J1

五、HDMI接口A

六、USB-JTAG接口

七、USB转UART接口

八、数码管与8组双色LED（引脚复用）

九、SPI FLASH（N25Q128）

十、SPI FLASH（GD25WQ128ESIGR）

十一、蜂鸣器

十二、乒乓开关

十三、4组按键

十四、TF卡槽（SD模式）

十五、以太网接口

十六、MIPI_CSI摄像头接口

十七、50M时钟源

## 表格 1

信号名称 \| FPGA引脚 \| 备注

核心芯片型号 \| PH1P35MDG324 \| 国产安路PH1

## 表格 2

信号名称 \| FPGA引脚 \| 信号名称 \| FPGA引脚

LED1 \| D10 \| LED2 \| E10

LED3 \| C6 \| LED4 \| D6

## 表格 3

脚位号与信号名 \| FPGA引脚 \| 脚位号与信号名 \| FPGA引脚

1(GPIOB_0) \| C18 \| 2(GPIOB_1) \| D15

3(GPIOB_2) \| E12 \| 4(GPIOB_3) \| E16

5(GPIOB_4) \| E17 \| 6(GPIOB_5) \| F13

7(GPIOB_6) \| F14 \| 8(GPIOB_7) \| F18

9(GPIOB_8) \| G17 \| 10(GPIOB_9) \| H17

11 \| VCC5V \| 12 \| GND

13(GPIOB_10) \| H18 \| 14(GPIOB_11) \| J13

15(GPIOB_12) \| J14 \| 16(GPIOB_13) \| J15

17(GPIOB_14) \| J16 \| 18(GPIOB_15) \| J18

19(GPIOB_16) \| D9 \| 20(GPIOB_17) \| K17

21(GPIOB_18) \| K16 \| 22(GPIOB_19) \| K15

23(GPIOB_20) \| K13 \| 24(GPIOB_21) \| L15

25(GPIOB_22) \| L16 \| 26(GPIOB_23) \| P10

27(GPIOB_24) \| P9 \| 28(GPIOB_25) \| P8

29 \| 3.3V \| 30 \| GND

31(GPIOB_26) \| R7 \| 32(GPIOB_27) \| R6

33(GPIOB_28) \| T5 \| 34(GPIOB_29) \| U7

35(GPIOB_30) \| U6 \| 36(GPIOB_31) \| U5

37(GPIOB_32) \| U4 \| 38(GPIOB_33) \| V7

39(GPIOB_34) \| V6 \| 40(GPIOB_35) \| V4

## 表格 4

脚位号与信号名 \| FPGA引脚 \| 脚位号与信号名 \| FPGA引脚

1(GPIOA_0) \| V2 \| 2(GPIOA_1) \| V1

3(GPIOA_2) \| U2 \| 4(GPIOA_3) \| U1

5(GPIOA_4) \| T4 \| 6(GPIOA_5) \| T3

7(GPIOA_6) \| T2 \| 8(GPIOA_7) \| R5

9(GPIOA_8) \| R3 \| 10(GPIOA_9) \| R2

11 \| VCC5V \| 12 \| GND

13(GPIOA_10) \| R1 \| 14(GPIOA_11) \| P6

15(GPIOA_12) \| P5 \| 16(GPIOA_13) \| P4

17(GPIOA_14) \| P3 \| 18(GPIOA_15) \| P1

19(GPIOA_16) \| N7 \| 20(GPIOA_17) \| N4

21(GPIOA_18) \| N3 \| 22(GPIOA_19) \| N2

23(GPIOA_20) \| N1 \| 24(GPIOA_21) \| M5

25(GPIOA_22) \| M4 \| 26(GPIOA_23) \| M2

27(GPIOA_24) \| M1 \| 28(GPIOA_25) \| L4

29 \| 3.3V \| 30 \| GND

31(GPIOA_26) \| K2 \| 32(GPIOA_27) \| K1

33(GPIOA_28) \| H2 \| 34(GPIOA_29) \| D4

35(GPIOA_30) \| C8 \| 36(GPIOA_31) \| B5

37(GPIOA_32) \| A5 \| 38(GPIOA_33) \| B14

39(GPIOA_34) \| B10 \| 40(GPIOA_35) \| A10

## 表格 5

信号名称 \| FPGA引脚 \| 信号名称 \| FPGA引脚

HDMIA_D2_P \| H14 \| HDMIA_D0_P \| G16

HDMIA_D2_N \| H13 \| HDMIA_D0_N \| H16

HDMIA_D1_P \| F17 \| HDMIA_SCL \| E15

HDMIA_D1_N \| E18 \| HDMIA_SDA \| F15

HDMIA_HPD \| B17 \| HDMIA_CLK_N \| D18

-   | - \| HDMIA_CLK_P \| C17

## 表格 6

信号名称 \| FPGA引脚 \| 信号名称 \| FPGA引脚

FPGA_TCK \| P15 \| FPGA_TDI \| R13

FPGA_TMS \| L14 \| FPGA_TDO \| T13

## 表格 7

引脚名称 \| FPGA引脚

RXD \| J1

TXD \| H1

## 表格 8

双色LED引脚名称 \| 数码管引脚名称 \| FPGA引脚

LED6红 \| DIG0（a段） \| C9

LED6绿 \| SEL0(左起第1个数码管) \| G15

LED7红 \| DIG1（b段） \| C11

LED7绿 \| SEL1(左起第2个数码管) \| G14

LED8红 \| DIG2（c段） \| B11

LED8绿 \| SEL2(左起第3个数码管) \| A17

LED9红 \| DIG3（d段） \| E7

LED9绿 \| SEL3(左起第4个数码管) \| A18

LED10红 \| DIG4（e段） \| E6

LED10绿 \| SEL4(左起第5个数码管) \| B16

LED11红 \| DIG5（f段） \| B6

LED11绿 \| SEL5(左起第6个数码管) \| A15

LED12红 \| DIG6（g段） \| B7

LED12绿 \| SEL6(左起第7个数码管) \| B15

LED13红 \| DIG7（h段/DP） \| E5

LED13绿 \| SEL7(左起第8个数码管) \| A14

## 表格 9

N25Q128引脚名称 \| FPGA引脚 \| N25Q128引脚名称 \| FPGA引脚

QSPI_CS \| D14 \| QSPI_HOLD(D3) \| A13

QSPI_SDO(D1) \| D16 \| QSPI_SCLK \| N6

QSPI_WP(D2) \| C16 \| QSPI_SDI \| E13

## 表格 10

信号名称 \| FPGA引脚 \| 信号名称 \| FPGA引脚

FLASH_CSN \| R8 \| FLASH_DQ3 \| U11

FLASH_DQ1(DIN) \| U12 \| FLASH_DQ0(MOSI) \| V12

FLASH_DQ2 \| V11 \| FLASH_GCLK \| R15

## 表格 11

引脚名称 \| FPGA引脚

BUZZER \| C12

## 表格 12

开关引脚信号 \| FPGA引脚 \| 开关引脚信号 \| FPGA引脚

SW1 \| A4 \| SW2 \| B4

SW3 \| E11 \| SW4 \| D11

备注 \| SW5为蜂鸣器开关，SW6为数码管/双色LED选择开关 \| \|

## 表格 13

信号名称 \| FPGA引脚 \| 信号名称 \| FPGA引脚

KEY1 \| D5 \| KEY2 \| A9

KEY3 \| B9 \| KEY4 \| C7

## 表格 14

TF信号名称 \| FPGA引脚 \| TF信号名称 \| FPGA引脚

SD_DAT3（CS） \| B12 \| SD_DAT2 \| A12

SD_DAT1 \| D8 \| SD_DAT0(MISO) \| E8

SD_CLK \| A7 \| SD_CMD(MOSI) \| A8

## 表格 15

信号名称 \| FPGA引脚 \| 信号名称 \| FPGA引脚

MDC0 \| V9 \| MDIO0 \| U10

RESET_N \| V8 \| TXCLK \| U9

RXD0 \| N9 \| TXD0 \| R11

RXD1 \| T7 \| TXD1 \| P11

RXD2 \| T8 \| TXD2 \| T10

RXD3 \| T9 \| TXD3 \| R12

TXEN \| R10 \| RXC_DV \| N8

## 表格 16

信号名称 \| FPGA引脚 \| 信号名称 \| FPGA引脚

MIPI_CSI_D0_P \| V14 \| MIPI_CSI_D0_N \| U14

MIPI_CSI_D1_P \| V15 \| MIPI_CSI_D1_N \| U15

MIPI_CSI_D2_P \| V17 \| MIPI_CSI_D2_N \| U17

MIPI_CSI_D3_P \| U18 \| MIPI_CSI_D3_N \| V18

MIPI_CSI_I2C_FSCL \| K3 \| MIPI_CSI_I2C_FSDA \| J3

MIPI_CSI_FCLK \| L3 \| MIPI_CSI_FPWDNB \| L2

MIPI_CSI_CK_P \| V16 \| MIPI_CSI_CK_N \| U16

## 表格 17

时钟信号 \| FPGA引脚

CLK \| C4

## AI检索关键词

-   HX1P35B
-   PH1P35MDG324
-   FPGA引脚分配
-   GPIO
-   LED
-   HDMI
-   UART
-   SPI FLASH
-   蜂鸣器
-   按键
-   TF卡
-   Ethernet
-   MIPI CSI
-   50MHz时钟
