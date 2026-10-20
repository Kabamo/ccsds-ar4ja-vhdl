#!/usr/bin/env bash
# AWGN sweep for the only implemented mode: K=1024, rate 1/2.
# Example: EBNO_POINTS="1.5 1.6 1.7 1.8" N_FRAMES=20 ./scripts/run_awgn_1k_rate12.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$ROOT"

GHDL="${GHDL:-ghdl}"
STD="--std=08"
POINTS="${EBNO_POINTS:-1.5 1.7 2.0}"
FRAMES="${N_FRAMES:-10}"

if ! command -v "$GHDL" >/dev/null 2>&1; then
  echo "ERROR: GHDL not found. Install GHDL or set GHDL=/path/to/ghdl." >&2
  exit 127
fi

"$GHDL" -a "$STD" --workdir="$WORK" \
  rtl/ldpc_fixed_pkg.vhd \
  rtl/ar4ja_1024_frame_pkg.vhd \
  rtl/ar4ja_1024_graph_pkg.vhd \
  rtl/ar4ja_1024_decoder.vhd \
  sim/tb_ar4ja_1024_awgn.vhd

"$GHDL" -e "$STD" --workdir="$WORK" tb_ar4ja_1024_awgn

echo "AWGN sweep: K=1024, rate 1/2; frames per point=$FRAMES"
echo "Eb/N0 points (dB): $POINTS"
echo "This script is intentionally limited to the currently implemented mode."

for point in $POINTS; do
  echo
  echo "===== Eb/N0=$point dB, frames=$FRAMES ====="
  "$GHDL" -r "$STD" --workdir="$WORK" tb_ar4ja_1024_awgn \
    -gEBNO_DB="$point" -gN_FRAMES="$FRAMES" --assert-level=error
done
