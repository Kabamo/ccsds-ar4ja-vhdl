# CCSDS AR4JA LDPC decoder in VHDL

Independent VHDL implementation targeting a Zynq UltraScale+ FPGA.

## Fixed target mode

- CCSDS AR4JA, information length K = 1024
- Code rate 1/2
- 2048 transmitted LLRs per frame
- 512 punctured internal variables, initialized with neutral LLR = 0
- 2560 internal variable nodes and 1536 parity checks
- 8-bit signed LLR/message datapath
- Normalized min-sum algorithm, normalization factor 3/4
- Intended integration target: Vivado / Zynq UltraScale+

## User-facing frame contract

The intended interface is one complete 2048-LLR input frame and one 1024-bit systematic information output frame. Positive LLR favors bit 0; negative LLR favors bit 1. The first array element represents transmitted CCSDS Bit 0. CRC processing is deliberately outside the LDPC decoder: the caller must specify which information bits contain CRC and remove them after decoding.

The shared constants and array/status types are in `rtl/ar4ja_1024_frame_pkg.vhd`. This is an interface contract only; it is not yet an operational decoder.

## Current status

- [x] Fixed-point helpers: saturation, magnitude, normalization and arithmetic
- [x] Check-node normalized min-sum primitive
- [x] Variable-node extrinsic and posterior primitives
- [x] Self-checking primitive testbench (user reported PASS in EDA Playground)
- [x] Fixed-mode frame contract and testbench (user reported PASS in EDA Playground)
- [x] Sparse AR4JA graph ROM generated for the fixed M=512 mode
- [x] Graph structural testbench: row degrees, edge count, column degrees and puncturing identity (awaiting user GHDL run)
- [ ] Iterative decoder datapath/control and message memory
- [ ] End-to-end golden vectors and error-correction tests
- [ ] Frame-level streaming interface and CRC placement integration
- [ ] Vivado synthesis, timing and resource checks

### Graph representation

`rtl/ar4ja_1024_graph_pkg.vhd` stores the sparse parity-check matrix as row adjacency: 1536 check nodes, 2560 variable nodes and 7680 edges. Each row has degree 3 or 6. The punctured variables are columns 2048..2559; each row in check block 2 has its corresponding punctured identity edge. The graph is generated from the fixed-mode permutation parameters transcribed from CCSDS 131.0-B-5 Tables 7-3 and 7-4; structural checks do not by themselves prove end-to-end decoder correctness.

## EDA Playground: primitive tests

1. Paste `rtl/ldpc_fixed_pkg.vhd` into Design and `sim/tb_ldpc_fixed_pkg.vhd` into Testbench.
2. Set top-level entity to `tb_ldpc_fixed_pkg`.
3. Compile and run with GHDL.

Expected report: `PASS: fixed-point, check-node and variable-node tests completed`.

## EDA Playground: frame contract test

1. Paste `rtl/ldpc_fixed_pkg.vhd` and `rtl/ar4ja_1024_frame_pkg.vhd` into Design, in that order.
2. Paste `sim/tb_ar4ja_1024_frame_pkg.vhd` into Testbench.
3. Set top-level entity to `tb_ar4ja_1024_frame_pkg`.
4. Compile and run with GHDL.

Expected report: `PASS: AR4JA K=1024 rate-1/2 frame contract completed`.

## EDA Playground: graph structural test

1. Paste the complete `rtl/ar4ja_1024_graph_pkg.vhd` into Design.
2. Paste `sim/tb_ar4ja_1024_graph_pkg.vhd` into Testbench.
3. Set top-level entity to `tb_ar4ja_1024_graph_pkg`.
4. Compile and run with GHDL.

Expected report: `PASS: AR4JA graph dimensions, row degrees, edges and puncturing checks completed`.

## Repository layout

- `rtl/`: synthesizable VHDL design sources
- `sim/`: self-checking simulation testbenches
- `docs/`: design notes and interface contracts
