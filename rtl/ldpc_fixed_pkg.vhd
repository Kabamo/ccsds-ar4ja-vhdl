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

  -- Unconstrained array for variable-degree check-node input/output messages.
  type llr_array_t is array (natural range <>) of llr_t;

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

  -- Check-node update for normalized min-sum.
  -- Each output is the 3/4-scaled minimum magnitude of all *other* inputs,
  -- with sign equal to the XOR/parity of the signs of all other inputs.
  -- Arrays with fewer than two inputs return zero messages.
  function check_node_min_sum(inputs : llr_array_t) return llr_array_t;
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

  function check_node_min_sum(inputs : llr_array_t) return llr_array_t is
    variable outputs       : llr_array_t(inputs'range);
    variable min1          : integer := 128;
    variable min2          : integer := 128;
    variable min1_index    : integer := -1;
    variable magnitude     : integer;
    variable selected_min  : integer;
    variable scaled_min    : integer;
    variable negative_count: integer := 0;
    variable output_negative : boolean;
  begin
    if inputs'length < 2 then
      for i in inputs'range loop
        outputs(i) := (others => '0');
      end loop;
      return outputs;
    end if;

    -- Find the two smallest magnitudes. Strict comparison in the first
    -- branch preserves a second equal minimum in min2.
    for i in inputs'range loop
      magnitude := to_integer(llr_magnitude(inputs(i)));
      if inputs(i) < to_signed(0, inputs(i)'length) then
        negative_count := negative_count + 1;
      end if;

      if magnitude < min1 then
        min2 := min1;
        min1 := magnitude;
        min1_index := i;
      elsif magnitude < min2 then
        min2 := magnitude;
      end if;
    end loop;

    for i in inputs'range loop
      if i = min1_index then
        selected_min := min2;
      else
        selected_min := min1;
      end if;

      scaled_min := to_integer(normalize_3_4(to_unsigned(selected_min, 7)));

      -- Sign of the outgoing edge excludes the sign of its own input.
      output_negative := ((negative_count mod 2) /= 0);
      if inputs(i) < to_signed(0, inputs(i)'length) then
        output_negative := not output_negative;
      end if;

      if output_negative then
        outputs(i) := sat_llr(-scaled_min);
      else
        outputs(i) := sat_llr(scaled_min);
      end if;
    end loop;

    return outputs;
  end function;
end package body ldpc_fixed_pkg;
