#!/usr/bin/env bash
# Ephemeral PostgreSQL CI only. Exercise genuine concurrent DB transactions
# instead of sequential calls inside a single DO $$ block.
set -euo pipefail

user="44444444-4444-4444-8444-444444444444"
psql -X -v ON_ERROR_STOP=1 -q <<SQL
insert into auth.users(id) values ('$user');
insert into public.commercial_credit_lots
  (user_id,kind,source,source_key,units_total)
values ('$user','document','manual','ci:single-credit',1);
SQL

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
pids=()
for i in $(seq 1 16); do
  (
    psql -X -v ON_ERROR_STOP=1 -A -t -q -c "
       select case when
         (public.commercial_reserve_credit(
           '$user','document','ci-parallel-request-$i'
         )->>'status')='reserved'
       then 1 else 0 end;"
  ) > "$tmpdir/$i.result" 2> "$tmpdir/$i.error" &
  pids+=("$!")
done

for pid in "${pids[@]}"; do wait "$pid"; done
successes="$(cat "$tmpdir"/*.result | grep -c '^1$' || true)"
if [[ "$successes" != 1 ]]; then
  echo "CRITICAL: $successes concurrent requests consumed one unit (expected 1)"
  cat "$tmpdir"/*.error
  exit 1
fi

psql -X -v ON_ERROR_STOP=1 -A -t -q -c "
do \$verify\$
declare r public.commercial_credit_lots%rowtype;
        op_count int;
begin
  select * into r from public.commercial_credit_lots
  where user_id='$user' and source_key='ci:single-credit';
  if r.units_reserved<>1 or r.units_used<>0 then
    raise exception 'Reserved % used %',r.units_reserved,r.units_used;
  end if;
  select count(*) into op_count
  from public.commercial_credit_operations
  where user_id='$user' and status='reserved';
  if op_count<>1 then raise exception 'Parallel operations %', op_count; end if;
end;
\$verify\$;"
echo "PASS: 16 overlapping reservations yield exactly 1 authorized credit"
