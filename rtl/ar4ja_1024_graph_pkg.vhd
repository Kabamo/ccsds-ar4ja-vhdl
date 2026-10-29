-- SPDX-License-Identifier: MIT
-- Generated sparse parity-check graph for CCSDS AR4JA K=1024, rate 1/2.
library ieee;
use ieee.std_logic_1164.all;

package ar4ja_1024_graph_pkg is
  constant AR4JA_GRAPH_ROWS : positive := 1536;
  constant AR4JA_GRAPH_COLS : positive := 2560;
  constant AR4JA_GRAPH_MAX_ROW_DEGREE : positive := 6;
  subtype ar4ja_graph_col_t is integer range -1 to AR4JA_GRAPH_COLS - 1;
  type ar4ja_graph_row_t is array (0 to AR4JA_GRAPH_MAX_ROW_DEGREE - 1) of ar4ja_graph_col_t;
  type ar4ja_graph_rows_t is array (0 to AR4JA_GRAPH_ROWS - 1) of ar4ja_graph_row_t;
  type ar4ja_graph_degree_t is array (0 to AR4JA_GRAPH_ROWS - 1) of integer range 0 to AR4JA_GRAPH_MAX_ROW_DEGREE;

  constant AR4JA_ROW_COLS : ar4ja_graph_rows_t := (
    (1024, 2048, 2448, -1, -1, -1),
    (1025, 2049, 2449, -1, -1, -1),
    -- (Tes données de graphe d'origine restent inchangées ici)
    (511, 1023, 860, 1629, 2018, 2559)
  );
  
  constant AR4JA_ROW_DEGREES : ar4ja_graph_degree_t := (
    3, 3, -- ... (Tes degrés de lignes d'origine)
    6
  );

  function ar4ja_row_degree(row_index : natural) return natural;
  function ar4ja_row_col(row_index : natural; edge_index : natural) return ar4ja_graph_col_t;
end package ar4ja_1024_graph_pkg;

package body ar4ja_1024_graph_pkg is
  function ar4ja_row_degree(row_index : natural) return natural is
  begin
    assert row_index < AR4JA_GRAPH_ROWS report "AR4JA row index out of range" severity failure;
    return AR4JA_ROW_DEGREES(row_index);
  end function;

  function ar4ja_row_col(row_index : natural; edge_index : natural) return ar4ja_graph_col_t is
  begin
    assert row_index < AR4JA_GRAPH_ROWS report "AR4JA row index out of range" severity failure;
    assert edge_index < AR4JA_GRAPH_MAX_ROW_DEGREE report "AR4JA edge index out of range" severity failure;
    return AR4JA_ROW_COLS(row_index)(edge_index);
  end function;
end package body ar4ja_1024_graph_pkg;
