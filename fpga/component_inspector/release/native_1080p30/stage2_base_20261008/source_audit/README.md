# SC500CS 1080p source and clock choices

`cfg_cs500.c` is copied unchanged from the user-provided archive. `source.json`
records the original archive and entry hashes. `audit.json` records the ordered
116-entry vendor / 121-entry RTL comparison. Only output size registers change;
read window, RAW10/two-lane overrides, sampling, exposure2244 half-lines, gain48
and initialization order remain at the baseline settings. The obsolete OV5640
header in the supplied C file is not device identification or an instruction.

The data sheet FHD30 table specifies 1x1 crop. Classification remains uncalibrated.
This video profile is not a recipe for polarity inspection at 130 mm.

The main camera/system PLL is byte-for-byte unchanged. The independent HDMI
module uses two integer PLLs: 50/5*108/32=33.75 MHz, then 33.75*33/15=74.25 MHz
and 33.75*33/3=371.25 MHz. Both VCOs lie within the vendor 800–1600 MHz range.
This uses 5/6 PLLs including the existing DDR pair. The fractional trial was
rejected because calculator, STA and model frequencies disagreed; failure logs
remain in the diagnostic candidate. Analog model frequency measurements disable
only vendor internal specify checks; routed setup/hold STA remains separate.

DDR retains the physical50 MHz reference. Vendor `update_pll` selected PLL0
N2/M32/VCO800 MHz, DDR /3=266.667 MHz, controller/reference /12=66.667 MHz and
configuration /16=50 MHz. PLL1 uses66.667 MHz, N2, output divider24 with its
fixed feedback topology. tCK3750 ps, DDR2-533C, CL4/CWL3 and2080-cycle refresh
(7.8 us) are aligned in RTL, define, Design.xml and IP parameter metadata.
PHY initialization/calibration has not been measured on the board.

At128 bits per MC word the address step is8 **16-bit address units**. FHD occupies
3,110,400 MC units /6,220,800 bytes per slot. All four original slot bases remain
within the 25-bit MC space and do not overlap. Read+write payload is373.248 MB/s;
the1066.667 MB/s theoretical DDR payload ceiling is not proof of usable bandwidth.
The ordered MC test includes arbitration, periodic service gaps and pause/recovery;
physical DDR read/write and stress remain mandatory.
