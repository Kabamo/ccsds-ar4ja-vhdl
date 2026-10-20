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
- [x] One corrupted information LLR corrected on an independent nonzero CCSDS TM2048 golden vector (user-reported GHDL PASS)
- [x] Four corrupted information LLRs corrected on an independent nonzero CCSDS TM2048 golden vector (user-reported GHDL PASS)
- [x] Reproducible AWGN channel testbench added and exercised by the user at 1.0, 1.25, 1.5, 1.55, 1.6, 1.7, 2.0 and 3.0 dB; exploratory results recorded in `docs/decoder-test-results.md`
- [ ] Additional golden vectors and broader randomized/channel testing
- [ ] Frame-level streaming interface and CRC placement integration
- [ ] Vivado synthesis, timing and resource checks

### Graph representation

`rtl/ar4ja_1024_graph_pkg.vhd` stores the sparse parity-check matrix as row adjacency: 1536 check nodes, 2560 variable nodes and 7680 edges. Each row has degree 3 or 6. The punctured variables are columns 2048..2559; each row in check block 2 has its corresponding punctured identity edge. The graph is generated from the fixed-mode permutation parameters transcribed from CCSDS 131.0-B-5 Tables 7-3 and 7-4; structural checks do not by themselves prove end-to-end decoder correctness.

## LUT/resource optimization status

A first synthesis-oriented cleanup pass is in progress. It narrows the LLR add/subtract intermediates to 9 bits, replaces integer-width magnitude/normalization arithmetic with fixed-width unsigned/signed operations, narrows normalized-min-sum temporaries, and constrains graph column indices to the 12-bit graph-index subtype. These changes are intended to reduce unnecessary logic width; **no LUT reduction is claimed until the revised RTL is simulated and synthesized for the target FPGA**.

The main remaining resource risk is the decoder's multi-access variable-node LLR array and the dynamic sparse-graph lookup. The next substantial optimization should be driven by Vivado reports and should investigate memory inference/banking and a more compact schedule/graph representation. Preserve the functional baseline branch when comparing alternatives.

Target objective: below 15,000 LUTs. This is a design target, not yet a measured or demonstrated result.

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

## EDA Playground: single-error correction on nonzero reference vector

Keep the same four RTL files in Design as in the decoder stress-sweep section. Paste `sim/tb_ar4ja_1024_reference_error.vhd` into Testbench and set the top-level entity to `tb_ar4ja_1024_reference_error`.

This test starts from the independent nonzero TM2048 reference codeword, then deliberately changes the LLR for information bit 0 from the expected positive sign to `-8`. The user reported the following GHDL result:

```text
PASS: decoder corrected one corrupted LLR on independent nonzero CCSDS TM2048 reference vector
```

All 1024 decoded information bits matched the expected reference message. This is one controlled correction case, not a general performance guarantee.

## EDA Playground: four-error correction on nonzero reference vector

Use the same four RTL files in Design as in the decoder stress-sweep section. Paste `sim/tb_ar4ja_1024_reference_four_errors.vhd` into Testbench and set the top-level entity to `tb_ar4ja_1024_reference_four_errors`.

This test reverses the LLR signs of information bits 0 through 3 on the independent nonzero TM2048 reference codeword. The user reported this GHDL result:

```text
PASS: decoder corrected four corrupted LLRs on independent nonzero CCSDS TM2048 reference vector
```

All 1024 decoded information bits matched the expected reference message. This is one controlled four-error pattern, not a general performance guarantee.

## Simulation results log

All user-reported GHDL outcomes and interpretation limits are recorded in [`docs/decoder-test-results.md`](docs/decoder-test-results.md). The observed AWGN FER plot is available [here](docs/awgn-fer.svg), with the underlying [CSV data](docs/awgn-fer-results.csv).

The source-level cycle budget and 40 Mbit/s feasibility estimate are recorded in [`docs/throughput-budget.md`](docs/throughput-budget.md).

## Repository layout

- `rtl/`: synthesizable VHDL design sources
- `sim/`: self-checking simulation testbenches
- `docs/`: design notes and interface contracts


## EDA Playground: AWGN channel test

This testbench applies reproducible Gaussian noise to all 2048 transmitted bits of the independent CCSDS TM2048 reference codeword, quantizes soft information to signed 8-bit LLRs, runs the RTL decoder, and reports channel hard-decision errors, decoded information-bit errors, FER and BER.

