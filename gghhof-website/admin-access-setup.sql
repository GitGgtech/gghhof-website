-- GGHHOF V7: secure, invitation-based administrator access + CMS permissions
-- Additive migration. Preserves existing admin_roles and the current admin user.
-- Run once in Supabase SQL Editor. Requires the existing public.is_site_admin() helper.

create extension if not exists pgcrypto;

-- Roles: admin = full control; editor = manage published website content; viewer = read-only.
create or replace function public.is_site_content_manager()
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select exists (
    select 1 from public.admin_roles ar
    where ar.user_id = auth.uid() and ar.role in ('admin','editor')
  );
$$;
create or replace function public.get_my_admin_role()
returns text language sql stable security definer set search_path = public, extensions as $$
  select ar.role from public.admin_roles ar where ar.user_id = auth.uid() limit 1;
$$;
revoke all on function public.is_site_content_manager() from public;
revoke all on function public.get_my_admin_role() from public;
grant execute on function public.is_site_content_manager() to authenticated;
grant execute on function public.get_my_admin_role() to authenticated;

-- Public impact totals used by the website and dashboard.
create table if not exists public.public_impact (
  id integer primary key check (id = 1),
  students_trained integer not null default 0 check (students_trained >= 0),
  students_current integer not null default 0 check (students_current >= 0),
  church_projects_ongoing integer not null default 0 check (church_projects_ongoing >= 0),
  church_projects_completed integer not null default 0 check (church_projects_completed >= 0),
  ministers_receiving_monthly_allowances integer not null default 0 check (ministers_receiving_monthly_allowances >= 0),
  updated_at timestamptz not null default now()
);
insert into public.public_impact(id) values (1) on conflict (id) do nothing;
alter table public.public_impact enable row level security;
grant select on public.public_impact to anon, authenticated;
grant insert, update on public.public_impact to authenticated;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='public_impact' and policyname='Anyone can read public impact') then
    create policy "Anyone can read public impact" on public.public_impact for select using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='public_impact' and policyname='Content managers update impact') then
    create policy "Content managers update impact" on public.public_impact for all to authenticated using (public.is_site_content_manager()) with check (public.is_site_content_manager());
  end if;
end $$;

-- Content managers may manage the CMS tables already created in the initial setup.
grant select on public.team_members, public.church_projects, public.media_items, public.news_posts, public.partners to anon, authenticated;
grant insert, update, delete on public.team_members, public.church_projects, public.media_items, public.news_posts, public.partners to authenticated;
do $$
declare t text;
begin
  foreach t in array array['team_members','church_projects','media_items','news_posts','partners'] loop
    execute format('alter table public.%I enable row level security', t);
    if not exists (select 1 from pg_policies where schemaname='public' and tablename=t and policyname='Content managers manage records') then
      execute format('create policy "Content managers manage records" on public.%I for all to authenticated using (public.is_site_content_manager()) with check (public.is_site_content_manager())', t);
    end if;
  end loop;
end $$;

-- Access requests. A signup is recorded only when it carries a valid invitation.
create table if not exists public.admin_access_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  full_name text,
  email text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id)
);
alter table public.admin_access_requests enable row level security;
grant select, insert, update, delete on public.admin_access_requests to authenticated;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='admin_access_requests' and policyname='Users view own request or admins view all') then
    create policy "Users view own request or admins view all" on public.admin_access_requests for select to authenticated using (user_id=auth.uid() or public.is_site_admin());
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='admin_access_requests' and policyname='Users submit own pending request') then
    create policy "Users submit own pending request" on public.admin_access_requests for insert to authenticated with check (user_id=auth.uid() and status='pending' and reviewed_at is null and reviewed_by is null);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='admin_access_requests' and policyname='Admins manage requests') then
    create policy "Admins manage requests" on public.admin_access_requests for all to authenticated using (public.is_site_admin()) with check (public.is_site_admin());
  end if;
end $$;

-- Invitations store only a SHA-256 hash of the one-time token.
create table if not exists public.admin_invitations (
  token_hash text primary key,
  invited_email text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id)
);
alter table public.admin_invitations enable row level security;
revoke all on public.admin_invitations from anon, authenticated;

create or replace function public.create_admin_invitation(p_email text, p_token_hash text, p_expires_at timestamptz)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.is_site_admin() then raise exception 'Not authorised'; end if;
  if p_email is null or length(trim(p_email)) < 5 or p_token_hash is null or length(p_token_hash) <> 64 then raise exception 'Invalid invitation details'; end if;
  if p_expires_at <= now() or p_expires_at > now() + interval '14 days' then raise exception 'Invitation expiry must be within 14 days'; end if;
  insert into public.admin_invitations(token_hash, invited_email, expires_at, created_by)
  values (lower(p_token_hash), lower(trim(p_email)), p_expires_at, auth.uid());
