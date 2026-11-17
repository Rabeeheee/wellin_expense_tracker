-- Optional receipt image on transactions + public receipts bucket

alter table public.transactions
  add column if not exists receipt_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'receipts',
  'receipts',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Receipt images are publicly accessible" on storage.objects;
create policy "Receipt images are publicly accessible"
on storage.objects for select
to public
using (bucket_id = 'receipts');

drop policy if exists "Users can upload own receipts" on storage.objects;
create policy "Users can upload own receipts"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can update own receipts" on storage.objects;
create policy "Users can update own receipts"
on storage.objects for update
to authenticated
using (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can delete own receipts" on storage.objects;
create policy "Users can delete own receipts"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'receipts'
  and (storage.foldername(name))[1] = auth.uid()::text
);