Add these files to Design in this order:
1. `rtl/ldpc_fixed_pkg.vhd`
2. `rtl/ar4ja_1024_frame_pkg.vhd`
3. `rtl/ar4ja_1024_graph_pkg.vhd`
4. `rtl/ar4ja_1024_decoder.vhd`

Paste `sim/tb_ar4ja_1024_awgn.vhd` into Testbench and set the top-level entity to `tb_ar4ja_1024_awgn`. Use VHDL-2008 and GHDL. The testbench has generics:
- `EBNO_DB`: default 3.0 dB.
- `N_FRAMES`: default 2 frames.

For the first run, keep the defaults. Then rerun at 2.0 dB and 4.0 dB, changing only `EBNO_DB`. If runtime permits, increase `N_FRAMES` to 10 or more per point. The random seed is fixed for reproducibility; the noise samples differ across frames.

Channel assumptions:
- BPSK: bit 0 maps to +1 and bit 1 maps to -1.
- Rate (R=1/2), with noise variance `sigma^2 = 1/(2*R*Eb/N0)`.
- The exact channel LLR is `2*y/sigma^2`; the testbench multiplies it by 4, rounds, and saturates to signed 8-bit.
- Positive LLR favors bit 0, matching the RTL frame contract.
- The transmitted frame is a valid published reference codeword, not a randomly generated information frame. This is sufficient for initial channel/decoder validation, but broader confidence should later use multiple codewords and many frames per SNR.

A frame counts as a frame error if the decoder does not report convergence **or** any of the 1024 decoded information bits is wrong. A completed simulation is not automatically a passing result: inspect the per-frame lines and the final AWGN summary. User-reported exploratory results show 19/20 frame failures at 1.0 dB, 8/15 at 1.25 dB, 2/15 at 1.55 dB, 0/15 at 1.7 dB, and 0/30 at 2.0 dB. The 1.5 and 1.6 dB runs were interrupted after 21 frames (exit 137). See `docs/decoder-test-results.md` for the complete table and caveats. These short runs are a smoke test, not enough to establish a statistically meaningful waterfall/FER curve.


## Multimode VHDL implementation (feature branch)

The branch now contains generated graph packages, frame contracts, decoder RTL and
self-checking structural/AWGN smoke benches for the six requested operating points.
Each decoder uses the existing signed 8-bit fixed-point helpers and normalized
min-sum factor 3/4. The higher-rate graphs use the CCSDS 131.0-B-5 block extension
matrices and permutation tables, not a copied rate-1/2 graph with altered constants.

| Decoder entity | Information bits | Rate | Transmitted LLRs | Checks | Internal variables | Max row degree |
|---|---:|:---:|---:|---:|---:|---:|
| `ar4ja_k1024_r12_decoder` | 1024 | 1/2 | 2048 | 1536 | 2560 | 6 |
| `ar4ja_k1024_r23_decoder` | 1024 | 2/3 | 1536 | 768 | 1792 | 10 |
| `ar4ja_k1024_r45_decoder` | 1024 | 4/5 | 1280 | 384 | 1408 | 18 |
| `ar4ja_k4096_r12_decoder` | 4096 | 1/2 | 8192 | 6144 | 10240 | 6 |
| `ar4ja_k4096_r23_decoder` | 4096 | 2/3 | 6144 | 3072 | 7168 | 10 |
| `ar4ja_k4096_r45_decoder` | 4096 | 4/5 | 5120 | 1536 | 5632 | 18 |

For each `k*_r*` tag, `rtl/ar4ja_<tag>_graph_pkg.vhd` contains the sparse graph,
`rtl/ar4ja_<tag>_frame_pkg.vhd` the frame contract, and
`rtl/ar4ja_<tag>_decoder.vhd` the decoder entity. The matching
`sim/tb_<tag>_graph.vhd` checks dimensions, sorted unique edges, index ranges
and the punctured identity block. `sim/tb_<tag>_awgn.vhd` runs a reproducible
AWGN smoke test against the all-zero valid codeword; it is not a replacement for
independent nonzero golden vectors or FER characterization.

### Run the six-mode smoke suite

From the repository root with GHDL installed:

```bash
bash scripts/run_multimode_smoke.sh
```

The script analyzes all six VHDL decoder variants and runs the six graph checks
plus one-frame AWGN smoke tests at 10 dB. The current execution environment did
not have GHDL installed, so these newly added benches have **not yet been
executed here**. Treat the RTL as implementation-in-progress until the script
passes on a GHDL installation and independent reference vectors are added for
each mode. Vivado synthesis, timing and resource measurements also remain open.
