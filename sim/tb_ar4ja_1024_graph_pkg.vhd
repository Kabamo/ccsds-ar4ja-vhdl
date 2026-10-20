-- SPDX-License-Identifier: MIT
-- Structural self-checks for the fixed CCSDS AR4JA sparse graph.
library ieee;
use ieee.std_logic_1164.all;
use work.ar4ja_1024_graph_pkg.all;

entity tb_ar4ja_1024_graph_pkg is
end entity;

architecture test of tb_ar4ja_1024_graph_pkg is
  type col_degree_count_t is array (0 to AR4JA_GRAPH_COLS - 1) of natural;
begin
  stimulus : process
    variable col_degree_count : col_degree_count_t := (others => 0);
    variable degree3_rows : natural := 0;
    variable degree6_rows : natural := 0;
    variable edge_count : natural := 0;
    variable current_col : integer;
    variable previous_col : integer;
    variable col_degree1 : natural := 0;
    variable col_degree2 : natural := 0;
    variable col_degree3 : natural := 0;
    variable col_degree6 : natural := 0;
  begin
    assert AR4JA_GRAPH_ROWS = 1536 severity failure;
    assert AR4JA_GRAPH_COLS = 2560 severity failure;

    for r in 0 to AR4JA_GRAPH_ROWS - 1 loop
      assert ar4ja_row_degree(r) = 3 or ar4ja_row_degree(r) = 6
        report "unexpected check-node degree at row " & integer'image(r)
        severity failure;

      if ar4ja_row_degree(r) = 3 then
        degree3_rows := degree3_rows + 1;
      else
        degree6_rows := degree6_rows + 1;
      end if;

      previous_col := -1;
      for e in 0 to AR4JA_GRAPH_MAX_ROW_DEGREE - 1 loop
        current_col := ar4ja_row_col(r, e);
        if e < ar4ja_row_degree(r) then
          assert current_col >= 0 and current_col < AR4JA_GRAPH_COLS
            report "out-of-range column in row " & integer'image(r)
            severity failure;
          assert current_col > previous_col
            report "duplicate or unsorted edge in row " & integer'image(r)
            severity failure;
          previous_col := current_col;
          col_degree_count(current_col) := col_degree_count(current_col) + 1;
          edge_count := edge_count + 1;
        else
          assert current_col = -1
            report "missing row padding sentinel in row " & integer'image(r)
            severity failure;
        end if;
      end loop;
    end loop;

    assert degree3_rows = 512 report "expected 512 degree-3 checks" severity failure;
    assert degree6_rows = 1024 report "expected 1024 degree-6 checks" severity failure;
    assert edge_count = 7680 report "expected 7680 graph edges" severity failure;

    -- Column-degree histogram derived from the constructed H matrix:
    -- 512 columns of degree 1, 512 of degree 2, 1024 of degree 3, 512 of degree 6.
    for c in 0 to AR4JA_GRAPH_COLS - 1 loop
      case col_degree_count(c) is
        when 1 => col_degree1 := col_degree1 + 1;
        when 2 => col_degree2 := col_degree2 + 1;
        when 3 => col_degree3 := col_degree3 + 1;
        when 6 => col_degree6 := col_degree6 + 1;
        when others =>
          assert false
            report "unexpected variable-node degree at column " & integer'image(c)
            severity failure;
      end case;
    end loop;
    assert col_degree1 = 512 and col_degree2 = 512 and
           col_degree3 = 1024 and col_degree6 = 512
      report "variable-node degree histogram mismatch" severity failure;

    -- The 512 punctured variables are the final block. Each row in the
    -- third check block contains exactly its matching punctured variable.
    for i in 0 to 511 loop
      assert ar4ja_row_col(1024 + i, 5) = 2048 + i
        report "punctured-column identity mismatch at row " & integer'image(1024 + i)
        severity failure;
    end loop;

    report "PASS: AR4JA graph dimensions, row degrees, edges and puncturing checks completed"
      severity note;
    wait;
  end process;
end architecture;
