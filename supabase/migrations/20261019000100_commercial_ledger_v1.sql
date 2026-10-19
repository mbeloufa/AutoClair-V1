-- AutoClair V1 | Lots 1-3, 6 | migration staged, NOT deployed by this PR.
-- All monetary purchases must be verified by the webhook backend.
-- No authenticated user can grant themselves credits.
create schema if not exists private;

create table if not exists public.commercial_products (
  code text primary key,
  kind text not null check (kind in ('subscription','consumable')),
  credit_kind text check (credit_kind in ('document','vehicle_360','tire','legal','trip','emergency','maintenance','identification','valuation')),
  store_product_id text unique,
  quantity integer check (quantity > 0),
  price_ttc_cents integer check (price_ttc_cents > 0),
  active boolean not null default false,
  created_at timestamptz not null default now(),
  check ((kind='subscription') or (credit_kind is not null and quantity is not null))
);
insert into public.commercial_products(code,kind,credit_kind,quantity,price_ttc_cents,active)
values
 ('premium_annual','subscription',null,null,2999,false),
 ('analysis_small','consumable','document',1,null,false),
 ('analysis_large','consumable','document',1,null,false),
 ('vehicle360_single','consumable','vehicle_360',1,null,false)
on conflict (code) do nothing;
-- All placeholders (notably small/large quantities) are inactive.

create table if not exists public.commercial_store_transactions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 store text not null check (store in ('app_store','play_store','stripe','amazon','test')),
 store_transaction_id text not null,
 product_code text not null references public.commercial_products(code),
 environment text not null check (environment in ('PRODUCTION','SANDBOX')),
 status text not null check (status in ('confirmed','refunded')),
 purchased_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique (store,store_transaction_id)
);
create index if not exists commercial_transactions_user_idx
 on public.commercial_store_transactions(user_id, purchased_at desc);

create table if not exists public.commercial_credit_lots (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check (kind in ('document','vehicle_360','tire','legal','trip','emergency','maintenance','identification','valuation')),
 source text not null check (source in ('trial','subscription','purchase','manual')),
 source_key text not null,
 transaction_id uuid references public.commercial_store_transactions(id),
 units_total integer not null check (units_total>0),
 units_reserved integer not null default 0 check (units_reserved>=0),
 units_used integer not null default 0 check (units_used>=0),
 expires_at timestamptz,
 revoked_at timestamptz,
 created_at timestamptz not null default now(),
 unique (user_id,kind,source_key),
 check (units_used+units_reserved<=units_total)
);
create index if not exists commercial_lots_spend_idx
 on public.commercial_credit_lots(user_id,kind,expires_at,created_at)
 where revoked_at is null;

create table if not exists public.commercial_credit_operations (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null,
 operation_key text not null,
 lot_id uuid not null references public.commercial_credit_lots(id),
 status text not null check (status in ('reserved','consumed','released')),
 reservation_expires_at timestamptz not null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique (user_id,kind,operation_key)
);
create index if not exists commercial_operations_expire_idx
 on public.commercial_credit_operations(reservation_expires_at)
 where status='reserved';

alter table public.commercial_products enable row level security;
alter table public.commercial_store_transactions enable row level security;
alter table public.commercial_credit_lots enable row level security;
alter table public.commercial_credit_operations enable row level security;

-- Privileges: no direct client insertion/update/deletion; receipt/ledger server only.
revoke all on public.commercial_products from public,anon,authenticated;
revoke all on public.commercial_store_transactions from public,anon,authenticated;
revoke all on public.commercial_credit_lots from public,anon,authenticated;
revoke all on public.commercial_credit_operations from public,anon,authenticated;
grant select on public.commercial_products to authenticated;
grant select on public.commercial_store_transactions to authenticated;
grant select on public.commercial_credit_lots to authenticated;
grant select on public.commercial_credit_operations to authenticated;
grant all on public.commercial_products,public.commercial_store_transactions,
  public.commercial_credit_lots,public.commercial_credit_operations to service_role;
