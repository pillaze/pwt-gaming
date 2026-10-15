# PWT Gaming Mobile — v1.0 Alpha 2

Social-first iOS/Android foundation for PWT Gaming.

## Alpha 2 additions

- Center-primary Chats bottom navigation retained.
- Native runtime opens directly into the social Home experience instead of the large web hero.
- PWT Now session card on Home.
- Admin session scheduling.
- Going / Maybe / Out RSVP with live Supabase Realtime updates.
- Session announcements are posted to the Official PWT Lobby.
- Session announcements trigger PWT chat push delivery when device notifications are enabled.
- Team Builder can load all accounts marked Going with one tap.
- Tracked players map to their real PWT player stats; community-only accounts remain provisional.
- PWT Activity panel surfaces recent matches, challenge activity and social posts.

## Backend

Uses the existing PWT Supabase project. Alpha 2 adds `pwt_events` and `pwt_event_rsvps`, both protected with RLS and enabled for Realtime.

## Native bootstrap

```bash
npm install
npm run native:init
```

Then open Android or iOS using the scripts in `package.json`. iOS generation/build requires macOS/Xcode.

## App identity

- App: PWT Gaming
- Bundle/package: `com.pwtgaming.app`
- Domain: `pwtgaming.com`
