#!/usr/bin/env python3
"""Encodeur logiciel AR4JA. Pour le test complet, voir ar4ja_pipeline.py."""
import argparse
import random
import re
import sys
from pathlib import Path
from ar4ja_pipeline import encode, matrix_mode, read_rows, syndrome_weight, TX_LENGTHS


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("matrix", type=Path)
    p.add_argument("--info", help="Chaîne binaire de longueur K; sinon génération pseudo-aléatoire.")
    p.add_argument("--seed", type=int, default=20261023)
    p.add_argument("--out", type=Path)
    a = p.parse_args()
    try:
        rows = read_rows(a.matrix)
        k, rate = matrix_mode(a.matrix)
        n = k + len(rows)
        info_text = a.info
        if info_text is None:
            rng = random.Random(a.seed)
            info_text = "".join(str(rng.getrandbits(1)) for _ in range(k))
        info_text = "".join(c for c in info_text if c not in " _\t\r\n")
        if len(info_text) != k or any(c not in "01" for c in info_text):
            raise ValueError("Il faut exactement K={} bits d'information.".format(k))
        word = encode(rows, [int(c) for c in info_text], n)
        if syndrome_weight(rows, word):
            raise RuntimeError("Syndrome non nul après encodage.")
        tx = TX_LENGTHS[(k, rate)]
        out = "K={}\nRATE={}\nFULL_BITS={}\nTX_BITS={}\nINFO_BITS={}\nFULL_CODEWORD={}\nTX_CODEWORD={}\nSYNDROME=ZERO\n".format(
            k, rate.replace("_", "/"), n, tx, info_text,
            "".join(map(str, word)), "".join(map(str, word[:tx])))
        print(out, end="")
        if a.out:
            a.out.write_text(out, encoding="utf-8")
    except (OSError, ValueError, RuntimeError) as exc:
        print("ERREUR : " + str(exc), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