create policy commercial_products_public_read on public.commercial_products
 for select to authenticated using (true);
create policy commercial_transactions_own_read on public.commercial_store_transactions
 for select to authenticated using ((select auth.uid())=user_id);
create policy commercial_lots_own_read on public.commercial_credit_lots
 for select to authenticated using ((select auth.uid())=user_id);
create policy commercial_operations_own_read on public.commercial_credit_operations
 for select to authenticated using ((select auth.uid())=user_id);

-- Return balances only for the caller; distinguish expiring subscription grants
-- from indefinitely valid purchased grants.
create or replace function public.get_commercial_balances()
returns jsonb language sql stable security invoker set search_path = ''
as $$
 select coalesce(jsonb_object_agg(kind, kinds), '{}'::jsonb)
 from (
   select kind, jsonb_build_object(
     'subscription',coalesce(sum(units_total-units_used-units_reserved) filter (where source='subscription'),0),
     'purchased',coalesce(sum(units_total-units_used-units_reserved) filter (where source='purchase'),0),
     'offered',coalesce(sum(units_total-units_used-units_reserved) filter (where source='trial'),0)
   ) as kinds
   from public.commercial_credit_lots
   where user_id=(select auth.uid()) and revoked_at is null
     and (expires_at is null or expires_at>now())
   group by kind
 ) summary;
$$;
revoke all on function public.get_commercial_balances() from public,anon;
grant execute on function public.get_commercial_balances() to authenticated;

