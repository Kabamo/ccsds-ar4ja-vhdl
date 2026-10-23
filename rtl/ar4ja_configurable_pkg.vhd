-- SPDX-License-Identifier: MIT
-- Common unconstrained interface for the configurable AR4JA decoder wrapper.
library ieee;
use ieee.std_logic_1164.all;
use work.ldpc_fixed_pkg.all;

package ar4ja_configurable_pkg is
  type ar4ja_llr_frame_t is array (natural range <>) of llr_t;
  type ar4ja_config_status_t is (IDLE, BUSY, CONVERGED, MAX_ITERATIONS);
  function ar4ja_tx_bits(k_bits : positive; rate_id : natural) return positive;
end package ar4ja_configurable_pkg;

package body ar4ja_configurable_pkg is
  function ar4ja_tx_bits(k_bits : positive; rate_id : natural) return positive is
  begin
    case rate_id is
      when 0 => return k_bits * 2;
      when 1 => return k_bits * 3 / 2;
      when 2 => return k_bits * 5 / 4;
      when others => return 1;
    end case;
  end function;
end package body ar4ja_configurable_pkg;
