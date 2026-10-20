# LDPC AR4JA 1K 1/2 — project roadmap

## Objective

Build a reproducible, testable VHDL IP family for CCSDS AR4JA LDPC decoding, initially preserving the working prototype and then adding all six requested operating points:

- information length K=1024, code rates 1/2, 2/3, 4/5
- information length K=4096, code rates 1/2, 2/3, 4/5

Primary target: Xilinx Zynq UltraScale+ / Vivado. Initial algorithm: layered normalized min-sum with fixed-point LLRs. Resource target discussed: below 15,000 LUTs; this remains a target until Vivado synthesis proves it.

## Ground rule: no fake green tests

A mode is **implemented** only when its graph, frame contract, decoder and testbench exist. It is **validated** only when the tests have actually run and their output is recorded. A testbench that compiles, a syndrome that converges, and correct recovery of the expected information frame are different checks and must be reported separately.

Do not clone the existing K=1024 rate-1/2 graph and merely change constants to claim support for another rate or block length. The parity-check matrix, puncturing/shortening conventions, transmitted-bit ordering and information/parity mapping must match the applicable CCSDS specification for each mode.

## Configuration matrix

| K | Rate | Implementation status | Required next work |
|---:|:---:|---|---|
| 1024 | 1/2 | Prototype exists; user-reported simulations pass for several vectors and AWGN trials | Re-run all tests after fixed-width arithmetic changes; measure Vivado resources |
| 1024 | 2/3 | Not implemented | Derive/check the exact standard graph, frame mapping and puncturing; generate independent vectors; RTL and tests |
| 1024 | 4/5 | Not implemented | Same |
| 4096 | 1/2 | Not implemented | Derive/check exact graph and frame mapping; scalable graph storage/scheduler; vectors and tests |
| 4096 | 2/3 | Not implemented | Same |
| 4096 | 4/5 | Not implemented | Same |

This table is deliberately conservative. Only the K=1024, rate-1/2 prototype currently exists in the repository.

## Existing architecture snapshot (K=1024, rate 1/2)

- 1024 information bits; 2048 transmitted LLRs per frame.
- 512 punctured internal variables initialized with neutral LLR=0.
- 2560 internal variable nodes, 1536 parity checks, 7680 edges.
- Signed 8-bit LLRs; positive favours bit 0 and negative favours bit 1.
- Layered normalized min-sum; normalization factor 3/4; maximum 20 iterations.
- One row is processed per clock; a syndrome sweep checks convergence.
- Source-level worst-case budget is about 61,440 cycles before overhead. At 100 MHz that is about 614 us, much slower than a 40 Mbit/s continuous input budget. This is a source-level estimate, not a timing report.

## Current AWGN evidence (user-reported)

On 2026-10-20, after fixing the width issue in `llr_magnitude`, the user ran the AWGN bench at Eb/N0=1.7 dB:

- 15-frame run: all 15 converged, 0 information-bit errors, observed FER=0.
- 100-frame run: EDA Playground exited with code 137 after 21 completed frames. All 21 completed frames converged with 0 information-bit errors. This is an interrupted run, not a completed 100-frame PASS.

These samples are encouraging but small; 0 failures in 21 frames does not imply true FER=0. The user needs to rerun the complete test suite after the arithmetic fix and before accepting the optimization branch.

## Milestones

### M0 — preserve and verify baseline
- [x] Keep a functional checkpoint branch available.
- [x] Independent nonzero CCSDS TM2048 reference vector exists.
- [x] Primitive, graph, controlled-error, stress and AWGN benches exist for K=1024 rate 1/2.
- [ ] Re-run primitive exhaustive arithmetic test after `llr_magnitude` fix.
- [ ] Re-run graph and independent reference-vector tests after the latest RTL edits.
- [ ] Run the short AWGN smoke test locally with GHDL.
- [ ] Record GHDL version, command line, output and commit SHA.

### M1 — reproducible local verification
- [ ] Use a single script to compile and run the fast regression suite.
- [ ] Separate fast smoke tests from long random-stress and AWGN campaigns.
- [ ] Add machine-readable result logs with configuration, seed, SNR, frames, failures and commit SHA.
- [ ] Add CI for the short suite only; do not make CI claim long statistical validation.

### M2 — standards-derived multi-mode graph layer
- [ ] Identify exact CCSDS standard revision and table/annex for each of the six modes.
- [ ] Record dimensions, base/permutation parameters, puncturing, systematic ordering and parity ordering in machine-readable config.
- [ ] Build a graph generator and independent structural checker.
- [ ] Cross-check generated parity checks against independent known-good encoder/reference vectors for every mode.
- [ ] Only then add a shared parameterized decoder or per-mode generated RTL.

### M3 — six complete decoder IPs
For every K/rate combination:
- [ ] Explicit frame contract and package.
- [ ] Generated/checkable graph package or ROM.
- [ ] Decoder RTL and top-level wrapper.
- [ ] Clean-codeword test.
- [ ] Independent nonzero golden-vector test.
- [ ] Controlled LLR sign-flip correction test.
- [ ] Syndrome and max-iteration checks.
- [ ] AWGN test with deterministic seeds and adjustable Eb/N0 / frame count.
- [ ] Synthesis and timing report.

### M4 — FPGA implementation
- [ ] Run Vivado synthesis for the intended exact FPGA part.
- [ ] Measure LUT, FF, BRAM/URAM, DSP, Fmax and timing slack.
- [ ] Optimize based on reports, not source-code appearance.
- [ ] Verify throughput and latency under the intended frame/streaming contract.
- [ ] Preserve known-good snapshots before major scheduling or memory changes.

## AWGN acceptance protocol

For each mode, use at least:
1. Zero-noise/clean valid codeword: zero decoded information errors and valid syndrome.
2. One or more independent nonzero golden vectors.
3. Controlled sign flips with known expected output.
4. Deterministic AWGN smoke test at a small frame count.
5. Longer AWGN campaigns across a documented Eb/N0 sweep after the smoke tests pass.

A frame error is counted if the decoder fails to converge **or** any information bit differs from the expected message. Always report both FER and information BER. Include the number of frames; zero observed failures is not evidence of a zero true FER.

## Naming

Project title: **LDPC AR4JA 1K 1/2**. Repository slug currently remains `ccsds-ar4ja-vhdl`; the project title is used in the docs until repository renaming is performed separately.
