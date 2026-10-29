-- SPDX-License-Identifier: MIT
-- Sequential frame-parallel AR4JA normalized min-sum decoder prototype.
-- Optimized for Vivado synthesis (flat memory mapping & fast elaboration).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ldpc_fixed_pkg.all;
use work.ar4ja_1024_frame_pkg.all;
use work.ar4ja_1024_graph_pkg.all;

entity ar4ja_1024_decoder is
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
end entity ar4ja_1024_decoder;

architecture rtl of ar4ja_1024_decoder is
  type state_t is (IDLE, PROCESS_ROW, CHECK_SYNDROME, FINISH);
  type variable_llr_mem_t is array (0 to AR4JA_GRAPH_COLS - 1) of llr_t;
  
  -- Flattened memory array for r_mem to avoid complex multidimensional elaboration overhead in Vivado
  constant TOTAL_EDGES : positive := AR4JA_GRAPH_ROWS * AR4JA_GRAPH_MAX_ROW_DEGREE;
  type message_mem_flat_t is array (0 to TOTAL_EDGES - 1) of llr_t;

  signal state          : state_t := IDLE;
  signal llr_mem        : variable_llr_mem_t := (others => (others => '0'));
  signal r_mem_flat     : message_mem_flat_t := (others => (others => '0'));
  signal row_index      : natural range 0 to AR4JA_GRAPH_ROWS - 1 := 0;
  signal iteration      : natural range 0 to AR4JA_MAX_ITERATIONS := 0;
  signal syndrome_bad   : std_logic := '
