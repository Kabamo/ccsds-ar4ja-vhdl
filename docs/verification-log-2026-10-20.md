# Verification log — 2026-10-20

This log contains user-reported EDA Playground/GHDL results. These are not CI artifacts and have not been independently reproduced in this session.

## K=1024, rate 1/2 — AWGN at 1.7 dB

### Run A: 15 frames

- Eb/N0: 1.7 dB
- Frames requested/completed: 15 / 15
- Frame failures: 0
- Information bit errors after decoding: 0
- Observed FER: 0/15
- Observed information BER: 0
- Channel hard-decision BER: 0.1114583
- Final report: `PASS: all AWGN frames decoded correctly at requested Eb/N0`

### Run B: 100 frames requested

- Eb/N0: 1.7 dB
- Frames requested/completed: 100 / 21
- Frame failures among completed frames: 0
- Information bit errors among completed frames: 0
- Process exit: 137, with message `Execution interrupted or reached maximum runtime`
- Final summary: **not produced**; this is not a completed 100-frame PASS.

The first 21 trials all reported `status=ar4ja_status_converged`, zero information bit errors and `frame_error=false`.

## Interpretation

The width fix in `llr_magnitude` removed the prior run-time bound-check failure, according to these user-reported runs. This is encouraging, but it is not a complete regression result.

- Run A has a small sample size.
- Run B was cut off by the execution environment.
- A zero observed FER on these samples does not establish a true FER of zero.
- AWGN performance tests do not prove the arithmetic primitives' exhaustive correctness or validate every graph edge case.
- No Vivado synthesis or timing result is available; the LUT target remains unmeasured.

## Immediate next action

From the repository checkout, install GHDL with VHDL-2008 support and run:

```bash
bash scripts/run_1k_rate12_smoke.sh
```

If that passes, run a longer campaign locally:

```bash
N_FRAMES=10 EBNO_POINTS="1.5 1.6 1.7 1.8 2.0" bash scripts/run_awgn_1k_rate12.sh
```

If any test fails, save the complete command output and the commit SHA before changing the RTL.
