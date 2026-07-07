/ ============================================================
/  db-benchmark :: groupby :: L store BUILD step (no queries)
/  Reads headerless CSV from $DBB_CSV, writes a 16-way partitioned
/  on-disk store to $DBB_HDB (default /tmp/dbb_l_hdb), appends
/    load,<load_ns>,<nrows>
/  to $DBB_OUT.  At the 50 GB tier run with -s 4: the 16 gather+
/  sort+compress+write jobs fork as copy-on-write children in waves
/  of -s (4 children x ~7 GB + ~60 GB parent fits a 128 GB box).
/  The queries then run per-query in fresh processes with per-query
/  -s pins (groupby-l-one.q, driven by compare-l.py).
/ ============================================================
csvpath:getenv`DBB_CSV
hdbp:getenv`DBB_HDB
hdbp:$[0=count hdbp;"/tmp/dbb_l_hdb";hdbp]
ls:.z.p
cn:`id1`id2`id3`id4`id5`id6`v1`v2`v3
/ `set` not colon-assign: colon-assign would run a serial whole-table
/ column-compression pass here; the forked children compress on write.
`raw set flip cn!("SSSIIIIIF";",")0:hsym`$csvpath
n:count raw
np:16                                                                           / partitions
/ partition on HASH(id3): bucket = (numeric suffix of id3) mod np --
/ uniform and stable, computed once per DISTINCT id3 then mapped per
/ row via find.  id3-DISJOINT by construction: every id3 lives in ONE
/ partition, so any `by` containing id3 combines trivially (measured
/ q3 2.3x / q7 3x vs row-index partitioning; the rest neutral).
u:distinct raw`id3
hb:"i"$("J"$2_'string u) mod np
gp:group hb u?raw`id3                                                           / part -> rows
hdb:hsym`$hdbp
system "rm -rf ",hdbp
system "mkdir -p ",hdbp
/ pre-fork sym realize: write the FULL distinct sym domain ONCE in the
/ parent (one lock, one write), then enumerate every sym column here.
/ Forked children then do ZERO sym-file work: no lock contention and
/ no per-child re-read of the sym domain.
pe:(hsym`$hdbp,"/sym")?raze(distinct raw`id1;distinct raw`id2;u)
u:hb:pe:0#0
`raw set @[raw;`id1`id2`id3;`sym?]
/ partition writer = .Q.dpft minus the per-call sym enumeration (the
/ columns are already enumerated above): sort on f, write each column,
/ write .d, then set the parted attribute on f.
wcol:{[dd;t;i;c] @[dd;c;:;t[c]i];}
dpd:{[dd;f;c] @[dd;`.d;:;f,c where not c=f]; @[dd;f;`p#]}
wpar:{[dd;f;t] i:iasc t f; wcol[dd;t;i] each c:cols t; dpd[dd;f;c]}
wprt:{[d;p;f;t] wpar[.Q.par[d;p;`bt];f;t]; p}
/ one copy-on-write fork per partition (gather+sort+compress+write)
pres:{[y] wprt[hdb;y;`id1;raw[gp y]]} peach til np
delete raw,gp,pres from `.
.Q.gc[]                                                                         / free CSV image
(hsym`$getenv`DBB_OUT) 0: enlist "load,",(string `long$.z.p-ls),",",string n
\\
