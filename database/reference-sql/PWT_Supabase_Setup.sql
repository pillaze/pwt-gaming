-- PWT Esports shared community database
-- Run this once in Supabase SQL Editor.

create extension if not exists pgcrypto;

-- 1) Public player/community profiles tied to Supabase Auth
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'PWT Player',
  role text not null default 'member' check (role in ('member','admin')),
  created_at timestamptz not null default now()
);

-- Automatically create a profile after sign-up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name',
             split_part(coalesce(new.email,'PWT Player'),'@',1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- 2) Social feed posts
create table if not exists public.feed_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  post_type text not null check (post_type in ('youtube','article','announcement')),
  title text not null,
  url text,
  body text,
  created_at timestamptz not null default now()
);

-- 3) Flexible comments: site, post, match, or player
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('site','post','match','player')),
  target_id text not null,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

-- 4) Flexible reactions/likes: site, post, match, or player
create table if not exists public.reactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('site','post','match','player')),
  target_id text not null,
  reaction_type text not null default 'like' check (reaction_type = 'like'),
  created_at timestamptz not null default now(),
  unique (user_id, target_type, target_id, reaction_type)
);

-- Helpful indexes
create index if not exists idx_feed_posts_created_at on public.feed_posts(created_at desc);
create index if not exists idx_comments_target on public.comments(target_type, target_id, created_at desc);
create index if not exists idx_reactions_target on public.reactions(target_type, target_id);

-- Enable Row Level Security
alter table public.profiles enable row level security;
alter table public.feed_posts enable row level security;
alter table public.comments enable row level security;
alter table public.reactions enable row level security;

-- Tighten grants
revoke all on public.profiles from anon, authenticated;
revoke all on public.feed_posts from anon, authenticated;
revoke all on public.comments from anon, authenticated;
revoke all on public.reactions from anon, authenticated;

grant select on public.profiles to anon, authenticated;
grant select on public.feed_posts to anon, authenticated;
grant select on public.comments to anon, authenticated;
grant select on public.reactions to anon, authenticated;

grant update on public.profiles to authenticated;
grant insert, update, delete on public.feed_posts to authenticated;
grant insert, update, delete on public.comments to authenticated;
grant insert, delete on public.reactions to authenticated;

-- PROFILES
drop policy if exists "profiles public read" on public.profiles;
create policy "profiles public read"
on public.profiles for select
to anon, authenticated
using (true);

drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- FEED POSTS
drop policy if exists "feed public read" on public.feed_posts;
create policy "feed public read"
on public.feed_posts for select
to anon, authenticated
using (true);

drop policy if exists "admins create feed posts" on public.feed_posts;
create policy "admins create feed posts"
on public.feed_posts for insert
to authenticated
with check (
  author_id = auth.uid()
  and exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);

drop policy if exists "admins update feed posts" on public.feed_posts;
create policy "admins update feed posts"
on public.feed_posts for update
to authenticated
using (
  exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
)
with check (
  exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);

drop policy if exists "admins delete feed posts" on public.feed_posts;
create policy "admins delete feed posts"
on public.feed_posts for delete
to authenticated
using (
  exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);

-- COMMENTS
drop policy if exists "comments public read" on public.comments;
create policy "comments public read"
on public.comments for select
to anon, authenticated
using (true);

drop policy if exists "signed in users create comments" on public.comments;
create policy "signed in users create comments"
on public.comments for insert
to authenticated
with check (author_id = auth.uid());

drop policy if exists "users update own comments" on public.comments;
create policy "users update own comments"
on public.comments for update
to authenticated
using (author_id = auth.uid())
with check (author_id = auth.uid());

drop policy if exists "users or admins delete comments" on public.comments;
create policy "users or admins delete comments"
on public.comments for delete
to authenticated
using (
  author_id = auth.uid()
  or exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  )
);

-- REACTIONS / LIKES
drop policy if exists "reactions public read" on public.reactions;
create policy "reactions public read"
on public.reactions for select
to anon, authenticated
using (true);

drop policy if exists "signed in users add reactions" on public.reactions;
create policy "signed in users add reactions"
on public.reactions for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "users remove own reactions" on public.reactions;
create policy "users remove own reactions"
on public.reactions for delete
to authenticated
using (user_id = auth.uid());
