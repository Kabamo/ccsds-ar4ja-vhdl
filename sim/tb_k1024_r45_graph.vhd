-- SPDX-License-Identifier: MIT
-- Structural self-check for k1024_r45 generated CCSDS AR4JA graph.
library ieee; use ieee.std_logic_1164.all;
use work.ar4ja_k1024_r45_graph_pkg.all;
entity tb_k1024_r45_graph is end entity;
architecture test of tb_k1024_r45_graph is begin
 process
  variable edges : natural := 0;
  variable d : natural;
  variable c, previous : integer;
 begin
  assert AR4JA_GRAPH_ROWS=384 report "wrong check count" severity failure;
  assert AR4JA_GRAPH_COLS=1408 report "wrong internal variable count" severity failure;
  assert AR4JA_TX_BITS=1280 report "wrong transmitted frame length" severity failure;
  assert AR4JA_M=128 report "wrong puncturing/submatrix size" severity failure;
  for r in 0 to AR4JA_GRAPH_ROWS-1 loop
   d:=ar4ja_row_degree(r);
   assert d>=2 and d<=AR4JA_GRAPH_MAX_ROW_DEGREE report "invalid row degree" severity failure;
   previous:=-1;
   for e in 0 to d-1 loop
    c:=ar4ja_row_col(r,e);
    assert c>=0 and c<AR4JA_GRAPH_COLS report "edge column out of range" severity failure;
    assert c>previous report "row columns not sorted or duplicate GF(2) edge remains" severity failure;
    if r<2*AR4JA_M then
     assert c<AR4JA_TX_BITS report "punctured edge in unexpected check block" severity failure;
    end if;
    previous:=c;
    edges:=edges+1;
   end loop;
   if r>=2*AR4JA_M then
    assert ar4ja_row_col(r,d-1)=AR4JA_TX_BITS+(r-2*AR4JA_M)
      report "last-M puncturing identity is not the final sorted edge" severity failure;
   end if;
  end loop;
  report "GRAPH SUMMARY: mode=k1024_r45, rows=" & integer'image(AR4JA_GRAPH_ROWS) &
    ", cols=" & integer'image(AR4JA_GRAPH_COLS) & ", edges=" & integer'image(edges) &
    ", max_degree=" & integer'image(AR4JA_GRAPH_MAX_ROW_DEGREE) severity note;
  report "PASS: graph structure k1024_r45" severity note;
  wait;
 end process;
end architecture;
