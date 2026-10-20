# CCSDS AR4JA multi-mode matrix construction notes

## Source of truth

Target specification: **CCSDS 131.0-B-5, section 7 (TM LDPC coding)**. Before calling an implementation standards-conformant, cross-check every constant and bit-ordering convention against the applicable official Blue Book revision and keep the revision/table references in the generated source.

Useful independent implementation references located during research:

- Greg Lucas, space-data-toolkit, file crates/sdtk-link/src/framing/coding/ldpc.rs: https://github.com/greglucas/space-data-toolkit/blob/ce292f75efb325c4e751cb757bfede3638bb3ebf/crates/sdtk-link/src/framing/coding/ldpc.rs
- Ved Jadhav, iq-wav-analysis, file tools/gen_ldpc_data.py: https://github.com/ved-jadhav-10/iq-wav-analysis/blob/f74ef4cef2e81a3c8a5c6c6438b9ef752484020b/tools/gen_ldpc_data.py
- LeoDOS project, crates/leodos-protocols/src/coding/fec/ldpc.rs: https://github.com/LeoDOS-Project/LeoDOS/blob/8282f1351c373d525e76ac21347e516c5dcdc316/crates/leodos-protocols/src/coding/fec/ldpc.rs

The references above describe or implement the same standard family. They are useful cross-checks, not a substitute for the official specification. In particular, one source explicitly notes that its extracted numerical tables were not compared against the official standard PDF. Any reused numerical table must retain the upstream license/attribution and be independently checked.

## Mode parameters

For information length K and rate factor q:

| Rate | q | Base-matrix columns | M = K/q | Parity-check rows |
|---|---:|---:|---:|---:|
| 1/2 | 2 | 5 | K/2 | 3M |
| 2/3 | 4 | 7 | K/4 | 3M |
| 4/5 | 8 | 11 | K/8 | 3M |

The full, pre-puncture parity-check matrix has 3M rows and N_internal = base_columns × M columns. The last M columns are punctured/not transmitted. Therefore the transmitted codeword length is N_tx = K / rate and N_internal = N_tx + M.

| K | Rate | M | Internal columns | Transmitted bits | Punctured bits | H rows |
|---:|:---:|---:|---:|---:|---:|---:|
| 1024 | 1/2 | 512 | 2560 | 2048 | 512 | 1536 |
| 1024 | 2/3 | 256 | 1792 | 1536 | 256 | 768 |
| 1024 | 4/5 | 128 | 1408 | 1280 | 128 | 384 |
| 4096 | 1/2 | 2048 | 10240 | 8192 | 2048 | 6144 |
| 4096 | 2/3 | 1024 | 7168 | 6144 | 1024 | 3072 |
| 4096 | 4/5 | 512 | 5632 | 5120 | 512 | 1536 |

## Permutation construction

The standard defines permutation matrices Pi_k through theta_k and phi_{j,k}(M). For a permutation block row index i:

- j = floor(4i/M), with j in {0,1,2,3}
- pi_k(i) = (M/4) × ((theta_k + j) mod 4) + ((phi_{j,k}(M) + i) mod (M/4))

Pi_k has one asserted element per row, at column pi_k(i). Check the precise indexing convention (k versus k-1, j versus j+1) when porting table data; off-by-one errors create a graph that can still compile but is the wrong code.

The rates use base matrices with 5, 7, or 11 block columns. Each block is zero, identity, or a modulo-2 sum of standard permutation matrices according to the appropriate CCSDS rate-specific base matrix. Build the complete sparse graph from the block matrix, then validate dimensions, degrees, edge counts, permutation bijectivity, and puncturing structure.

## Hardware implications

The current prototype's row-message array only supports degree 6 and its graph package is hard-wired to K=1024 rate 1/2. The generalized graph can have larger row degrees and up to 10,240 internal columns (K=4096 rate 1/2). A multi-mode implementation must resize or parameterize:

- row degree and row-message storage,
- row/column index subtypes,
- check-node temporary arrays,
- graph storage and lookup,
- syndrome scheduler counters,
- input/output frame packages and AWGN vectors.

Do not simply change AR4JA_INFO_BITS and AR4JA_TX_BITS: the matrix, puncturing, permutation tables and row schedule all depend on the selected mode.
