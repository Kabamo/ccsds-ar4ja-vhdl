-- SPDX-License-Identifier: MIT
-- Independent fixed-point helper package for a CCSDS AR4JA decoder.
-- VHDL-2008. No source code copied from the reference SystemVerilog project.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ldpc_fixed_pkg is
  -- LLRs and check-node messages use signed 8-bit two's-complement values.
  subtype llr_t is signed(7 downto 0);

  -- Non-negative magnitudes are deliberately limited to 0..127.
  subtype mag_t is unsigned(6 downto 0);

  -- Saturate an integer to the signed 8-bit LLR range [-128, 127].
  function sat_llr(value : integer) return llr_t;

  -- Absolute value represented as 0..127. abs(-128) saturates to 127.
  function llr_magnitude(value : llr_t) return mag_t;

  -- Normalized min-sum scale factor 3/4, with truncation toward zero.
  -- Input and output are non-negative magnitudes.
  function normalize_3_4(value : mag_t) return mag_t;

  -- Saturating LLR arithmetic; unlike signed wraparound, overflow clamps.
  function sat_add(a : llr_t; b : llr_t) return llr_t;
  function sat_sub(a : llr_t; b : llr_t) return llr_t;
end package ldpc_fixed_pkg;

package body ldpc_fixed_pkg is
  function sat_llr(value : integer) return llr_t is
    variable clipped : integer;
  begin
    if value > 127 then
      clipped := 127;
    elsif value < -128 then
      clipped := -128;
    else
      clipped := value;
    end if;
    return to_signed(clipped, 8);
  end function;

  function llr_magnitude(value : llr_t) return mag_t is
    variable v : integer;
    variable m : integer;
  begin
    v := to_integer(value);
    if v < 0 then
      m := -v;
    else
      m := v;
    end if;
    if m > 127 then
      m := 127;
    end if;
    return to_unsigned(m, 7);
  end function;

  function normalize_3_4(value : mag_t) return mag_t is
    variable scaled : integer;
  begin
    -- Integer division gives the intended floor for non-negative values.
    scaled := (to_integer(value) * 3) / 4;
    return to_unsigned(scaled, 7);
  end function;

  function sat_add(a : llr_t; b : llr_t) return llr_t is
  begin
    return sat_llr(to_integer(a) + to_integer(b));
  end function;

  function sat_sub(a : llr_t; b : llr_t) return llr_t is
  begin
    return sat_llr(to_integer(a) - to_integer(b));
  end function;
end package body ldpc_fixed_pkg;
