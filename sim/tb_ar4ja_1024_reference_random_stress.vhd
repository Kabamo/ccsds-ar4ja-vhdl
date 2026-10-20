-- SPDX-License-Identifier: MIT
-- Reproducible randomized stress test using an independent nonzero CCSDS TM2048
-- golden codeword. 100 trials across error counts from 1 to 512.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.ldpc_fixed_pkg.all;
use work.ar4ja_1024_frame_pkg.all;

entity tb_ar4ja_1024_reference_random_stress is
end entity;

architecture test of tb_ar4ja_1024_reference_random_stress is
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

  constant PARITY_HEX : string :=
    "EEA9AAAF98D916CE6C2B282D1A5B944C"
    & "A4F1B3D31AEC585AB3E6A4C40DFB4F4D"
    & "D807A1AD0AE962C4D40BADA106E56EC8"
    & "A6686AD5E6AC09BE3FF1F34C7F359027"
    & "F26469038337429121B7BAD050E49142"
    & "E40D64197084A5B7866F067B12E6C7D5"
    & "AB10DB034FF68AFE17AC67BFF34A3642"
    & "04AE85B3B647CEC40FA58EB8BD4CC5CF";

  function hex_nibble(c : character) return natural is
  begin
    case c is
      when '0' => return 0;
      when '1' => return 1;
      when '2' => return 2;
      when '3' => return 3;
      when '4' => return 4;
      when '5' => return 5;
      when '6' => return 6;
      when '7' => return 7;
      when '8' => return 8;
      when '9' => return 9;
      when 'A' | 'a' => return 10;
      when 'B' | 'b' => return 11;
      when 'C' | 'c' => return 12;
      when 'D' | 'd' => return 13;
      when 'E' | 'e' => return 14;
      when 'F' | 'f' => return 15;
      when others =>
        assert false report "invalid hexadecimal character in reference vector"
          severity failure;
        return 0;
    end case;
  end function;

  function expected_info_bit(index : natural) return std_logic is
    variable byte_value : natural;
    variable bit_pos : natural;
  begin
    byte_value := index / 8;
    bit_pos := 7 - (index mod 8);
    if ((byte_value / (2 ** bit_pos)) mod 2) = 1 then
      return '1';
    else
      return '0';
    end if;
  end function;

  function expected_parity_bit(index : natural) return std_logic is
    variable nibble_index : natural;
    variable nibble_value : natural;
    variable bit_pos : natural;
  begin
    nibble_index := index / 4 + 1;
    nibble_value := hex_nibble(PARITY_HEX(nibble_index));
    bit_pos := 3 - (index mod 4);
    if ((nibble_value / (2 ** bit_pos)) mod 2) = 1 then
      return '1';
    else
      return '0';
    end if;
  end function;

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
    variable pass_count : natural := 0;
    variable fail_count : natural := 0;
    variable total_count : natural := 0;
    variable clean_frame : ar4ja_llr_frame_t;

    procedure build_reference_frame(variable frame : out ar4ja_llr_frame_t) is
      variable expected_bit : std_logic;
    begin
      for b in 0 to AR4JA_INFO_BITS - 1 loop
        expected_bit := expected_info_bit(b);
        if expected_bit = '0' then
          frame(b) := to_signed(20, 8);
        else
          frame(b) := to_signed(-20, 8);
        end if;
      end loop;
      for b in 0 to AR4JA_TX_BITS - AR4JA_INFO_BITS - 1 loop
        expected_bit := expected_parity_bit(b);
        if expected_bit = '0' then
          frame(AR4JA_INFO_BITS + b) := to_signed(20, 8);
        else
          frame(AR4JA_INFO_BITS + b) := to_signed(-20, 8);
        end if;
      end loop;
    end procedure;

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

      build_reference_frame(frame);

      -- Pick distinct information-bit positions, then reverse each LLR sign.
      -- The wrong-sign magnitude is 8; all untouched LLRs retain magnitude 20.
      while placed < n_errors loop
        uniform(seed1, seed2, rand_value);
        index_value := integer(rand_value * real(AR4JA_INFO_BITS));
        if index_value >= AR4JA_INFO_BITS then
          index_value := AR4JA_INFO_BITS - 1;
        end if;
        if not selected(index_value) then
          selected(index_value) := true;
          if expected_info_bit(index_value) = '0' then
            frame(index_value) := to_signed(-8, 8);
          else
            frame(index_value) := to_signed(8, 8);
          end if;
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
        if decoded_bits(b) /= expected_info_bit(b) then
          passed := false;
          bad_bit := b;
          exit;
        end if;
      end loop;

      total_count := total_count + 1;
      if passed then
        pass_count := pass_count + 1;
        report "PASS: randomized reference trial " & integer'image(trial_id) &
          " corrected " & integer'image(n_errors) & " information LLR errors"
          severity note;
      else
        fail_count := fail_count + 1;
        report "RANDOM STRESS RESULT: trial " & integer'image(trial_id) &
          " failed with " & integer'image(n_errors) &
          " information LLR errors; status=" & ar4ja_decode_status_t'image(status) &
          ", first wrong decoded bit=" & integer'image(bad_bit)
          severity warning;
      end if;
    end procedure;
  begin
    assert PARITY_HEX'length = 256
      report "TM2048 parity vector must contain exactly 128 bytes"
      severity failure;

    wait for 20 ns;
    wait until rising_edge(clk);
    rst <= '0';

    -- First verify the clean nonzero golden vector.
    build_reference_frame(clean_frame);
    llr_in <= clean_frame;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait until done = '1';
    assert status = AR4JA_STATUS_CONVERGED
      report "clean nonzero reference codeword did not converge" severity failure;
    for b in 0 to AR4JA_INFO_BITS - 1 loop
      assert decoded_bits(b) = expected_info_bit(b)
        report "clean reference frame mismatch at bit " & integer'image(b)
        severity failure;
    end loop;
    report "PASS: clean nonzero CCSDS reference codeword" severity note;

    -- Ten reproducible trials per level: 100 trials total.
    run_random_error_case(1,    101,   1001,  1);
    run_random_error_case(1,    211,   2003,  2);
    run_random_error_case(1,    307,   3001,  3);
    run_random_error_case(1,    401,   4001,  4);
    run_random_error_case(1,    503,   5003,  5);
    run_random_error_case(1,    601,   6007,  6);
    run_random_error_case(1,    701,   7001,  7);
    run_random_error_case(1,    809,   8009,  8);
    run_random_error_case(1,    907,   9001,  9);
    run_random_error_case(1,   1009,  10007, 10);

    run_random_error_case(4,   1103,  11003, 11);
    run_random_error_case(4,   1201,  12007, 12);
    run_random_error_case(4,   1301,  13001, 13);
    run_random_error_case(4,   1409,  14011, 14);
    run_random_error_case(4,   1511,  15013, 15);
    run_random_error_case(4,   1601,  16001, 16);
    run_random_error_case(4,   1709,  17011, 17);
    run_random_error_case(4,   1801,  18013, 18);
    run_random_error_case(4,   1901,  19001, 19);
    run_random_error_case(4,   2003,  20011, 20);

    run_random_error_case(8,   2111,  21001, 21);
    run_random_error_case(8,   2203,  22003, 22);
    run_random_error_case(8,   2309,  23011, 23);
    run_random_error_case(8,   2411,  24001, 24);
    run_random_error_case(8,   2503,  25013, 25);
    run_random_error_case(8,   2609,  26003, 26);
    run_random_error_case(8,   2707,  27011, 27);
    run_random_error_case(8,   2801,  28019, 28);
    run_random_error_case(8,   2903,  29009, 29);
    run_random_error_case(8,   3001,  30011, 30);

    run_random_error_case(16,  3109,  31013, 31);
    run_random_error_case(16,  3203,  32003, 32);
    run_random_error_case(16,  3301,  33013, 33);
    run_random_error_case(16,  3407,  34019, 34);
    run_random_error_case(16,  3511,  35023, 35);
    run_random_error_case(16,  3607,  36013, 36);
    run_random_error_case(16,  3701,  37003, 37);
    run_random_error_case(16,  3803,  38011, 38);
    run_random_error_case(16,  3907,  39019, 39);
    run_random_error_case(16,  4001,  40009, 40);

    run_random_error_case(32,  4103,  41017, 41);
    run_random_error_case(32,  4201,  42011, 42);
    run_random_error_case(32,  4303,  43003, 43);
    run_random_error_case(32,  4409,  44017, 44);
    run_random_error_case(32,  4513,  45007, 45);
    run_random_error_case(32,  4603,  46021, 46);
    run_random_error_case(32,  4703,  47017, 47);
    run_random_error_case(32,  4801,  48023, 48);
    run_random_error_case(32,  4903,  49009, 49);
    run_random_error_case(32,  5003,  50021, 50);

    run_random_error_case(64,  5101,  51031, 51);
    run_random_error_case(64,  5209,  52027, 52);
    run_random_error_case(64,  5303,  53017, 53);
    run_random_error_case(64,  5407,  54037, 54);
    run_random_error_case(64,  5501,  55021, 55);
    run_random_error_case(64,  5603,  56001, 56);
    run_random_error_case(64,  5701,  57041, 57);
    run_random_error_case(64,  5801,  58013, 58);
    run_random_error_case(64,  5903,  59009, 59);
    run_random_error_case(64,  6007,  60013, 60);

    run_random_error_case(128, 6101,  61027, 61);
    run_random_error_case(128, 6203,  62011, 62);
    run_random_error_case(128, 6301,  63029, 63);
    run_random_error_case(128, 6401,  64007, 64);
    run_random_error_case(128, 6503,  65011, 65);
    run_random_error_case(128, 6607,  66029, 66);
    run_random_error_case(128, 6701,  67003, 67);
    run_random_error_case(128, 6803,  68023, 68);
    run_random_error_case(128, 6907,  69013, 69);
    run_random_error_case(128, 7001,  70009, 70);

    run_random_error_case(256, 7103,  71011, 71);
    run_random_error_case(256, 7207,  72019, 72);
    run_random_error_case(256, 7307,  73009, 73);
    run_random_error_case(256, 7403,  74017, 74);
    run_random_error_case(256, 7507,  75011, 75);
    run_random_error_case(256, 7603,  76001, 76);
    run_random_error_case(256, 7703,  77023, 77);
    run_random_error_case(256, 7807,  78041, 78);
    run_random_error_case(256, 7901,  79031, 79);
    run_random_error_case(256, 8009,  80021, 80);

    run_random_error_case(384, 8101,  81013, 81);
    run_random_error_case(384, 8209,  82003, 82);
    run_random_error_case(384, 8303,  83017, 83);
    run_random_error_case(384, 8401,  84011, 84);
    run_random_error_case(384, 8501,  85027, 85);
    run_random_error_case(384, 8609,  86029, 86);
    run_random_error_case(384, 8707,  87011, 87);
    run_random_error_case(384, 8803,  88019, 88);
    run_random_error_case(384, 8903,  89017, 89);
    run_random_error_case(384, 9001,  90023, 90);

    run_random_error_case(512, 9103,  91009, 91);
    run_random_error_case(512, 9203,  92003, 92);
    run_random_error_case(512, 9301,  93001, 93);
    run_random_error_case(512, 9403,  94009, 94);
    run_random_error_case(512, 9503,  95003, 95);
    run_random_error_case(512, 9601,  96017, 96);
    run_random_error_case(512, 9703,  97001, 97);
    run_random_error_case(512, 9803,  98009, 98);
    run_random_error_case(512, 9901,  99017, 99);
    run_random_error_case(512, 10007, 100003, 100);

    report "RANDOM STRESS SUMMARY: " & integer'image(pass_count) &
      " passed, " & integer'image(fail_count) & " failed out of " &
      integer'image(total_count) & " randomized trials" severity note;
    report "PASS: randomized nonzero CCSDS reference stress sweep completed"
      severity note;
    clock_enable <= '0';
    wait;
  end process;
end architecture;
