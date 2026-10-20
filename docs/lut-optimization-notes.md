# LUT/resource optimization notes

## Objective

Target fewer than 15,000 LUTs for the CCSDS AR4JA K=1024, rate-1/2 decoder. This is an objective only; no synthesis result is available yet.

## Low-risk RTL changes made

- `sat_add` / `sat_sub` use 9-bit signed intermediates, which are sufficient for the exact sum or difference of two signed 8-bit values. Saturation is decided from the top two bits.
- `llr_magnitude` widens before negating, then saturates the absolute value of -128 to 127.
- `normalize_3_4` uses a 9-bit `x + 2*x` intermediate and a two-bit right shift to implement exactly floor(3*x/4) for 0..127.
- Normalized min-sum temporary ranges are bounded to the actual magnitude range, and the sign parity is accumulated as a single toggle bit instead of an integer count.
- Graph column indices now use `ar4ja_graph_col_t` (range -1..2559) through the graph lookup and decoder, rather than a general integer variable.

An exhaustive arithmetic loop has been added to `sim/tb_ldpc_fixed_pkg.vhd` for all 65,536 pairs of signed 8-bit operands for both saturated addition and subtraction, plus all 128 values of the 3/4 normalization. The tests still need to be run against this revision; the changes must not be treated as verified until the testbench and decoder regression tests pass.

## Important limitation

These changes reduce unnecessarily wide arithmetic and index types, but they do not by themselves guarantee fewer than 15k LUTs. No synthesis has been run in this environment.

Likely dominant remaining costs:
- multi-access reads/writes to the variable-node `llr_mem` array;
- implementation of the sparse graph lookup indexed by `row_index` and edge;
- whether `r_mem` and other arrays infer RAM resources or expand into registers/multiplexers.

## Next steps

1. Run `tb_ldpc_fixed_pkg` on GHDL to validate the fixed-width arithmetic changes.
2. Re-run the reference-vector, corruption, and AWGN regressions before trusting the optimized RTL.
3. Synthesize the exact target part in Vivado and record LUT, FF, BRAM, DSP, timing, and warnings.
4. If LUT count exceeds the budget, use reports to prioritize memory banking/inference and graph representation. Do not guess a LUT count from RTL.
5. Keep the functional checkpoint branch as the comparison reference while iterating on the optimized implementation.
