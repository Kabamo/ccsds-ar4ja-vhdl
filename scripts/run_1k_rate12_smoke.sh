#!/usr/bin/env bash
# Fast local regression for the currently implemented K=1024, rate-1/2 prototype.
# Requires GHDL with VHDL-2008 support. Run from any working directory.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$ROOT"

GHDL="${GHDL:-ghdl}"
STD="--std=08"

if ! command -v "$GHDL" >/dev/null 2>&1; then
  echo "ERROR: GHDL not found. Install GHDL or set GHDL=/path/to/ghdl." >&2
  exit 127
fi

echo "Project: LDPC AR4JA 1K 1/2"
echo "GHDL: $("$GHDL" --version | head -n 1)"
echo "Source revision: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown (source archive)')"

# Compile RTL in dependency order.
"$GHDL" -a "$STD" --workdir="$WORK" \
  rtl/ldpc_fixed_pkg.vhd \
  rtl/ar4ja_1024_frame_pkg.vhd \
  rtl/ar4ja_1024_graph_pkg.vhd \
  rtl/ar4ja_1024_decoder.vhd

run_tb() {
  local entity="$1"
  local source="$2"
  shift 2
  echo
  echo "===== $entity ====="
  "$GHDL" -a "$STD" --workdir="$WORK" "$source"
  "$GHDL" -e "$STD" --workdir="$WORK" "$entity"
  "$GHDL" -r "$STD" --workdir="$WORK" "$entity" "$@" --assert-level=error
}

# Fast deterministic functional tests.
run_tb tb_ldpc_fixed_pkg sim/tb_ldpc_fixed_pkg.vhd
run_tb tb_ar4ja_1024_frame_pkg sim/tb_ar4ja_1024_frame_pkg.vhd
run_tb tb_ar4ja_1024_graph_pkg sim/tb_ar4ja_1024_graph_pkg.vhd
run_tb tb_ar4ja_1024_reference_vector sim/tb_ar4ja_1024_reference_vector.vhd
run_tb tb_ar4ja_1024_reference_error sim/tb_ar4ja_1024_reference_error.vhd
run_tb tb_ar4ja_1024_reference_four_errors sim/tb_ar4ja_1024_reference_four_errors.vhd

# Deliberately short AWGN smoke test; increase N_FRAMES separately for statistics.
run_tb tb_ar4ja_1024_awgn sim/tb_ar4ja_1024_awgn.vhd -gEBNO_DB=1.7 -gN_FRAMES="${AWGN_FRAMES:-2}"

echo
echo "PASS: all selected K=1024 rate-1/2 smoke tests completed."
echo "NOTE: this script does not test the five not-yet-implemented configurations."
