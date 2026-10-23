#!/usr/bin/env python3
"""Décodeur logiciel normalized min-sum AR4JA. Voir ar4ja_pipeline.py."""
import argparse
import math
import random
import re
import sys
from pathlib import Path
from ar4ja_pipeline import matrix_mode, read_rows, decode_normalized_min_sum, syndrome_weight, TX_LENGTHS


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("matrix", type=Path)
    p.add_argument("tx", help="Chaîne binaire transmise, ou fichier avec TX_CODEWORD=...")
    p.add_argument("--ebn0", type=float, default=6.0)
    p.add_argument("--seed", type=int, default=12345)
    p.add_argument("--iterations", type=int, default=30)
    p.add_argument("--alpha", type=float, default=0.8)
    p.add_argument("--no-noise", action="store_true", help="LLR forts selon les bits reçus.")
    p.add_argument("--info", help="Bits d'information attendus, pour calculer le nombre d'erreurs.")
    a = p.parse_args()
    try:
        rows = read_rows(a.matrix)
        k, rate = matrix_mode(a.matrix)
        n = k + len(rows)
        tx_bits = TX_LENGTHS[(k, rate)]
        value = Path(a.tx)
        if value.is_file():
            txt = value.read_text(encoding="utf-8")
            match = re.search(r"^\s*TX_CODEWORD\s*=\s*([01]+)\s*$", txt, re.M)
            tx_text = match.group(1) if match else "".join(c for c in txt if c in "01")
        else:
            tx_text = "".join(c for c in a.tx if c in "01")
        if len(tx_text) != tx_bits or any(c not in "01" for c in tx_text):
            raise ValueError("Il faut exactement TX_BITS={} bits transmis.".format(tx_bits))
        tx = [int(c) for c in tx_text]
        rng = random.Random(a.seed)
        if a.no_noise:
            llr = [20.0 if bit == 0 else -20.0 for bit in tx]
        else:
            ebn0 = 10 ** (a.ebn0 / 10)
            r = k / tx_bits
            sigma = math.sqrt(1 / (2 * r * ebn0))
            llr = []
            for bit in tx:
                received = (1.0 if bit == 0 else -1.0) + rng.gauss(0.0, sigma)
                llr.append(2 * received / (sigma * sigma))
        hard, used, sw = decode_normalized_min_sum(rows, n, tx_bits, llr, k, a.iterations, a.alpha)
        out = "".join(map(str, hard[:k]))
        print("K={} N={} TX_BITS={} RATE={}".format(k, n, tx_bits, rate.replace("_", "/")))
        print("iterations={} syndrome_weight={}".format(used, sw))
        print("DECODED_INFO_BITS=" + out)
        if a.info:
            expected = Path(a.info).read_text(encoding="utf-8") if Path(a.info).is_file() else a.info
            match = re.search(r"^\s*INFO_BITS\s*=\s*([01]+)\s*$", expected, re.M)
            expected = match.group(1) if match else "".join(c for c in expected if c in "01")
            if len(expected) != k:
                raise ValueError("INFO attendu doit faire K={} bits.".format(k))
            errors = sum(x != y for x, y in zip(out, expected))
            print("INFO_BIT_ERRORS={}".format(errors))
            print("RESULT=" + ("PASS" if errors == 0 and sw == 0 else "FAIL"))
    except (OSError, ValueError, RuntimeError) as exc:
        print("ERREUR : " + str(exc), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
