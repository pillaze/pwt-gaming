from pathlib import Path
import re, tempfile, shutil
# Run from the repository root. Uses an isolated mock backend; never production data.
root=Path(tempfile.gettempdir())/'pwt-chat-preview';root.mkdir(exist_ok=True)
assets=root/'assets'
shutil.copytree(Path('web/assets'),assets,dirs_exist_ok=True)
s=Path('web/index.html').read_text()
s=re.sub(r'<script src="https://cdn.jsdelivr.net/npm/@supabase/[^>]+></script>','<script src="/mock.js"></script>',s)
s=s.replace('boot();', '''
// Isolated UI fixture: no production authentication, network, or persistence.
currentUser=new URLSearchParams(location.search).has('signedout')?null:{id:'demo-me',email:'player@example.test'};
state.profiles=window.chatFixture.profiles;currentProfile=currentUser?state.profiles[0]:null;
window.previewSignOut=()=>{currentUser=null;currentProfile=null;renderAccount();resetChatSystem()};
(async()=>{await loadChatHome();renderAccount();$('#boot').classList.add('off');if(currentUser){navTo('chats');await openPlayerLobby();}else resetChatSystem();})();
''')
(root/'index.html').write_text(s)
(root/'mock.js').write_text(r'''
const now=Date.now(),ago=m=>new Date(now-m*60000).toISOString();
window.chatFixture={profiles:[{id:'demo-me',display_name:'You',avatar_key:'fox_hacker',role:'member'},{id:'ace',display_name:'Ace',avatar_key:'blaze_tiger'},{id:'nova',display_name:'Nova',avatar_key:'neon_wolf'},{id:'ghost',display_name:'Ghost',avatar_key:'ghost_raven'}]};
const fixture={chat_conversations:[{id:'squad',kind:'group',name:'The evening squad',description:'Good games. Better company.',created_at:ago(100),last_message_at:ago(1)},{id:'lobby',kind:'group',name:'PWT Lobby',is_official:true,created_at:ago(200),last_message_at:ago(12)},{id:'dm',kind:'dm',created_at:ago(100),last_message_at:ago(30)}],chat_members:[...['demo-me','ace','nova','ghost'].map(user_id=>({conversation_id:'squad',user_id,member_role:user_id==='demo-me'?'owner':'member'})),...['demo-me','nova'].map(user_id=>({conversation_id:'dm',user_id,member_role:'member'})),...['demo-me','ace','nova','ghost'].map(user_id=>({conversation_id:'lobby',user_id,member_role:'member'}))],chat_member_state:[{conversation_id:'squad',user_id:'demo-me',pinned:true}],chat_notifications:[{id:'n1',user_id:'demo-me',conversation_id:'lobby',title:'PWT Players Lounge',body:'Tonight’s custom room opens at 9. Who’s in?',created_at:ago(12)},{id:'n2',user_id:'demo-me',conversation_id:'dm',title:'Nova',body:'Send me your loadout after the match 👀',created_at:ago(30)}],chat_messages:[{id:'m1',conversation_id:'squad',sender_id:'ace',body:'Squad check! Who’s dropping in tonight? 🎮',created_at:ago(8),message_type:'text'},{id:'m2',conversation_id:'squad',sender_id:'nova',body:'I’m in. Let’s get a warm-up match before the tournament.',created_at:ago(6),message_type:'text'},{id:'m3',conversation_id:'squad',sender_id:'demo-me',body:'Count me in 🙌\nI’ll share the teams here at 8:45.',created_at:ago(4),message_type:'text'},{id:'m4',conversation_id:'squad',sender_id:'ghost',body:'Perfect. Same squad, new chicken dinner 🏆',created_at:ago(1),message_type:'text'},{id:'m5',conversation_id:'lobby',sender_id:'ace',body:'Tonight’s custom room opens at 9. Who’s in?',created_at:ago(12),message_type:'text'},{id:'m6',conversation_id:'dm',sender_id:'nova',body:'Send me your loadout after the match 👀',created_at:ago(30),message_type:'text'}],chat_message_reactions:[{message_id:'m4',user_id:'ace',emoji:'🔥'},{message_id:'m4',user_id:'demo-me',emoji:'🔥'}],chat_starred_messages:[]};
let seq=20;
function from(table){let rows=[...(fixture[table]||[])],operation='select',payload,limit=1000,single=false;const q={select(){return q},eq(k,v){rows=rows.filter(r=>r[k]===v);return q},in(k,vs){rows=rows.filter(r=>vs.includes(r[k]));return q},is(k,v){rows=rows.filter(r=>v===null?r[k]==null:r[k]===v);return q},lt(k,v){rows=rows.filter(r=>r[k]<v);return q},order(k,{ascending=true}={}){rows.sort((a,b)=>String(a[k]).localeCompare(String(b[k]))*(ascending?1:-1));return q},limit(n){limit=n;return q},single(){single=true;return q},maybeSingle(){single=true;return q},update(p){operation='update';payload=p;return q},insert(p){operation='insert';payload=p;return q},delete(){operation='delete';return q},then(resolve,reject){if(operation==='insert'){rows=(Array.isArray(payload)?payload:[payload]).map(p=>({...p,id:'demo-'+seq++,created_at:new Date().toISOString()}));(fixture[table]??=[]).push(...rows)}if(operation==='update')rows.forEach(r=>Object.assign(r,payload));if(operation==='delete')fixture[table]=fixture[table].filter(r=>!rows.includes(r));return Promise.resolve({data:single?rows[0]:rows.slice(0,limit),error:null}).then(resolve,reject)}};return q}

fixture.pwt_chat_polls=[{id:'poll1',conversation_id:'lobby',creator_id:'demo-me',question:'When are we playing tonight? (ET)',created_at:ago(5),closed_at:null}];
fixture.pwt_chat_poll_options=[{id:'o1',poll_id:'poll1',label:'8:00 PM',position:0},{id:'o2',poll_id:'poll1',label:'9:00 PM',position:1},{id:'o3',poll_id:'poll1',label:'10:00 PM',position:2},{id:'o4',poll_id:'poll1',label:'Not tonight',position:3}];
fixture.pwt_chat_poll_votes=[{poll_id:'poll1',user_id:'ace',option_id:'o2'},{poll_id:'poll1',user_id:'nova',option_id:'o2'},{poll_id:'poll1',user_id:'ghost',option_id:'o1'}];
fixture.chat_messages.push({id:'poll-message',conversation_id:'lobby',sender_id:'demo-me',body:'When are we playing tonight? (ET)',metadata:{pwt_poll_id:'poll1'},created_at:ago(5),message_type:'text'});
fixture.chat_messages.push({id:'lobby-reply',conversation_id:'lobby',sender_id:'ace',body:'9 works for me. Vote above so we can set the teams 🙌',created_at:ago(2),message_type:'text'});
async function rpc(name,args={}){
 if(name==='pwt_join_lobby')return{data:'lobby',error:null};
 if(name==='pwt_set_chat_mute'){let st=fixture.chat_member_state.find(s=>s.conversation_id===args.p_conversation&&s.user_id==='demo-me');if(!st){st={conversation_id:args.p_conversation,user_id:'demo-me'};fixture.chat_member_state.push(st)}st.muted_until=args.p_muted_until;return{error:null}};
 if(name==='pwt_vote_poll'){const poll=fixture.pwt_chat_polls.find(p=>p.id===args.p_poll);if(poll.closed_at)return{error:{message:'This poll is closed'}};fixture.pwt_chat_poll_votes=fixture.pwt_chat_poll_votes.filter(v=>!(v.poll_id===args.p_poll&&v.user_id==='demo-me'));fixture.pwt_chat_poll_votes.push({poll_id:args.p_poll,user_id:'demo-me',option_id:args.p_option});return{error:null}};
 if(name==='pwt_close_poll'){fixture.pwt_chat_polls.find(p=>p.id===args.p_poll).closed_at=new Date().toISOString();return{error:null}};
 if(name==='pwt_create_poll'){const id='poll'+seq++,mid='m'+seq++;fixture.pwt_chat_polls.push({id,conversation_id:args.p_conversation,creator_id:'demo-me',question:args.p_question,created_at:new Date().toISOString()});args.p_options.forEach((label,position)=>fixture.pwt_chat_poll_options.push({id:'option'+seq++,poll_id:id,label,position}));fixture.chat_messages.push({id:mid,conversation_id:args.p_conversation,sender_id:'demo-me',body:args.p_question,metadata:{pwt_poll_id:id},message_type:'text',created_at:new Date().toISOString()});return{data:{poll_id:id,message_id:mid},error:null}};
 return{error:{message:'Unsupported preview operation'}};
}
window.supabase={createClient:()=>({from,rpc,channel:()=>({on(){return this},subscribe(){return this},presenceState(){return{}},track:async()=>{},send:async()=>{}}),removeChannel(){},functions:{invoke:async()=>({data:{},error:null})},storage:{from:()=>({createSignedUrls:async()=>({data:[]})})},auth:{signOut:async()=>{window.previewSignOut();return{error:null}}}})};
''')

print('Sample-only Lobby preview created at:', root)