-- Called ONLY by service_role after validation of RevenueCat webhook AND
-- fresh subscriber purchase lookup. A duplicate store receipt cannot grant twice.
create or replace function private.commercial_grant_verified_purchase(
 p_user_id uuid,p_store text,p_transaction_id text,p_product_code text,
 p_environment text,p_purchased_at timestamptz default now()
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_product public.commercial_products%rowtype;
        v_tx public.commercial_store_transactions%rowtype;
begin
 select * into v_product from public.commercial_products
 where code=p_product_code and active=true and kind='consumable'
 and quantity is not null and store_product_id is not null;
 if not found then raise exception 'PRODUCT_NOT_SELLABLE'; end if;
 insert into public.commercial_store_transactions
 (user_id,store,store_transaction_id,product_code,environment,status,purchased_at)
 values(p_user_id,p_store,p_transaction_id,p_product_code,p_environment,'confirmed',p_purchased_at)
 on conflict (store,store_transaction_id) do nothing;
 select * into v_tx from public.commercial_store_transactions
 where store=p_store and store_transaction_id=p_transaction_id for update;
 if v_tx.user_id <> p_user_id or v_tx.product_code <> p_product_code
 or v_tx.status <> 'confirmed' then
   raise exception 'PURCHASE_CONFLICT_OR_REFUNDED';
 end if;
 insert into public.commercial_credit_lots
 (user_id,kind,source,source_key,transaction_id,units_total)
 values (p_user_id,v_product.credit_kind,'purchase',
         p_store||':'||p_transaction_id,v_tx.id,v_product.quantity)
 on conflict (user_id,kind,source_key) do nothing;
 return jsonb_build_object('ok',true,'transaction_id',v_tx.id);
end;$$;
revoke all on function private.commercial_grant_verified_purchase(uuid,text,text,text,text,timestamptz) from public,anon,authenticated;
grant execute on function private.commercial_grant_verified_purchase(uuid,text,text,text,text,timestamptz) to service_role;

create or replace function private.commercial_revoke_purchase(
 p_user_id uuid,p_product_code text,p_store text,
 p_transaction_id text,p_environment text
) returns boolean language plpgsql security definer set search_path=''
as $$
declare v_tx public.commercial_store_transactions%rowtype;
begin
 -- Refund tombstones protect against out-of-order webhook notifications.
 insert into public.commercial_store_transactions
  (user_id,store,store_transaction_id,product_code,environment,status)
 values (p_user_id,p_store,p_transaction_id,p_product_code,p_environment,'refunded')
 on conflict (store,store_transaction_id) do update
   set status='refunded',updated_at=now()
 returning * into v_tx;
 if v_tx.user_id<>p_user_id or v_tx.product_code<>p_product_code then
    raise exception 'REFUND_PURCHASE_OWNER_MISMATCH';
 end if;
 update public.commercial_credit_lots
   set revoked_at=coalesce(revoked_at,now())
 where transaction_id=v_tx.id;
 return true;
end;$$;
revoke all on function private.commercial_revoke_purchase(uuid,text,text,text,text) from public,anon,authenticated;
grant execute on function private.commercial_revoke_purchase(uuid,text,text,text,text) to service_role;

-- Atomic reservation. Idempotence is bound to authenticated user, feature
-- and a stable request key; the external API is called only after success.
create or replace function private.commercial_reserve_credit(
 p_user_id uuid,p_kind text,p_request_key text
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_op public.commercial_credit_operations%rowtype;
        v_lot public.commercial_credit_lots%rowtype;
begin
 if length(trim(coalesce(p_request_key,'')))<12 then raise exception 'REQUEST_KEY_INVALID'; end if;
 -- Serialize all credits of this account + feature, not just matching requests.
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text||':'||p_kind,0));
 select * into v_op from public.commercial_credit_operations
 where user_id=p_user_id and kind=p_kind and operation_key=p_request_key for update;
 if found and v_op.status in ('reserved','consumed') then
   return jsonb_build_object('ok',true,'status',v_op.status,'operation_id',v_op.id);
 end if;
 -- Single complete documentary trial per account. Existing completed
 -- analyses are not retroactively given another free treatment.
 if p_kind='document' and not exists (
   select 1 from public.commercial_credit_lots
   where user_id=p_user_id and kind='document'
     and source='trial' and source_key='trial:document:v1'
 ) and not exists (
   select 1 from public.document_analyses where user_id=p_user_id
 ) then
   insert into public.commercial_credit_lots
    (user_id,kind,source,source_key,units_total)
   values(p_user_id,'document','trial','trial:document:v1',1)
   on conflict (user_id,kind,source_key) do nothing;
 end if;
 select * into v_lot from public.commercial_credit_lots
 where user_id=p_user_id and kind=p_kind and revoked_at is null
 and (expires_at is null or expires_at>now())
 and (units_total-units_used-units_reserved)>0
 order by case source when 'subscription' then 0 when 'trial' then 1 else 2 end,
          expires_at nulls last,created_at
 for update skip locked limit 1;
 if not found then return jsonb_build_object('ok',false,'status','insufficient'); end if;
 update public.commercial_credit_lots set units_reserved=units_reserved+1
 where id=v_lot.id;
 if v_op.id is null then
   insert into public.commercial_credit_operations
    (user_id,kind,operation_key,lot_id,status,reservation_expires_at)
   values(p_user_id,p_kind,p_request_key,v_lot.id,'reserved',now()+interval '45 minutes')
   returning * into v_op;
 else
   update public.commercial_credit_operations
     set lot_id=v_lot.id,status='reserved',
         reservation_expires_at=now()+interval '45 minutes',updated_at=now()
     where id=v_op.id returning * into v_op;
 end if;
 return jsonb_build_object('ok',true,'status','reserved','operation_id',v_op.id);
end;$$;
revoke all on function private.commercial_reserve_credit(uuid,text,text) from public,anon,authenticated;
grant execute on function private.commercial_reserve_credit(uuid,text,text) to service_role;

