// No network: exercise notification routing and send safety using the real functions.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync('web/index.html', 'utf8');
function extract(name){const start=html.indexOf(`function ${name}(`);assert(start>=0);const prefix=html.slice(start-6,start)==='async '?'async ':'';const next=html.indexOf('\nfunction ',start+1),asyncNext=html.indexOf('\nasync function ',start+1);return prefix+html.slice(start,Math.min(...[next,asyncNext].filter(x=>x>=0)));}
const nodes = new Map();
function node(id){if(!nodes.has(id))nodes.set(id,{value:'',textContent:'',disabled:false,hidden:false,style:{},classList:{contains:()=>true},focus(){}});return nodes.get(id)}
let writes=[],resolveSend;
const c={console,Date,Set,Map,matchMedia:()=>({matches:false}),document:{hidden:false},currentUser:{id:'me'},chatState:{selected:'a',sending:false,replyTo:null,notifications:[],memberStates:[]},$:node,chatMeState:id=>c.chatState.memberStates.find(x=>x.conversation_id===id),chatConversation:()=>({kind:'group'}),chatSetBadge(){},dispatchChatPush:async()=>true,renderChatList(){},renderReplyPreview(){},sendTyping(){},resizeChatInput(){},saveChatDraft(){},loadChatThread:async()=>{},loadChatHome:async()=>{},sessionStorage:{removeItem(){}},chatToast(...args){c.toasts.push(args)},toasts:[],sb:{from(){return {insert(payload){writes.push(payload);return {select(){return {single(){return new Promise(r=>resolveSend=r)}}}}}}},functions:{invoke:()=>Promise.resolve({})}}};
vm.createContext(c);
for(const name of ['chatIsVisible','chatMuted','receiveChatNotification','updateChatComposer','sendChatMessage','chatMuteUntil'])vm.runInContext(extract(name),c);
c.markChatRead=async id=>{c.read=id};
(async()=>{
 assert.equal(c.chatMuteUntil('off'),null);assert.equal(c.chatMuteUntil('8',0),'1970-01-01T08:00:00.000Z');assert.equal(c.chatMuteUntil('forever'),'9999-12-31T23:59:59.000Z');assert.throws(()=>c.chatMuteUntil('invalid'));
 c.chatConversation=()=>({kind:'dm'});c.updateChatComposer();assert.equal(node('#chatPlanMatch').hidden,true);c.chatConversation=()=>({kind:'group'});c.updateChatComposer();assert.equal(node('#chatPlanMatch').hidden,false);
 c.document.hidden=true;
 await c.receiveChatNotification({id:'n1',user_id:'me',conversation_id:'a',title:'Hi'});
 assert.equal(c.read,undefined,'hidden tab must not mark messages read');assert.equal(c.toasts.length,1);
 await c.receiveChatNotification({id:'n1',user_id:'me',conversation_id:'a'});
 assert.equal(c.chatState.notifications.length,1,'notification IDs must deduplicate');
 c.document.hidden=false;await c.receiveChatNotification({id:'n2',user_id:'me',conversation_id:'a'});assert.equal(c.read,'a');
 c.chatState.memberStates=[{conversation_id:'b',muted_until:new Date(Date.now()+60000).toISOString()}];const before=c.toasts.length;
 await c.receiveChatNotification({id:'n3',user_id:'me',conversation_id:'b'});assert.equal(c.toasts.length,before,'muted chat must not toast');assert(c.chatState.notifications.some(n=>n.id==='n3'),'muted chat retains inbox notification');
 await c.receiveChatNotification({id:'other',user_id:'another-user',conversation_id:'a'});assert(!c.chatState.notifications.some(n=>n.id==='other'));
 node('#chatInput').value='Hello squad';const pending=c.sendChatMessage();await c.sendChatMessage();assert.equal(writes.length,1,'double submit only writes once');
 c.chatState.selected='b';node('#chatInput').value='Draft for B';resolveSend({data:{id:'sent'},error:null});await pending;
 assert.equal(writes[0].conversation_id,'a','message stays with original conversation');assert.equal(node('#chatInput').value,'Draft for B','switching chats must preserve the new draft');
 const failed=c.sendChatMessage();resolveSend({data:null,error:{message:'Offline'}});await failed;assert.equal(node('#chatInput').value,'Draft for B');assert.equal(c.chatState.sending,false);
 console.log('Passed: visible-only reads, deduplication, mute handling, user isolation, duplicate-send prevention, destination capture, and failed-send draft retention.');
})().catch(e=>{console.error(e);process.exitCode=1});
