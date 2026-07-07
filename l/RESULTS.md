# L vs DuckDB — groupby at 50 GB (1e9 rows)

The 10 groupby questions on the same `G1_1e9_1e2_0_0` CSV (52.9 GB,
`gen_data.sh 1000000000`), run 2026-07-06.

## Setup

- Hardware: AMD EPYC 9454 (48c/96t), 125 GB RAM, Ubuntu
  (Linux 6.8.0-124), md RAID storage.
- L: release `lv3-beta-20260705` (PGO AVX-512 build). CSV re-saved as
  a 16-way `hash(id3)`-partitioned compressed store (`-s 4` build);
  each question runs in a fresh process with its measured `-s` pin
  (`S_MODE` in `compare-l.py`), twice, best-of-2 (run 1 cold mmap,
  run 2 warm).
- DuckDB: v1.5.4 (Variegata) CLI, in-memory table from the same CSV,
  default settings (96 threads), twice, best-of-2. The engines run
  sequentially, never concurrently.
- Validation: row counts exact; per-column checksums within 1e-4
  relative tolerance. The table below is from a fully-validated run.

## Load (one-time)

| step | time |
|---|---:|
| L: CSV read + 16-way partitioned store build | 73.5 s |
| DuckDB: CSV load into in-memory table | 27.1 s |

## Results (best-of-2 per query)

| q | query | L `-s` | L (s) | DuckDB (s) | DuckDB / L |
|---|---|---:|---:|---:|---:|
| q1 | sum v1 by id1 | 0 | 0.103 | 0.262 | **2.54×** |
| q2 | sum v1 by id1,id2 | 48 | 0.495 | 0.505 | **1.02×** |
| q3 | sum v1, mean v3 by id3 | 16 | 1.599 | 34.045 | **21.29×** |
| q4 | mean v1,v2,v3 by id4 | 0 | 0.128 | 0.153 | **1.20×** |
| q5 | sum v1,v2,v3 by id6 | 16 | 3.804 | 26.060 | **6.85×** |
| q6 | median v3, sd v3 by id4,id5 | 16 | 1.679 | 3.941 | **2.35×** |
| q7 | max v1 − min v2 by id3 | 16 | 1.392 | 15.337 | **11.02×** |
| q8 | top-2 v3 by id6 | 16 | 8.628 | 24.715 | **2.86×** |
| q9 | corr(v1,v2)² by id2,id4 | 48 | 0.542 | 0.651 | **1.20×** |
| q10 | sum v3, count by id1..id6 | 16 | 38.270 | 73.165 | **1.91×** |

**Total query time: L 56.6 s vs DuckDB 178.8 s (3.16×). Geomean
per-query speedup 3.08×; L faster on all 10 queries.** No OOM: q10's
1e9-row result completed on both engines. All 10 queries validated
(rows exact, checksums within 1e-4).
