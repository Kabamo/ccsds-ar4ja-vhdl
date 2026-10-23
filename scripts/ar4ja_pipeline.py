#!/usr/bin/env python3
"""Chaîne de référence AR4JA : bits d'information -> encodage -> erreurs -> décodage.

Python standard uniquement. Les erreurs sont des inversions de bits transmis (BSC
déterministe), pas une simulation AWGN. Le décodeur est une référence logicielle,
pas un modèle cycle-par-cycle du RTL VHDL.
"""
import argparse
import csv
import random
import re
import sys
from pathlib import Path


TX_LENGTHS = {
    (1024, "1_2"): 2048, (1024, "2_3"): 1536, (1024, "4_5"): 1280,
    (4096, "1_2"): 8192, (4096, "2_3"): 6144, (4096, "4_5"): 5120,
}


def read_rows(path):
    text = Path(path).read_text(encoding="utf-8")
    rows = []
    for match in re.finditer(r"\(([^()]*)\)", text):
        try:
            values = [int(x.strip()) for x in match.group(1).split(",") if x.strip()]
        except ValueError:
            continue
        row = [v for v in values if v >= 0]
        if row:
            rows.append(row)
    if not rows:
        raise ValueError("Aucune ligne H trouvée dans " + str(path))
    return rows


def matrix_mode(path):
    name = Path(path).name
    match = re.search(r"rate_(1_2|2_3|4_5)_k_(1024|4096)", name, re.I)
    if not match:
        raise ValueError("Le nom de matrice doit contenir rate_1_2, rate_2_3 ou rate_4_5 et k_1024 ou k_4096.")
    return int(match.group(2)), match.group(1)


def encode(rows, info, n):
    k, m = len(info), len(rows)
    np = n - k
    if np != m:
        raise ValueError("N-K doit être égal au nombre de lignes de H.")
    coeff, rhs = [], []
    for ri, cols in enumerate(rows):
        c, b, seen = 0, 0, set()
        for col in cols:
            if not 0 <= col < n:
                raise ValueError("Colonne H hors limites à la ligne " + str(ri))
            if col in seen:
                raise ValueError("Colonne dupliquée à la ligne " + str(ri))
            seen.add(col)
            if col < k:
                b ^= info[col]
            else:
                c |= 1 << (col - k)
        coeff.append(c)
        rhs.append(b)

    # Élimination de Gauss sur GF(2), représentée par des bitsets entiers.
    pivot = 0
    for col in range(np):
        mask = 1 << col
        found = next((r for r in range(pivot, m) if coeff[r] & mask), None)
        if found is None:
            raise ValueError("Sous-matrice de parité singulière au pivot " + str(col) + "/" + str(np) +
                             ". Cette représentation de H ne permet pas cet encodage systématique direct.")
        if found != pivot:
            coeff[pivot], coeff[found] = coeff[found], coeff[pivot]
            rhs[pivot], rhs[found] = rhs[found], rhs[pivot]
        pc, pb = coeff[pivot], rhs[pivot]
        for r in range(pivot + 1, m):
            if coeff[r] & mask:
                coeff[r] ^= pc
                rhs[r] ^= pb
        pivot += 1

    pword = 0
    for r in range(m - 1, -1, -1):
        bit = rhs[r] ^ ((coeff[r] & pword).bit_count() & 1)
        if bit:
            pword |= 1 << r
    iword = sum(bit << i for i, bit in enumerate(info))
    word = iword | (pword << k)
    return [(word >> i) & 1 for i in range(n)]


def syndrome_weight(rows, hard):
    return sum((sum(hard[col] for col in row) & 1) for row in rows)


