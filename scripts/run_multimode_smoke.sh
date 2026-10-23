#!/usr/bin/env bash
# Compile all six CCSDS AR4JA decoder variants once, then run graph checks and
# an AWGN campaign (two frames per mode by default).
# Requires GHDL with VHDL-2008.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$ROOT"
GHDL="${GHDL:-ghdl}"
STD="--std=08"
EBNO="${AWGN_EBNO_DB:-10.0}"
NFRAMES="${AWGN_FRAMES:-2}"
CSV="${AWGN_CSV:-$PWD/multimode_awgn_results.csv}"
command -v "$GHDL" >/dev/null 2>&1 || { echo "ERROR: GHDL not found" >&2; exit 127; }
echo "GHDL: $("$GHDL" --version | head -n 1)"
echo "Campaign: Eb/N0=$EBNO dB; frames/mode=$NFRAMES"
echo "CSV report: $CSV"

"$GHDL" -a "$STD" --workdir="$WORK" rtl/ldpc_fixed_pkg.vhd
for tag in k1024_r12 k1024_r23 k1024_r45 k4096_r12 k4096_r23 k4096_r45; do
  "$GHDL" -a "$STD" --workdir="$WORK" "rtl/ar4ja_${tag}_frame_pkg.vhd"
  "$GHDL" -a "$STD" --workdir="$WORK" "rtl/ar4ja_${tag}_graph_pkg.vhd"
  "$GHDL" -a "$STD" --workdir="$WORK" "rtl/ar4ja_${tag}_decoder.vhd"
done
"$GHDL" -a "$STD" --workdir="$WORK" rtl/ar4ja_configurable_pkg.vhd
"$GHDL" -a "$STD" --workdir="$WORK" rtl/ar4ja_configurable_decoder.vhd

run_tb() {
  local entity="$1" source="$2"; shift 2
  echo "===== $entity ====="
  "$GHDL" -a "$STD" --workdir="$WORK" "$source"
  "$GHDL" -e "$STD" --workdir="$WORK" "$entity"
  "$GHDL" -r "$STD" --workdir="$WORK" "$entity" "$@" --assert-level=error
}

# Preserve the simulator's full AWGN summary in a quoted CSV field.
printf 'mode,ebno_db,frames,passed,summary\n' > "$CSV"
for tag in k1024_r12 k1024_r23 k1024_r45 k4096_r12 k4096_r23 k4096_r45; do
  run_tb "tb_${tag}_graph" "sim/tb_${tag}_graph.vhd"
  log="$WORK/${tag}-awgn.log"
  if ! run_tb "tb_${tag}_awgn" "sim/tb_${tag}_awgn.vhd" -gEBNO_DB="$EBNO" -gN_FRAMES="$NFRAMES" 2>&1 | tee "$log"; then
    echo "ERROR: AWGN test process failed for $tag" >&2
    exit 1
  fi
  summary="$(sed -n 's/.*AWGN SUMMARY:/AWGN SUMMARY:/p' "$log" | tail -n 1)"
  if grep -q "PASS: all AWGN frames decoded correctly at requested Eb/N0" "$log"; then
    passed=true
  else
    passed=false
  fi
  escaped_summary="${summary//\"/\"\"}"
  printf '"%s",%s,%s,%s,"%s"\n' "$tag" "$EBNO" "$NFRAMES" "$passed" "$escaped_summary" >> "$CSV"
  if [[ "$passed" != true ]]; then
    echo "ERROR: AWGN test failed for $tag; partial CSV retained at $CSV" >&2
    exit 1
  fi
done

echo "PASS: all six graph structural checks and all AWGN smoke tests passed."
echo "CSV results written to: $CSV"
echo "NOTE: two frames/mode are only a smoke test, not a statistically meaningful FER estimate."
echo "NOTE: all-zero-codeword AWGN tests do not replace independent nonzero golden vectors."
