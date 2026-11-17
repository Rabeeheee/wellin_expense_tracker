-- Skip auto profile creation when signup metadata has no role (e.g. Google).
-- The Flutter app then routes to /complete-profile for name + role selection.

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_role text := new.raw_user_meta_data ->> 'role';
  requested_name text := coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1));
  final_role public.user_role;
  final_status public.user_status;
  super_count int;
begin
  if requested_role is null or btrim(requested_role) = '' then
    return new;
  end if;

  select count(*) into super_count
  from public.profiles
  where role = 'super_admin' and status = 'active';

  if requested_role = 'super_admin' then
    if super_count = 0 then
      final_role := 'super_admin';
      final_status := 'active';
    else
      final_role := 'super_admin';
      final_status := 'pending';
    end if;
  else
    final_role := 'admin';
    final_status := 'active';
  end if;

  insert into public.profiles (id, name, email, role, status)
  values (new.id, requested_name, new.email, final_role, final_status)
  on conflict (id) do nothing;

  return new;
end;
$$;
