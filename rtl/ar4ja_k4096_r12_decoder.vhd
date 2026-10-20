-- SPDX-License-Identifier: MIT
-- Sequential layered AR4JA normalized min-sum decoder for K=4096 rate 1/2.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ldpc_fixed_pkg.all;
use work.ar4ja_k4096_r12_frame_pkg.all;
use work.ar4ja_k4096_r12_graph_pkg.all;

entity ar4ja_k4096_r12_decoder is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    start        : in  std_logic;
    llr_in       : in  ar4ja_llr_frame_t;
    decoded_bits : out ar4ja_bit_frame_t;
    busy         : out std_logic;
    done         : out std_logic;
    status       : out ar4ja_decode_status_t
  );
end entity ar4ja_k4096_r12_decoder;

architecture rtl of ar4ja_k4096_r12_decoder is
  type state_t is (IDLE, PROCESS_ROW, CHECK_SYNDROME, FINISH);
  type variable_llr_mem_t is array (0 to AR4JA_GRAPH_COLS - 1) of llr_t;
  type row_message_t is array (0 to AR4JA_GRAPH_MAX_ROW_DEGREE - 1) of llr_t;
  type message_mem_t is array (0 to AR4JA_GRAPH_ROWS - 1) of row_message_t;

  signal state          : state_t := IDLE;
  signal llr_mem        : variable_llr_mem_t := (others => (others => '0'));
  signal r_mem          : message_mem_t := (others => (others => (others => '0')));
  signal row_index      : natural range 0 to AR4JA_GRAPH_ROWS - 1 := 0;
  signal iteration      : natural range 0 to AR4JA_MAX_ITERATIONS := 0;
  signal syndrome_bad   : std_logic := '0';
  signal done_reg       : std_logic := '0';
  signal status_reg     : ar4ja_decode_status_t := AR4JA_STATUS_IDLE;
begin
  done <= done_reg;
  status <= status_reg;
  busy <= '1' when state = PROCESS_ROW or state = CHECK_SYNDROME else '0';

  process (clk)
    variable q          : llr_array_t(0 to AR4JA_GRAPH_MAX_ROW_DEGREE - 1);
    variable r_new      : llr_array_t(0 to AR4JA_GRAPH_MAX_ROW_DEGREE - 1);
    variable degree     : natural range 0 to AR4JA_GRAPH_MAX_ROW_DEGREE;
    variable col        : ar4ja_graph_col_t;
    variable parity     : std_logic;
  begin
    if rising_edge(clk) then
      done_reg <= '0';

      if rst = '1' then
        state <= IDLE;
        row_index <= 0;
        iteration <= 0;
        syndrome_bad <= '0';
        status_reg <= AR4JA_STATUS_IDLE;
        decoded_bits <= (others => '0');
      else
        case state is
          when IDLE =>
            if start = '1' then
              for c in 0 to AR4JA_TX_BITS - 1 loop
                llr_mem(c) <= llr_in(c);
              end loop;
              for c in AR4JA_TX_BITS to AR4JA_GRAPH_COLS - 1 loop
                llr_mem(c) <= (others => '0');
              end loop;
              row_index <= 0;
              iteration <= 0;
              syndrome_bad <= '0';
              status_reg <= AR4JA_STATUS_BUSY;
              state <= PROCESS_ROW;
            end if;

          when PROCESS_ROW =>
            degree := ar4ja_row_degree(row_index);
            q := (others => (others => '0'));
            r_new := (others => (others => '0'));

            for e in 0 to degree - 1 loop
              col := ar4ja_row_col(row_index, e);
              if iteration = 0 then
                q(e) := llr_mem(col);
              else
                q(e) := sat_sub(llr_mem(col), r_mem(row_index)(e));
              end if;
            end loop;

            if degree = 3 then
              check_node_min_sum(q(0 to 2), r_new(0 to 2));
            else
              check_node_min_sum(q, r_new);
            end if;

            for e in 0 to degree - 1 loop
              col := ar4ja_row_col(row_index, e);
              llr_mem(col) <= sat_add(q(e), r_new(e));
              r_mem(row_index)(e) <= r_new(e);
            end loop;

            if row_index = AR4JA_GRAPH_ROWS - 1 then
              row_index <= 0;
              syndrome_bad <= '0';
              state <= CHECK_SYNDROME;
            else
              row_index <= row_index + 1;
            end if;

          when CHECK_SYNDROME =>
            parity := '0';
            degree := ar4ja_row_degree(row_index);
            for e in 0 to degree - 1 loop
              col := ar4ja_row_col(row_index, e);
              if llr_mem(col) < to_signed(0, llr_mem(col)'length) then
                parity := not parity;
              end if;
            end loop;

            if parity = '1' then
              syndrome_bad <= '1';
            end if;

            if row_index = AR4JA_GRAPH_ROWS - 1 then
              if syndrome_bad = '0' and parity = '0' then
                for b in 0 to AR4JA_INFO_BITS - 1 loop
                  if llr_mem(b) < to_signed(0, llr_mem(b)'length) then
                    decoded_bits(b) <= '1';
                  else
                    decoded_bits(b) <= '0';
                  end if;
                end loop;
                status_reg <= AR4JA_STATUS_CONVERGED;
                done_reg <= '1';
                state <= FINISH;
              elsif iteration + 1 >= AR4JA_MAX_ITERATIONS then
                for b in 0 to AR4JA_INFO_BITS - 1 loop
                  if llr_mem(b) < to_signed(0, llr_mem(b)'length) then
                    decoded_bits(b) <= '1';
                  else
                    decoded_bits(b) <= '0';
                  end if;
                end loop;
                status_reg <= AR4JA_STATUS_MAX_ITERATIONS;
                done_reg <= '1';
                state <= FINISH;
              else
                iteration <= iteration + 1;
                row_index <= 0;
                state <= PROCESS_ROW;
              end if;
            else
              row_index <= row_index + 1;
            end if;

          when FINISH =>
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;
