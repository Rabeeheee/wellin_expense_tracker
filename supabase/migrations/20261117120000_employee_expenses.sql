-- Employee expenses: flag, settlement, and spender

alter table public.transactions
  add column if not exists is_employee_expense boolean not null default false,
  add column if not exists employee_expense_settled boolean not null default false,
  add column if not exists spent_by uuid references public.profiles (id) on delete restrict;

alter table public.transactions
  drop constraint if exists employee_expense_spent_by_required;

alter table public.transactions
  add constraint employee_expense_spent_by_required
  check (not is_employee_expense or spent_by is not null);

alter table public.transactions
  drop constraint if exists employee_expense_settled_requires_flag;

alter table public.transactions
  add constraint employee_expense_settled_requires_flag
  check (not employee_expense_settled or is_employee_expense);

create index if not exists transactions_employee_expense_idx
  on public.transactions (txn_date desc)
  where is_employee_expense;

create index if not exists transactions_spent_by_idx
  on public.transactions (spent_by)
  where spent_by is not null;

drop policy if exists "Active users update employee expenses" on public.transactions;
create policy "Active users update employee expenses"
on public.transactions for update
to authenticated
using (public.is_active_user() and is_employee_expense = true)
with check (public.is_active_user() and is_employee_expense = true);
