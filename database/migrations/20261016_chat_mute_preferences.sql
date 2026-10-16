-- Profile-scoped chat notification preferences. Apply after the existing chat schema.
-- This RPC handles users whose chat_member_state row has not been created yet.
create or replace function public.pwt_set_chat_mute(p_conversation uuid,p_muted_until timestamptz)
returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null or not exists(select 1 from public.chat_members where conversation_id=p_conversation and user_id=auth.uid()) then
  raise exception 'Only conversation members can change notification preferences';
 end if;
 if p_muted_until is not null and p_muted_until<=now() then raise exception 'Mute expiry must be in the future'; end if;
 insert into public.chat_member_state(conversation_id,user_id,muted_until,updated_at)
 values(p_conversation,auth.uid(),p_muted_until,now())
 on conflict(conversation_id,user_id) do update set muted_until=excluded.muted_until,updated_at=now();
end $$;
revoke all on function public.pwt_set_chat_mute(uuid,timestamptz) from public,anon;
grant execute on function public.pwt_set_chat_mute(uuid,timestamptz) to authenticated;
