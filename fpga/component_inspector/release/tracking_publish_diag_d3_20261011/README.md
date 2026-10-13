# D3发布条件诊断

camera_to_dsi_display.bit：1789539字节，SHA-256 `7cda6149c57585308e26dce31bd6acbb28cb1a4fcdf9b97c63a3d59bc3c87c54`。

用途：为v2仍黑提供上一采集帧P/W发布条件证据。只读诊断，不声称黑屏已修复。六项新测通过、28项编译输入未变复用；Routed慢/快角setup+0.351ns、hold+0.020ns、TNS0；Slice13698/21216=64.56%，ERAM48、DSP8；STA覆盖92.36%。

复位等待5秒，确认顶部 `D3 Pxx Wxxxxx`，拍完整HDMI照片。使用说明见开发实施/41_B黑屏D3发布诊断_上板说明.md。现场验收PENDING；无JTAG/Flash操作，未提交/推送。
