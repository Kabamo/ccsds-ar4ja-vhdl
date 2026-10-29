-- SPDX-License-Identifier: MIT
-- Fixed-mode frame contract for the CCSDS AR4JA K=1024, rate-1/2 decoder.
library ieee;
use ieee.std_logic_1164.all;
use work.ldpc_fixed_pkg.all;

package ar4ja_1024_frame_pkg is
  constant AR4JA_M             : positive := 512;
  constant AR4JA_INFO_BITS     : positive := 1024;
  constant AR4JA_TX_BITS       : positive := 2048;
  constant AR4JA_FULL_BITS     : positive := 2560;
  constant AR4JA_PUNCTURED     : positive := 512;
  constant AR4JA_CHECKS        : positive := 1536;
  constant AR4JA_MAX_ITERATIONS : positive := 20;

  type ar4ja_llr_frame_t is array (0 to AR4JA_TX_BITS - 1) of llr_t;
  type ar4ja_bit_frame_t is array (0 to AR4JA_INFO_BITS - 1) of std_logic;

  type ar4ja_decode_status_t is (
    AR4JA_STATUS_IDLE,
    AR4JA_STATUS_BUSY,
    AR4JA_STATUS_CONVERGED,
    AR4JA_STATUS_MAX_ITERATIONS
  );
end package ar4ja_1024_frame_pkg;
