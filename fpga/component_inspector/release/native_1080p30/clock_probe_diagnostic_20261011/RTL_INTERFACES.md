# F clock/raster diagnostic

This diagnostic keeps E's PLL, TMDS encoder, PHY, debounced SW1 and raster.
SW1 down selects720p60; up selects1080p30. Both use74.25/371.25MHz.
The old working image's independent50MHz FPS-window approach is reused to
measure internal pixel, line-end and frame-end events. It does not measure
camera FPS. The old identified bit is c3a1cce7…, with nominal1024x600 HDMI.
No camera, DDR, EDGE, classification, AVI or audio is enabled in F.

`clock_probe_counter` has three32-bit binary counters and registered Gray
outputs in the pixel domain.32 bits cover the largest one-second delta
(74,250,000), and subtraction is modulo2^32 across rollover. Counters do
not reset on a raster change. A PLL loss asynchronously resets them.

`clock_probe_measure` runs on the continuously available50MHz board clock.
Each Gray bus and mode/lock pass two synchronizer stages; Gray decoding is
registered. Its26-bit window counts50,000,000 reference cycles. It rejects
the initial window and any window containing a mode change or lock loss.
Lock loss clears validity even if the pixel clock is stopped. Each mode
retains its last clean96-bit{P,H,V} sample. Snapshot bits192/193 are the
HD/FHD validity bits. First clean measurements need up to two seconds.
The absolute frequency accuracy depends on the board reference oscillator.

The existing194-bit `status_cdc` mailbox holds source payload until ack,
and shares global reset assertion. The display latches the entire mailbox
at end of frame. `clock_probe_osd` delays RGB/DE/HS/VS equally by three
pixel cycles; its small diagnostic font is synthesized as logic. There
are no image buffers, multipliers or variable dividers. Expected resource
types are counters/adders, LUTs, flops and the two existing PLLs; actual
mapping and budgets are in the release reports.

The added CDC max-delay budgets are12ns for registered Gray crossings,
8ns for mode/mailbox crossings and2ns between synchronizer stages.
Normal hold checking remains enabled. TD packed-cell aliases can include
other flops, so these budgets are deliberately stricter than all involved
clock periods; no crossing hold exception or blanket clock-group cut is
used. Only reset, asynchronous SW first input and hard PLL-lock first input
are false paths. Check every constraint's matches/ignored status in TD.

Frozen tests separately cover counter/Gray correctness, per-mode retention,
mixed/first windows, rollover, pixel clock stop, lock chatter, reset,
194-bit atomic mailbox snapshots with destination stop/resume, complete
720/FHD OSD rasters and equal delay. The full serialized pin reference
checks all RGB (initial zero-count OSD), DE/HS/VS, frame counts, disparity,
bounced SW/frame-boundary switching, and continuous common clocks. It uses
an ideal5:1 PLL with vendor ODDR; full-frame real-PLL simulation and board
acceptance remain NOT_RUN. Dynamic per-frame snapshot latching is reviewed
in RTL; the serialized simulation ends before the hardware one-second
window and therefore does not claim dynamic measured-field pin coverage.
