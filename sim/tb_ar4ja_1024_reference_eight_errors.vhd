-- SPDX-License-Identifier: MIT
-- Independent nonzero-codeword regression using the published CCSDS TM2048
-- encoder vector from adamgreig/labrador-ldpc (MIT), reproduced by the
-- independent Ray-Rose/tomcruise Python encoder's test_spec_vector.py.
--
-- Information bytes are 00 01 02 ... 7F; bits are unpacked MSB-first.
-- The 1024 transmitted parity bits are the published TM2048 parity bytes.
-- This testbench checks a nonzero golden vector with eight deliberately flipped
-- information-bit LLRs, to test correction rather than only clean decoding.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ldpc_fixed_pkg.all;
use work.ar4ja_1024_frame_pkg.all;

entity tb_ar4ja_1024_reference_eight_errors is
end entity;

architecture test of tb_ar4ja_1024_reference_eight_errors is
  signal clk          : std_logic := '0';
  signal clock_enable : std_logic := '1';
  signal rst          : std_logic := '1';
  signal start        : std_logic := '0';
  signal llr_in       : ar4ja_llr_frame_t := (others => to_signed(20, 8));
  signal decoded_bits : ar4ja_bit_frame_t;
  signal busy         : std_logic;
  signal done         : std_logic;
  signal status       : ar4ja_decode_status_t;

  -- Published CCSDS 131.0-B-5 TM2048 parity vector, 128 bytes = 1024 bits.
  -- The bytes represent parity block 1 followed by parity block 2.
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
    -- Input bytes are 0x00, 0x01, ... 0x7F; unpack MSB first.
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
    variable expected_bit : std_logic;
  begin
    assert PARITY_HEX'length = 256
      report "TM2048 parity vector must contain exactly 128 bytes"
      severity failure;

    -- Build soft inputs from the independent known-good transmitted codeword.
    for b in 0 to AR4JA_INFO_BITS - 1 loop
      expected_bit := expected_info_bit(b);
      if b < 8 then
        -- Deliberately reverse the sign for information bits 0..7.
        if expected_bit = '0' then
          llr_in(b) <= to_signed(-8, 8);
        else
          llr_in(b) <= to_signed(8, 8);
        end if;
      elsif expected_bit = '0' then
        llr_in(b) <= to_signed(20, 8);
      else
        llr_in(b) <= to_signed(-20, 8);
      end if;
    end loop;

    for b in 0 to AR4JA_TX_BITS - AR4JA_INFO_BITS - 1 loop
      expected_bit := expected_parity_bit(b);
      if expected_bit = '0' then
        llr_in(AR4JA_INFO_BITS + b) <= to_signed(20, 8);
      else
        llr_in(AR4JA_INFO_BITS + b) <= to_signed(-20, 8);
      end if;
    end loop;

    wait for 20 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait until done = '1';

    assert status = AR4JA_STATUS_CONVERGED
      report "reference TM2048 codeword did not converge; status=" &
        ar4ja_decode_status_t'image(status)
      severity failure;

    for b in 0 to AR4JA_INFO_BITS - 1 loop
      assert decoded_bits(b) = expected_info_bit(b)
        report "TM2048 reference mismatch at information bit " &
          integer'image(b)
        severity failure;
    end loop;

    report "PASS: decoder corrected eight corrupted LLRs on independent nonzero CCSDS TM2048 reference vector"
      severity note;
    clock_enable <= '0';
    wait;
  end process;
end architecture;
