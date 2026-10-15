-- PWT Supabase security hardening
-- Run this once in Supabase SQL Editor after the original setup script.

revoke update on table public.profiles from authenticated;
grant update (display_name) on table public.profiles to authenticated;
