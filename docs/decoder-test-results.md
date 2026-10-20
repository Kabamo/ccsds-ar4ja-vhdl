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
- The stress test uses a deterministic, well-spread set of information-bit positions: `(e * 157) mod 1024`. It does not randomize positions between trials.

## Results

### 2026-10-20 — clean frame, single error and four errors

GHDL run reported at 09:55 UTC:

- PASS: clean all-zero codeword
- PASS: decoder corrects one corrupted information-bit LLR
- PASS: decoder corrects four corrupted information-bit LLRs
- PASS: AR4JA decoder clean-frame, single-error and four-error tests completed

The single-error test corrupts information bit 0. The four-error test corrupts information bits 0, 1, 2 and 3.

### 2026-10-20 — descending deterministic stress sweep

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

The simulator reported the clean-frame test passing and the overall descending sweep completing. The 512-error case is a detected decoding failure, not a successful decode. The smaller cases were still run after that failure.

### Previously reported component tests

The user also reported PASS for:

- Fixed-point arithmetic and check-/variable-node primitive tests.
- K=1024 rate-1/2 frame contract tests.
- AR4JA graph structural tests (dimensions, row degrees, edges, column degrees and puncturing).
- Clean-frame decoder smoke test.

## Important interpretation limits

- These results use the all-zero codeword and one deterministic error-position pattern. They are not a measured bit-error-rate curve and do not establish a universal correction threshold.
- A PASS means the tested frame converged to the expected all-zero information bits for that specific test pattern and LLR magnitude.
- The 512-error failure and 256-error success do not imply all patterns of 256 errors are correctable or all patterns of 512 errors fail.
- The intermediate 448-, 384-, 320- and 288-error tests have been added to the latest testbench but had not yet been reported as run when this log was updated.
- Independent golden vectors, nonzero valid codewords, randomized error patterns, convergence-failure coverage, and Vivado synthesis/timing/resource checks remain outstanding.
