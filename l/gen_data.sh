#!/bin/bash
# usage: gen_data.sh N OUTFILE   (group factor K fixed at 100: *_1e2_*)
# db-benchmark groupby schema, 0 NAs, unsorted; headerless CSV.
set -e
N=$1; OUT=$2; NK=$((N/100))
duckdb :memory: >/dev/null <<SQL
SELECT setseed(0.42);
COPY (
  SELECT
    'id' || lpad((1+floor(random()*100)::INTEGER)::VARCHAR,3,'0')   AS id1,
    'id' || lpad((1+floor(random()*100)::INTEGER)::VARCHAR,3,'0')   AS id2,
    'id' || lpad((1+floor(random()*$NK)::INTEGER)::VARCHAR,10,'0')  AS id3,
    (1+floor(random()*100)::INTEGER)                                AS id4,
    (1+floor(random()*100)::INTEGER)                                AS id5,
    (1+floor(random()*$NK)::INTEGER)                                AS id6,
    (1+floor(random()*5)::INTEGER)                                  AS v1,
    (1+floor(random()*15)::INTEGER)                                 AS v2,
    round(random()*100,6)                                           AS v3
  FROM range($N)
) TO '$OUT' (HEADER false, DELIMITER ',');
SQL
echo "generated $N rows -> $OUT ($(du -h "$OUT" | cut -f1))"
