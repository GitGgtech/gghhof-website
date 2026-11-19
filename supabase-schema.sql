-- GGHHOF public website CMS foundation
-- Run in Supabase SQL Editor. Review with your technical administrator before production.
create table if not exists public.public_impact (
  id integer primary key check (id = 1),
  students_trained integer not null default 0 check (students_trained >= 0),
  students_current integer not null default 0 check (students_current >= 0),
  church_projects_ongoing integer not null default 0 check (church_projects_ongoing >= 0),
  church_projects_completed integer not null default 0 check (church_projects_completed >= 0),
  ministers_receiving_monthly_allowances integer not null default 0 check (ministers_receiving_monthly_allowances >= 0),
  updated_at timestamptz not null default now()
);
insert into public.public_impact (id) values (1) on conflict (id) do nothing;

create table if not exists public.site_content (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('leadership','church_project','training_programme','gallery','partner','news','report')),
  title text not null,
  body text,
  image_url text,
  video_url text,
  metadata jsonb not null default '{}'::jsonb,
  published boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.public_impact enable row level security;
alter table public.site_content enable row level security;

-- Public visitors can read only approved content and the public impact totals.
drop policy if exists "Public can read impact" on public.public_impact;
create policy "Public can read impact" on public.public_impact for select using (true);
drop policy if exists "Public can read published content" on public.site_content;
create policy "Public can read published content" on public.site_content for select using (published = true);

-- Authenticated users have no write access by default. Grant admin access only through
-- a trusted server-side role/claims setup after configuring and testing your admin roles.
-- Do NOT add a blanket authenticated write policy. Use Supabase custom claims or a
-- private admin-members table + security-definer function for production authorization.

-- Suggested Storage bucket: 'public-media'. Use public read for approved published media,
-- and restrict uploads/deletes to authorised admin users through Storage RLS policies.

-- Secure administrator allow-list. Add only trusted auth.users UUIDs here.
create table if not exists public.site_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.site_admins enable row level security;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.site_admins
    where user_id = (select auth.uid())
  );
$$;

-- Users cannot read or modify the administrator allow-list through the public API.
revoke all on public.site_admins from anon, authenticated;
grant select, insert, update, delete on public.public_impact to authenticated;
grant select, insert, update, delete on public.site_content to authenticated;

drop policy if exists "Admins manage impact" on public.public_impact;
create policy "Admins manage impact" on public.public_impact
  for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());
drop policy if exists "Admins manage all content" on public.site_content;
create policy "Admins manage all content" on public.site_content
  for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());

-- After the first administrator signs up via Supabase Auth, run this in SQL Editor,
-- replacing the UUID with that user's auth.users.id:
-- insert into public.site_admins (user_id) values ('YOUR-AUTH-USER-UUID');
