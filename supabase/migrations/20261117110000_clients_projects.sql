-- Clients, projects, and optional project link on transactions

create type public.project_status as enum ('active', 'upcoming', 'completed');

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  company text,
  email text,
  phone text,
  notes text,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete restrict,
  title text not null,
  description text,
  status public.project_status not null default 'upcoming',
  contract_value numeric(12, 2) not null default 0 check (contract_value >= 0),
  start_date date,
  due_date date,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.transactions
  add column if not exists project_id uuid references public.projects (id) on delete set null;

create index clients_created_by_idx on public.clients (created_by);
create index projects_client_id_idx on public.projects (client_id);
create index projects_status_idx on public.projects (status);
create index transactions_project_id_idx on public.transactions (project_id);

create trigger clients_set_updated_at
before update on public.clients
for each row execute function public.set_updated_at();

create trigger projects_set_updated_at
before update on public.projects
for each row execute function public.set_updated_at();

alter table public.clients enable row level security;
alter table public.projects enable row level security;

-- Clients
drop policy if exists "Active users read clients" on public.clients;
create policy "Active users read clients"
on public.clients for select
to authenticated
using (public.is_active_user());

drop policy if exists "Active users insert own clients" on public.clients;
create policy "Active users insert own clients"
on public.clients for insert
to authenticated
with check (public.is_active_user() and created_by = auth.uid());

drop policy if exists "Users update own clients" on public.clients;
create policy "Users update own clients"
on public.clients for update
to authenticated
using (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
)
with check (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
);

drop policy if exists "Users delete own clients" on public.clients;
create policy "Users delete own clients"
on public.clients for delete
to authenticated
using (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
);

-- Projects
drop policy if exists "Active users read projects" on public.projects;
create policy "Active users read projects"
on public.projects for select
to authenticated
using (public.is_active_user());

drop policy if exists "Active users insert own projects" on public.projects;
create policy "Active users insert own projects"
on public.projects for insert
to authenticated
with check (public.is_active_user() and created_by = auth.uid());

drop policy if exists "Users update own projects" on public.projects;
create policy "Users update own projects"
on public.projects for update
to authenticated
using (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
)
with check (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
);

drop policy if exists "Users delete own projects" on public.projects;
create policy "Users delete own projects"
on public.projects for delete
to authenticated
using (
  public.is_active_user()
  and (created_by = auth.uid() or public.is_super_admin())
);
