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

The shared constants and array/status types are in `rtl/ar4ja_1024_frame_pkg.vhd`. The first sequential decoder prototype is in `rtl/ar4ja_1024_decoder.vhd`; it is not yet validated beyond compilation/simulation tests and is not yet optimized for FPGA resources or timing.

## Current status

- [x] Fixed-point helpers: saturation, magnitude, normalization and arithmetic
- [x] Check-node normalized min-sum primitive
- [x] Variable-node extrinsic and posterior primitives
- [x] Self-checking primitive testbench (user reported PASS in EDA Playground)
- [x] Fixed-mode frame contract and testbench (user reported PASS in EDA Playground)
- [x] Sparse AR4JA graph ROM generated for the fixed M=512 mode
- [x] Graph structural testbench: row degrees, edge count, column degrees and puncturing identity (user reported PASS in EDA Playground)
- [x] First sequential layered normalized-min-sum decoder RTL prototype
- [x] Decoder smoke test: all-zero codeword converges and all 1024 decoded information bits are checked (user reported PASS in EDA Playground)
- [x] Single-LLR error-correction test (user reported GHDL PASS)
- [x] Four-LLR error-correction test (user reported GHDL PASS)
- [x] Deterministic error-stress sweep (user-reported results: 512/448/384/320 failed to converge; 288 and below passed for the tested pattern)
- [x] Initial reproducible pseudo-random sweep: 12/12 patterns passed for 32, 64, 128 and 256 errors (three trials per level; user-reported GHDL results)
- [x] Expanded reproducible pseudo-random sweep: 25/25 patterns passed at 64, 128, 256, 288 and 320 errors (five trials per level; user-reported GHDL results)
- [x] One nonzero valid codeword checked against an independent CCSDS TM2048 golden vector (user-reported GHDL PASS)
- [ ] Additional golden vectors and broader randomized testing
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

## EDA Playground: deterministic decoder stress sweep

Add these files to Design in this order:
1. `rtl/ldpc_fixed_pkg.vhd`
2. `rtl/ar4ja_1024_frame_pkg.vhd`
3. `rtl/ar4ja_1024_graph_pkg.vhd`
4. `rtl/ar4ja_1024_decoder.vhd`

Paste `sim/tb_ar4ja_1024_decoder.vhd` into Testbench and set top-level entity to `tb_ar4ja_1024_decoder`. This test uses a clean all-zero codeword and deterministic error positions `(e * 157) mod 1024), with corrupted LLRs `-8` and all other transmitted LLRs `+20`. The latest reported run failed to converge at 512, 448, 384 and 320 errors, and passed at 288 and below. This applies only to the tested pattern and LLR magnitudes, not a universal correction threshold.

## EDA Playground: reproducible pseudo-random stress sweep

Keep the same four RTL files listed above in Design. Paste `sim/tb_ar4ja_1024_random_sweep.vhd` into Testbench and set the top-level entity to `tb_ar4ja_1024_random_sweep`. Run with GHDL.

The test first checks a clean all-zero codeword, then runs five fixed-seed pseudo-random unique error-position patterns at each of 64, 128, 256, 288 and 320 corrupted information-bit LLRs. Corrupted LLRs are `-8`; all other transmitted LLRs are `+20`. The user reported **25/25 trials passing**, including 5/5 at 320 errors. Simulation completion was reported at 5,315,105 ns. These limited tests are not a BER estimate and do not prove a universal correction capability; nonzero valid codewords and independent golden vectors are still needed.

## EDA Playground: independent nonzero CCSDS reference vector

Keep the four RTL files listed in the decoder stress-sweep section in Design. Paste `sim/tb_ar4ja_1024_reference_vector.vhd` into Testbench and set the top-level entity to `tb_ar4ja_1024_reference_vector`. Run with GHDL.

The test uses the nonzero TM2048 reference message with information bytes `00 01 02 ... 7F` and an independently sourced parity vector. The user reported:

```text
PASS: independent nonzero CCSDS TM2048 reference vector decoded
```

This validates one nonzero golden vector only; more vectors and broader testing are still needed.

## Simulation results log

All user-reported GHDL outcomes and interpretation limits are recorded in [`docs/decoder-test-results.md`](docs/decoder-test-results.md).

## Repository layout

- `rtl/`: synthesizable VHDL design sources
- `sim/`: self-checking simulation testbenches
- `docs/`: design notes and interface contracts
