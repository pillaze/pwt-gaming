const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('supabase/functions/pwt-chat-push/index.ts','utf8').replace(/^import .*;$/gm,'');
const id='11111111-1111-4111-8111-111111111111';
let tables,authUser='sender',sent=[],claims=new Set();
function reset(){sent=[];claims.clear();tables={chat_messages:[{id,sender_id:'sender',conversation_id:'lobby',created_at:new Date().toISOString(),body:'Ready?'}],chat_members:[{user_id:'sender',conversation_id:'lobby'},{user_id:'player',conversation_id:'lobby'}],chat_member_state:[],chat_conversations:[{id:'lobby',kind:'group',name:'PWT Lobby'}],profiles:[{id:'sender',display_name:'Ace'}],chat_blocks:[],push_subscriptions:[{user_id:'player',endpoint:'https://fcm.googleapis.com/fcm/send/test',p256dh:'key',auth:'auth'}],pwt_chat_push_delivery:[]};authUser='sender'}
function from(table){let rows=tables[table]||[],single=false,op='read',payload;const q={select(){return q},eq(k,v){rows=rows.filter(r=>r[k]===v);return q},in(k,a){rows=rows.filter(r=>a.includes(r[k]));return q},single(){single=true;return q},insert(p){payload=p;op='insert';return q},delete(){op='delete';return q},then(resolve,reject){let error=null;if(op==='insert'){if(claims.has(payload.delivery_key))error={code:'23505'};else claims.add(payload.delivery_key)}if(op==='delete')tables[table]=tables[table].filter(r=>!rows.includes(r));return Promise.resolve({data:single?rows[0]:rows,error}).then(resolve,reject)}};return q}
const context={console,Response,Request,URL,TextEncoder,crypto:require('node:crypto').webcrypto,Uint8Array,Date,createClient:()=>({from,auth:{getUser:async()=>({data:{user:{id:authUser}},error:null})}}),webpush:{setVapidDetails(){},sendNotification:async(sub,payload)=>{sent.push({sub,payload:JSON.parse(payload)})}},Deno:{env:{get:()=> 'configured'},serve:fn=>context.handler=fn}};
vm.createContext(context);vm.runInContext(source,context);
const request=()=>new Request('https://example.test/push',{method:'POST',headers:{authorization:'Bearer test','content-type':'application/json'},body:JSON.stringify({message_id:id})});
(async()=>{
 reset();let r=await context.handler(request());assert.equal(r.status,200);assert.equal(sent.length,1);assert.equal(sent[0].payload.conversation_id,'lobby');
 await context.handler(request());assert.equal(sent.length,1,'replay must not duplicate device delivery');
 reset();authUser='outsider';r=await context.handler(request());assert.equal(r.status,403);assert.equal(sent.length,0);
 reset();tables.chat_member_state=[{user_id:'player',conversation_id:'lobby',muted_until:new Date(Date.now()+60000).toISOString()}];await context.handler(request());assert.equal(sent.length,0,'muted member must not receive push');
 reset();tables.chat_blocks=[{blocker_id:'player',blocked_id:'sender'}];await context.handler(request());assert.equal(sent.length,0);
 reset();tables.push_subscriptions[0].endpoint='http://127.0.0.1/private';await context.handler(request());assert.equal(sent.length,0,'untrusted endpoints must not be fetched');
 reset();tables.chat_member_state=[{user_id:'player',conversation_id:'lobby',last_read_at:new Date(Date.now()+1000).toISOString()}];await context.handler(request());assert.equal(sent.length,0);
 reset();tables.chat_members.push({user_id:'second',conversation_id:'lobby'});
 tables.push_subscriptions.push({user_id:'player',endpoint:'https://fcm.googleapis.com/fcm/send/second-device',p256dh:'key',auth:'auth'},{user_id:'second',endpoint:'https://fcm.googleapis.com/fcm/send/second-player',p256dh:'key',auth:'auth'},{user_id:'outsider',endpoint:'https://fcm.googleapis.com/fcm/send/outsider',p256dh:'key',auth:'auth'});
 tables.chat_member_state=[{user_id:'player',conversation_id:'lobby',muted_until:new Date(Date.now()-60000).toISOString()}];
 await context.handler(request());assert.equal(sent.length,3,'all eligible members and their devices, but no outsiders, receive push');
 await context.handler(request());assert.equal(sent.length,3,'multi-device replay does not send duplicates');
 console.log('Passed: push authentication, per-device deduplication, mute/block/read suppression, safe endpoints, and conversation deep links.');
})().catch(e=>{console.error(e);process.exitCode=1});
