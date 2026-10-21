# EDA Playground — packs VHDL prêts à copier-coller

Ces six documents reprennent les sources VHDL originales de la branche [`feature/multimode-ar4ja-project`](https://github.com/Kabamo/ccsds-ar4ja-vhdl/tree/feature/multimode-ar4ja-project) sans réécrire leur code. Chaque document contient :
- les quatre fichiers Design concaténés dans l'ordre de dépendance : package commun, frame package, graph package, décodeur ;
- le testbench AWGN ;
- le testbench structurel du graphe en alternative.

## Choisir le mode à tester

| K (bits d'information) | Taux | LLR transmis | Document |
|---:|:---:|---:|---|
| 1024 | 1/2 | 2048 | [Ouvrir le pack](eda-playground-k1024_r12.md) |
| 1024 | 2/3 | 1536 | [Ouvrir le pack](eda-playground-k1024_r23.md) |
| 1024 | 4/5 | 1280 | [Ouvrir le pack](eda-playground-k1024_r45.md) |
| 4096 | 1/2 | 8192 | [Ouvrir le pack](eda-playground-k4096_r12.md) |
| 4096 | 2/3 | 6144 | [Ouvrir le pack](eda-playground-k4096_r23.md) |
| 4096 | 4/5 | 5120 | [Ouvrir le pack](eda-playground-k4096_r45.md) |

## Procédure EDA Playground

1. Créer un playground VHDL avec le simulateur **GHDL** et le standard **VHDL-2008**.
2. Ouvrir le document du mode souhaité.
3. Copier tout le bloc **Design** dans le panneau Design.
4. Copier uniquement le bloc **Testbench A — AWGN smoke test** dans Testbench et choisir l'entité `tb_<mode>_awgn` comme top.
5. Lancer la simulation. Pour tester le graphe séparément, remplacer Testbench A par Testbench B et sélectionner `tb_<mode>_graph`.
6. Lire les messages de synthèse AWGN et les erreurs éventuelles dans la console.

**Important :** ces bancs AWGN utilisent le mot de code valide tout-zéro. Deux trames sont un test rapide, pas une estimation statistiquement robuste de la FER. Aucun résultat n'est présumé PASS tant que la simulation n'a pas été lancée.
