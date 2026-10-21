-- SPDX-License-Identifier: MIT
-- Common unconstrained interface for the configurable AR4JA decoder wrapper.
library ieee;
use ieee.std_logic_1164.all;
use work.ldpc_fixed_pkg.all;

package ar4ja_configurable_pkg is
  type ar4ja_llr_frame_t is array (natural range <>) of llr_t;
  type ar4ja_config_status_t is
    (IDLE, BUSY, CONVERGED, MAX_ITERATIONS);
end package ar4ja_configurable_pkg;