end;
$$;

create or replace function public.validate_admin_invitation(p_email text, p_token text)
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select exists (
    select 1 from public.admin_invitations i
    where i.token_hash = encode(digest(p_token, 'sha256'), 'hex')
      and i.invited_email = lower(trim(p_email))
      and i.used_at is null and i.expires_at > now()
  );
$$;

-- Trigger records the request only after validating the one-time invitation.
create or replace function public.capture_invited_admin_request()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
declare token text; invitation public.admin_invitations%rowtype;
begin
  token := new.raw_user_meta_data ->> 'admin_invitation_token';
  if token is null or new.email is null then return new; end if;
  select * into invitation from public.admin_invitations
  where token_hash = encode(digest(token, 'sha256'), 'hex')
    and invited_email = lower(new.email) and used_at is null and expires_at > now()
  for update;
  if invitation.token_hash is null then
    raise exception 'A valid, unused administrator invitation for this email is required';
  end if;
  insert into public.admin_access_requests(user_id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name',''), lower(new.email))
  on conflict (user_id) do nothing;
  update public.admin_invitations set used_at=now() where token_hash=invitation.token_hash;
  return new;
end;
$$;

do $$ begin
  if not exists (select 1 from pg_trigger where tgname='gghhof_capture_invited_admin_request' and tgrelid='auth.users'::regclass) then
    create trigger gghhof_capture_invited_admin_request after insert on auth.users
    for each row execute function public.capture_invited_admin_request();
  end if;
end $$;

create or replace function public.approve_admin_access_request(request_id uuid)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare target_user uuid;
begin
  if not public.is_site_admin() then raise exception 'Not authorised'; end if;
  select user_id into target_user from public.admin_access_requests where id=request_id and status='pending' for update;
  if target_user is null then raise exception 'Pending request not found'; end if;
  insert into public.admin_roles(user_id,role) values(target_user,'editor')
  on conflict(user_id) do update set role='editor';
  update public.admin_access_requests set status='approved', reviewed_at=now(), reviewed_by=auth.uid() where id=request_id;
end;
$$;
create or replace function public.reject_admin_access_request(request_id uuid)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.is_site_admin() then raise exception 'Not authorised'; end if;
  update public.admin_access_requests set status='rejected', reviewed_at=now(), reviewed_by=auth.uid() where id=request_id and status='pending';
  if not found then raise exception 'Pending request not found'; end if;
end;
$$;
revoke all on function public.create_admin_invitation(text,text,timestamptz) from public;
revoke all on function public.validate_admin_invitation(text,text) from public;
revoke all on function public.approve_admin_access_request(uuid) from public;
revoke all on function public.reject_admin_access_request(uuid) from public;
grant execute on function public.create_admin_invitation(text,text,timestamptz) to authenticated;
grant execute on function public.validate_admin_invitation(text,text) to anon, authenticated;
grant execute on function public.approve_admin_access_request(uuid) to authenticated;
grant execute on function public.reject_admin_access_request(uuid) to authenticated;

-- Public media bucket; uploads and deletes are limited to admin/editor users.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('gghhof-public-media','gghhof-public-media',true,10485760,array['image/jpeg','image/png','image/webp','image/gif','video/mp4'])
on conflict (id) do nothing;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Public can view GGHHOF media') then
    create policy "Public can view GGHHOF media" on storage.objects for select using (bucket_id='gghhof-public-media');
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Content managers upload GGHHOF media') then
    create policy "Content managers upload GGHHOF media" on storage.objects for insert to authenticated with check (bucket_id='gghhof-public-media' and public.is_site_content_manager());
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Content managers update GGHHOF media') then
    create policy "Content managers update GGHHOF media" on storage.objects for update to authenticated using (bucket_id='gghhof-public-media' and public.is_site_content_manager()) with check (bucket_id='gghhof-public-media' and public.is_site_content_manager());
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='Content managers delete GGHHOF media') then
    create policy "Content managers delete GGHHOF media" on storage.objects for delete to authenticated using (bucket_id='gghhof-public-media' and public.is_site_content_manager());
  end if;
end $$;

-- Note: new applicants receive editor access only after owner approval.
-- Existing admin_roles rows, including the Foundation owner's admin role, are preserved.
