
-- ============================================================
-- PWT MATCH + PLAYER STATS DATABASE
-- Run AFTER:
--   1) PWT_Supabase_Setup.sql
--   2) PWT_Supabase_Security_Patch.sql
-- Safe to run once on the current project.
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  display_name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  session_code text not null unique,
  played_at timestamptz not null,
  team1_size integer not null check (team1_size > 0),
  team2_size integer not null check (team2_size > 0),
  balance text not null check (balance in ('Even','Uneven')),
  rounds integer not null check (rounds > 0),
  team1_round_wins integer not null check (team1_round_wins >= 0),
  team2_round_wins integer not null check (team2_round_wins >= 0),
  winner_team integer not null check (winner_team in (1,2)),
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (team1_round_wins + team2_round_wins = rounds)
);

create table if not exists public.match_player_stats (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  team_number integer not null check (team_number in (1,2)),
  eliminations integer not null check (eliminations >= 0),
  assists integer check (assists >= 0),
  damage_dealt integer check (damage_dealt >= 0),
  damage_taken integer check (damage_taken >= 0),
  knockouts integer check (knockouts >= 0),
  created_at timestamptz not null default now(),
  unique(match_id, player_id)
);

create index if not exists idx_matches_played_at on public.matches(played_at desc);
create index if not exists idx_match_stats_match on public.match_player_stats(match_id);
create index if not exists idx_match_stats_player on public.match_player_stats(player_id);

alter table public.players enable row level security;
alter table public.matches enable row level security;
alter table public.match_player_stats enable row level security;

revoke all on public.players from anon, authenticated;
revoke all on public.matches from anon, authenticated;
revoke all on public.match_player_stats from anon, authenticated;

grant select on public.players to anon, authenticated;
grant select on public.matches to anon, authenticated;
grant select on public.match_player_stats to anon, authenticated;

grant insert, update, delete on public.players to authenticated;
grant insert, update, delete on public.matches to authenticated;
grant insert, update, delete on public.match_player_stats to authenticated;

-- Public read
drop policy if exists "players public read" on public.players;
create policy "players public read"
on public.players for select to anon, authenticated using (true);

drop policy if exists "matches public read" on public.matches;
create policy "matches public read"
on public.matches for select to anon, authenticated using (true);

drop policy if exists "match stats public read" on public.match_player_stats;
create policy "match stats public read"
on public.match_player_stats for select to anon, authenticated using (true);

-- Admin-only writes
drop policy if exists "admins write players" on public.players;
create policy "admins write players"
on public.players for all to authenticated
using (exists (select 1 from public.profiles where id=auth.uid() and role='admin'))
with check (exists (select 1 from public.profiles where id=auth.uid() and role='admin'));

drop policy if exists "admins write matches" on public.matches;
create policy "admins write matches"
on public.matches for all to authenticated
using (exists (select 1 from public.profiles where id=auth.uid() and role='admin'))
with check (exists (select 1 from public.profiles where id=auth.uid() and role='admin'));

drop policy if exists "admins write match stats" on public.match_player_stats;
create policy "admins write match stats"
on public.match_player_stats for all to authenticated
using (exists (select 1 from public.profiles where id=auth.uid() and role='admin'))
with check (exists (select 1 from public.profiles where id=auth.uid() and role='admin'));

-- Seed PWT players
insert into public.players(display_name) values
('RGODxEMPEROR'),
('DeathwishツSpy'),
('KG696969'),
('TheWolverine'),
('PARABloodthirs'),
('Sarthakkkd'),
('Strike333'),
('KhajwaKILL3R'),
('StarJohnnysins'),
('Makjets69'),
('BruceWayne³'),
('InnocentDevil'),
('WonderWoman888'),
('TrishaSingh'),
('OmkarKurhade')
on conflict (display_name) do nothing;

-- Seed matches
insert into public.matches
(session_code,played_at,team1_size,team2_size,balance,rounds,team1_round_wins,team2_round_wins,winner_team,notes)
values
('S1','2026-09-27 21:44:00-04',6,6,'Even',29,17,12,1,'Only eliminations were available in the original result screenshots.'),
('S2','2026-09-28 21:21:00-04',7,6,'Uneven',25,15,10,1,'Full combat statistics available.'),
('S3','2026-09-28 23:51:00-04',6,6,'Even',25,10,15,2,'Full combat statistics available.')
on conflict (session_code) do nothing;

