-- SPDX-License-Identifier: MIT
-- Reproducible AWGN channel test for the sequential CCSDS AR4JA K=1024 rate-1/2 decoder.
-- Uses the independent published TM2048 codeword (information bytes 00..7F plus parity).
-- BPSK: bit 0 -> +1, bit 1 -> -1. AWGN sigma^2 = 1/(2*R*Eb/N0), R=1/2.
-- LLR convention: positive favors bit 0. Quantization uses 4x exact channel LLR,
-- rounded and saturated to signed 8-bit. Set generics to sweep SNR / frame count.
--
-- Suggested first runs: EBNO_DB=2.0, 3.0, 4.0; N_FRAMES=2 or 4.
-- Runtime can be substantial because the decoder is a sequential RTL prototype.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.ldpc_fixed_pkg.all;
use work.ar4ja_1024_frame_pkg.all;

entity tb_ar4ja_1024_awgn is
  generic (
    EBNO_DB  : real := 3.0;
    N_FRAMES : positive := 2
  );
end entity;

architecture test of tb_ar4ja_1024_awgn is
  signal clk          : std_logic := '0';
  signal clock_enable : std_logic := '1';
  signal rst          : std_logic := '1';
  signal start        : std_logic := '0';
  signal llr_in       : ar4ja_llr_frame_t := (others => to_signed(20, 8));
  signal decoded_bits : ar4ja_bit_frame_t;
  signal busy         : std_logic;
  signal done         : std_logic;
  signal status       : ar4ja_decode_status_t;

  constant LLR_SCALE : real := 4.0;
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
      when '0' => return 0; when '1' => return 1;
      when '2' => return 2; when '3' => return 3;
      when '4' => return 4; when '5' => return 5;
      when '6' => return 6; when '7' => return 7;
      when '8' => return 8; when '9' => return 9;
      when 'A' | 'a' => return 10; when 'B' | 'b' => return 11;
      when 'C' | 'c' => return 12; when 'D' | 'd' => return 13;
      when 'E' | 'e' => return 14; when 'F' | 'f' => return 15;
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
    if ((byte_value / (2 ** bit_pos)) mod 2) = 1 then return '1';
    else return '0'; end if;
  end function;

  function expected_parity_bit(index : natural) return std_logic is
    variable nibble_value : natural;
    variable bit_pos : natural;
  begin
    nibble_value := hex_nibble(PARITY_HEX(index / 4 + 1));
    bit_pos := 3 - (index mod 4);
    if ((nibble_value / (2 ** bit_pos)) mod 2) = 1 then return '1';
    else return '0'; end if;
  end function;

  function expected_tx_bit(index : natural) return std_logic is
  begin
    if index < AR4JA_INFO_BITS then return expected_info_bit(index);
    else return expected_parity_bit(index - AR4JA_INFO_BITS); end if;
  end function;

  procedure gaussian_pair(
    variable seed1 : inout positive;
    variable seed2 : inout positive;
    variable g1 : out real;
    variable g2 : out real
  ) is
    variable u1, u2 : real;
  begin
    uniform(seed1, seed2, u1);
    uniform(seed1, seed2, u2);
    -- Protect ln(0); uniform is normally in (0,1), but guard the edge.
    if u1 < 1.0E-12 then u1 := 1.0E-12; end if;
    g1 := sqrt(-2.0 * log(u1)) * cos(2.0 * MATH_PI * u2);
    g2 := sqrt(-2.0 * log(u1)) * sin(2.0 * MATH_PI * u2);
  end procedure;

  procedure make_awgn_frame(
    variable frame : out ar4ja_llr_frame_t;
    constant sigma : in real;
    variable seed1 : inout positive;
    variable seed2 : inout positive
  ) is
    variable n1, n2 : real;
    variable y, llr_real : real;
    variable quantized : integer;
    variable tx_bit : std_logic;
  begin
    for i in 0 to AR4JA_TX_BITS - 1 loop
      if (i mod 2) = 0 then
        gaussian_pair(seed1, seed2, n1, n2);
        tx_bit := expected_tx_bit(i);
        if tx_bit = '0' then y := 1.0 + sigma * n1;
        else y := -1.0 + sigma * n1; end if;
      else
        tx_bit := expected_tx_bit(i);
        if tx_bit = '0' then y := 1.0 + sigma * n2;
        else y := -1.0 + sigma * n2; end if;
      end if;

      -- For BPSK amplitude +/-1, log(P(y|0)/P(y|1)) = 2*y/sigma^2.
      llr_real := LLR_SCALE * 2.0 * y / (sigma * sigma);
      quantized := integer(floor(llr_real + 0.5));
      if quantized > 127 then quantized := 127; end if;
      if quantized < -128 then quantized := -128; end if;
      frame(i) := to_signed(quantized, 8);
    end loop;
  end procedure;

