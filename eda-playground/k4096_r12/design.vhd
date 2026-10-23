-- SOURCE FILE: rtl/ldpc_fixed_pkg.vhd
-- SPDX-License-Identifier: MIT
-- Independent fixed-point helper package for a CCSDS AR4JA decoder.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ldpc_fixed_pkg is
  subtype llr_t is signed(7 downto 0);
  subtype mag_t is unsigned(6 downto 0);
  type llr_array_t is array (natural range <>) of llr_t;

  function sat_llr(value : integer) return llr_t;
  function llr_magnitude(value : llr_t) return mag_t;
  function normalize_3_4(value : mag_t) return mag_t;
  function sat_add(a : llr_t; b : llr_t) return llr_t;
  function sat_sub(a : llr_t; b : llr_t) return llr_t;

  -- Normalized min-sum check-node update. Output bounds must match input bounds.
  -- Each output excludes its own input; degree < 2 is defined as all zeros.
  procedure check_node_min_sum(
    inputs  : in  llr_array_t;
    outputs : out llr_array_t
  );

  -- Variable-node extrinsic update:
  -- extrinsic(i) = channel_llr + sum(check_messages(j), j /= i).
  -- Accumulation is done in integer precision and saturated once per output.
  procedure variable_node_extrinsic(
    channel_llr    : in  llr_t;
    check_messages : in  llr_array_t;
    extrinsic      : out llr_array_t
  );

  -- Posterior LLR = channel LLR + all incoming check-node messages.
  function variable_node_posterior(
    channel_llr    : llr_t;
    check_messages : llr_array_t
  ) return llr_t;
end package ldpc_fixed_pkg;

