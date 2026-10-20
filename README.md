# CCSDS AR4JA LDPC decoder in VHDL

VHDL-2008 implementation work targeting a Zynq UltraScale+ FPGA.

## Target configuration

- CCSDS AR4JA, information length K = 1024
- Code rate 1/2
- 8-bit signed LLR/message datapath
- Normalized min-sum algorithm, normalization factor 3/4
- Intended integration target: Vivado / Zynq UltraScale+

## Current status

This repository is being built incrementally, with simulation checks before adding the next block.

- [x] Fixed-point helper package: saturation, magnitude and 3/4 normalization
- [x] Check-node normalized min-sum function (two minima, extrinsic sign, 3/4 scaling)
- [x] Self-checking tests for fixed-point arithmetic and check-node cases
- [ ] CCSDS AR4JA parity-check graph and schedule
- [ ] Layered min-sum decoder core
- [ ] AXI-Stream wrapper
- [ ] End-to-end reference vectors and Vivado resource/timing checks

The arithmetic and check-node functions are an independent implementation. The testbench checks selected corner cases; the package has not yet been validated against an independent golden model or synthesized in Vivado.

## Simulation: EDA Playground

Use [EDA Playground](https://www.edaplayground.com/) for quick functional checks.

1. Select **VHDL** for both design and testbench.
2. Paste the full content of `rtl/ldpc_fixed_pkg.vhd` into the Design editor.
3. Paste the full content of `sim/tb_ldpc_fixed_pkg.vhd` into the Testbench editor.
4. Set the top-level entity to `tb_ldpc_fixed_pkg`.
5. Run with GHDL. The package must be analyzed before the testbench.

Expected report after all assertions pass:
`PASS: ldpc_fixed_pkg and check-node tests completed`

If EDA Playground reports that `std.env` is missing, make sure the testbench version pasted from this repository is used; this testbench does not depend on `std.env`.

## Repository layout

- `rtl/`: synthesizable VHDL design sources
- `sim/`: self-checking simulation testbenches
