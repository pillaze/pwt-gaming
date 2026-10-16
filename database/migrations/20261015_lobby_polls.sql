-- Apply to a staging copy first. Requires the existing PWT chat schema.
-- This migration does not recreate or replace existing chat tables or policies.
begin;
create table public.pwt_lobby_config (
 singleton boolean primary key default true check (singleton),
 conversation_id uuid not null references public.chat_conversations(id) on delete cascade
);
alter table public.pwt_lobby_config enable row level security;
create policy "Signed in players can locate lobby" on public.pwt_lobby_config for select to authenticated using (true);
grant select on public.pwt_lobby_config to authenticated;

do $$
declare lobby uuid; owner_id uuid;
begin
 select id into owner_id from public.profiles where role='admin' order by created_at limit 1;
 if owner_id is null then raise exception 'A PWT admin profile is required to provision the Lobby'; end if;
 select id into lobby from public.chat_conversations where kind='group' and is_official=true and name='PWT Lobby' order by created_at limit 1;
 if lobby is null then
  insert into public.chat_conversations(kind,name,description,is_official,created_by)
  values('group','PWT Lobby','All PWT players. Match plans, availability and squad chat.',true,owner_id) returning id into lobby;
 end if;
 insert into public.pwt_lobby_config values(true,lobby);
 insert into public.chat_members(conversation_id,user_id,member_role)
 select lobby,id,case when id=owner_id then 'owner' else 'member' end from public.profiles on conflict do nothing;
end $$;

create function public.pwt_join_lobby() returns uuid language plpgsql security definer set search_path=public as $$
declare lobby uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 if not exists(select 1 from public.profiles where id=auth.uid()) then raise exception 'Create your player profile first'; end if;
 select conversation_id into lobby from public.pwt_lobby_config where singleton;
 if lobby is null then raise exception 'Lobby has not been configured'; end if;
 insert into public.chat_members(conversation_id,user_id,member_role) values(lobby,auth.uid(),'member') on conflict do nothing;
 return lobby;
end $$;
revoke all on function public.pwt_join_lobby() from public,anon;
grant execute on function public.pwt_join_lobby() to authenticated;

-- New registered profiles become Lobby members, so they can receive Lobby alerts.
create function public.pwt_add_profile_to_lobby() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.chat_members(conversation_id,user_id,member_role)
 select conversation_id,new.id,'member' from public.pwt_lobby_config where singleton on conflict do nothing;
 return new;
end $$;
revoke all on function public.pwt_add_profile_to_lobby() from public,anon,authenticated;
create trigger pwt_profile_lobby after insert on public.profiles for each row execute function public.pwt_add_profile_to_lobby();

