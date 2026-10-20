-- SPDX-License-Identifier: MIT
-- Compile-time/frame-contract checks for the fixed AR4JA mode.
library ieee;
use ieee.std_logic_1164.all;
use work.ldpc_fixed_pkg.all;
use work.ar4ja_1024_frame_pkg.all;

entity tb_ar4ja_1024_frame_pkg is
end entity;

architecture test of tb_ar4ja_1024_frame_pkg is
begin
  stimulus : process
    variable llrs : ar4ja_llr_frame_t;
    variable bits : ar4ja_bit_frame_t;
    variable status : ar4ja_decode_status_t := AR4JA_STATUS_IDLE;
  begin
    assert AR4JA_M = 512 severity failure;
    assert AR4JA_INFO_BITS = 1024 severity failure;
    assert AR4JA_TX_BITS = 2048 severity failure;
    assert AR4JA_FULL_BITS = 2560 severity failure;
    assert AR4JA_PUNCTURED = 512 severity failure;
    assert AR4JA_CHECKS = 1536 severity failure;
    assert AR4JA_TX_BITS + AR4JA_PUNCTURED = AR4JA_FULL_BITS
      report "transmitted and punctured dimensions do not match full graph"
      severity failure;

    llrs(0) := to_signed(40, 8);
    llrs(AR4JA_TX_BITS - 1) := to_signed(-40, 8);
    bits(0) := '0';
    bits(AR4JA_INFO_BITS - 1) := '1';
    assert llrs(0) > to_signed(0, 8)
      report "positive LLR convention failed" severity failure;
    assert llrs(AR4JA_TX_BITS - 1) < to_signed(0, 8)
      report "negative LLR convention failed" severity failure;
    assert bits(0) = '0' and bits(AR4JA_INFO_BITS - 1) = '1'
      report "information output indexing failed" severity failure;
    assert status = AR4JA_STATUS_IDLE severity failure;

    report "PASS: AR4JA K=1024 rate-1/2 frame contract completed"
      severity note;
    wait;
  end process;
end architecture;
