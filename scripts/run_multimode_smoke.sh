#!/usr/bin/env bash
# Compile all six CCSDS AR4JA VHDL decoder variants, then run graph and AWGN smoke tests.
# Requires GHDL with VHDL-2008. The AWGN benches use the all-zero valid codeword; default Eb/N0 is 10 dB (override with AWGN_EBNO_DB).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$ROOT"
GHDL="${GHDL:-ghdl}"
STD="--std=08"
command -v "$GHDL" >/dev/null 2>&1 || { echo "ERROR: GHDL not found" >&2; exit 127; }
echo "GHDL: $("$GHDL" --version | head -n 1)"
"$GHDL" -a "$STD" --workdir="$WORK" rtl/ldpc_fixed_pkg.vhd
for tag in k1024_r12 k1024_r23 k1024_r45 k4096_r12 k4096_r23 k4096_r45; do
  "$GHDL" -a "$STD" --workdir="$WORK" "rtl/ar4ja_${tag}_frame_pkg.vhd"
  "$GHDL" -a "$STD" --workdir="$WORK" "rtl/ar4ja_${tag}_graph_pkg.vhd"
  "$GHDL" -a "$STD" --workdir="$WORK" "rtl/ar4ja_${tag}_decoder.vhd"
done
run_tb() {
  local entity="$1" source="$2"; shift 2
  echo "===== $entity ====="
  "$GHDL" -a "$STD" --workdir="$WORK" "$source"
  "$GHDL" -e "$STD" --workdir="$WORK" "$entity"
  "$GHDL" -r "$STD" --workdir="$WORK" "$entity" "$@" --assert-level=error
}
for tag in k1024_r12 k1024_r23 k1024_r45 k4096_r12 k4096_r23 k4096_r45; do
  run_tb "tb_${tag}_graph" "sim/tb_${tag}_graph.vhd"
  log="$WORK/${tag}-awgn.log"
  if ! run_tb "tb_${tag}_awgn" "sim/tb_${tag}_awgn.vhd" -gEBNO_DB="${AWGN_EBNO_DB:-10.0}" -gN_FRAMES="${AWGN_FRAMES:-1}" 2>&1 | tee "$log"; then
    echo "ERROR: AWGN test process failed for $tag" >&2; exit 1
  fi
  grep -q "PASS: all AWGN frames decoded correctly at requested Eb/N0" "$log" || {
    echo "ERROR: AWGN did not report PASS for $tag" >&2; exit 1;
  }
done
echo "PASS: all six graph structural checks and AWGN smoke tests passed."
echo "NOTE: all-zero-codeword AWGN smoke is not a substitute for independent golden vectors or FER sweeps."
