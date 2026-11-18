-- =====================================================================
-- Beyond Basic: database setup for Supabase
-- Run this whole file once in: Supabase dashboard > SQL Editor > New query
-- =====================================================================

-- 1. Tables ------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null default '',
  email       text,
  avatar_url  text,
  created_at  timestamptz not null default now()
);

create table if not exists public.progress (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

-- 2. Row Level Security: each person can only touch their own rows -----
alter table public.profiles enable row level security;
alter table public.progress enable row level security;

create policy "profiles: read own"   on public.profiles
  for select to authenticated using (auth.uid() = id);
create policy "profiles: insert own" on public.profiles
  for insert to authenticated with check (auth.uid() = id);
create policy "profiles: update own" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create policy "progress: read own"   on public.progress
  for select to authenticated using (auth.uid() = user_id);
create policy "progress: insert own" on public.progress
  for insert to authenticated with check (auth.uid() = user_id);
create policy "progress: update own" on public.progress
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 3. Explicit API permissions (the project was created with auto-grant off)
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.progress to authenticated;

-- 4. Avatar storage: public bucket for reading, own folder for writing --
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "avatars: upload own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars: update own folder" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- 5. Upserting a file also needs read access to its own row in storage.objects
create policy "avatars: read own folder" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