package body ldpc_fixed_pkg is
  function sat_llr(value : integer) return llr_t is
    variable clipped : integer;
  begin
    if value > 127 then
      clipped := 127;
    elsif value < -128 then
      clipped := -128;
    else
      clipped := value;
    end if;
    return to_signed(clipped, 8);
  end function;

  -- Keep the magnitude datapath narrow. Widen before negation so -128
  -- is representable as +128, then saturate it to the 7-bit magnitude max.
  function llr_magnitude(value : llr_t) return mag_t is
    variable wide_value : signed(8 downto 0);
    variable abs_value  : signed(8 downto 0);
    variable magnitude  : unsigned(7 downto 0);
  begin
    -- Widen before negation so -128 is representable as +128.
    wide_value := resize(value, wide_value'length);
    if value(7) = '1' then
      abs_value := -wide_value;
      magnitude := unsigned(abs_value(7 downto 0));
    else
      magnitude := unsigned(wide_value(7 downto 0));
    end if;

    -- Saturate magnitudes >= 128 to the 7-bit maximum.
    if magnitude(7) = '1' then
      return to_unsigned(127, 7);
    else
      return magnitude(6 downto 0);
    end if;
  end function;

  -- Exact floor(3*value/4) using a 9-bit constant multiply (x + 2*x)
  -- followed by a two-bit shift, rather than VHDL integer arithmetic.
  function normalize_3_4(value : mag_t) return mag_t is
    variable wide_value : unsigned(8 downto 0);
    variable triple     : unsigned(8 downto 0);
  begin
    wide_value := resize(value, wide_value'length);
    triple := wide_value + shift_left(wide_value, 1);
    return resize(shift_right(triple, 2), 7);
  end function;

  -- Use a 9-bit intermediate: the exact sum/difference of two signed
  -- 8-bit operands fits in 9 bits. This avoids widening the datapath to
  -- VHDL integer width during synthesis.
  function sat_add(a : llr_t; b : llr_t) return llr_t is
    variable wide_sum : signed(8 downto 0);
  begin
    wide_sum := resize(a, wide_sum'length) + resize(b, wide_sum'length);
    if wide_sum(8 downto 7) = "01" then
      return to_signed(127, 8);
    elsif wide_sum(8 downto 7) = "10" then
      return to_signed(-128, 8);
    else
      return wide_sum(7 downto 0);
    end if;
  end function;

  function sat_sub(a : llr_t; b : llr_t) return llr_t is
    variable wide_diff : signed(8 downto 0);
  begin
    wide_diff := resize(a, wide_diff'length) - resize(b, wide_diff'length);
    if wide_diff(8 downto 7) = "01" then
      return to_signed(127, 8);
    elsif wide_diff(8 downto 7) = "10" then
      return to_signed(-128, 8);
    else
      return wide_diff(7 downto 0);
    end if;
  end function;

  procedure check_node_min_sum(
    inputs  : in  llr_array_t;
    outputs : out llr_array_t
  ) is
    -- Supports the generated AR4JA row degrees up to 18 for rate 4/5.
    -- Explicit ranges keep these temporaries narrow instead of using integer-width datapaths.
    variable min1            : integer range 0 to 128 := 128;
    variable min2            : integer range 0 to 128 := 128;
    variable min1_index      : integer := -1;
    variable magnitude       : integer range 0 to 127;
    variable selected_min    : integer range 0 to 128;
    variable scaled_min      : integer range 0 to 96;
    variable negative_parity : std_logic := '0';
    variable output_negative : boolean;
  begin
    if inputs'length < 2 then
      for i in inputs'range loop
        outputs(i) := (others => '0');
      end loop;
      return;
    end if;

    for i in inputs'range loop
      magnitude := to_integer(llr_magnitude(inputs(i)));
      if inputs(i) < to_signed(0, inputs(i)'length) then
        negative_parity := not negative_parity;
      end if;

      if magnitude < min1 then
        min2 := min1;
        min1 := magnitude;
        min1_index := i;
      elsif magnitude < min2 then
        min2 := magnitude;
      end if;
    end loop;

    for i in inputs'range loop
      if i = min1_index then
        selected_min := min2;
      else
        selected_min := min1;
      end if;

      scaled_min := to_integer(normalize_3_4(to_unsigned(selected_min, 7)));
      output_negative := (negative_parity = '1');
      if inputs(i) < to_signed(0, inputs(i)'length) then
        output_negative := not output_negative;
      end if;

      if output_negative then
        outputs(i) := sat_llr(-scaled_min);
      else
        outputs(i) := sat_llr(scaled_min);
      end if;
    end loop;
  end procedure;

  procedure variable_node_extrinsic(
    channel_llr    : in  llr_t;
    check_messages : in  llr_array_t;
    extrinsic      : out llr_array_t
  ) is
    variable accumulated : integer;
  begin
    for i in check_messages'range loop
      accumulated := to_integer(channel_llr);
      for j in check_messages'range loop
        if j /= i then
          accumulated := accumulated + to_integer(check_messages(j));
        end if;
      end loop;
      extrinsic(i) := sat_llr(accumulated);
    end loop;
  end procedure;

  function variable_node_posterior(
    channel_llr    : llr_t;
    check_messages : llr_array_t
  ) return llr_t is
    variable accumulated : integer := to_integer(channel_llr);
  begin
    for i in check_messages'range loop
      accumulated := accumulated + to_integer(check_messages(i));
    end loop;
    return sat_llr(accumulated);
  end function;
end package body ldpc_fixed_pkg;


-- SOURCE FILE: rtl/ar4ja_k4096_r12_frame_pkg.vhd
-- SPDX-License-Identifier: MIT
-- Frame contract for K=4096 rate 1/2.
library ieee; use ieee.std_logic_1164.all; use work.ldpc_fixed_pkg.all;
package ar4ja_k4096_r12_frame_pkg is
 constant AR4JA_M: positive := 2048; constant AR4JA_INFO_BITS: positive := 4096;
 constant AR4JA_TX_BITS: positive := 8192; constant AR4JA_FULL_BITS: positive := 10240;
 constant AR4JA_PUNCTURED: positive := 2048; constant AR4JA_CHECKS: positive := 6144;
 constant AR4JA_MAX_ITERATIONS: positive := 20;
 type ar4ja_llr_frame_t is array(0 to AR4JA_TX_BITS-1) of llr_t;
 type ar4ja_bit_frame_t is array(0 to AR4JA_INFO_BITS-1) of std_logic;
 type ar4ja_decode_status_t is (AR4JA_STATUS_IDLE, AR4JA_STATUS_BUSY, AR4JA_STATUS_CONVERGED, AR4JA_STATUS_MAX_ITERATIONS);
end package ar4ja_k4096_r12_frame_pkg;


-- SOURCE FILE: rtl/ar4ja_k4096_r12_graph_pkg.vhd
-- SPDX-License-Identifier: MIT
-- Compact exact representation of the CCSDS AR4JA K=4096 rate 1/2 graph.
-- Generated by delta-compressing the reference adjacency table.
-- Each active edge advances by one column per row; exceptional transitions are corrections.
library ieee;
use ieee.std_logic_1164.all;

package ar4ja_k4096_r12_graph_pkg is
  constant AR4JA_GRAPH_ROWS : positive := 6144;
  constant AR4JA_GRAPH_COLS : positive := 10240;
  constant AR4JA_GRAPH_MAX_ROW_DEGREE : positive := 6;

  subtype ar4ja_graph_col_t is integer range -1 to AR4JA_GRAPH_COLS-1;
  type ar4ja_graph_row_t is array (0 to AR4JA_GRAPH_MAX_ROW_DEGREE-1) of ar4ja_graph_col_t;
  type ar4ja_graph_rows_t is array (0 to AR4JA_GRAPH_ROWS-1) of ar4ja_graph_row_t;
  type ar4ja_graph_degree_t is array (0 to AR4JA_GRAPH_ROWS-1) of integer range 0 to AR4JA_GRAPH_MAX_ROW_DEGREE;

  type ar4ja_edge_start_row_t is array (0 to AR4JA_GRAPH_MAX_ROW_DEGREE-1) of natural range 0 to AR4JA_GRAPH_ROWS-1;
  type ar4ja_edge_start_col_t is array (0 to AR4JA_GRAPH_MAX_ROW_DEGREE-1) of ar4ja_graph_col_t;
  constant AR4JA_EDGE_START_ROW : ar4ja_edge_start_row_t := (0, 0, 0, 2048, 2048, 2048);
  constant AR4JA_EDGE_START_COL : ar4ja_edge_start_col_t := (4096, 8192, 9836, 8318, 8942, 9697);

  type ar4ja_graph_correction_t is record
    row_index  : natural range 0 to AR4JA_GRAPH_ROWS-1;
    edge_index : natural range 0 to AR4JA_GRAPH_MAX_ROW_DEGREE-1;
    correction : integer range -10000 to 10000;
  end record;
  type ar4ja_graph_corrections_t is array (natural range <>) of ar4ja_graph_correction_t;
  constant AR4JA_GRAPH_CORRECTIONS : ar4ja_graph_corrections_t(0 to 60) := (
    (404, 2, -512),
    (512, 1, -512),
    (512, 2, -1132),
    (2048, 0, -6144),
    (2048, 1, -7680),
    (2048, 2, -4096),
    (2079, 5, -512),
    (2322, 4, -512),
    (2434, 3, -512),
    (2560, 3, 761),
    (2560, 4, 710),
    (2560, 5, 381),
    (2636, 4, -512),
    (2697, 3, -512),
    (2722, 5, -512),
    (3072, 3, -624),
    (3072, 4, -217),
    (3072, 5, -334),
    (3321, 3, -512),
    (3365, 4, -512),
    (3568, 5, -512),
    (3584, 3, 240),
    (3584, 4, -343),
    (3584, 5, 296),
    (3593, 3, -512),
    (3708, 4, -512),
    (3784, 5, -512),
    (4096, 0, -2048),
    (4096, 1, -928),
    (4096, 2, -4580),
    (4096, 3, -2492),
    (4096, 4, -2211),
    (4096, 5, -1848),
    (4383, 4, -512),
    (4512, 1, -512),
    (4549, 3, -512),
    (4580, 2, -512),
    (4608, 1, -1036),
    (4608, 2, 232),
    (4608, 3, 771),
    (4608, 4, 669),
    (4738, 4, -512),
    (4802, 3, -512),
    (4860, 2, -512),
    (5036, 1, -512),
    (5120, 1, 331),
    (5120, 2, -881),
    (5120, 3, 378),
    (5120, 4, 409),
    (5217, 1, -512),
    (5229, 2, -512),
    (5353, 4, -512),
    (5448, 3, -512),
    (5632, 1, 145),
    (5632, 2, 116),
    (5632, 3, -880),
    (5632, 4, -94),
    (5816, 3, -512),
    (5959, 4, -512),
    (6096, 1, -512),
    (6137, 2, -512)
  );

  function ar4ja_row_degree(row_index : natural) return natural;
  function ar4ja_row_col(row_index : natural; edge_index : natural) return ar4ja_graph_col_t;
end package ar4ja_k4096_r12_graph_pkg;

package body ar4ja_k4096_r12_graph_pkg is
  function ar4ja_row_degree(row_index : natural) return natural is
  begin
    assert row_index < AR4JA_GRAPH_ROWS report "AR4JA row index out of range" severity failure;
    if row_index < AR4JA_GRAPH_ROWS / 3 then
      return 3;
    else
      return AR4JA_GRAPH_MAX_ROW_DEGREE;
    end if;
  end function;

  function ar4ja_row_col(row_index : natural; edge_index : natural) return ar4ja_graph_col_t is
    variable column_value : integer;
  begin
    assert row_index < AR4JA_GRAPH_ROWS report "AR4JA row index out of range" severity failure;
    assert edge_index < AR4JA_GRAPH_MAX_ROW_DEGREE report "AR4JA edge index out of range" severity failure;
    if row_index < AR4JA_EDGE_START_ROW(edge_index) then
      return -1;
    end if;

    column_value := AR4JA_EDGE_START_COL(edge_index)
                  + integer(row_index - AR4JA_EDGE_START_ROW(edge_index));
    for i in AR4JA_GRAPH_CORRECTIONS'range loop
      if AR4JA_GRAPH_CORRECTIONS(i).edge_index = edge_index
         and AR4JA_GRAPH_CORRECTIONS(i).row_index <= row_index then
        column_value := column_value + AR4JA_GRAPH_CORRECTIONS(i).correction;
      end if;
    end loop;
    return column_value;
  end function;
end package body ar4ja_k4096_r12_graph_pkg;


-- SOURCE FILE: rtl/ar4ja_k4096_r12_decoder.vhd
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

            -- Pass only active edges. The higher-rate AR4JA matrices have
            -- row degrees greater than six; padded zero entries are not edges.
            check_node_min_sum(q(0 to degree - 1), r_new(0 to degree - 1));

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
