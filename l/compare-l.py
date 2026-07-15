#!/usr/bin/env python3
"""db-benchmark groupby :: L vs DuckDB on the same CSV.

Builds the 16-way partitioned L store (groupby-l-build.q), runs each
of the 10 questions in a fresh L process with a per-query thread pin
(groupby-l-one.q), runs the DuckDB side (groupby-duckdb.sql), then
validates the engines agree (rows exact, checksums within tolerance)
and prints a markdown comparison table.  Stdlib only.

Binaries: `l` from $L_BIN or PATH; `duckdb` from $DUCKDB_BIN or PATH.
Usage: compare-l.py <abs-csv-path> [label]
"""
import os, re, sys, math, shutil, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
L_BIN = os.environ.get("L_BIN") or shutil.which("l")
DUCK_BIN = os.environ.get("DUCKDB_BIN") or shutil.which("duckdb")
L_Q_BUILD = os.path.join(HERE, "groupby-l-build.q")
L_Q_ONE = os.path.join(HERE, "groupby-l-one.q")
DUCK_SQL = os.path.join(HERE, "groupby-duckdb.sql")

QIDS = [f"q{i}" for i in range(1, 11)]
RELTOL = 1e-4                                                                   # cross-engine checksum tolerance

# Per-query -s pins (L worker threads; 0 = flag omitted = serial),
# measured on the 50 GB tier (EPYC 9454, s0/s16/s48 sweep): q1/q2/q9
# scan-bound -> 48; q4 tiny fold -> serial; rest -> 16 (one thread
# per store partition).  Set $L_S to force one -s on other machines.
S_MODE = {"q1": 0, "q2": 48, "q3": 16, "q4": 0, "q5": 16,
          "q6": 16, "q7": 16, "q8": 16, "q9": 48, "q10": 16}
if os.environ.get("L_S") is not None:
    S_MODE = {q: int(os.environ["L_S"]) for q in QIDS}
BUILD_S = int(os.environ.get("L_BUILD_S", "0"))                                 # -s for the build step


def fail(msg, p):
    """Exit with msg plus the failed subprocess's stderr/stdout."""
    sys.exit(f"{msg}\nSTDERR:\n{p.stderr}\nSTDOUT:\n{p.stdout}")


def l_lines(script_path, env_extra, args=()):
    """Run one L process on script_path (via stdin); return $DBB_OUT
    lines plus the CompletedProcess."""
    outf = tempfile.NamedTemporaryFile(suffix=".lout", delete=False).name
    env = dict(os.environ, DBB_OUT=outf, **env_extra)
    with open(script_path) as f:
        script = f.read()
    p = subprocess.run([L_BIN, *args], input=script, env=env,
                       capture_output=True, text=True, timeout=7200)
    try:
        with open(outf) as f:
            lines = f.read().splitlines()
    except FileNotFoundError:
        lines = []
    finally:
        try:
            os.unlink(outf)
        except FileNotFoundError:
            pass
    return lines, p


def run_l(csv):
    # If $DBB_HDB names an existing pre-built store, skip the CSV build
    # and just run the 10 pinned queries (each in its own process).
    hdb = os.environ.get("DBB_HDB", "/tmp/dbb_l_hdb")
    load_ms = None
    if os.environ.get("DBB_HDB") and os.path.isdir(hdb):
        load_ms = 0.0                                                           # pre-built store: no load to time
    else:
        args = ("-s", str(BUILD_S)) if BUILD_S else ()
        lines, p = l_lines(L_Q_BUILD, dict(DBB_CSV=csv, DBB_HDB=hdb),
                           args)
        for line in lines:
            parts = line.strip().split(",")
            if parts[0] == "load" and len(parts) >= 3:
                load_ms = int(parts[1]) / 1e6
        if load_ms is None:
            fail("L store build failed.", p)
    out = {}
    for i, q in enumerate(QIDS, 1):
        s = S_MODE[q]
        args = ("-s", str(s)) if s else ()
        lines, p = l_lines(L_Q_ONE, dict(DBB_HDB=hdb, DBB_Q=str(i)),
                           args)
        for line in lines:
            parts = line.strip().split(",")
            if parts[0] == q and len(parts) >= 4:
                out[q] = dict(t1=int(parts[1]) / 1e6,
                              t2=int(parts[2]) / 1e6,
                              rows=int(parts[3]),
                              chk=[float(x) for x in parts[4:]])
        if q not in out:
            fail(f"L {q} (-s {s}) failed.", p)
    return load_ms, out


