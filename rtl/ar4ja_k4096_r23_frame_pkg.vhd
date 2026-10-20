-- SPDX-License-Identifier: MIT
-- Frame contract for K=4096 rate 2/3.
library ieee; use ieee.std_logic_1164.all; use work.ldpc_fixed_pkg.all;
package ar4ja_k4096_r23_frame_pkg is
 constant AR4JA_M: positive := 1024; constant AR4JA_INFO_BITS: positive := 4096;
 constant AR4JA_TX_BITS: positive := 6144; constant AR4JA_FULL_BITS: positive := 7168;
 constant AR4JA_PUNCTURED: positive := 1024; constant AR4JA_CHECKS: positive := 3072;
 constant AR4JA_MAX_ITERATIONS: positive := 20;
 type ar4ja_llr_frame_t is array(0 to AR4JA_TX_BITS-1) of llr_t;
 type ar4ja_bit_frame_t is array(0 to AR4JA_INFO_BITS-1) of std_logic;
 type ar4ja_decode_status_t is (AR4JA_STATUS_IDLE, AR4JA_STATUS_BUSY, AR4JA_STATUS_CONVERGED, AR4JA_STATUS_MAX_ITERATIONS);
end package ar4ja_k4096_r23_frame_pkg;
