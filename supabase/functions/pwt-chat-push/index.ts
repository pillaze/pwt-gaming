// Deploy with the existing project's VAPID key pair. Never put the private key in web/.
import { createClient } from 'npm:@supabase/supabase-js@2.117.2';
import webpush from 'npm:web-push@3.6.7';

const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Content-Type': 'application/json' };
const reply = (body, status = 200) => new Response(JSON.stringify(body), { status, headers });
const allowedEndpoint = (value) => {
  try {
    const u = new URL(value);
    return u.protocol === 'https:' && !u.username && !u.password && (!u.port || u.port === '443') &&
      (u.hostname === 'fcm.googleapis.com' || u.hostname === 'updates.push.services.mozilla.com' ||
       u.hostname.endsWith('.push.apple.com') || u.hostname.endsWith('.notify.windows.com'));
  } catch { return false; }
};
const hash = async (value) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))).map(x => x.toString(16).padStart(2, '0')).join('');

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response(null, { headers });
  if (req.method !== 'POST') return reply({ error: 'POST required' }, 405);
  const url = Deno.env.get('SUPABASE_URL'), key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const publicKey = Deno.env.get('VAPID_PUBLIC_KEY'), privateKey = Deno.env.get('VAPID_PRIVATE_KEY'), subject = Deno.env.get('VAPID_SUBJECT');
  if (!url || !key || !publicKey || !privateKey || !subject) return reply({ error: 'Push service is not configured' }, 503);
  const token = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!token) return reply({ error: 'Authentication required' }, 401);
  const db = createClient(url, key, { auth: { persistSession: false } });
  try {
    const { data: auth, error: authError } = await db.auth.getUser(token);
    if (authError || !auth.user) return reply({ error: 'Authentication required' }, 401);
    const { message_id } = await req.json();
    if (typeof message_id !== 'string' || !/^[0-9a-f-]{36}$/i.test(message_id)) return reply({ error: 'Invalid message' }, 400);
    const { data: message, error } = await db.from('chat_messages').select('*').eq('id', message_id).single();
    if (error || !message || message.sender_id !== auth.user.id || message.deleted_at) return reply({ error: 'Message unavailable' }, 403);
    // Limit abuse/replay. Delivery claims below make repeat calls idempotent per device.
    if (Date.now() - new Date(message.created_at).getTime() > 10 * 60 * 1000) return reply({ error: 'Message is too old for a new alert' }, 409);
    const [members, states, conv, sender] = await Promise.all([
      db.from('chat_members').select('user_id').eq('conversation_id', message.conversation_id),
      db.from('chat_member_state').select('user_id,muted_until,last_read_at').eq('conversation_id', message.conversation_id),
      db.from('chat_conversations').select('name,kind').eq('id', message.conversation_id).single(),
      db.from('profiles').select('display_name').eq('id', auth.user.id).single()
    ]);
    if (members.error || states.error || conv.error || sender.error) throw new Error('Could not resolve recipients');
    if (!members.data.some(m => m.user_id === auth.user.id)) return reply({ error: 'Membership required' }, 403);
    const blocked = await db.from('chat_blocks').select('blocker_id').eq('blocked_id', auth.user.id);
    if (blocked.error) throw new Error('Could not resolve notification preferences');
    const recipients = members.data.filter(m => m.user_id !== auth.user.id && !blocked.data.some(b => b.blocker_id === m.user_id)).filter(m => {
      const state = states.data.find(s => s.user_id === m.user_id);
      return !(state?.muted_until && new Date(state.muted_until).getTime() > Date.now()) &&
        !(state?.last_read_at && new Date(state.last_read_at) >= new Date(message.created_at));
    }).map(m => m.user_id);
    if (!recipients.length) return reply({ sent: 0 });
    const subscriptions = await db.from('push_subscriptions').select('user_id,endpoint,p256dh,auth').in('user_id', recipients);
    if (subscriptions.error) throw subscriptions.error;
    webpush.setVapidDetails(subject, publicKey, privateKey);
    const title = conv.data.kind === 'group' ? conv.data.name || 'PWT Lobby' : sender.data.display_name || 'PWT player';
    const summary = message.metadata?.pwt_poll_id ? 'New availability poll — vote for your match time.' : message.message_type === 'voice' ? 'Sent a voice note' : message.attachment_name ? 'Shared an attachment' : message.body || 'New message';
    const payload = JSON.stringify({ title, body: `${sender.data.display_name}: ${summary}`.slice(0, 180), conversation_id: message.conversation_id, message_id, url: '/?chat=' + encodeURIComponent(message.conversation_id) });
    let sent = 0, failed = 0;
    // Small batches keep large Lobby fan-outs within resource limits.
    const devices = subscriptions.data.filter(s => allowedEndpoint(s.endpoint));
    for (let i = 0; i < devices.length; i += 8) {
      await Promise.all(devices.slice(i, i + 8).map(async sub => {
        const delivery_key = await hash(message_id + ':' + sub.endpoint);
        const claim = await db.from('pwt_chat_push_delivery').insert({ delivery_key, message_id });
        if (claim.error?.code === '23505') return;
        if (claim.error) { failed++; return; }
        try {
          await webpush.sendNotification({ endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } }, payload, { TTL: 3600, timeout: 8000 });
          sent++;
        } catch (err) {
          if (err.statusCode === 404 || err.statusCode === 410) {
            await db.from('push_subscriptions').delete().eq('endpoint', sub.endpoint).eq('user_id', sub.user_id);
          } else {
            await db.from('pwt_chat_push_delivery').delete().eq('delivery_key', delivery_key);
            failed++;
          }
        }
      }));
    }
    return reply({ sent, failed }, failed ? 502 : 200);
  } catch {
    // Do not return subscriptions, tokens, or provider response bodies to the caller.
    return reply({ error: 'Notification delivery failed. The chat message is still saved.' }, 500);
  }
});