-- Helper for compact seed inserts
create or replace function public.pwt_seed_stat(
  p_session text, p_player text, p_team int, p_kills int,
  p_assists int default null, p_damage int default null,
  p_taken int default null, p_kos int default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  mid uuid;
  pid uuid;
begin
  select id into mid from public.matches where session_code=p_session;
  select id into pid from public.players where display_name=p_player;
  if mid is null or pid is null then
    raise exception 'Missing match or player for % / %', p_session, p_player;
  end if;
  insert into public.match_player_stats
    (match_id,player_id,team_number,eliminations,assists,damage_dealt,damage_taken,knockouts)
  values
    (mid,pid,p_team,p_kills,p_assists,p_damage,p_taken,p_kos)
  on conflict (match_id,player_id) do update set
    team_number=excluded.team_number,
    eliminations=excluded.eliminations,
    assists=excluded.assists,
    damage_dealt=excluded.damage_dealt,
    damage_taken=excluded.damage_taken,
    knockouts=excluded.knockouts;
end;
$$;

-- S1
select public.pwt_seed_stat('S1','KhajwaKILL3R',1,15);
select public.pwt_seed_stat('S1','TheWolverine',1,22);
select public.pwt_seed_stat('S1','Makjets69',1,15);
select public.pwt_seed_stat('S1','WonderWoman888',1,3);
select public.pwt_seed_stat('S1','RGODxEMPEROR',1,38);
select public.pwt_seed_stat('S1','PARABloodthirs',1,21);
select public.pwt_seed_stat('S1','BruceWayne³',2,5);
select public.pwt_seed_stat('S1','StarJohnnysins',2,12);
select public.pwt_seed_stat('S1','DeathwishツSpy',2,19);
select public.pwt_seed_stat('S1','KG696969',2,19);
select public.pwt_seed_stat('S1','Strike333',2,18);
select public.pwt_seed_stat('S1','Sarthakkkd',2,19);

-- S2
select public.pwt_seed_stat('S2','StarJohnnysins',1,14,26,4204,3609,16);
select public.pwt_seed_stat('S2','TrishaSingh',1,2,18,1353,2847,2);
select public.pwt_seed_stat('S2','Makjets69',1,11,18,3420,3681,19);
select public.pwt_seed_stat('S2','WonderWoman888',1,6,12,1395,3260,7);
select public.pwt_seed_stat('S2','RGODxEMPEROR',1,35,12,6352,3771,45);
select public.pwt_seed_stat('S2','TheWolverine',1,19,23,4582,3674,20);
select public.pwt_seed_stat('S2','PARABloodthirs',1,16,13,2834,3644,17);
select public.pwt_seed_stat('S2','BruceWayne³',2,11,10,2627,3617,13);
select public.pwt_seed_stat('S2','DeathwishツSpy',2,23,17,5552,4388,34);
select public.pwt_seed_stat('S2','Strike333',2,13,13,3619,3880,12);
select public.pwt_seed_stat('S2','KG696969',2,23,14,4446,3844,26);
select public.pwt_seed_stat('S2','InnocentDevil',2,6,14,2478,4325,13);
select public.pwt_seed_stat('S2','Sarthakkkd',2,13,19,5344,4889,23);

-- S3
select public.pwt_seed_stat('S3','KG696969',1,28,18,5542,4290,33);
select public.pwt_seed_stat('S3','StarJohnnysins',1,14,12,3562,4113,16);
select public.pwt_seed_stat('S3','Sarthakkkd',1,25,21,6437,4198,30);
select public.pwt_seed_stat('S3','DeathwishツSpy',1,14,18,4371,4744,24);
select public.pwt_seed_stat('S3','BruceWayne³',1,0,8,1261,3572,3);
select public.pwt_seed_stat('S3','WonderWoman888',1,7,7,1746,3890,7);
select public.pwt_seed_stat('S3','OmkarKurhade',2,20,19,4634,3774,20);
select public.pwt_seed_stat('S3','PARABloodthirs',2,17,9,3078,3528,20);
select public.pwt_seed_stat('S3','TheWolverine',2,17,19,4216,4145,24);
select public.pwt_seed_stat('S3','TrishaSingh',2,3,18,1839,3978,4);
select public.pwt_seed_stat('S3','Strike333',2,14,21,3925,3615,15);
select public.pwt_seed_stat('S3','RGODxEMPEROR',2,31,17,6716,4295,36);

drop function if exists public.pwt_seed_stat(text,text,int,int,int,int,int,int);

-- Verify seeded rows
select
  m.session_code,
  m.rounds,
  m.balance,
  count(s.id) as player_rows,
  sum(s.eliminations) as total_kills
from public.matches m
left join public.match_player_stats s on s.match_id=m.id
group by m.id,m.session_code,m.rounds,m.balance,m.played_at
order by m.played_at;
