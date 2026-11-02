# R59 fixtures

These are exact executed fixtures copied from the accepted-input validation workspace. The production sources are fpga/component_inspector/; the complete runtime inputs, logs, tool models and SHA-bound receipts are in the source/evidence delivery ZIP.

- tb_r59_four_modes_native: four complete 1920x1080 RAW frames, both dense lanes, all four views, same-frame capture/classification binding.
- tb_sobel_view_r59 / tb_sobel_tail_r59: independent four-mode pixel/gradient/packing reference, production address XOR, bubbles/tail/backpressure/cancellation.
- tb_r59_latency_char_equivalence:196864 character outputs against the exact previous function, all positions/lines/nibble values and deterministic random fields.
- tb_r58_ui: R59 title, current true-latency panel and dual-lane UI.
- tb_r58_frame_latency_chain:13 actual DDR/FIFO/phase/OSD rasters with external first-output-pixel time reference.

Run helpers are in scripts/r59/. They preserve the actual machine paths used for the evidence; update paths/tool/license configuration when moving machines, then rerun validation. Current software/physical PASS is bound to its original inputs and databases. Board acceptance remains HUMAN_PENDING.
