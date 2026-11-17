-- Expense Tracker schema for Supabase
-- Run in Supabase SQL Editor

create extension if not exists "pgcrypto";

create type public.user_role as enum ('super_admin', 'admin');
create type public.user_status as enum ('active', 'pending', 'disabled');
create type public.txn_type as enum ('income', 'expense');
create type public.txn_category as enum (
  'project_income',
  'day_to_day',
  'other_income',
  'project_expenses',
  'office_expenses',
  'room_rent',
  'electricity',
  'other_expense'
);
create type public.reminder_preset as enum (
  'electricity',
  'project_host',
  'room_rent',
  'custom'
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  email text not null,
  role public.user_role not null default 'admin',
  status public.user_status not null default 'active',
  created_at timestamptz not null default now()
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  type public.txn_type not null,
  category public.txn_category not null,
  amount numeric(12, 2) not null check (amount > 0),
  txn_date date not null default current_date,
  note text,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  preset public.reminder_preset not null default 'custom',
  amount numeric(12, 2),
  due_date date not null,
  is_recurring_monthly boolean not null default false,
  is_done boolean not null default false,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index transactions_txn_date_idx on public.transactions (txn_date desc);
create index transactions_created_by_idx on public.transactions (created_by);
create index reminders_due_date_idx on public.reminders (due_date);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger transactions_set_updated_at
before update on public.transactions
for each row execute function public.set_updated_at();

create trigger reminders_set_updated_at
before update on public.reminders
for each row execute function public.set_updated_at();

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.status = 'active'
  );
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'super_admin'
      and p.status = 'active'
  );
$$;

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_role text := coalesce(new.raw_user_meta_data ->> 'role', 'admin');
  requested_name text := coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1));
  final_role public.user_role;
  final_status public.user_status;
  super_count int;
begin
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

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user_profile();

alter table public.profiles enable row level security;
alter table public.transactions enable row level security;
alter table public.reminders enable row level security;

-- Profiles policies
create policy "Active users read active profiles"
on public.profiles for select
to authenticated
using (
  status = 'active'
  or id = auth.uid()
  or public.is_super_admin()
);

create policy "Users insert own profile"
on public.profiles for insert
to authenticated
with check (id = auth.uid());

create policy "Users update own profile name"
on public.profiles for update
to authenticated
using (id = auth.uid() or public.is_super_admin())
with check (id = auth.uid() or public.is_super_admin());

create policy "Super admin manage profiles"
on public.profiles for all
to authenticated
using (public.is_super_admin())
with check (public.is_super_admin());

-- Transactions policies
create policy "Active users read transactions"
on public.transactions for select
to authenticated
using (public.is_active_user());

create policy "Active users insert own transactions"
on public.transactions for insert
to authenticated
with check (public.is_active_user() and created_by = auth.uid());

create policy "Users update own transactions"
on public.transactions for update
to authenticated
using (public.is_active_user() and created_by = auth.uid())
with check (created_by = auth.uid());

create policy "Users delete own transactions"
on public.transactions for delete
to authenticated
using (public.is_active_user() and created_by = auth.uid());

-- Reminders policies
create policy "Active users read reminders"
on public.reminders for select
to authenticated
using (public.is_active_user());

create policy "Active users insert own reminders"
on public.reminders for insert
to authenticated
with check (public.is_active_user() and created_by = auth.uid());

create policy "Users update own reminders"
on public.reminders for update
to authenticated
using (public.is_active_user() and created_by = auth.uid())
with check (created_by = auth.uid());

create policy "Users delete own reminders"
on public.reminders for delete
to authenticated
using (public.is_active_user() and created_by = auth.uid());
