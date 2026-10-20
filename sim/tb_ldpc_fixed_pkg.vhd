-- SPDX-License-Identifier: MIT
-- Self-checking testbench for ldpc_fixed_pkg.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ldpc_fixed_pkg.all;

entity tb_ldpc_fixed_pkg is
end entity;

architecture test of tb_ldpc_fixed_pkg is
begin
  stimulus : process
    variable incoming : llr_array_t(0 to 2);
    variable outgoing : llr_array_t(0 to 2);
    variable singleton : llr_array_t(0 to 0);
    variable singleton_out : llr_array_t(0 to 0);
  begin
    -- Fixed-point helpers
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

    -- Mixed signs and distinct minima: (+10, -20, +30) -> (-15, +7, -7).
    incoming(0) := to_signed(10, 8);
    incoming(1) := to_signed(-20, 8);
    incoming(2) := to_signed(30, 8);
    check_node_min_sum(incoming, outgoing);
    assert to_integer(outgoing(0)) = -15
      report "check-node output 0 failed" severity failure;
    assert to_integer(outgoing(1)) = 7
      report "check-node output 1 failed" severity failure;
    assert to_integer(outgoing(2)) = -7
      report "check-node output 2 failed" severity failure;

    -- Three negative inputs: each outgoing sign is positive.
    incoming(0) := to_signed(-8, 8);
    incoming(1) := to_signed(-12, 8);
    incoming(2) := to_signed(-20, 8);
    check_node_min_sum(incoming, outgoing);
    assert to_integer(outgoing(0)) = 9
      report "all-negative check-node output 0 failed" severity failure;
    assert to_integer(outgoing(1)) = 6
      report "all-negative check-node output 1 failed" severity failure;
    assert to_integer(outgoing(2)) = 6
      report "all-negative check-node output 2 failed" severity failure;

    -- Equal minima must be handled correctly for every edge.
    incoming(0) := to_signed(5, 8);
    incoming(1) := to_signed(5, 8);
    incoming(2) := to_signed(9, 8);
    check_node_min_sum(incoming, outgoing);
    assert to_integer(outgoing(0)) = 3 and
           to_integer(outgoing(1)) = 3 and
           to_integer(outgoing(2)) = 3
      report "equal-minimum check-node case failed" severity failure;

    -- A degree-one check has no extrinsic minimum; define output as zero.
    singleton(0) := to_signed(-17, 8);
    check_node_min_sum(singleton, singleton_out);
    assert to_integer(singleton_out(0)) = 0
      report "degree-one check-node fallback failed" severity failure;

    report "PASS: ldpc_fixed_pkg and check-node tests completed" severity note;
    wait;
  end process;
end architecture;
