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
- [x] Self-checking testbench for the helper package
- [ ] CCSDS AR4JA parity-check graph and schedule
- [ ] Layered min-sum decoder core
- [ ] AXI-Stream wrapper
- [ ] End-to-end reference vectors and Vivado resource/timing checks

The fixed-point helper package is an independent implementation. Arithmetic behavior must be checked against the intended decoder specification before it is used in the complete datapath.

## First simulation: EDA Playground

The small package testbench can be run at [EDA Playground](https://www.edaplayground.com/), an online HDL simulator.

1. Select **VHDL** for both design and testbench.
2. Select a simulator that supports **VHDL-2008** (for example, GHDL if available).
3. Paste `rtl/ldpc_fixed_pkg.vhd` into the design editor.
4. Paste `sim/tb_ldpc_fixed_pkg.vhd` into the testbench editor.
5. Set the top-level testbench entity to `tb_ldpc_fixed_pkg`, enable VHDL-2008 if the option is exposed, then click **Run**.
6. Expected output includes `PASS: ldpc_fixed_pkg checks completed`. Any failed assertion stops the test.

Compile order matters: the package must be analyzed before the testbench. The online playground is for quick functional checks; later we should also run GHDL locally and synthesize the full design in Vivado.

## Repository layout

- `rtl/`: synthesizable VHDL design sources
- `sim/`: self-checking simulation testbenches
