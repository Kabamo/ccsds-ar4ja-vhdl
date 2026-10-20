# Decoder simulation test log

This file records simulation results reported from GHDL runs in EDA Playground. These are user-reported logs, not runs executed in CI by the repository maintainer. Results apply only to the exact RTL/testbench revision used for each run.

## Configuration under test

- Decoder: `rtl/ar4ja_1024_decoder.vhd`
- Testbench: `sim/tb_ar4ja_1024_decoder.vhd`
- Mode: CCSDS AR4JA, K=1024, rate 1/2
- Algorithm: layered normalized min-sum, normalization 3/4
- LLR datapath: signed 8-bit
- Baseline all-zero codeword: transmitted LLRs +20
- Corrupted information-bit LLRs: -8; all other transmitted LLRs +20
- The deterministic stress test uses positions `(e * 157) mod 1024`; randomized stress tests use reproducible pseudo-random unique positions.

## Results

### 2026-10-20 — clean frame, single error and four errors

GHDL run reported at 09:55 UTC:

- PASS: clean all-zero codeword
- PASS: decoder corrects one corrupted information-bit LLR
- PASS: decoder corrects four corrupted information-bit LLRs
- PASS: AR4JA decoder clean-frame, single-error and four-error tests completed

The single-error test corrupts information bit 0. The four-error test corrupts information bits 0, 1, 2 and 3.

### 2026-10-20 — initial deterministic stress sweep

GHDL run reported at 09:57 UTC:

| Number of corrupted information-bit LLRs | Result |
|---:|---|
| 512 | STRESS RESULT: did not recover; status `AR4JA_STATUS_MAX_ITERATIONS`; first wrong decoded bit 0 |
| 256 | PASS |
| 128 | PASS |
| 64 | PASS |
| 32 | PASS |
| 16 | PASS |
| 8 | PASS |
| 4 | PASS |
| 1 | PASS |

The simulator reported the clean-frame test passing and the overall sweep completing. The 512-error case is a detected decoding failure, not a successful decode. The smaller cases were still run after that failure.

### 2026-10-20 — extended deterministic stress sweep

GHDL run reported at 13:39 UTC:

| Number of corrupted information-bit LLRs | Result |
|---:|---|
| 512 | STRESS RESULT: did not recover; status `AR4JA_STATUS_MAX_ITERATIONS`; first wrong decoded bit 0 |
| 448 | STRESS RESULT: did not recover; status `AR4JA_STATUS_MAX_ITERATIONS`; first wrong decoded bit 1 |
| 384 | STRESS RESULT: did not recover; status `AR4JA_STATUS_MAX_ITERATIONS`; first wrong decoded bit 0 |
| 320 | STRESS RESULT: did not recover; status `AR4JA_STATUS_MAX_ITERATIONS`; first wrong decoded bit 0 |
| 288 | PASS |
| 256 | PASS |
| 128 | PASS |
| 64 | PASS |
| 32 | PASS |
| 16 | PASS |
| 8 | PASS |
| 4 | PASS |
| 1 | PASS |

The clean all-zero codeword also passed. For this single deterministic position pattern, the observed transition lies between 288 (pass) and 320 (failure). This is not a universal error-correction threshold.

### 2026-10-20 — reproducible pseudo-random error-position sweep (12 trials)

GHDL run reported at 13:44 UTC:

| Trial | Corrupted information-bit LLRs | Result |
|---:|---:|---|
| 1–3 | 32 each | 3/3 PASS |
| 4–6 | 64 each | 3/3 PASS |
| 7–9 | 128 each | 3/3 PASS |
| 10–12 | 256 each | 3/3 PASS |

The clean all-zero codeword passed before the sweep. All 12 fixed-seed pseudo-random position patterns decoded to the expected all-zero information bits. The simulation reported completion at 1,351,965 ns.

### 2026-10-20 — expanded pseudo-random error-position sweep (25 trials)

GHDL run reported at 13:46 UTC using `sim/tb_ar4ja_1024_random_sweep.vhd`:

| Corrupted information-bit LLRs | Trials | Result |
|---:|---:|---|
| 64 | 5 | 5/5 PASS |
| 128 | 5 | 5/5 PASS |
| 256 | 5 | 5/5 PASS |
| 288 | 5 | 5/5 PASS |
| 320 | 5 | 5/5 PASS |
| **Total** | **25** | **25/25 PASS** |

The clean all-zero codeword passed first. The simulation reported completion at 5,315,105 ns. Each trial used a reproducible pseudo-random set of unique corrupted information-bit positions. Corrupted LLRs were -8 and all other transmitted LLRs +20. All trials decoded to the expected all-zero information bits.

These 25 trials are encouraging, including the five trials at 320 errors, but they do not establish a guaranteed correction threshold or a statistically meaningful BER curve. They all use the all-zero codeword, fixed LLR magnitudes and a limited set of seeds/patterns.

### Previously reported component tests

The user also reported PASS for:

- Fixed-point arithmetic and check-/variable-node primitive tests.
- K=1024 rate-1/2 frame contract tests.
- AR4JA graph structural tests (dimensions, row degrees, edges, column degrees and puncturing).
- Clean-frame decoder smoke test.


### 2026-10-20 — independent nonzero CCSDS TM2048 reference vector

GHDL run reported at 13:50 UTC using `sim/tb_ar4ja_1024_reference_vector.vhd`:

- **PASS:** independent nonzero CCSDS TM2048 reference vector decoded.
- The information bytes are `00 01 02 ... 7F` (unpacked MSB-first).
- The parity bits are compared against an independent published TM2048 reference vector.
- The decoder reported `AR4JA_STATUS_CONVERGED` and all 1024 decoded information bits matched the expected input.

This is an important end-to-end check beyond the all-zero codeword: it exercises a nonzero valid codeword and independently sourced parity bits. It is still one golden vector, not broad proof of correctness or BER performance.

## Important interpretation limits

- These are user-reported EDA Playground GHDL outcomes, not CI runs independently executed by the repository maintainer.
- A PASS means the tested frame converged to the expected all-zero information bits for that specific test pattern and LLR magnitude.
- Results do not establish that every pattern with the same number of errors will decode, nor that a higher count always fails.
- The randomized trials remain a small stress sample, not a BER estimate.
- Additional independent golden vectors, broader randomized testing, convergence-failure coverage, and Vivado synthesis/timing/resource checks remain outstanding.
