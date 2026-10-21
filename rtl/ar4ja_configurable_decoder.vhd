-- SPDX-License-Identifier: MIT
-- Configurable top-level wrapper selecting one of the six supported CCSDS AR4JA modes.
-- K_BITS: 1024 or 4096. RATE_ID: 0 => 1/2, 1 => 2/3, 2 => 4/5.
-- This wrapper selects a statically elaborated specialized decoder; it does not
-- dynamically reconfigure an already synthesized FPGA at run time.
library ieee;
use ieee.std_logic_1164.all;
use work.ldpc_fixed_pkg.all;
use work.ar4ja_configurable_pkg.all;

entity ar4ja_configurable_decoder is
  generic (
    K_BITS : positive := 1024;
    RATE_ID : natural range 0 to 2 := 0
  );
  port (
    clk : in std_logic;
    rst : in std_logic;
    start : in std_logic;
    llr_in : in ar4ja_llr_frame_t(0 to ar4ja_tx_bits(K_BITS, RATE_ID) - 1);
    decoded_bits : out std_logic_vector(K_BITS-1 downto 0);
    busy : out std_logic;
    done : out std_logic;
    status : out ar4ja_config_status_t
  );
end entity;

architecture rtl of ar4ja_configurable_decoder is
begin
  assert (K_BITS = 1024 or K_BITS = 4096)
    report "K_BITS must be 1024 or 4096" severity failure;

  g_k1024_r12 : if K_BITS = 1024 and RATE_ID = 0 generate
    signal llr_local : work.ar4ja_k1024_r12_frame_pkg.ar4ja_llr_frame_t;
    signal bits_local : work.ar4ja_k1024_r12_frame_pkg.ar4ja_bit_frame_t;
    signal status_local : work.ar4ja_k1024_r12_frame_pkg.ar4ja_decode_status_t;
  begin
    convert_in : process(all)
    begin
      for i in 0 to 2048-1 loop llr_local(i) <= llr_in(i); end loop;
    end process;

    u_decoder : entity work.ar4ja_k1024_r12_decoder
      port map (clk => clk, rst => rst, start => start, llr_in => llr_local,
        decoded_bits => bits_local, busy => busy, done => done, status => status_local);

    convert_out : process(all)
    begin
      for i in 0 to 1024-1 loop decoded_bits(i) <= bits_local(i); end loop;
      case status_local is
        when work.ar4ja_k1024_r12_frame_pkg.AR4JA_STATUS_IDLE => status <= IDLE;
        when work.ar4ja_k1024_r12_frame_pkg.AR4JA_STATUS_BUSY => status <= BUSY;
        when work.ar4ja_k1024_r12_frame_pkg.AR4JA_STATUS_CONVERGED => status <= CONVERGED;
        when work.ar4ja_k1024_r12_frame_pkg.AR4JA_STATUS_MAX_ITERATIONS => status <= MAX_ITERATIONS;
      end case;
    end process;
  end generate;

  g_k1024_r23 : if K_BITS = 1024 and RATE_ID = 1 generate
    signal llr_local : work.ar4ja_k1024_r23_frame_pkg.ar4ja_llr_frame_t;
    signal bits_local : work.ar4ja_k1024_r23_frame_pkg.ar4ja_bit_frame_t;
    signal status_local : work.ar4ja_k1024_r23_frame_pkg.ar4ja_decode_status_t;
  begin
    convert_in : process(all)
    begin
      for i in 0 to 1536-1 loop llr_local(i) <= llr_in(i); end loop;
    end process;

    u_decoder : entity work.ar4ja_k1024_r23_decoder
      port map (clk => clk, rst => rst, start => start, llr_in => llr_local,
        decoded_bits => bits_local, busy => busy, done => done, status => status_local);

    convert_out : process(all)
    begin
      for i in 0 to 1024-1 loop decoded_bits(i) <= bits_local(i); end loop;
      case status_local is
        when work.ar4ja_k1024_r23_frame_pkg.AR4JA_STATUS_IDLE => status <= IDLE;
        when work.ar4ja_k1024_r23_frame_pkg.AR4JA_STATUS_BUSY => status <= BUSY;
        when work.ar4ja_k1024_r23_frame_pkg.AR4JA_STATUS_CONVERGED => status <= CONVERGED;
        when work.ar4ja_k1024_r23_frame_pkg.AR4JA_STATUS_MAX_ITERATIONS => status <= MAX_ITERATIONS;
      end case;
    end process;
  end generate;

  g_k1024_r45 : if K_BITS = 1024 and RATE_ID = 2 generate
    signal llr_local : work.ar4ja_k1024_r45_frame_pkg.ar4ja_llr_frame_t;
    signal bits_local : work.ar4ja_k1024_r45_frame_pkg.ar4ja_bit_frame_t;
    signal status_local : work.ar4ja_k1024_r45_frame_pkg.ar4ja_decode_status_t;
  begin
    convert_in : process(all)
    begin
      for i in 0 to 1280-1 loop llr_local(i) <= llr_in(i); end loop;
    end process;

    u_decoder : entity work.ar4ja_k1024_r45_decoder
      port map (clk => clk, rst => rst, start => start, llr_in => llr_local,
        decoded_bits => bits_local, busy => busy, done => done, status => status_local);

    convert_out : process(all)
    begin
      for i in 0 to 1024-1 loop decoded_bits(i) <= bits_local(i); end loop;
      case status_local is
        when work.ar4ja_k1024_r45_frame_pkg.AR4JA_STATUS_IDLE => status <= IDLE;
        when work.ar4ja_k1024_r45_frame_pkg.AR4JA_STATUS_BUSY => status <= BUSY;
        when work.ar4ja_k1024_r45_frame_pkg.AR4JA_STATUS_CONVERGED => status <= CONVERGED;
        when work.ar4ja_k1024_r45_frame_pkg.AR4JA_STATUS_MAX_ITERATIONS => status <= MAX_ITERATIONS;
      end case;
    end process;
  end generate;

  g_k4096_r12 : if K_BITS = 4096 and RATE_ID = 0 generate
    signal llr_local : work.ar4ja_k4096_r12_frame_pkg.ar4ja_llr_frame_t;
    signal bits_local : work.ar4ja_k4096_r12_frame_pkg.ar4ja_bit_frame_t;
    signal status_local : work.ar4ja_k4096_r12_frame_pkg.ar4ja_decode_status_t;
  begin
    convert_in : process(all)
    begin
      for i in 0 to 8192-1 loop llr_local(i) <= llr_in(i); end loop;
    end process;

    u_decoder : entity work.ar4ja_k4096_r12_decoder
      port map (clk => clk, rst => rst, start => start, llr_in => llr_local,
        decoded_bits => bits_local, busy => busy, done => done, status => status_local);

    convert_out : process(all)
    begin
      for i in 0 to 4096-1 loop decoded_bits(i) <= bits_local(i); end loop;
      case status_local is
        when work.ar4ja_k4096_r12_frame_pkg.AR4JA_STATUS_IDLE => status <= IDLE;
        when work.ar4ja_k4096_r12_frame_pkg.AR4JA_STATUS_BUSY => status <= BUSY;
        when work.ar4ja_k4096_r12_frame_pkg.AR4JA_STATUS_CONVERGED => status <= CONVERGED;
        when work.ar4ja_k4096_r12_frame_pkg.AR4JA_STATUS_MAX_ITERATIONS => status <= MAX_ITERATIONS;
      end case;
    end process;
  end generate;

  g_k4096_r23 : if K_BITS = 4096 and RATE_ID = 1 generate
    signal llr_local : work.ar4ja_k4096_r23_frame_pkg.ar4ja_llr_frame_t;
    signal bits_local : work.ar4ja_k4096_r23_frame_pkg.ar4ja_bit_frame_t;
    signal status_local : work.ar4ja_k4096_r23_frame_pkg.ar4ja_decode_status_t;
  begin
    convert_in : process(all)
    begin
      for i in 0 to 6144-1 loop llr_local(i) <= llr_in(i); end loop;
    end process;

    u_decoder : entity work.ar4ja_k4096_r23_decoder
      port map (clk => clk, rst => rst, start => start, llr_in => llr_local,
        decoded_bits => bits_local, busy => busy, done => done, status => status_local);

    convert_out : process(all)
    begin
      for i in 0 to 4096-1 loop decoded_bits(i) <= bits_local(i); end loop;
      case status_local is
        when work.ar4ja_k4096_r23_frame_pkg.AR4JA_STATUS_IDLE => status <= IDLE;
        when work.ar4ja_k4096_r23_frame_pkg.AR4JA_STATUS_BUSY => status <= BUSY;
        when work.ar4ja_k4096_r23_frame_pkg.AR4JA_STATUS_CONVERGED => status <= CONVERGED;
        when work.ar4ja_k4096_r23_frame_pkg.AR4JA_STATUS_MAX_ITERATIONS => status <= MAX_ITERATIONS;
      end case;
    end process;
  end generate;

  g_k4096_r45 : if K_BITS = 4096 and RATE_ID = 2 generate
    signal llr_local : work.ar4ja_k4096_r45_frame_pkg.ar4ja_llr_frame_t;
    signal bits_local : work.ar4ja_k4096_r45_frame_pkg.ar4ja_bit_frame_t;
    signal status_local : work.ar4ja_k4096_r45_frame_pkg.ar4ja_decode_status_t;
  begin
    convert_in : process(all)
    begin
      for i in 0 to 5120-1 loop llr_local(i) <= llr_in(i); end loop;
    end process;

    u_decoder : entity work.ar4ja_k4096_r45_decoder
      port map (clk => clk, rst => rst, start => start, llr_in => llr_local,
        decoded_bits => bits_local, busy => busy, done => done, status => status_local);

    convert_out : process(all)
    begin
      for i in 0 to 4096-1 loop decoded_bits(i) <= bits_local(i); end loop;
      case status_local is
        when work.ar4ja_k4096_r45_frame_pkg.AR4JA_STATUS_IDLE => status <= IDLE;
        when work.ar4ja_k4096_r45_frame_pkg.AR4JA_STATUS_BUSY => status <= BUSY;
        when work.ar4ja_k4096_r45_frame_pkg.AR4JA_STATUS_CONVERGED => status <= CONVERGED;
        when work.ar4ja_k4096_r45_frame_pkg.AR4JA_STATUS_MAX_ITERATIONS => status <= MAX_ITERATIONS;
      end case;
    end process;
  end generate;

  g_invalid : if not ((K_BITS = 1024 or K_BITS = 4096)) generate
    busy <= '0'; done <= '0'; decoded_bits <= (others => '0'); status <= IDLE;
  end generate;
end architecture rtl;
