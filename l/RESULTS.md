# L vs DuckDB — groupby at 50 GB (1e9 rows)

The 10 groupby questions on the same `G1_1e9_1e2_0_0` CSV (52.9 GB,
`gen_data.sh 1000000000`), run 2026-07-15.

## Setup

- Hardware: AMD EPYC 9454 (48c/96t), 125 GB RAM, Ubuntu
  (Linux 6.8.0-124), md RAID storage.
- L: release `lv3-beta-20260716` (PGO AVX-512 build). CSV re-saved as
  a 16-way `hash(id3)`-partitioned compressed store; each question runs
  in a fresh process with its measured `-s` pin (`S_MODE` in
  `compare-l.py`), twice, best-of-2 (run 1 cold mmap, run 2 warm).
- DuckDB: v1.5.4 (Variegata) CLI, in-memory table from the same CSV,
  default settings (96 threads), twice, best-of-2. The engines run
  sequentially, never concurrently.
- Validation: row counts exact; per-column checksums within 1e-4
  relative tolerance. The table below is from a fully-validated run.

## Load (one-time)

| step | time |
|---|---:|
| L: CSV read + 16-way partitioned store build | 90.6 s |
| DuckDB: CSV load into in-memory table | 31.1 s |

## Results (best-of-2 per query)

| q | query | L `-s` | L (s) | DuckDB (s) | DuckDB / L |
|---|---|---:|---:|---:|---:|
| q1 | sum v1 by id1 | 0 | 0.085 | 0.266 | **3.11×** |
| q2 | sum v1 by id1,id2 | 48 | 0.524 | 0.504 | 0.96× |
| q3 | sum v1, mean v3 by id3 | 16 | 1.939 | 31.617 | **16.30×** |
| q4 | mean v1,v2,v3 by id4 | 0 | 0.105 | 0.154 | **1.47×** |
| q5 | sum v1,v2,v3 by id6 | 16 | 3.195 | 25.426 | **7.96×** |
| q6 | median v3, sd v3 by id4,id5 | 16 | 1.670 | 4.272 | **2.56×** |
| q7 | max v1 − min v2 by id3 | 16 | 1.651 | 13.153 | **7.97×** |
| q8 | top-2 v3 by id6 | 16 | 9.380 | 26.518 | **2.83×** |
| q9 | corr(v1,v2)² by id2,id4 | 48 | 0.582 | 0.653 | **1.12×** |
| q10 | sum v3, count by id1..id6 | 16 | 33.845 | 71.636 | **2.12×** |

**Total query time: L 53.0 s, DuckDB 174.2 s — 3.29× faster overall.**
**Geomean per-query speedup: 3.08× (L faster; 9 of 10 questions won).**

Notable this release: L now computes directly on compressed temporal
columns (dates/timestamps) end-to-end, and grouped weighted folds
(`wsum`/`wavg`) stream the compressed store — neither appears in these
10 questions, but both widen the store shapes that stay compressed.
