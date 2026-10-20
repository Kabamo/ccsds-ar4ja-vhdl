-- SPDX-License-Identifier: MIT
-- Reproducible pseudo-random error-position tests for the AR4JA decoder.
-- Uses a fixed all-zero valid codeword and randomizes only the received LLR errors.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.ldpc_fixed_pkg.all;
use work.ar4ja_1024_frame_pkg.all;

entity tb_ar4ja_1024_random_errors is
end entity;

architecture test of tb_ar4ja_1024_random_errors is
  type boolean_frame_t is array (0 to AR4JA_INFO_BITS - 1) of boolean;

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
    procedure run_random_error_case(
      constant n_errors : in natural;
      constant seed1_init : in positive;
      constant seed2_init : in positive;
      constant trial_id : in natural
    ) is
      variable frame : ar4ja_llr_frame_t;
      variable selected : boolean_frame_t := (others => false);
      variable seed1 : positive := seed1_init;
      variable seed2 : positive := seed2_init;
      variable rand_value : real;
      variable index_value : natural;
      variable placed : natural := 0;
      variable passed : boolean;
      variable bad_bit : integer;
    begin
      assert n_errors <= AR4JA_INFO_BITS
        report "random test asks for more errors than information bits"
        severity failure;

      frame := (others => to_signed(20, 8));

      -- Pick distinct information-bit positions using fixed-seed uniform PRNG.
      while placed < n_errors loop
        uniform(seed1, seed2, rand_value);
        index_value := integer(rand_value * real(AR4JA_INFO_BITS));
        if index_value >= AR4JA_INFO_BITS then
          index_value := AR4JA_INFO_BITS - 1;
        end if;
        if not selected(index_value) then
          selected(index_value) := true;
          frame(index_value) := to_signed(-8, 8);
          placed := placed + 1;
        end if;
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
        report "PASS: random-pattern trial " & integer'image(trial_id) &
          " corrected " & integer'image(n_errors) & " LLR errors"
          severity note;
      else
        report "RANDOM STRESS RESULT: trial " & integer'image(trial_id) &
          " did not recover " & integer'image(n_errors) &
          " errors; status=" & ar4ja_decode_status_t'image(status) &
          ", first wrong decoded bit=" & integer'image(bad_bit)
          severity warning;
      end if;
    end procedure;
  begin
    wait for 20 ns;
    wait until rising_edge(clk);
    rst <= '0';

    -- First prove the clean all-zero codeword still works.
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
        report "clean frame: unexpected nonzero decoded bit at index " &
          integer'image(b) severity failure;
    end loop;
    report "PASS: clean all-zero codeword" severity note;

    -- Three repeatable random position patterns at each error count.
    run_random_error_case(32, 101, 1001, 1);
    run_random_error_case(32, 211, 2003, 2);
    run_random_error_case(32, 307, 3001, 3);

    run_random_error_case(64, 401, 4001, 4);
    run_random_error_case(64, 503, 5003, 5);
    run_random_error_case(64, 601, 6007, 6);

    run_random_error_case(128, 701, 7001, 7);
    run_random_error_case(128, 809, 8009, 8);
    run_random_error_case(128, 907, 9001, 9);

    run_random_error_case(256, 1009, 10007, 10);
    run_random_error_case(256, 1103, 11003, 11);
    run_random_error_case(256, 1201, 12007, 12);

    report "PASS: reproducible pseudo-random error-position sweep completed"
      severity note;
    clock_enable <= '0';
    wait;
  end process;
end architecture;
