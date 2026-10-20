-- SPDX-License-Identifier: MIT
-- Frame contract for K=1024 rate 4/5.
library ieee; use ieee.std_logic_1164.all; use work.ldpc_fixed_pkg.all;
package ar4ja_k1024_r45_frame_pkg is
 constant AR4JA_M: positive := 128; constant AR4JA_INFO_BITS: positive := 1024;
 constant AR4JA_TX_BITS: positive := 1280; constant AR4JA_FULL_BITS: positive := 1408;
 constant AR4JA_PUNCTURED: positive := 128; constant AR4JA_CHECKS: positive := 384;
 constant AR4JA_MAX_ITERATIONS: positive := 20;
 type ar4ja_llr_frame_t is array(0 to AR4JA_TX_BITS-1) of llr_t;
 type ar4ja_bit_frame_t is array(0 to AR4JA_INFO_BITS-1) of std_logic;
 type ar4ja_decode_status_t is (AR4JA_STATUS_IDLE, AR4JA_STATUS_BUSY, AR4JA_STATUS_CONVERGED, AR4JA_STATUS_MAX_ITERATIONS);
end package ar4ja_k1024_r45_frame_pkg;
