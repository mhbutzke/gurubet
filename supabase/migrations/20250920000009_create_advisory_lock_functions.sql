-- Advisory lock helpers to prevent concurrent job executions
create or replace function public.try_advisory_lock(lock_name text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select pg_try_advisory_lock(hashtext(lock_name));
$$;

create or replace function public.advisory_unlock(lock_name text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select pg_advisory_unlock(hashtext(lock_name));
$$;
