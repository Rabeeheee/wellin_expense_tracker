-- Super admins can complete/delete any reminder; users keep own-only access.

drop policy if exists "Users update own reminders" on public.reminders;
create policy "Users update own reminders"
on public.reminders for update
to authenticated
using (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
)
with check (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
);

drop policy if exists "Users delete own reminders" on public.reminders;
create policy "Users delete own reminders"
on public.reminders for delete
to authenticated
using (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
);
