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

run_tb tb_ldpc_fixed_pkg sim/tb_ldpc_fixed_pkg.vhd
run_tb tb_ar4ja_1024_frame_pkg sim/tb_ar4ja_1024_frame_pkg.vhd
run_tb tb_ar4ja_1024_graph_pkg sim/tb_ar4ja_1024_graph_pkg.vhd
run_tb tb_ar4ja_1024_reference_vector sim/tb_ar4ja_1024_reference_vector.vhd
run_tb tb_ar4ja_1024_reference_error sim/tb_ar4ja_1024_reference_error.vhd
run_tb tb_ar4ja_1024_reference_four_errors sim/tb_ar4ja_1024_reference_four_errors.vhd

# The AWGN bench reports frame failures as a warning rather than a non-zero exit.
# Capture its log and explicitly require the all-frames PASS marker.
echo
echo "===== tb_ar4ja_1024_awgn (Eb/N0=1.7 dB) ====="
"$GHDL" -a "$STD" --workdir="$WORK" sim/tb_ar4ja_1024_awgn.vhd
"$GHDL" -e "$STD" --workdir="$WORK" tb_ar4ja_1024_awgn
if ! "$GHDL" -r "$STD" --workdir="$WORK" tb_ar4ja_1024_awgn \
  -gEBNO_DB=1.7 -gN_FRAMES="${AWGN_FRAMES:-2}" --assert-level=error 2>&1 | tee "$WORK/awgn-smoke.log"; then
  echo "ERROR: GHDL AWGN smoke test exited unsuccessfully." >&2
  exit 1
fi
if ! grep -q "PASS: all AWGN frames decoded correctly at requested Eb/N0" "$WORK/awgn-smoke.log"; then
  echo "ERROR: AWGN test did not report PASS; inspect the per-frame output above." >&2
  exit 1
fi

echo
echo "PASS: all selected K=1024 rate-1/2 smoke tests completed."
echo "NOTE: this script does not test the five not-yet-implemented configurations."
