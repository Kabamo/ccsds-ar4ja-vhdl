-- SPDX-License-Identifier: MIT
-- Independent fixed-point helper package for a CCSDS AR4JA decoder.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ldpc_fixed_pkg is
  subtype llr_t is signed(7 downto 0);
  subtype mag_t is unsigned(6 downto 0);
  type llr_array_t is array (natural range <>) of llr_t;

  function sat_llr(value : integer) return llr_t;
  function llr_magnitude(value : llr_t) return mag_t;
  function normalize_3_4(value : mag_t) return mag_t;
  function sat_add(a : llr_t; b : llr_t) return llr_t;
  function sat_sub(a : llr_t; b : llr_t) return llr_t;

  -- Normalized min-sum check-node update. Output bounds must match input bounds.
  -- Each output excludes its own input; degree < 2 is defined as all zeros.
  procedure check_node_min_sum(
    inputs  : in  llr_array_t;
    outputs : out llr_array_t
  );

  -- Variable-node extrinsic update:
  -- extrinsic(i) = channel_llr + sum(check_messages(j), j /= i).
  -- Accumulation is done in integer precision and saturated once per output.
  procedure variable_node_extrinsic(
    channel_llr    : in  llr_t;
    check_messages : in  llr_array_t;
    extrinsic      : out llr_array_t
  );

  -- Posterior LLR = channel LLR + all incoming check-node messages.
  function variable_node_posterior(
    channel_llr    : llr_t;
    check_messages : llr_array_t
  ) return llr_t;
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
    scaled := (to_integer(value) * 3) / 4;
    return to_unsigned(scaled, 7);
  end function;

  -- Use a 9-bit intermediate: the exact sum/difference of two signed
  -- 8-bit operands fits in 9 bits. This avoids widening the datapath to
  -- VHDL integer width during synthesis.
  function sat_add(a : llr_t; b : llr_t) return llr_t is
    variable wide_sum : signed(8 downto 0);
  begin
    wide_sum := resize(a, wide_sum'length) + resize(b, wide_sum'length);
    if wide_sum(8 downto 7) = "01" then
      return to_signed(127, 8);
    elsif wide_sum(8 downto 7) = "10" then
      return to_signed(-128, 8);
    else
      return wide_sum(7 downto 0);
    end if;
  end function;

  function sat_sub(a : llr_t; b : llr_t) return llr_t is
    variable wide_diff : signed(8 downto 0);
  begin
    wide_diff := resize(a, wide_diff'length) - resize(b, wide_diff'length);
    if wide_diff(8 downto 7) = "01" then
      return to_signed(127, 8);
    elsif wide_diff(8 downto 7) = "10" then
      return to_signed(-128, 8);
    else
      return wide_diff(7 downto 0);
    end if;
  end function;

  procedure check_node_min_sum(
    inputs  : in  llr_array_t;
    outputs : out llr_array_t
  ) is
    variable min1            : integer := 128;
    variable min2            : integer := 128;
    variable min1_index      : integer := -1;
    variable magnitude       : integer;
    variable selected_min    : integer;
    variable scaled_min      : integer;
    variable negative_count  : integer := 0;
    variable output_negative : boolean;
  begin
    if inputs'length < 2 then
      for i in inputs'range loop
        outputs(i) := (others => '0');
      end loop;
      return;
    end if;

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
  end procedure;

  procedure variable_node_extrinsic(
    channel_llr    : in  llr_t;
    check_messages : in  llr_array_t;
    extrinsic      : out llr_array_t
  ) is
    variable accumulated : integer;
  begin
    for i in check_messages'range loop
      accumulated := to_integer(channel_llr);
      for j in check_messages'range loop
        if j /= i then
          accumulated := accumulated + to_integer(check_messages(j));
        end if;
      end loop;
      extrinsic(i) := sat_llr(accumulated);
    end loop;
  end procedure;

  function variable_node_posterior(
    channel_llr    : llr_t;
    check_messages : llr_array_t
  ) return llr_t is
    variable accumulated : integer := to_integer(channel_llr);
  begin
    for i in check_messages'range loop
      accumulated := accumulated + to_integer(check_messages(i));
    end loop;
    return sat_llr(accumulated);
  end function;
end package body ldpc_fixed_pkg;
