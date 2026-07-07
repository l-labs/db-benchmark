# L — db-benchmark groupby solution

[L](https://github.com/l-labs) solution for the groupby task, plus a
standalone L-vs-DuckDB driver that checks both engines agree.

## Quickstart

```sh
./l/setup-l.sh                             # check `l` (or set $L_BIN)
./l/gen_data.sh 10000000 data/G1_1e7.csv   # 0.5 GB tier (1e9 = 50 GB)
python3 l/compare-l.py "$PWD/data/G1_1e7.csv" G1_1e7
```

`compare-l.py` builds a 16-way partitioned L store from the CSV, runs
the 10 questions in both engines (twice each, best-of-2), prints a
comparison table, and validates: row counts exact, per-column
checksums within 1e-4. `$L_S` forces one `-s` (worker threads) for
all queries; `$DBB_HDB` reuses a pre-built store.

The q scripts also run standalone (L reads q from stdin):

```sh
DBB_CSV=$PWD/data/G1_1e7.csv DBB_OUT=/tmp/l.load l < l/groupby-l-build.q
DBB_HDB=/tmp/dbb_l_hdb DBB_Q=1 DBB_OUT=/tmp/l.out \
  l -s 4 < l/groupby-l-one.q && cat /tmp/l.out
```

## Files

- `groupby-l-build.q` — CSV -> 16-way `hash(id3)`-partitioned store
- `groupby-l-one.q` — one question (`$DBB_Q`=1..10) from the store
- `compare-l.py` — build + 10 pinned L processes + DuckDB + validation
- `groupby-duckdb.sql`, `gen_data.sh` — DuckDB side; data generator
- `setup-l.sh`, `ver-l.sh`, `VERSION` — binary check; pinned release

50 GB results: [RESULTS.md](RESULTS.md).
