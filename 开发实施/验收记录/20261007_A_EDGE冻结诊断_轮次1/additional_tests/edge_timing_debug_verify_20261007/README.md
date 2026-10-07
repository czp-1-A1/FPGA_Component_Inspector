# Independent timing_debug regression, 2026-10-07

PASS. The engineering RTL was read and frozen once; no engineering file was edited. Source SHA-256: `377f6b3ff67cd3f11a744ce3cf0839576f78431754845eaba78cb014e4c3de11`. It was checked again after run and still matches.

- 18 directed cases, 471221 compared clocks, 6406 output PPC4 beats, 4101 direct independent RAW RGB reference beats.
- LP row starts at exact intervals 256,257,640,65535,65536 clocks. Values are 0x0100,0x0101,0x0280,0xffff,0xffff. A single row followed by 65540 idle clocks retains LP=0 while line_age saturates, because period_seen=0. Minimum changes from640 to257 on a shorter next interval.
- Real pending EDGE row is built by input of two complete1024-pixel rows with credit low. Pixel input then pauses, with no force or hierarchical writes. Consecutive credit waits0,1,2,65535,65536 clocks give exact/saturated WS. Credit release replays the row; low credit during that admitted row is ignored for WS and does not pause output. Independent episodes7 then3 retain max7.
- A live9-clock wait is cut by early SOF with simultaneous stale valid. A synchronous NBA receiver captures old0x01000009 while current timing_debug becomes0. Input remains disarmed. Actual bank-overrun via a fourth input row freezes previous262-cycle max rather than accumulating forever.
- RAW and GRAY each spend65536 clocks with credit low and WS=0. Fresh EDGE epoch after them reports LP640/WS0.
- A control module is generated from this exact tested RTL by removing only diagnostic port/block, retaining the no-idle repaired video logic. Everyclock compares video_valid,last,early,x,y,frame_bad,statistics,RGB whenvalid, read_issue/cache_overrun/read pointers/ready_rows/input_armed. This proves diagnosis logic does not change functional video/flow behavior; it is not an independent Sobel math oracle. RAW additionally compares actual output RGB/valid/last to driver inputs.

`console.log`, `compile.log`, `optimize.log` all have Errors0/Warnings0 and explicit PASS. `attempt1_license_failure` preserves the initial runner's missing-process-license error and control-text newline warnings; successful runner inherits the existing configured user/machine license without displaying it and normalizes only its own generated control text.

Run: `powershell -File run.ps1` in thisdirectory, using ModelSim D:/modelsim/win64. No vendor dependencies are required for thisSobel behavioral test. Full ISP, mailboxCDC/OSD integration and board validation remain root responsibilities.
