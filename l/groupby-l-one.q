/ ============================================================
/  db-benchmark :: groupby :: L ONE-query driver
/  Runs ONE query (DBB_Q=1..10) from the store at $DBB_HDB, twice,
/  in a fresh process.  compare-l.py launches one L process per query
/  with that query's pinned -s mode (see S_MODE there): threading
/  pays on the big scans but costs more than the work on tiny-group
/  folds, so the -s flag has to be per-query -> per-process.
/  Output ($DBB_OUT):
/    load,<map_ns>,<nrows>            (store map time; NOT query time)
/    <qid>,<run1_ns>,<run2_ns>,<rows>,<chk1>[,<chk2>,...]
/ ============================================================
ls:.z.p
system "l ",getenv`DBB_HDB
ld:`long$.z.p-ls
q1:{select v1:sum v1 by id1 from bt}
q2:{select v1:sum v1 by id1,id2 from bt}
q3:{select v1:sum v1, v3:avg v3 by id3 from bt}
q4:{select v1:avg v1, v2:avg v2, v3:avg v3 by id4 from bt}
q5:{select v1:sum v1, v2:sum v2, v3:sum v3 by id6 from bt}
q6:{select v3_med:med v3, v3_sd:sdev v3 by id4,id5 from bt}
q7:{select rng:(max v1)-min v2 by id3 from bt}
q8:{ungroup select v3:2 sublist desc v3 by id6 from bt}                         / top-2 v3
/ q9: regression r2 by id2,id4, closed form from avg moments (identical
/ to squared population correlation); assembled as strings to keep the
/ select on one logical statement across 80-column lines.
m9:"select mx:avg v1,my:avg v2,mxy:avg v1*v2,mxx:avg v1*v1,"
m9,:"myy:avg v2*v2 by id2,id4 from bt"
u9:"update cxy:mxy-mx*my,vrx:mxx-mx*mx,vry:myy-my*my from `a9"
q9:{`a9 set value m9; value u9; select r2:(cxy*cxy)%vrx*vry from a9}
q10:{select v3:sum v3, cnt:count i by id1,id2,id3,id4,id5,id6 from bt}
/ ---- checksums: avg of each value column (rows validated separately) ----
c1:{enlist avg (0!x)`v1}
c2:c1                                                                           / q2 chk = same as q1
c3:{(avg (0!x)`v1; avg (0!x)`v3)}
c4:{(avg (0!x)`v1; avg (0!x)`v2; avg (0!x)`v3)}
c5:c4                                                                           / q5 chk = same as q4
c6:{(avg (0!x)`v3_med; avg (0!x)`v3_sd)}
c7:{enlist avg (0!x)`rng}
c8:{enlist avg (0!x)`v3}
c9:{enlist avg (0!x)`r2}
c10:{(avg (0!x)`v3; avg (0!x)`cnt)}
qs:(q1;q2;q3;q4;q5;q6;q7;q8;q9;q10)
cs:(c1;c2;c3;c4;c5;c6;c7;c8;c9;c10)
nms:("q1";"q2";"q3";"q4";"q5";"q6";"q7";"q8";"q9";"q10")
qi:("J"$getenv`DBB_Q)-1
qf:qs qi
cf:cs qi
/ t1r: gc, then one timed run of f; returns (ns;result)
t1r:{[f] .Q.gc[]; s:.z.p; r:f[]; (`long$.z.p-s;r)}
a:t1r qf                                                                        / run 1 (cold)
t1:a 0
rows:count a 1
ck:cf a 1
a:0#0                                                                           / free run 1
b:t1r qf                                                                        / run 2 (warm)
t2:b 0
line:(nms qi),",",("," sv string (t1;t2;rows)),",",("," sv string ck)
(hsym`$getenv`DBB_OUT) 0: (("load,",(string ld),",",string count bt); line)
\\
