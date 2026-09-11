create table if not exists public.vault_recovery_keys (
  user_id uuid primary key references auth.users(id) on delete cascade,
  recovery_key text not null check (char_length(recovery_key) between 40 and 64),
  updated_at timestamptz not null default now()
);

alter table public.vault_recovery_keys enable row level security;

revoke all on table public.vault_recovery_keys from anon;
grant select, insert, update, delete on table public.vault_recovery_keys
  to authenticated;

drop policy if exists "Users can read their recovery key"
  on public.vault_recovery_keys;
create policy "Users can read their recovery key"
  on public.vault_recovery_keys
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their recovery key"
  on public.vault_recovery_keys;
create policy "Users can create their recovery key"
  on public.vault_recovery_keys
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their recovery key"
  on public.vault_recovery_keys;
create policy "Users can update their recovery key"
  on public.vault_recovery_keys
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their recovery key"
  on public.vault_recovery_keys;
create policy "Users can delete their recovery key"
  on public.vault_recovery_keys
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
