-- Allow any signed-in user to become super_admin when none are active.
create or replace function public.has_active_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.role = 'super_admin'
      and p.status = 'active'
  );
$$;

create or replace function public.claim_super_admin_if_none()
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  -- Serialize concurrent claims.
  perform pg_advisory_xact_lock(872314001);

  if public.has_active_super_admin() then
    raise exception 'A super admin already exists';
  end if;

  update public.profiles
  set role = 'super_admin',
      status = 'active'
  where id = auth.uid()
  returning * into result;

  if result.id is null then
    raise exception 'Profile not found';
  end if;

  return result;
end;
$$;

revoke all on function public.has_active_super_admin() from public;
revoke all on function public.claim_super_admin_if_none() from public;
grant execute on function public.has_active_super_admin() to authenticated;
grant execute on function public.claim_super_admin_if_none() to authenticated;
