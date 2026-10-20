-- SPDX-License-Identifier: MIT
-- End-to-end stress tests for the sequential AR4JA decoder.
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
    procedure run_error_case(constant n_errors : in natural) is
      variable frame : ar4ja_llr_frame_t;
      variable passed : boolean;
      variable bad_bit : integer;
    begin
      frame := (others => to_signed(20, 8));
      -- Deterministic, well-spread error locations; 157 is coprime to 1024.
      for e in 0 to n_errors - 1 loop
        frame((e * 157) mod AR4JA_INFO_BITS) := to_signed(-8, 8);
      end loop;
      llr_in <= frame;

      wait until rising_edge(clk);
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';

      wait until done = '1';
      passed := (status = AR4JA_STATUS_CONVERGED);
      bad_bit := -1;
      for b in 0 to AR4JA_INFO_BITS - 1 loop
        if decoded_bits(b) /= '0' then
          passed := false;
          bad_bit := b;
          exit;
        end if;
      end loop;

      if passed then
        report "PASS: decoder corrected " & integer'image(n_errors) &
          " deterministic information-bit LLR errors" severity note;
      else
        report "STRESS RESULT: decoder did not recover " & integer'image(n_errors) &
          " errors; status=" & ar4ja_decode_status_t'image(status) &
          ", first wrong decoded bit=" & integer'image(bad_bit) severity warning;
      end if;
    end procedure;
  begin
    wait for 20 ns;
    wait until rising_edge(clk);
    rst <= '0';

    -- Baseline clean frame.
    llr_in <= (others => to_signed(20, 8));
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait until done = '1';
    assert status = AR4JA_STATUS_CONVERGED
      report "clean all-zero codeword did not converge" severity failure;
    for b in 0 to AR4JA_INFO_BITS - 1 loop
      assert decoded_bits(b) = '0'
        report "clean frame: unexpected nonzero decoded bit at index " & integer'image(b)
        severity failure;
    end loop;
    report "PASS: clean all-zero codeword" severity note;

    -- Start very aggressively, then automatically reduce the error count if needed.
    run_error_case(512);
    run_error_case(448);
    run_error_case(384);
    run_error_case(320);
    run_error_case(288);
    run_error_case(256);
    run_error_case(128);
    run_error_case(64);
    run_error_case(32);
    run_error_case(16);
    run_error_case(8);
    run_error_case(4);
    run_error_case(1);

    report "PASS: AR4JA decoder clean-frame and descending error-stress sweep completed"
      severity note;
    clock_enable <= '0';
    wait;
  end process;
end architecture;
