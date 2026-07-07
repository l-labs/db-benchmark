-- ============================================================
--  db-benchmark :: groupby :: duckdb solution
--  port of h2oai/db-benchmark groupby (the 10 canonical questions)
--  reads headerless CSV from $DBB_CSV; each query run twice (two
--  CREATE statements) so timer prints 21 lines: load + 20 query runs,
--  in order. Checksums (timer off) printed as csv rows q1..q10.
-- ============================================================
.mode csv
.headers off
.timer on
CREATE TABLE t AS SELECT * FROM read_csv(getenv('DBB_CSV'), header=false,
  columns={'id1':'VARCHAR','id2':'VARCHAR','id3':'VARCHAR',
           'id4':'INTEGER','id5':'INTEGER','id6':'INTEGER',
           'v1':'INTEGER','v2':'INTEGER','v3':'DOUBLE'});

CREATE OR REPLACE TEMP TABLE q1r AS SELECT id1, sum(v1) v1 FROM t GROUP BY id1;
CREATE OR REPLACE TEMP TABLE q1r AS SELECT id1, sum(v1) v1 FROM t GROUP BY id1;

CREATE OR REPLACE TEMP TABLE q2r AS SELECT id1,id2, sum(v1) v1 FROM t
  GROUP BY id1,id2;
CREATE OR REPLACE TEMP TABLE q2r AS SELECT id1,id2, sum(v1) v1 FROM t
  GROUP BY id1,id2;

CREATE OR REPLACE TEMP TABLE q3r AS SELECT id3, sum(v1) v1, avg(v3) v3
  FROM t GROUP BY id3;
CREATE OR REPLACE TEMP TABLE q3r AS SELECT id3, sum(v1) v1, avg(v3) v3
  FROM t GROUP BY id3;

CREATE OR REPLACE TEMP TABLE q4r AS SELECT id4, avg(v1) v1, avg(v2) v2,
  avg(v3) v3 FROM t GROUP BY id4;
CREATE OR REPLACE TEMP TABLE q4r AS SELECT id4, avg(v1) v1, avg(v2) v2,
  avg(v3) v3 FROM t GROUP BY id4;

CREATE OR REPLACE TEMP TABLE q5r AS SELECT id6, sum(v1) v1, sum(v2) v2,
  sum(v3) v3 FROM t GROUP BY id6;
CREATE OR REPLACE TEMP TABLE q5r AS SELECT id6, sum(v1) v1, sum(v2) v2,
  sum(v3) v3 FROM t GROUP BY id6;

CREATE OR REPLACE TEMP TABLE q6r AS SELECT id4,id5, median(v3) v3_med,
  stddev(v3) v3_sd FROM t GROUP BY id4,id5;
CREATE OR REPLACE TEMP TABLE q6r AS SELECT id4,id5, median(v3) v3_med,
  stddev(v3) v3_sd FROM t GROUP BY id4,id5;

CREATE OR REPLACE TEMP TABLE q7r AS SELECT id3, max(v1)-min(v2) rng
  FROM t GROUP BY id3;
CREATE OR REPLACE TEMP TABLE q7r AS SELECT id3, max(v1)-min(v2) rng
  FROM t GROUP BY id3;

CREATE OR REPLACE TEMP TABLE q8r AS SELECT id6, v3 FROM (SELECT id6, v3,
  row_number() OVER (PARTITION BY id6 ORDER BY v3 DESC) rn FROM t)
  WHERE rn<=2;
CREATE OR REPLACE TEMP TABLE q8r AS SELECT id6, v3 FROM (SELECT id6, v3,
  row_number() OVER (PARTITION BY id6 ORDER BY v3 DESC) rn FROM t)
  WHERE rn<=2;

CREATE OR REPLACE TEMP TABLE q9r AS SELECT id2,id4, pow(corr(v1,v2),2)
  r2 FROM t GROUP BY id2,id4;
CREATE OR REPLACE TEMP TABLE q9r AS SELECT id2,id4, pow(corr(v1,v2),2)
  r2 FROM t GROUP BY id2,id4;

CREATE OR REPLACE TEMP TABLE q10r AS SELECT id1,id2,id3,id4,id5,id6,
  sum(v3) v3, count(*) cnt FROM t GROUP BY id1,id2,id3,id4,id5,id6;
CREATE OR REPLACE TEMP TABLE q10r AS SELECT id1,id2,id3,id4,id5,id6,
  sum(v3) v3, count(*) cnt FROM t GROUP BY id1,id2,id3,id4,id5,id6;
.timer off

SELECT 'q1' qid, count(*) n, avg(v1) a1 FROM q1r;
SELECT 'q2' qid, count(*) n, avg(v1) a1 FROM q2r;
SELECT 'q3' qid, count(*) n, avg(v1) a1, avg(v3) a2 FROM q3r;
SELECT 'q4' qid, count(*) n, avg(v1) a1, avg(v2) a2, avg(v3) a3 FROM q4r;
SELECT 'q5' qid, count(*) n, avg(v1) a1, avg(v2) a2, avg(v3) a3 FROM q5r;
SELECT 'q6' qid, count(*) n, avg(v3_med) a1, avg(v3_sd) a2 FROM q6r;
SELECT 'q7' qid, count(*) n, avg(rng) a1 FROM q7r;
SELECT 'q8' qid, count(*) n, avg(v3) a1 FROM q8r;
SELECT 'q9' qid, count(*) n, avg(r2) a1 FROM q9r;
SELECT 'q10' qid, count(*) n, avg(v3) a1, avg(cnt) a2 FROM q10r;