create or replace function private.commercial_finish_credit(
 p_user_id uuid,p_kind text,p_request_key text,p_success boolean
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_op public.commercial_credit_operations%rowtype;
begin
 select * into v_op from public.commercial_credit_operations
 where user_id=p_user_id and kind=p_kind and operation_key=p_request_key for update;
 if not found then return jsonb_build_object('ok',false,'status','not_found'); end if;
 if v_op.status<>'reserved' then
   return jsonb_build_object('ok',true,'status',v_op.status);
 end if;
 update public.commercial_credit_lots set units_reserved=units_reserved-1,
       units_used=units_used+(case when p_success then 1 else 0 end)
 where id=v_op.lot_id;
 update public.commercial_credit_operations set
 status=case when p_success then 'consumed' else 'released' end,updated_at=now()
 where id=v_op.id;
 return jsonb_build_object('ok',true,
   'status',case when p_success then 'consumed' else 'released' end);
end;$$;
revoke all on function private.commercial_finish_credit(uuid,text,text,boolean) from public,anon,authenticated;
grant execute on function private.commercial_finish_credit(uuid,text,text,boolean) to service_role;

-- Admin-only cleanup can release reservations abandoned past their TTL.
create or replace function private.commercial_release_expired()
returns integer language plpgsql security definer set search_path=''
as $$
declare v_count integer;
begin
 with expired as (
   update public.commercial_credit_operations
   set status='released',updated_at=now()
   where status='reserved' and reservation_expires_at<now()
   returning lot_id
 ), totals as (
   select lot_id,count(*)::integer as qty from expired group by lot_id
 ), updated as (
   update public.commercial_credit_lots l
   set units_reserved=greatest(0,l.units_reserved-t.qty)
   from totals t where l.id=t.lot_id returning l.id
 )
 select count(*) into v_count from updated;
 return v_count;
end;$$;
revoke all on function private.commercial_release_expired() from public,anon,authenticated;
grant execute on function private.commercial_release_expired() to service_role;

comment on table public.commercial_store_transactions is
 'Registre vérifié et dédupliqué des achats ; ne pas exposer les reçus aux clients.';

-- Public RPC wrappers remain completely inaccessible to anon/authenticated.
-- Private routines cannot be called from the Supabase Data API directly.
grant usage on schema private to service_role;
create or replace function public.commercial_grant_verified_purchase(
 p_user_id uuid,p_store text,p_transaction_id text,p_product_code text,
 p_environment text,p_purchased_at timestamptz default now()
) returns jsonb language sql security invoker set search_path=''
as $$ select private.commercial_grant_verified_purchase(
 p_user_id,p_store,p_transaction_id,p_product_code,p_environment,p_purchased_at); $$;
revoke all on function public.commercial_grant_verified_purchase(uuid,text,text,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.commercial_grant_verified_purchase(uuid,text,text,text,text,timestamptz) to service_role;

create or replace function public.commercial_revoke_purchase(
 p_user_id uuid,p_product_code text,p_store text,
 p_transaction_id text,p_environment text
) returns boolean language sql security invoker set search_path=''
as $ select private.commercial_revoke_purchase(
 p_user_id,p_product_code,p_store,p_transaction_id,p_environment); $;
revoke all on function public.commercial_revoke_purchase(uuid,text,text,text,text) from public,anon,authenticated;
grant execute on function public.commercial_revoke_purchase(uuid,text,text,text,text) to service_role;

create or replace function public.commercial_reserve_credit(
 p_user_id uuid,p_kind text,p_request_key text
) returns jsonb language sql security invoker set search_path=''
as $$ select private.commercial_reserve_credit(p_user_id,p_kind,p_request_key); $$;
revoke all on function public.commercial_reserve_credit(uuid,text,text) from public,anon,authenticated;
grant execute on function public.commercial_reserve_credit(uuid,text,text) to service_role;

create or replace function public.commercial_finish_credit(
 p_user_id uuid,p_kind text,p_request_key text,p_success boolean
) returns jsonb language sql security invoker set search_path=''
as $$ select private.commercial_finish_credit(p_user_id,p_kind,p_request_key,p_success); $$;
revoke all on function public.commercial_finish_credit(uuid,text,text,boolean) from public,anon,authenticated;
grant execute on function public.commercial_finish_credit(uuid,text,text,boolean) to service_role;

create or replace function public.commercial_release_expired()
returns integer language sql security invoker set search_path=''
as $$ select private.commercial_release_expired(); $$;
revoke all on function public.commercial_release_expired() from public,anon,authenticated;
grant execute on function public.commercial_release_expired() to service_role;
