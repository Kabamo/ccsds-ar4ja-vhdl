# Decoder throughput budget

## Scope

This is a source-level cycle budget for the current sequential prototype in `rtl/ar4ja_1024_decoder.vhd`. It is not a Vivado timing result and does not establish an achievable clock frequency.

## Current control flow

Each layered normalized-min-sum iteration contains two sequential sweeps:

1. `PROCESS_ROW`: one parity-check row per clock, over 1536 rows.
2. `CHECK_SYNDROME`: one parity-check row per clock, over 1536 rows.

Therefore, the nominal sweep cost is:

| Item | Cycles |
|---|---:|
| One row-processing sweep | 1536 |
| One syndrome-check sweep | 1536 |
| One full iteration | 3072 |
| 20 iterations (configured maximum) | 61,440 |

A few control cycles are additional. Exact latency depends on the iteration at which syndrome convergence is detected.

## 40 Mbit/s input-rate budget

The transmitted frame contains 2048 coded bits. At 40 Mbit/s, the input frame interval is:

`2048 / 40,000,000 = 51.2 us`

At 100 MHz, that interval contains 5120 clock cycles. The 20-iteration worst-case sequential budget of about 61,440 cycles is 12 times larger, before accounting for any other integration overhead. To complete the full worst-case budget within 51.2 us would require approximately 1.2 GHz if no architectural parallelism or overlap is added; this is a budget calculation, not a proposed clock target.

The design may converge before 20 iterations, but average-case convergence is not enough to guarantee continuous 40 Mbit/s operation unless buffering, backpressure, or a specified frame-loss/latency contract permits it.

## Next measurements

Run Vivado synthesis and implementation for the intended Zynq UltraScale+ part, then record:

- LUT, FF, BRAM, and DSP utilization.
- Post-synthesis and post-route maximum frequency / worst slack.
- Latency in cycles for convergence at several iteration counts and at the maximum-iteration exit.
- Whether the input interface can accept a new frame while the previous frame is decoding.
- Whether the actual system requires a hard worst-case frame interval or can use buffering/backpressure.

Likely architectural work includes parallel row/check processing, memory banking and conflict analysis, pipelining, and/or a schedule that improves throughput. These should be evaluated against resource and timing reports rather than guessed from RTL alone.
