-- SPDX-License-Identifier: MIT
-- Smoke test: the all-zero codeword has positive LLRs and zero syndrome.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ldpc_fixed_pkg.all;
use work.ar4ja_1024_frame_pkg.all;

entity tb_ar4ja_1024_decoder is
end entity;

architecture test of tb_ar4ja_1024_decoder is
  signal clk          : std_logic := '0';
  signal clock_enable : std_logic := '1';
  signal rst          : std_logic := '1';
  signal start        : std_logic := '0';
  signal llr_in       : ar4ja_llr_frame_t := (others => to_signed(20, 8));
  signal decoded_bits : ar4ja_bit_frame_t;
  signal busy         : std_logic;
  signal done         : std_logic;
  signal status       : ar4ja_decode_status_t;
begin
  clock_driver : process
  begin
    while clock_enable = '1' loop
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    end loop;
    clk <= '0';
    wait;
  end process;

  dut : entity work.ar4ja_1024_decoder
    port map (
      clk => clk,
      rst => rst,
      start => start,
      llr_in => llr_in,
      decoded_bits => decoded_bits,
      busy => busy,
      done => done,
      status => status
    );

  stimulus : process
  begin
    wait for 20 ns;
    wait until rising_edge(clk);
    rst <= '0';
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';

    wait until done = '1';
    assert status = AR4JA_STATUS_CONVERGED
      report "all-zero codeword did not converge" severity failure;
    for b in 0 to AR4JA_INFO_BITS - 1 loop
      assert decoded_bits(b) = '0'
        report "unexpected nonzero decoded bit at index " & integer'image(b)
        severity failure;
    end loop;

    report "PASS: AR4JA decoder converges on the all-zero codeword" severity note;
    clock_enable <= '0';
    wait;
  end process;
end architecture;
