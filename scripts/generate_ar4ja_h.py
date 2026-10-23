#!/usr/bin/env python3
"""Generate sparse CCSDS AR4JA H matrices for K=1024 and K=4096,
at rates 1/2, 2/3 and 4/5.

Dependencies: numpy, scipy.
Permutation tables/function are imported from GalenMui's reference model:
https://github.com/GalenMui/ccsds-ar4ja-ldpc-decoder
Run with that repository's root on PYTHONPATH (it provides models.ar4ja_matrix).

Outputs in ./generated_h/: full and transmitted-view matrices as .mtx and .npz,
plus summary.csv. The transmitted view drops the final M punctured columns.
This is an exploratory matrix generator; validate each rate's block structure
against CCSDS 131.0-B-5 before using the matrices as a decoder golden reference.
"""
from __future__ import annotations

import csv
from pathlib import Path

from scipy.io import mmwrite
from scipy.sparse import coo_matrix, save_npz
from models.ar4ja_matrix import permutation

OUT = Path("generated_h")
INFO_LENGTHS = (1024, 4096)
# information length = K_factor * M
RATES = {"1_2": 2, "2_3": 4, "4_5": 8}


def toggle(rows: list[set[int]], r: int, c: int) -> None:
    if c in rows[r]:
        rows[r].remove(c)
    else:
        rows[r].add(c)


def ident(rows: list[set[int]], rb: int, cb: int, m: int, offset: int = 0) -> None:
    for i in range(m):
        toggle(rows, rb*m+i, offset+cb*m+i)


def perm(rows: list[set[int]], rb: int, cb: int, k: int, m: int, offset: int = 0) -> None:
    for i, c in enumerate(permutation(k, m=m)):
        toggle(rows, rb*m+i, offset+cb*m+c)


def perm_sum(rows: list[set[int]], rb: int, cb: int, ks: tuple[int, ...],
             m: int, offset: int = 0) -> None:
    for k in ks:
        perm(rows, rb, cb, k, m, offset)


def h_half(m: int) -> list[set[int]]:
    rows = [set() for _ in range(3*m)]
    ident(rows, 0, 2, m); ident(rows, 0, 4, m); perm(rows, 0, 4, 1, m)
    ident(rows, 1, 0, m); ident(rows, 1, 1, m); ident(rows, 1, 3, m)
    perm_sum(rows, 1, 4, (2, 3, 4), m)
    ident(rows, 2, 0, m); perm_sum(rows, 2, 1, (5, 6), m)
    perm_sum(rows, 2, 3, (7, 8), m); ident(rows, 2, 4, m)
    return rows


def h_two_thirds(m: int) -> list[set[int]]:
    # H_2/3 = [A | H_1/2], A has 3M rows and 2M columns.
    rows = [set() for _ in range(3*m)]
    perm_sum(rows, 1, 0, (9, 10, 11), m); ident(rows, 1, 1, m)
    ident(rows, 2, 0, m); perm_sum(rows, 2, 1, (12, 13, 14), m)
    for r, cols in enumerate(h_half(m)):
        for c in cols:
            toggle(rows, r, 2*m+c)
    return rows


def h_four_fifths(m: int) -> list[set[int]]:
    # H_4/5 = [B | H_2/3], B has 3M rows and 4M columns.
    rows = [set() for _ in range(3*m)]
    perm_sum(rows, 1, 0, (21, 22, 23), m); ident(rows, 1, 1, m)
    perm_sum(rows, 1, 2, (15, 16, 17), m); ident(rows, 1, 3, m)
    ident(rows, 2, 0, m); perm_sum(rows, 2, 1, (24, 25, 26), m)
    ident(rows, 2, 2, m); perm_sum(rows, 2, 3, (18, 19, 20), m)
    for r, cols in enumerate(h_two_thirds(m)):
        for c in cols:
            toggle(rows, r, 4*m+c)
    return rows


def sparse(rows: list[set[int]], ncols: int):
    rr, cc = [], []
    for r, cols in enumerate(rows):
        for c in sorted(cols):
            rr.append(r); cc.append(c)
    return coo_matrix(([1]*len(rr), (rr, cc)),
                      shape=(len(rows), ncols), dtype="uint8").tocsr()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    summary = []
    builders = {"1_2": h_half, "2_3": h_two_thirds, "4_5": h_four_fifths}
    for info_bits in INFO_LENGTHS:
        for rate, k_factor in RATES.items():
            m = info_bits // k_factor
            if m not in (128, 256, 512, 1024, 2048, 4096, 8192):
                raise ValueError(f"Unsupported M={m}")
            rows = builders[rate](m)
            full_cols = m * (k_factor + 3)
            hfull = sparse(rows, full_cols)
            htx = hfull[:, :full_cols-m].tocsr()
            stem = f"H_rate_{rate}_k_{info_bits}"
            mmwrite(OUT / f"{stem}_full.mtx", hfull)
            mmwrite(OUT / f"{stem}_tx.mtx", htx)
            save_npz(OUT / f"{stem}_full.npz", hfull)
            save_npz(OUT / f"{stem}_tx.npz", htx)
            summary.append({
                "rate": rate.replace("_", "/"), "information_bits": info_bits,
                "M": m, "rows": hfull.shape[0], "full_columns": hfull.shape[1],
                "transmitted_columns": htx.shape[1], "full_nnz": hfull.nnz,
                "transmitted_nnz": htx.nnz,
                "full_density_percent": 100*hfull.nnz/(hfull.shape[0]*hfull.shape[1]),
            })
            print(f"{stem}: M={m}, H_full={hfull.shape}, H_tx={htx.shape}")
    with (OUT / "summary.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(summary[0]))
        w.writeheader(); w.writerows(summary)
    (OUT / "README.txt").write_text(
        "Generated sparse CCSDS AR4JA H matrices.\n"
        "full = includes final M punctured columns; tx = drops those columns.\n"
        "See script header: rate constructions must be checked against CCSDS 131.0-B-5.\n",
        encoding="utf-8")
    print(f"Done: {OUT.resolve()}")


if __name__ == "__main__":
    main()