def decode_normalized_min_sum(rows, n, tx_bits, llr_tx, k, max_iter=30, alpha=0.8):
    if len(llr_tx) != tx_bits:
        raise ValueError("Longueur LLR incompatible avec TX_BITS.")
    channel = list(llr_tx) + [0.0] * (n - tx_bits)
    edges_by_check, edges_by_var, edge_vars = [], [[] for _ in range(n)], []
    for ri, row in enumerate(rows):
        edge_ids = []
        for col in row:
            if not 0 <= col < n:
                raise ValueError("Colonne H hors limites à la ligne " + str(ri))
            eid = len(edge_vars)
            edge_vars.append(col)
            edge_ids.append(eid)
            edges_by_var[col].append(eid)
        edges_by_check.append(edge_ids)

    r_msg = [0.0] * len(edge_vars)
    posterior = channel[:]
    hard = [0] * n
    for iteration in range(1, max_iter + 1):
        q_msg = [0.0] * len(edge_vars)
        for var, edge_ids in enumerate(edges_by_var):
            total = channel[var] + sum(r_msg[e] for e in edge_ids)
            posterior[var] = total
            for e in edge_ids:
                q_msg[e] = total - r_msg[e]

        for edge_ids in edges_by_check:
            if not edge_ids:
                continue
            sign_product, min1, min2, min_edge = 1.0, float("inf"), float("inf"), -1
            for e in edge_ids:
                q = q_msg[e]
                if q < 0:
                    sign_product = -sign_product
                mag = abs(q)
                if mag < min1:
                    min2, min1, min_edge = min1, mag, e
                elif mag < min2:
                    min2 = mag
            for e in edge_ids:
                q = q_msg[e]
                sign = sign_product * (-1.0 if q < 0 else 1.0)
                r_msg[e] = alpha * sign * (min2 if e == min_edge else min1)

        for var, edge_ids in enumerate(edges_by_var):
            posterior[var] = channel[var] + sum(r_msg[e] for e in edge_ids)
        hard = [0 if value >= 0 else 1 for value in posterior]
        sw = syndrome_weight(rows, hard)
        if sw == 0:
            return hard, iteration, sw
    return hard, max_iter, syndrome_weight(rows, hard)


def clean_bits(value):
    return "".join(ch for ch in value if ch not in " \t\r\n_")


def show_bits(label, bits, width):
    print("\n" + label + " (" + str(len(bits)) + " bits) :")
    for offset in range(0, len(bits), width):
        end = min(offset + width, len(bits))
        print("  {:>5}-{:<5} {}".format(offset, end - 1, bits[offset:end]))


