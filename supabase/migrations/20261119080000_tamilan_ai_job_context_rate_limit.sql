-- Durable per-user quota for the read-only TAMILAN AI job-context endpoint.
-- One row per registered user; account deletion cascades. No user text or prompt is stored.
create table if not exists private.tamilan_ai_job_context_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  minute_bucket bigint not null,
  minute_count smallint not null default 0,
  day_bucket bigint not null,
  day_count smallint not null default 0,
  updated_at timestamptz not null default pg_catalog.now(),
  constraint tamilan_ai_minute_count_nonnegative check (minute_count >= 0),
  constraint tamilan_ai_day_count_nonnegative check (day_count >= 0)
);

alter table private.tamilan_ai_job_context_rate_limits enable row level security;
revoke all on table private.tamilan_ai_job_context_rate_limits from public, anon, authenticated;

create or replace function public.tamilan_ai_consume_job_context_quota()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := (select auth.uid());
  v_is_anonymous boolean;
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_minute_bucket bigint;
  v_day_bucket bigint;
  v_minute_count smallint;
  v_day_count smallint;
  v_minute_limit constant smallint := 10;
  v_day_limit constant smallint := 100;
  v_retry integer := 0;
  v_allowed boolean;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  select u.is_anonymous into v_is_anonymous
  from auth.users u
  where u.id = v_user;

  if not found or coalesce(v_is_anonymous, true) then
    raise exception 'Registered user account required';
  end if;

  v_minute_bucket := floor(extract(epoch from v_now) / 60)::bigint;
  v_day_bucket := floor(extract(epoch from v_now) / 86400)::bigint;

  insert into private.tamilan_ai_job_context_rate_limits as current_quota
    (user_id, minute_bucket, minute_count, day_bucket, day_count, updated_at)
  values (v_user, v_minute_bucket, 1, v_day_bucket, 1, v_now)
  on conflict (user_id) do update
  set minute_bucket = excluded.minute_bucket,
      minute_count = case
        when current_quota.minute_bucket = excluded.minute_bucket
          then least(current_quota.minute_count + 1, v_minute_limit + 1)::smallint
        else 1
      end,
      day_bucket = excluded.day_bucket,
      day_count = case
        when current_quota.day_bucket = excluded.day_bucket
          then least(current_quota.day_count + 1, v_day_limit + 1)::smallint
        else 1
      end,
      updated_at = excluded.updated_at
  returning minute_count, day_count
  into v_minute_count, v_day_count;

  v_allowed := v_minute_count <= v_minute_limit and v_day_count <= v_day_limit;

  if v_minute_count > v_minute_limit then
    v_retry := greatest(v_retry,
      ceil(((v_minute_bucket + 1) * 60) - extract(epoch from v_now))::integer);
  end if;
  if v_day_count > v_day_limit then
    v_retry := greatest(v_retry,
      ceil(((v_day_bucket + 1) * 86400) - extract(epoch from v_now))::integer);
  end if;

  return pg_catalog.jsonb_build_object(
    'allowed', v_allowed,
    'minute_remaining', greatest(0, v_minute_limit - v_minute_count),
    'day_remaining', greatest(0, v_day_limit - v_day_count),
    'retry_after_seconds', case when v_allowed then 0 else greatest(1, v_retry) end
  );
end;
$function$;

revoke all on function public.tamilan_ai_consume_job_context_quota() from public, anon;
grant execute on function public.tamilan_ai_consume_job_context_quota() to authenticated;
