# Player Lobby and notifications

This change is local source, not a live deployment. The existing production chat schema and notification triggers are not included in the original repository. Validate the additions against an export of that schema in staging before deploying. Do not run the historical seed SQL files.

## What changed

- Lobby-first, mobile-friendly open message feed; private conversations remain available.
- Home-page Lobby entry, notification inbox, unread badges, and direct links from alerts.
- Group-only availability polls, created from the composer’s + menu: 2–6 choices, one named vote per player, change vote, results, and creator-controlled closing.
- Draft preservation, latest-first message loading with older history, inline search, reactions, and emoji insertion.
- Device notification sender source with sender authentication, membership checks, mute/block/read preferences, stale-subscription cleanup, safe push endpoints, and per-device duplicate suppression.

## Local review

`python3 -m http.server 8080 --bind 127.0.0.1 --directory web`

The normal preview uses the existing Supabase project. It cannot use new shared polls or provision the all-player Lobby until the migrations have been applied. It shows a setup message instead of pretending those features are connected.

For a **sample-only** preview with no real chat writes:

1. Run `python3 tests/build_chat_preview.py` from the repository root.
2. Serve the printed temporary directory with `python3 -m http.server 8081 --bind 127.0.0.1 --directory <printed-directory>`.
3. Open `http://127.0.0.1:8081/`. Polls, votes and messages are fake, in-memory data. Reload resets them.

## Staging and deployment

1. Export the actual database schema and existing `pwt-chat-push` function before replacing anything. Preserve its VAPID key pair; changing the public key requires users to re-enable device alerts.
2. Check the existing chat table columns, membership constraints, RLS policies, profile-creation flow, realtime publications, and notification triggers. The new migrations expect the tables already used by the current frontend: `profiles`, `chat_conversations`, `chat_members`, `chat_member_state`, `chat_messages`, `chat_notifications`, `chat_blocks`, and `push_subscriptions`.
3. Apply `database/migrations/20261015_lobby_polls.sql` once in staging. It creates/reuses the official **PWT Lobby**, adds existing profiles as members, adds new profiles through a trigger, and introduces membership-checked poll RPCs. It requires an existing admin profile. It does not import old WhatsApp messages or register new users.
4. Apply `database/migrations/20261015_chat_push_delivery.sql` once. The delivery-claim table is accessible only to the server service role.
5. Apply `database/migrations/20261016_chat_mute_preferences.sql`. It adds a membership-checked RPC for each profile’s notification preference (on, 1/8/24 hours, or indefinitely). Include `chat_member_state` in the existing realtime publication to synchronize preferences between devices.
6. Configure the function secrets `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, and `VAPID_SUBJECT` (a real `mailto:` or HTTPS contact). The public key must match `CHAT_VAPID_PUBLIC` in both HTML files. Keep the private key and Supabase service-role key out of frontend source. The hosted runtime supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
7. Deploy `supabase/functions/pwt-chat-push/index.ts` to the same project. The function verifies the calling user's bearer token and only dispatches their own newly saved messages. The frontend retries once if dispatch fails. This is best-effort push, not a durable background queue; add a server-side queue/webhook for delivery guarantees if the app closes immediately after sending. Delivery claims should be pruned periodically after the replay window (e.g. after 30 days).
8. Confirm that the existing message-insert trigger writes `chat_notifications` for all other Lobby members, with their user ID, conversation ID, title, body, and timestamp. Do not add a duplicate trigger blindly. Existing realtime publication must include `chat_notifications`, `chat_messages`, `chat_members`, and `chat_conversations`. The polls migration publishes the new poll tables.
9. Deploy `web/` over HTTPS. The service worker cache version has changed and notification clicks open the corresponding conversation.

## Release checks still required on the deployed backend

- Two real test accounts see the same Lobby and can exchange text, attachments, and voice notes.
- A newly registered profile joins the Lobby; signing out clears private UI data.
- Unauthorized users cannot read polls, vote, close someone else's poll, or dispatch another sender's push.
- Two clients see live votes; changing votes does not increase the voter count; closing prevents later votes.
- Actual device notifications arrive on a registered Android browser and an installed iPhone web app, with the app closed. Verify denied permissions, muted chat, blocked sender, expired subscriptions, and notification navigation.
- Verify existing membership and notification triggers produce `chat_member_state` and inbox rows for newly joined Lobby members.

Local automated checks: `node tests/chat-regression.cjs` and `node tests/chat-push.cjs`. These use mocks and do not prove database RLS, deployed runtime compatibility, or real device delivery. The SQL was not executed and the Edge Function was not deployed during local design work.

Implementation references: [Web Push library](https://github.com/web-push-libs/web-push) and [Supabase Edge Functions](https://supabase.com/docs/guides/functions).
