-- When an employee entry is settled, choose whether it hits company books.
alter table public.transactions
  add column if not exists employee_charge_company boolean not null default false;

alter table public.transactions
  drop constraint if exists employee_charge_company_requires_settled;

alter table public.transactions
  add constraint employee_charge_company_requires_settled
  check (
    not employee_charge_company
    or (is_employee_expense and employee_expense_settled)
  );

-- Pending / personal employee entries must not affect company books again after undo.
update public.transactions
set employee_charge_company = false
where is_employee_expense = true
  and employee_expense_settled = false;
