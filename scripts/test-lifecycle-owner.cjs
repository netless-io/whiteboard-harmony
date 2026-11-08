// Runs the actual ArkTS owner with a deterministic bridge/timer transport; no credentials.
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert');
const ts=require(require.resolve('typescript', {paths: [process.env.WHITEBOARD_BRIDGE_ROOT || path.join(__dirname, '../../Whiteboard-bridge')]}));
const source=path.join(__dirname,'../library/src/main/ets/DsBridge.ets');
const code=ts.transpileModule(fs.readFileSync(source,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
function environment(){
 const mod={exports:{}},timers=[];let now=0,sequence=0;
 const epoch=new Date(2026,9,19,8,9,5).getTime();
 class ClockDate extends Date {constructor(){super(epoch+now);}}
 vm.runInNewContext(code,{module:mod,exports:mod.exports,require(name){return name==='@kit.ArkTS'?{util:{generateRandomUUID:()=>`00000000-0000-4000-8000-${String(++sequence).padStart(12,'0')}`}}:{Logger:{error(){},info(){}}}},console,JSON,Promise,Date:ClockDate,setTimeout(fn,ms){timers.push({at:now+ms,fn});}});
 const joins=[],setups=[];
 function host({handshake=true,setup=true}={}){
  const b=new mod.exports.DsBridge({runJavaScript(){}});let handshakeReply;
  b.dsInitBridge.callHandler=(m,a,cb)=>{
   if(m==='sdk.getLifecycle'){handshakeReply=()=>cb({value:JSON.stringify({documentId:'doc'})});if(handshake)handshakeReply();}
   else if(m==='sdk.newWhiteSdk'){setups.push(a.at(-1));b.completeSetup=(value='{}',scope=a[0].__whiteScope)=>cb({value,scope});if(setup)b.completeSetup();}
   else if(m==='sdk.observePreload'){b.observations=(b.observations||0)+1;b.completePreload=(value={state:'success',message:''},scope=a[0].__whiteScope)=>cb({value:JSON.stringify(value),scope});}
   else if(m==='sdk.joinRoom'){b.actualUid=a[1].uid;joins.push(JSON.parse(JSON.stringify(a[1])));cb({scope:{...b.scope},value:'{}'});}
   else if(m==='sdk.leaveRoom'){b.leaves=(b.leaves||0)+1;const scope={...b.scope};b.completeLeave=()=>cb({scope,value:'{}'});if(!b.holdLeave)b.completeLeave();}
  };b.completeHandshake=()=>handshakeReply();return b;
 }
 async function advance(ms){now+=ms;for(let n=0;n<10;n++){const due=timers.filter(t=>t.at<=now);for(const t of due){timers.splice(timers.indexOf(t),1);t.fn();}await Promise.resolve();if(!due.length)break;}}
 return {host,joins,setups,advance};
}
const params=()=>({uuid:'room',roomToken:'mock',uid:'uid',timeout:100,windowParams:{fullscreen:false}});
const tests=[];const test=(name,fn)=>tests.push({name,fn});
test('snapshots SDK, identity and nested Room payload before queue',async()=>{
 const e=environment(),b=e.host();const sdk={appIdentifier:'app',nested:{enabled:true}},p=params();
 b.initializeRoom(sdk,p,()=>{});sdk.appIdentifier='mutated';sdk.nested.enabled=false;p.uuid='mutated';p.uid='mutated';p.windowParams.fullscreen=true;
 await e.advance(0);assert.equal(b.identity,JSON.stringify(['app','room','uid']));assert.equal(e.joins[0].uuid,'room');assert.equal(e.joins[0].uid,'uid');assert.equal(e.joins[0].windowParams.fullscreen,false);assert.equal(e.setups[0].appIdentifier,'app');assert.equal(e.setups[0].nested.enabled,true);
});
test('T0 is stamped after delayed setup and survives serialized join payload without mutating caller',async()=>{
 const e=environment(),b=e.host({setup:false}),p={...params(),timeout:10000};p.__nativeTags={custom:'retained',time:'stale',traceId:'stale'};
 const original=JSON.stringify(p);b.initializeRoom({appIdentifier:'app'},p,()=>{});await e.advance(0);
 assert.equal(e.joins.length,0);await e.advance(2100);b.completeSetup();
 assert.equal(e.joins[0].__nativeTags.time,'2026-10-19 08:09:07');
 assert.equal(e.joins[0].__nativeTags.custom,'retained');
 assert.match(e.joins[0].__nativeTags.traceId,/^[0-9a-f-]{36}$/i);assert.notEqual(e.joins[0].__nativeTags.traceId,'stale');
 assert.equal(JSON.stringify(p),original);
 await e.advance(50);b.initializeRoom({appIdentifier:'app'},p,()=>{});await e.advance(0);await e.advance(20);b.completeSetup();
 assert.equal(e.joins[1].__nativeTags.time,'2026-10-19 08:09:07');
 assert.notEqual(e.joins[0].__nativeTags.traceId,e.joins[1].__nativeTags.traceId);assert.equal(JSON.stringify(p),original);
});
test('delayed handshake T0 uses the eventual dispatch second',async()=>{
 const e=environment(),b=e.host({handshake:false}),p={...params(),timeout:10000};
 b.initializeRoom({appIdentifier:'app'},p,()=>{});await e.advance(0);await e.advance(2100);b.completeHandshake();
 assert.equal(e.joins[0].__nativeTags.time,'2026-10-19 08:09:07');assert.equal(p.__nativeTags,undefined);
});
test('same captured identity across two hosts closes old before new join',async()=>{
 const e=environment(),a=e.host(),b=e.host();a.initializeRoom({appIdentifier:'app'},params(),()=>{});await e.advance(0);
 b.initializeRoom({appIdentifier:'app'},params(),()=>{});await e.advance(0);assert.equal(a.state,'idle');assert.equal(b.state,'active');assert.equal(e.joins.length,2);
});
test('owner switching identity during local leave is not closed by stale replacement',async()=>{
 const e=environment(),a=e.host(),b=e.host(),p=uid=>({...params(),uid});
 a.initializeRoom({appIdentifier:'app'},p('K1'),()=>{});b.initializeRoom({appIdentifier:'app'},p('K2'),()=>{});await e.advance(0);
 b.holdLeave=true;b.initializeRoom({appIdentifier:'app'},p('K1'),()=>{});await e.advance(0);assert.equal(b.state,'closing');
 a.initializeRoom({appIdentifier:'app'},p('K3'),()=>{});await e.advance(0);assert.equal(a.state,'active');assert.equal(a.actualUid,'K3');
 b.completeLeave();await e.advance(0);assert.equal(b.state,'active');assert.equal(b.actualUid,'K1');assert.equal(a.state,'active');assert.equal(a.leaves,1);assert.equal(a.scope.generation,2);
});
for(const missingHandshake of [true,false])test((missingHandshake?'handshake':'setup')+' uses configured deadline and late callback never joins',async()=>{
 const e=environment(),b=e.host({handshake:!missingHandshake,setup:false}),results=[];b.initializeRoom({appIdentifier:'app'},params(),v=>results.push(v));await e.advance(0);await e.advance(101);
 assert.equal(results.length,1);assert.match(results[0],/JoinTimeout/);if(missingHandshake)b.completeHandshake();b.completeSetup?.();assert.equal(e.joins.length,0);assert.equal(results.length,1);
});
test('late failed setup cannot overwrite completed close',async()=>{
 const e=environment(),b=e.host({setup:false});b.initializeRoom({appIdentifier:'app'},params(),()=>{});await e.advance(0);await e.advance(101);assert.equal(b.state,'idle');b.completeSetup('{"__error":{"message":"late setup error"}}');assert.equal(b.state,'idle');assert.equal(e.joins.length,0);
});
test('late idle cannot overwrite cached close failure',async()=>{
 const e=environment(),b=e.host();b.initializeRoom({appIdentifier:'app'},params(),()=>{});await e.advance(0);b.closeResult='{"__error":{"message":"LeaveTimeout"}}';b.state='blocked';b.addJavascriptObject({},'sdk');b.call('sdk.lifecycleState',JSON.stringify({data:{scope:{...b.scope},value:{state:'idle'}}}));assert.equal(b.state,'blocked');
});
test('preparation never joins and same-config join reuses one setup',async()=>{
 const e=environment(),b=e.host(),results=[];
 b.prepare({appIdentifier:'app'},15000,v=>results.push(v));assert.equal(results.length,1);
 assert.equal(b.preparationInfo().ready,true);assert.equal(b.preparationInfo().generation,0);assert.equal(b.preparationInfo().roomState,'idle');assert.equal(e.joins.length,0);
 b.initializeRoom({appIdentifier:'app'},params(),()=>{});await e.advance(0);
 assert.equal(e.setups.length,1);assert.equal(e.joins.length,1);assert.equal(b.preparationInfo().setupCount,1);assert.equal(b.state,'active');
});
test('coalesced prepare uses immutable SDK snapshot',async()=>{
 const e=environment(),b=e.host({setup:false}),config={appIdentifier:'app',nested:{enabled:true}},results=[];
 b.prepare(config,15000,v=>results.push(v));b.prepare(config,15000,v=>results.push(v));config.nested.enabled=false;
 assert.equal(e.setups.length,1);assert.equal(e.setups[0].nested.enabled,true);b.completeSetup();assert.equal(results.length,2);assert.equal(b.preparationInfo().ready,true);
});
test('shorter prepare deadline rejects all callers once and late response cannot mark ready',async()=>{
 const e=environment(),b=e.host({setup:false}),results=[];
 b.prepare({appIdentifier:'app'},15000,v=>results.push(v));b.prepare({appIdentifier:'app'},50,v=>results.push(v));
 const late=b.completeSetup;await e.advance(51);assert.equal(results.length,2);assert.match(results[0],/PrepareTimeout/);late();assert.equal(b.preparationInfo().ready,false);
 b.prepare({appIdentifier:'app'},15000,v=>results.push(v));b.completeSetup();assert.equal(b.preparationInfo().ready,true);assert.equal(results.length,3);
});
test('cancel before handshake prevents SDK construction and join',async()=>{
 const e=environment(),b=e.host({handshake:false}),results=[];
 b.prepare({appIdentifier:'app'},15000,v=>results.push(v));b.cancelPreparation();b.completeHandshake();
 assert.equal(e.setups.length,0);assert.equal(e.joins.length,0);assert.equal(results.length,1);assert.match(results[0],/Cancelled/);
});
test('invalidation rejects preparation and ignores old response',async()=>{
 const e=environment(),b=e.host({setup:false}),results=[];
 b.prepare({appIdentifier:'app'},15000,v=>results.push(v));const late=b.completeSetup;b.invalidate();late();
 assert.equal(results.length,1);assert.match(results[0],/HostInvalid/);assert.equal(b.preparationInfo().ready,false);
});
test('preparation cannot reconfigure active Room and malformed setup can retry',async()=>{
 const e=environment(),b=e.host({setup:false}),results=[];
 b.prepare({appIdentifier:'app'},15000,v=>results.push(v));b.completeSetup('[]');assert.match(results[0],/InvalidSetupResult/);
 b.prepare({appIdentifier:'app'},15000,v=>results.push(v));b.completeSetup();b.initializeRoom({appIdentifier:'app'},params(),()=>{});await e.advance(0);
 b.prepare({appIdentifier:'other'},15000,v=>results.push(v));assert.match(results.at(-1),/Busy/);assert.equal(e.setups.length,2);
});
test('preparation on another facade cannot change SDK during a pending join',async()=>{
 const e=environment(),b=e.host({setup:false}),results=[];
 b.initializeRoom({appIdentifier:'app'},params(),()=>{});await e.advance(0);
 b.prepare({appIdentifier:'other'},15000,v=>results.push(v));assert.match(results[0],/Busy/);assert.equal(e.setups.length,1);
 b.completeSetup();assert.equal(e.joins.length,1);assert.equal(b.state,'active');
});
test('mismatched document setup result cannot mark preparation ready',async()=>{
 const e=environment(),b=e.host({setup:false}),results=[];
 b.prepare({appIdentifier:'app'},15000,v=>results.push(v));b.completeSetup('{}',{documentId:'stale-doc',generation:0});
 assert.match(results[0],/StaleScope/);assert.equal(b.preparationInfo().ready,false);assert.equal(e.joins.length,0);
});
test('equivalent reordered nested SDK JSON shares the prepared instance',async()=>{
 const e=environment(),b=e.host();b.prepare({appIdentifier:'app',dynamicConfig:{'cn-hz':'url-cn',us:'url-us'}},15000,()=>{});
 b.prepare({dynamicConfig:{us:'url-us','cn-hz':'url-cn'},appIdentifier:'app'},15000,()=>{});
 assert.equal(e.setups.length,1);assert.equal(b.preparationInfo().ready,true);
});
test('ordinary optional-off configs never observe preload',async()=>{
 for(const options of [{},{enableModelPreload:false},{preloadBuiltinApps:[]},{enableAppliancePlugin:true},{enablePreLoadAppliancePlugin:true}]) {
  const e=environment(),b=e.host();b.prepare({appIdentifier:'app',...options},15000,()=>{});
  assert.equal(b.observations,undefined);assert.equal(b.preparationInfo().ready,true);
 }
});
test('each explicit optional preparation enables observation',async()=>{
 for(const options of [{enableModelPreload:true},{dynamicConfig:{}},{preloadBuiltinApps:['Slide']},{enableAppliancePlugin:true,enablePreLoadAppliancePlugin:true}]) {
  const e=environment(),b=e.host();b.prepare({appIdentifier:'app',...options},15000,()=>{});assert.equal(b.observations,1);
 }
});
test('background construction has no implicit deadline and join reuses pending setup',async()=>{
 const e=environment(),b=e.host({setup:false});b.prepareInBackground({appIdentifier:'app'});
 await e.advance(20000);assert.equal(b.preparationInfo().ready,false);assert.equal(e.setups.length,1);
 b.initializeRoom({appIdentifier:'app'},params(),()=>{});await e.advance(0);b.completeSetup();
 assert.equal(e.setups.length,1);assert.equal(e.joins.length,1);assert.equal(b.preparationInfo().ready,true);
});
test('preload completion buffers for late listener and delivers original warn once',async()=>{
 const e=environment(),b=e.host(),results=[];
 b.prepare({appIdentifier:'app',preloadBuiltinApps:['Slide']},15000,()=>{});assert.equal(b.observations,1);
 b.completePreload({state:'warn',message:'Slide preparation failed'});await e.advance(0);assert.equal(results.length,0);
 b.setPreloadCallback(result=>results.push(result));await e.advance(0);assert.equal(results.length,1);assert.equal(results[0].state,'warn');
 b.completePreload();b.setPreloadCallback(result=>results.push(result));await e.advance(0);assert.equal(results.length,1);
});
test('cancelled and replaced preload tasks never deliver late results',async()=>{
 const e=environment(),b=e.host(),results=[];b.setPreloadCallback(result=>results.push(result));
 b.prepare({appIdentifier:'app',preloadBuiltinApps:['Slide']},15000,()=>{});const late=b.completePreload;b.cancelPreparation();late();await e.advance(0);assert.equal(results.length,0);
 b.prepare({appIdentifier:'other',preloadBuiltinApps:['Slide']},15000,()=>{});late();await e.advance(0);assert.equal(results.length,0);
 b.completePreload();await e.advance(0);assert.equal(results.length,1);
});
test('wrong document and malformed optional result are ignored without affecting readiness',async()=>{
 const e=environment(),b=e.host(),results=[];b.setPreloadCallback(result=>results.push(result));
 b.prepare({appIdentifier:'app',preloadBuiltinApps:['Slide']},15000,()=>{});b.completePreload({state:'success',message:''},{documentId:'old',generation:0});
 b.completePreload({state:'warn',message:''});await e.advance(0);assert.equal(results.length,0);assert.equal(b.preparationInfo().ready,true);
 b.completePreload();await e.advance(0);assert.equal(results.length,1);
});
test('throwing preload listener is isolated and never called a second time',async()=>{
 const e=environment(),b=e.host();let calls=0;b.setPreloadCallback(()=>{calls++;throw Error('host');});
 b.prepare({appIdentifier:'app',preloadBuiltinApps:['Slide']},15000,()=>{});b.completePreload();await e.advance(0);b.completePreload();await e.advance(0);assert.equal(calls,1);assert.equal(b.preparationInfo().ready,true);
});
(async()=>{for(const {name,fn} of tests){await fn();console.log('PASS '+name);}console.log(tests.length+' owner unit tests passed');})().catch(e=>{console.error(e);process.exitCode=1});