def run_pipeline(matrix, info_text, errors=0, seed=12345, iterations=30, alpha=0.8, width=128, csv_out=Path("bits_envoyes_recus.csv")):
    rows = read_rows(matrix)
    k, rate = matrix_mode(matrix)
    m = len(rows)
    n = k + m
    tx_bits = TX_LENGTHS[(k, rate)]
    if tx_bits > n or tx_bits < k:
        raise ValueError("TX_BITS incohérent avec K et la matrice H.")
    info_text = clean_bits(info_text)
    if len(info_text) != k or any(c not in "01" for c in info_text):
        raise ValueError("Il faut exactement " + str(k) + " bits d'information (0/1).")
    if not 0 <= errors <= tx_bits:
        raise ValueError("Le nombre d'erreurs doit être compris entre 0 et TX_BITS=" + str(tx_bits) + ".")
    if iterations < 1 or not 0 < alpha <= 1 or width < 1:
        raise ValueError("Paramètres invalides : iterations>=1, 0<alpha<=1, width>=1.")

    info = [int(c) for c in info_text]
    full = encode(rows, info, n)
    sw_enc = syndrome_weight(rows, full)
    if sw_enc:
        raise RuntimeError("Le mot encodé a un syndrome non nul : " + str(sw_enc))
    full_text = "".join(map(str, full))
    tx = full[:tx_bits]
    tx_text = "".join(map(str, tx))

    rng = random.Random(seed)
    positions = sorted(rng.sample(range(tx_bits), errors))
    corrupted = tx[:]
    for pos in positions:
        corrupted[pos] ^= 1
    corrupted_text = "".join(map(str, corrupted))
    with Path(csv_out).open("w", newline="", encoding="utf-8-sig") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(["bits_envoyes", "bits_recus"])
        # Une cellule contient la chaîne complète, afin de pouvoir la copier/coller
        # et rechercher la chaîne entière dans Excel avec Ctrl+F.
        writer.writerow([tx_text, corrupted_text])
    print("CSV chaînes complètes envoyées/reçues écrit : " + str(csv_out))
    llr = [20.0 if bit == 0 else -20.0 for bit in corrupted]
    decoded, used, sw_dec = decode_normalized_min_sum(rows, n, tx_bits, llr, k, iterations, alpha)
    output = "".join(map(str, decoded[:k]))
    bad_info = [i for i, (a, b) in enumerate(zip(info_text, output)) if a != b]
    passed = output == info_text and sw_dec == 0

    print("=" * 76)
    print("CHAÎNE AR4JA : INFORMATION -> ENCODEUR -> ERREURS -> DÉCODEUR")
    print("Matrice : " + str(matrix))
    print("K={} | N={} | contrôles={} | TX_BITS={} | taux nominal {}".format(k, n, m, tx_bits, rate.replace("_", "/")))
    print("Erreurs injectées={} | seed={} | positions indexées à partir de 0".format(errors, seed))
    show_bits("1. BITS EN ENTRÉE DE L'ENCODEUR", info_text, width)
    show_bits("2. MOT DE CODE COMPLET (avant poncturation)", full_text, width)
    show_bits("3. BITS ENCODÉS TRANSMIS (sans erreurs)", tx_text, width)
    print("\n4. BITS INVERSÉS :")
    if positions:
        print("  index 0-based : " + ", ".join(map(str, positions)))
        print("  index 1-based : " + ", ".join(str(p + 1) for p in positions))
        print("  avant -> après : " + ", ".join("{}->{} (bit {})".format(tx[p], corrupted[p], p) for p in positions))
    else:
        print("  Aucun bit inversé.")
    show_bits("5. BITS EN ENTRÉE DU DÉCODEUR (après erreurs)", corrupted_text, width)
    show_bits("6. SORTIE DU DÉCODEUR : BITS D'INFORMATION, FEC retiré", output, width)
    print("\nRÉSULTAT :")
    print("  Itérations : {}/{}".format(used, iterations))
    print("  Poids du syndrome en sortie : {}".format(sw_dec))
    print("  Erreurs sur les bits d'information : {}".format(len(bad_info)))
    if bad_info:
        print("  Positions information erronées (0-based) : " + ", ".join(map(str, bad_info[:100])))
        if len(bad_info) > 100:
            print("  ... et {} autres".format(len(bad_info) - 100))
    print("  " + ("PASS : sortie identique à l'entrée" if passed else
                  "FAIL : sortie différente de l'entrée ou syndrome non nul"))
    print("=" * 76)
    return 0 if passed else 1


def main():
    parser = argparse.ArgumentParser(description="Encode, injecte exactement N erreurs de bits transmis, puis décode.")
    parser.add_argument("matrix", type=Path, help="Matrice H *_full_adj.vhd.inc")
    parser.add_argument("--info", help="Chaîne binaire d'information; si absente, saisie interactive.")
    parser.add_argument("--errors", type=int, help="Nombre exact de bits transmis à inverser (0 par défaut si interactif).")
    parser.add_argument("--seed", type=int, default=12345, help="Graine aléatoire reproductible des positions.")
    parser.add_argument("--iterations", type=int, default=30)
    parser.add_argument("--alpha", type=float, default=0.8)
    parser.add_argument("--width", type=int, default=128)
    parser.add_argument("--csv-out", type=Path, default=Path("bits_envoyes_recus.csv"),
                        help="Chemin du CSV à deux colonnes contenant chacune une chaîne binaire complète.")
    args = parser.parse_args()
    try:
        k, _ = matrix_mode(args.matrix)
        info = args.info if args.info is not None else input("Entre les {} bits d'information (0/1) : ".format(k))
        errors = args.errors
        if errors is None:
            raw = input("Nombre de bits transmis à inverser [0] : ").strip()
            errors = int(raw) if raw else 0
        return run_pipeline(args.matrix, info, errors, args.seed, args.iterations, args.alpha, args.width, args.csv_out)
    except (OSError, ValueError, RuntimeError) as exc:
        print("ERREUR : " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
