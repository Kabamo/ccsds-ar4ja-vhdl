# CCSDS AR4JA LDPC decoder in VHDL

VHDL implementation work targeting a Zynq UltraScale+ FPGA.

## Target configuration

- CCSDS AR4JA, information length K = 1024
- Code rate 1/2
- 8-bit signed LLR/message datapath
- Normalized min-sum algorithm, normalization factor 3/4
- Intended integration target: Vivado / Zynq UltraScale+

## Current status

- [x] Fixed-point helpers: saturation, magnitude, normalization and arithmetic
- [x] Check-node normalized min-sum update (two minima, extrinsic sign, 3/4 scaling)
- [x] Variable-node extrinsic and posterior LLR updates
- [x] Self-checking testbench for the above primitives
- [ ] Independent golden-model comparison and broader randomized tests
- [ ] CCSDS AR4JA parity-check graph and schedule
- [ ] Iterative decoder core
- [ ] AXI-Stream wrapper
- [ ] End-to-end reference vectors and Vivado resource/timing checks

The current testbench has passed in the user's EDA Playground run for the earlier check-node version. The newly added variable-node tests have **not yet been run**. Arithmetic conventions and all primitives still need validation against an independent reference model before being treated as a complete decoder.

## Simulation: EDA Playground

1. Paste the full content of `rtl/ldpc_fixed_pkg.vhd` into the Design editor.
2. Paste the full content of `sim/tb_ldpc_fixed_pkg.vhd` into the Testbench editor.
3. Set the top-level entity to `tb_ldpc_fixed_pkg`.
4. Compile the package before the testbench and run.

Expected report after the updated tests pass:
`PASS: fixed-point, check-node and variable-node tests completed`

## Repository layout

- `rtl/`: synthesizable VHDL design sources
- `sim/`: self-checking simulation testbenches
