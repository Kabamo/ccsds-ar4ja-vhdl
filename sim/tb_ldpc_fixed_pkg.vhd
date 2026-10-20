-- SPDX-License-Identifier: MIT
-- Small self-checking testbench for ldpc_fixed_pkg (VHDL-2008).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.ldpc_fixed_pkg.all;

entity tb_ldpc_fixed_pkg is
end entity;

architecture test of tb_ldpc_fixed_pkg is
begin
  stimulus : process
  begin
    assert to_integer(sat_llr(0)) = 0
      report "sat_llr(0) failed" severity failure;
    assert to_integer(sat_llr(200)) = 127
      report "positive saturation failed" severity failure;
    assert to_integer(sat_llr(-200)) = -128
      report "negative saturation failed" severity failure;

    assert to_integer(llr_magnitude(to_signed(0, 8))) = 0
      report "magnitude of zero failed" severity failure;
    assert to_integer(llr_magnitude(to_signed(-23, 8))) = 23
      report "negative magnitude failed" severity failure;
    assert to_integer(llr_magnitude(to_signed(-128, 8))) = 127
      report "magnitude of -128 must saturate to 127" severity failure;

    assert to_integer(normalize_3_4(to_unsigned(127, 7))) = 95
      report "3/4 normalization at 127 failed" severity failure;
    assert to_integer(normalize_3_4(to_unsigned(4, 7))) = 3
      report "3/4 normalization at 4 failed" severity failure;
    assert to_integer(normalize_3_4(to_unsigned(3, 7))) = 2
      report "3/4 normalization at 3 failed" severity failure;

    assert to_integer(sat_add(to_signed(120, 8), to_signed(20, 8))) = 127
      report "saturating addition positive overflow failed" severity failure;
    assert to_integer(sat_add(to_signed(-120, 8), to_signed(-20, 8))) = -128
      report "saturating addition negative overflow failed" severity failure;
    assert to_integer(sat_sub(to_signed(-100, 8), to_signed(50, 8))) = -128
      report "saturating subtraction failed" severity failure;
    assert to_integer(sat_sub(to_signed(100, 8), to_signed(-50, 8))) = 127
      report "saturating subtraction positive overflow failed" severity failure;

    report "PASS: ldpc_fixed_pkg checks completed" severity note;
    finish;
    wait;
  end process;
end architecture;
