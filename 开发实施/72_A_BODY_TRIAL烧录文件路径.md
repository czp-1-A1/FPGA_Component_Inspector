# BODY TRIAL烧录文件路径

用户报PRG-8002 Cannot open file，相对路径以../../../../FPGA_Component_Inspector开头。已核对本机原候选存在、1789539字节且SHA与交付一致；报错在程序打开文件阶段，不能据此认定算法或bit内容损坏。

已准备本机短ASCII绝对路径副本：`D:/fpga_download/3528_body_trial_cb0a2636.bit`。在烧录窗口重新选择此完整路径，不继续使用保存的相对路径条目。副本与原候选逐字节一致，SHA256 `cb0a2636b2512c36140b96bd1b01229029ae80457efc457a4203bcc00dc95cda`；无需重新综合。若在另一台电脑操作，需要把同一bit复制到该电脑实际存在的路径再选择，路径不会由聊天跨电脑传送。

预期版本文字180MM BODY TRIAL / OUT32 CORE16；这是有件尺寸下限候选，完整空穴/定位孔标定仍待验证。当前只修交付路径，没有JTAG/Flash操作，没有修改RTL或冻结交付包，也没有Git提交/推送。