create table public.pwt_chat_polls (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
 creator_id uuid not null references public.profiles(id) on delete cascade,
 question text not null check(char_length(question) between 1 and 160),
 closed_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.pwt_chat_poll_options (
 id uuid primary key default gen_random_uuid(),
 poll_id uuid not null references public.pwt_chat_polls(id) on delete cascade,
 label text not null check(char_length(label) between 1 and 80),
 position smallint not null,
 unique(poll_id,position),unique(poll_id,id)
);
create table public.pwt_chat_poll_votes (
 poll_id uuid not null references public.pwt_chat_polls(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 option_id uuid not null,
 updated_at timestamptz not null default now(),
 primary key(poll_id,user_id),
 foreign key(poll_id,option_id) references public.pwt_chat_poll_options(poll_id,id) on delete cascade
);
create index pwt_poll_conversation on public.pwt_chat_polls(conversation_id,created_at desc);
create index pwt_poll_vote_option on public.pwt_chat_poll_votes(option_id);
alter table public.pwt_chat_polls enable row level security;
alter table public.pwt_chat_poll_options enable row level security;
alter table public.pwt_chat_poll_votes enable row level security;
create policy "Members read polls" on public.pwt_chat_polls for select to authenticated using(exists(select 1 from public.chat_members m where m.conversation_id=pwt_chat_polls.conversation_id and m.user_id=auth.uid()));
create policy "Members read poll options" on public.pwt_chat_poll_options for select to authenticated using(exists(select 1 from public.pwt_chat_polls p where p.id=poll_id));
create policy "Members read named votes" on public.pwt_chat_poll_votes for select to authenticated using(exists(select 1 from public.pwt_chat_polls p where p.id=poll_id));
grant select on public.pwt_chat_polls,public.pwt_chat_poll_options,public.pwt_chat_poll_votes to authenticated;
-- Writes are only through membership-checked RPCs, never direct client writes.
revoke insert,update,delete on public.pwt_chat_polls,public.pwt_chat_poll_options,public.pwt_chat_poll_votes from anon,authenticated;

create function public.pwt_create_poll(p_conversation uuid,p_question text,p_options text[]) returns jsonb language plpgsql security definer set search_path=public as $$
declare poll uuid; message uuid; item text; idx smallint:=0;
begin
 if auth.uid() is null or not exists(select 1 from public.chat_members where conversation_id=p_conversation and user_id=auth.uid()) then raise exception 'Only conversation members can create a poll'; end if;
 if not exists(select 1 from public.chat_conversations where id=p_conversation and kind='group') then raise exception 'Polls are only available in group chats'; end if;
 if char_length(trim(p_question)) not between 1 and 160 or p_question is null then raise exception 'Enter a question (up to 160 characters)'; end if;
 if cardinality(p_options) not between 2 and 6 or p_options is null then raise exception 'Choose 2 to 6 options'; end if;
 if exists(select 1 from unnest(p_options) x where x is null or char_length(trim(x)) not between 1 and 80) then raise exception 'Each option needs 1 to 80 characters'; end if;
 if (select count(distinct lower(trim(x))) from unnest(p_options) x)<>cardinality(p_options) then raise exception 'Options must be different'; end if;
 insert into public.pwt_chat_polls(conversation_id,creator_id,question) values(p_conversation,auth.uid(),trim(p_question)) returning id into poll;
 foreach item in array p_options loop
  insert into public.pwt_chat_poll_options(poll_id,label,position) values(poll,trim(item),idx);idx:=idx+1;
 end loop;
 insert into public.chat_messages(conversation_id,sender_id,body,message_type,metadata)
 values(p_conversation,auth.uid(),'📊 '||trim(p_question),'text',jsonb_build_object('pwt_poll_id',poll)) returning id into message;
 return jsonb_build_object('poll_id',poll,'message_id',message);
end $$;

create function public.pwt_vote_poll(p_poll uuid,p_option uuid) returns void language plpgsql security definer set search_path=public as $$
declare poll public.pwt_chat_polls;
begin
 select * into poll from public.pwt_chat_polls where id=p_poll for update;
 if poll.id is null or auth.uid() is null or not exists(select 1 from public.chat_members where conversation_id=poll.conversation_id and user_id=auth.uid()) then raise exception 'Only conversation members can vote'; end if;
 if poll.closed_at is not null then raise exception 'This poll is closed'; end if;
 if not exists(select 1 from public.pwt_chat_poll_options where id=p_option and poll_id=p_poll) then raise exception 'Invalid poll option'; end if;
 insert into public.pwt_chat_poll_votes(poll_id,user_id,option_id) values(p_poll,auth.uid(),p_option)
 on conflict(poll_id,user_id) do update set option_id=excluded.option_id,updated_at=now();
end $$;
create function public.pwt_close_poll(p_poll uuid) returns void language plpgsql security definer set search_path=public as $$
declare poll public.pwt_chat_polls;
begin
 select * into poll from public.pwt_chat_polls where id=p_poll for update;
 if poll.id is null or auth.uid() is null or poll.creator_id<>auth.uid() or not exists(select 1 from public.chat_members where conversation_id=poll.conversation_id and user_id=auth.uid()) then raise exception 'Only the poll creator can close it'; end if;
 update public.pwt_chat_polls set closed_at=coalesce(closed_at,now()) where id=p_poll;
end $$;
revoke all on function public.pwt_create_poll(uuid,text,text[]),public.pwt_vote_poll(uuid,uuid),public.pwt_close_poll(uuid) from public,anon;
grant execute on function public.pwt_create_poll(uuid,text,text[]),public.pwt_vote_poll(uuid,uuid),public.pwt_close_poll(uuid) to authenticated;
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  alter publication supabase_realtime add table public.pwt_chat_polls,public.pwt_chat_poll_options,public.pwt_chat_poll_votes;
 end if;
end $$;
commit;
