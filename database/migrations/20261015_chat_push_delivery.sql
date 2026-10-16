-- Per-device idempotency for pwt-chat-push. Run after the existing chat schema.
create table public.pwt_chat_push_delivery (
 delivery_key text primary key,
 message_id uuid not null references public.chat_messages(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table public.pwt_chat_push_delivery enable row level security;
revoke all on public.pwt_chat_push_delivery from anon,authenticated;
grant all on public.pwt_chat_push_delivery to service_role;