begin
  clock_driver : process
  begin
    while clock_enable = '1' loop
      clk <= '0'; wait for 5 ns;
      clk <= '1'; wait for 5 ns;
    end loop;
    clk <= '0'; wait;
  end process;

  dut : entity work.ar4ja_1024_decoder
    port map (
      clk => clk, rst => rst, start => start, llr_in => llr_in,
      decoded_bits => decoded_bits, busy => busy, done => done, status => status
    );

  stimulus : process
    variable seed1 : positive := 173;
    variable seed2 : positive := 947;
    variable sigma2 : real;
    variable sigma : real;
    variable frame : ar4ja_llr_frame_t;
    variable bit_errors_total : natural := 0;
    variable frame_errors : natural := 0;
    variable bit_errors_frame : natural;
    variable channel_bit_errors : natural := 0;
    variable channel_bit_errors_frame : natural;
    variable channel_bit_errors_total : natural := 0;
    variable frame_llr : integer;
    variable failed : boolean;
  begin
    assert PARITY_HEX'length = 256
      report "TM2048 parity vector must contain exactly 128 bytes"
      severity failure;

    assert EBNO_DB >= -2.0 and EBNO_DB <= 12.0
      report "EBNO_DB outside intended test range [-2, 12] dB"
      severity failure;

    sigma2 := 1.0 / (2.0 * 0.5 * (10.0 ** (EBNO_DB / 10.0)));
    sigma := sqrt(sigma2);
    report "AWGN test start: Eb/N0=" & real'image(EBNO_DB) &
      " dB, sigma=" & real'image(sigma) &
      ", frames=" & integer'image(N_FRAMES) &
      ", LLR scale=" & real'image(LLR_SCALE) severity note;

    wait for 20 ns;
    wait until rising_edge(clk);
    rst <= '0';

    for trial in 1 to N_FRAMES loop
      make_awgn_frame(frame, sigma, seed1, seed2);

      -- Count hard-decision channel errors separately from decoder errors.
      channel_bit_errors_frame := 0;
      for i in 0 to AR4JA_TX_BITS - 1 loop
        frame_llr := to_integer(frame(i));
        if (frame_llr < 0 and expected_tx_bit(i) = '0') or
           (frame_llr >= 0 and expected_tx_bit(i) = '1') then
          channel_bit_errors_frame := channel_bit_errors_frame + 1;
        end if;
      end loop;
      channel_bit_errors_total := channel_bit_errors_total + channel_bit_errors_frame;

      llr_in <= frame;
      wait until rising_edge(clk);
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait until done = '1';

      bit_errors_frame := 0;
      for b in 0 to AR4JA_INFO_BITS - 1 loop
        if decoded_bits(b) /= expected_info_bit(b) then
          bit_errors_frame := bit_errors_frame + 1;
        end if;
      end loop;

      failed := (status /= AR4JA_STATUS_CONVERGED) or (bit_errors_frame /= 0);
      bit_errors_total := bit_errors_total + bit_errors_frame;
      if failed then frame_errors := frame_errors + 1; end if;

      report "AWGN trial " & integer'image(trial) &
        ": status=" & ar4ja_decode_status_t'image(status) &
        ", channel hard errors=" & integer'image(channel_bit_errors_frame) &
        "/" & integer'image(AR4JA_TX_BITS) &
        ", information bit errors after decode=" & integer'image(bit_errors_frame) &
        "/" & integer'image(AR4JA_INFO_BITS) &
        ", frame_error=" & boolean'image(failed) severity note;
    end loop;

    report "AWGN SUMMARY: Eb/N0=" & real'image(EBNO_DB) &
      " dB, frames=" & integer'image(N_FRAMES) &
      ", FER=" & real'image(real(frame_errors) / real(N_FRAMES)) &
      ", information BER=" & real'image(real(bit_errors_total) /
        real(N_FRAMES * AR4JA_INFO_BITS)) &
      ", channel hard BER=" & real'image(real(channel_bit_errors_total) /
        real(N_FRAMES * AR4JA_TX_BITS)) severity note;

    if frame_errors = 0 then
      report "PASS: all AWGN frames decoded correctly at requested Eb/N0" severity note;
    else
      report "WARNING: AWGN failures observed; see per-frame results" severity warning;
    end if;
    clock_enable <= '0';
    wait;
  end process;
end architecture;
