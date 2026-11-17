-- Allow super admins to update/delete any transaction; users keep own-only access.

drop policy if exists "Users update own transactions" on public.transactions;
create policy "Users update own transactions"
on public.transactions for update
to authenticated
using (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
)
with check (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
);

drop policy if exists "Users delete own transactions" on public.transactions;
create policy "Users delete own transactions"
on public.transactions for delete
to authenticated
using (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
);
