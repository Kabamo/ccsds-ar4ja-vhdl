# EDA Playground — fichiers VHDL en binômes

Chaque dossier contient exactement les deux fichiers à copier dans EDA Playground :
- `design.vhd` : sources du design original concaténées dans l'ordre de compilation ;
- `testbench.vhd` : banc AWGN correspondant.

| Configuration | Design | Testbench |
|---|---|---|
| K=1024, taux 1/2 | [design.vhd](k1024_r12/design.vhd) | [testbench.vhd](k1024_r12/testbench.vhd) |
| K=1024, taux 2/3 | [design.vhd](k1024_r23/design.vhd) | [testbench.vhd](k1024_r23/testbench.vhd) |
| K=1024, taux 4/5 | [design.vhd](k1024_r45/design.vhd) | [testbench.vhd](k1024_r45/testbench.vhd) |
| K=4096, taux 1/2 | [design.vhd](k4096_r12/design.vhd) | [testbench.vhd](k4096_r12/testbench.vhd) |
| K=4096, taux 2/3 | [design.vhd](k4096_r23/design.vhd) | [testbench.vhd](k4096_r23/testbench.vhd) |
| K=4096, taux 4/5 | [design.vhd](k4096_r45/design.vhd) | [testbench.vhd](k4096_r45/testbench.vhd) |

## Lancement

Dans EDA Playground, sélectionner **VHDL**, le simulateur **GHDL** et le standard **VHDL-2008**. Copier le fichier `design.vhd` du mode choisi dans Design et le `testbench.vhd` correspondant dans Testbench. L'entité de simulation est `tb_<tag>_awgn`, par exemple `tb_k1024_r12_awgn`.

Les sources de design sont copiées depuis les fichiers originaux de la branche `feature/multimode-ar4ja-project`, avec leurs limites de fichiers indiquées par des commentaires. Le code fonctionnel n'est pas réécrit. Les tests n'ont pas été exécutés ici ; un résultat PASS doit être confirmé par la simulation.