def run_duck(csv):
    env = dict(os.environ, DBB_CSV=csv)
    with open(DUCK_SQL) as f:
        script = f.read()
    p = subprocess.run([DUCK_BIN, ":memory:"], input=script, env=env,
                       capture_output=True, text=True, timeout=7200)
    reals = [float(m) * 1000.0 for m in
             re.findall(r"Run Time \(s\):\s*real\s+([\d.eE+-]+)",
                        p.stdout)]
    if len(reals) < 21:
        fail(f"duckdb gave {len(reals)} timer lines (need 21).", p)
    load_ms = reals[0]
    runs = reals[1:21]                                                          # (q1run1,q1run2,...,q10run2)
    chk_rows = {}
    for line in p.stdout.splitlines():
        parts = line.strip().split(",")
        if parts and parts[0] in QIDS and len(parts) >= 3:
            chk_rows[parts[0]] = dict(rows=int(parts[1]),
                                      chk=[float(x) for x in parts[2:]])
    out = {}
    for i, q in enumerate(QIDS):
        cr = chk_rows[q]
        out[q] = dict(t1=runs[2 * i], t2=runs[2 * i + 1],
                      rows=cr["rows"], chk=cr["chk"])
    return load_ms, out


def close(a, b):
    if a == b:
        return True
    denom = max(abs(a), abs(b), 1e-12)
    return abs(a - b) / denom <= RELTOL


def agree(e, d):
    return (e["rows"] == d["rows"] and len(e["chk"]) == len(d["chk"])
            and all(close(a, b) for a, b in zip(e["chk"], d["chk"])))


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: compare-l.py <abs-csv-path> [label]")
    if not L_BIN:
        sys.exit("l binary not found: set $L_BIN or put `l` on PATH")
    if not DUCK_BIN:
        sys.exit("duckdb not found: set $DUCKDB_BIN or put it on PATH")
    csv = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(csv)
    nrows_file = sum(1 for _ in open(csv))

    print("# db-benchmark groupby -- L vs DuckDB")
    print(f"\ndataset: `{label}`  ({nrows_file:,} rows)\n")
    l_load, lr = run_l(csv)
    du_load, du = run_duck(csv)

    failures = []
    for q in QIDS:
        if lr[q]["rows"] != du[q]["rows"]:
            failures.append(f"{q}: rows L={lr[q]['rows']} "
                            f"duck={du[q]['rows']}")
        ec, dc = lr[q]["chk"], du[q]["chk"]
        if len(ec) != len(dc):
            failures.append(f"{q}: chk arity L={len(ec)} "
                            f"duck={len(dc)}")
            continue
        for j, (a, b) in enumerate(zip(ec, dc)):
            if not close(a, b):
                failures.append(f"{q}: chk[{j}] L={a:.6g} "
                                f"duck={b:.6g}")

    print(f"load: L {l_load:,.0f} ms | duckdb {du_load:,.0f} ms\n")
    print("| q | L -s | L best (ms) | duckdb best (ms) "
          "| speedup (duck/L) | rows | valid |")
    print("|---|---:|---:|---:|---:|---:|:--:|")
    speedups = []
    for q in QIDS:
        eb = min(lr[q]["t1"], lr[q]["t2"])
        db = min(du[q]["t1"], du[q]["t2"])
        sp = db / eb if eb > 0 else float("inf")
        speedups.append(sp)
        tag = "ok" if agree(lr[q], du[q]) else "FAIL"
        bold = "**" if sp >= 1 else ""
        print(f"| {q} | {S_MODE[q]} | {eb:,.1f} | {db:,.1f} "
              f"| {bold}{sp:.2f}x{bold} | {lr[q]['rows']:,} | {tag} |")

    geo = math.exp(sum(math.log(s) for s in speedups) / len(speedups))
    l_tot = sum(min(lr[q]["t1"], lr[q]["t2"]) for q in QIDS)
    du_tot = sum(min(du[q]["t1"], du[q]["t2"]) for q in QIDS)
    rel = "faster" if du_tot > l_tot else "slower"
    print(f"\n**total query time (best-of-2):** L {l_tot:,.0f} ms | "
          f"duckdb {du_tot:,.0f} ms -> L {du_tot/l_tot:.2f}x {rel}")
    who = "L faster" if geo > 1 else "duckdb faster"
    print(f"**geomean per-query speedup (duck/L):** {geo:.2f}x ({who})")

    if failures:
        print("\n### VALIDATION FAILURES")
        for f in failures:
            print(f"- {f}")
        sys.exit(1)
    print("\n### all 10 queries: L and DuckDB agree "
          f"(rows exact, checksums within {RELTOL:.0e})")


if __name__ == "__main__":
    main()
