// Executes the real controller and option mapper with a controlled host transport.
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert');
const ts=require(require.resolve('typescript',{paths:[path.join(__dirname,'../../Whiteboard-bridge')]}));
const root=path.join(__dirname,'../library/src/main/ets');
function load(name,runtime={}){
 const mod={exports:{}};
 const code=ts.transpileModule(fs.readFileSync(path.join(root,name+'.ets'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
 vm.runInNewContext(code,{module:mod,exports:mod.exports,require(id){
  if(id==='./JsInterfaces')return load('SDKError',runtime);
  if(id==='./WhiteboardJoinOptions')return load('WhiteboardJoinOptions',runtime);
  return {};
 },JSON,Promise,Date:runtime.Date||Date,setTimeout,clearTimeout,Number,Error});
 return mod.exports;
}
const {WhiteboardController}=load('WhiteboardController');
function host(){return {
 cancelPendingJoins(){},leaveRoom(cb){cb("{}");},calls:0,joins:[],info:{ready:false,viewId:'view',documentId:'doc',setupCount:1,generation:0,roomState:'idle',elapsedMs:10},
 prepare(sdk,timeout,cb){this.calls++;this.sdk=sdk;this.timeout=timeout;this.reply=(value='{}')=>{this.info.ready=!value.includes('__error');cb(value);};},
 preparationInfo(){return this.info;},cancelPreparation(){this.info.ready=false;this.cancelled=true;},
 initializeRoom(sdk,room,cb){this.joins.push(room);this.joinReply=cb;if(!this.holdJoin)cb('{"isWritable":false,"observerId":1,"state":{}}');},
};}
const tests=[];const test=(name,fn)=>tests.push({name,fn});
const flush=async()=>{for(let n=0;n<8;n++)await Promise.resolve();};
const ownerTests=fs.readFileSync(path.join(__dirname,'test-lifecycle-owner.cjs'),'utf8');
const ownerModule={exports:{}};
vm.runInNewContext(ownerTests.slice(0,ownerTests.indexOf('const params='))+'\nmodule.exports=environment;',
 {module:ownerModule,exports:ownerModule.exports,require,__dirname,process,console});
function realPreparation({attached=true,setup=false}={}){
 const e=ownerModule.exports(),b=e.host({setup}),c=new WhiteboardController();
 c.configureSdk({appIdentifier:'app'},()=>{});if(attached)c.attachWhiteboard(b);
 return {e,b,c};
}
test('prepare waits for actual attachment and uses captured SDK config',async()=>{
 const c=new WhiteboardController(),b=host(),sdk={appIdentifier:'app',log:true,disableNewPencilStroke:false,nested:{enabled:true}};
 const p=c.prepare(100);c.configureSdk(sdk,()=>{});sdk.nested.enabled=false;c.attachWhiteboard(b);await flush();
 assert.equal(b.calls,1);assert.equal(b.sdk.nested.enabled,true);assert.equal(b.joins.length,0);b.reply();assert.equal((await p).ready,true);
});
test('cancellation before attachment rejects and cannot start on later attachment',async()=>{
 const c=new WhiteboardController(),b=host();const p=c.prepare(30);const rejected=assert.rejects(p,/Cancelled/);c.cancelPreparation();await rejected;
 c.configureSdk({appIdentifier:'app'},()=>{});c.attachWhiteboard(b);await flush();assert.equal(b.calls,0);
});
test('detach rejects pending preparation and ignores late successful callback',async()=>{
 const c=new WhiteboardController(),b=host();c.configureSdk({appIdentifier:'app'},()=>{});c.attachWhiteboard(b);
 const p=c.prepare(100),rejected=assert.rejects(p,/Cancelled/);await flush();c.detachWhiteboard(b);b.reply();await rejected;assert.equal(c.getPreparationInfo(),undefined);
});
test('join snapshots room before waiting for attachment and preserves wire names',async()=>{
 const c=new WhiteboardController(),b=host(),room={roomUuid:'room',roomToken:'mock',uid:'uid',region:'cn-hz',writable:false,windowParams:{fullscreen:false}};
 const p=c.joinRoom(room);room.uid='mutated';room.windowParams.fullscreen=true;
 let ready=0;c.configureSdk({appIdentifier:'app'},w=>{assert.equal(w,false);ready++});c.attachWhiteboard(b);await p;
 assert.equal(b.joins[0].uuid,'room');assert.equal(b.joins[0].uid,'uid');assert.equal(b.joins[0].isWritable,false);assert.equal(b.joins[0].windowParams.fullscreen,false);assert.equal(ready,1);
});
test('missing attachment has a bounded deadline and invalid timeouts reject',async()=>{
 const c=new WhiteboardController();await assert.rejects(c.prepare(5),/AttachTimeout/);await assert.rejects(c.prepare(0),/InvalidPreparationOptions/);
});
test('detach rejects a dispatched join and its late success cannot update a prepared replacement',async()=>{
 const c=new WhiteboardController(),a=host(),b=host(),ready=[];a.holdJoin=true;
 c.configureSdk({appIdentifier:'app'},()=>ready.push('A'));c.attachWhiteboard(a);
 const joining=c.joinRoom({roomUuid:'room',roomToken:'mock',uid:'uid',region:'sg'});
 const rejected=assert.rejects(joining,/HostInvalid/);await flush();assert.equal(a.joins.length,1);
 c.detachWhiteboard(a);await rejected;
 c.configureSdk({appIdentifier:'app',region:'sg'},()=>ready.push('B'));c.attachWhiteboard(b);
 const preparing=c.prepare(100);await flush();b.reply();await preparing;
 a.joinReply('{"isWritable":true,"observerId":1,"state":{}}');
 assert.deepEqual(ready,[]);assert.equal(c.getWritable(),false);assert.equal(b.joins.length,0);assert.equal(c.joinCancels.length,0);
});
test('attach epoch rejects stale success even if the identical bridge is reattached',async()=>{
 const c=new WhiteboardController(),a=host(),ready=[];a.holdJoin=true;
 c.configureSdk({appIdentifier:'app'},()=>ready.push('old'));c.attachWhiteboard(a);
 const joining=c.joinRoom({roomUuid:'room',roomToken:'mock',uid:'uid',region:'cn-hz'});
 const rejected=assert.rejects(joining,/HostInvalid/);await flush();const late=a.joinReply;
 c.detachWhiteboard(a);c.attachWhiteboard(a);await rejected;
 late('{"isWritable":true,"observerId":1,"state":{}}');assert.deepEqual(ready,[]);assert.equal(c.getWritable(),false);
});
test('direct host replacement rejects old join; stale detach cannot cancel the current join',async()=>{
 const c=new WhiteboardController(),a=host(),b=host(),ready=[];a.holdJoin=true;b.holdJoin=true;
 c.configureSdk({appIdentifier:'app'},()=>ready.push('A'));c.attachWhiteboard(a);
 const old=c.joinRoom({roomUuid:'room',roomToken:'mock',uid:'uid',region:'cn-hz'});
 const rejected=assert.rejects(old,/HostInvalid/);await flush();
 c.configureSdk({appIdentifier:'app'},()=>ready.push('B'));c.attachWhiteboard(b);await rejected;
 const next=c.joinRoom({roomUuid:'room',roomToken:'mock',uid:'uid',region:'cn-hz'});await flush();
 c.detachWhiteboard(a);a.joinReply('{"isWritable":true,"observerId":1,"state":{}}');
 b.joinReply('{"isWritable":false,"observerId":2,"state":{}}');await next;
 assert.deepEqual(ready,['B']);assert.equal(c.joinCancels.length,0);
});
test('prepareCompletion defaults to 15000ms and resolves void; diagnostics stay separate',async()=>{
 class ClockDate extends Date{constructor(){super(1000);}}
 const {WhiteboardController:Controller}=load('WhiteboardController',{Date:ClockDate});
 const c=new Controller(),b=host();c.configureSdk({appIdentifier:'app'},()=>{});c.attachWhiteboard(b);
 const p=c.prepareCompletion();await flush();assert.equal(b.timeout,15000);b.reply();
 assert.equal(await p,undefined);assert.equal(c.getPreparationInfo().ready,true);
});
test('prepareCompletion explicit timeout includes time spent waiting for attachment',async()=>{
 let now=1000;class ClockDate extends Date{constructor(){super(now);}}
 const {WhiteboardController:Controller}=load('WhiteboardController',{Date:ClockDate});
 const c=new Controller(),b=host();const p=c.prepareCompletion(1200);
 now+=350;c.configureSdk({appIdentifier:'app'},()=>{});c.attachWhiteboard(b);await flush();
 assert.equal(b.timeout,850);b.reply();assert.equal(await p,undefined);
});
test('new and legacy preparation share one real SDK construction and reuse it on join',async()=>{
 const {e,b,c}=realPreparation();let preloadCount=0;b.setPreloadCallback(()=>preloadCount++);
 const legacy=c.prepare(15000),completion=c.prepareCompletion();await flush();
 assert.equal(e.setups.length,1);assert.equal(e.joins.length,0);b.completeSetup();
 assert.equal(await completion,undefined);const info=await legacy;
 assert.equal(info.ready,true);assert.equal(info.documentId,'doc');assert.equal(info.setupCount,1);
 // Optional preparation is still pending: basic completion must not wait for it.
 assert.equal(b.observations,1);assert.equal(preloadCount,0);
 assert.equal(await c.prepareCompletion(),undefined);assert.equal((await c.prepare()).ready,true);
 const call=b.dsInitBridge.callHandler;
 b.dsInitBridge.callHandler=(m,a,cb)=>call(m,a,m==='sdk.joinRoom'?v=>cb({...v,value:'{"isWritable":false,"observerId":1,"state":{}}'}):cb);
 await c.joinRoom({roomUuid:'room',roomToken:'mock',uid:'uid',region:'cn-hz'});
 assert.equal(e.setups.length,1);assert.equal(e.joins.length,1);assert.equal(preloadCount,0);
});
test('prepareCompletion propagates real setup errors and permits a later retry',async()=>{
 const {e,b,c}=realPreparation();const p=c.prepareCompletion(),rejected=assert.rejects(p,/synthetic setup failure/);
 await flush();b.completeSetup('{"__error":{"message":"synthetic setup failure"}}');await rejected;
 assert.equal(c.getPreparationInfo().ready,false);
 const retry=c.prepareCompletion();await flush();b.completeSetup();assert.equal(await retry,undefined);
 assert.equal(e.setups.length,2);
});
test('prepareCompletion cancellation before attachment cannot start a later SDK',async()=>{
 const {e,b,c}=realPreparation({attached:false});const p=c.prepareCompletion(100),rejected=assert.rejects(p,/Cancelled/);
 c.cancelPreparation();await rejected;c.attachWhiteboard(b);await flush();assert.equal(e.setups.length,0);
});
test('prepareCompletion dispatched cancellation rejects once and ignores a late real response',async()=>{
 const {e,b,c}=realPreparation();let settled=0;
 const p=c.prepareCompletion().then(()=>{settled++;},error=>{settled++;throw error;});
 const rejected=assert.rejects(p,/Cancelled/);await flush();assert.equal(e.setups.length,1);
 c.cancelPreparation();await rejected;b.completeSetup();await flush();
 assert.equal(settled,1);assert.equal(c.getPreparationInfo().ready,false);assert.equal(e.joins.length,0);
});
test('prepareCompletion explicit deadline rejects real pending setup and discards late success',async()=>{
 const {e,b,c}=realPreparation();const p=c.prepareCompletion(50),rejected=assert.rejects(p,/PrepareTimeout/);
 await flush();await e.advance(51);await rejected;b.completeSetup();await flush();
 assert.equal(c.getPreparationInfo().ready,false);assert.equal(e.joins.length,0);
});
test('prepareCompletion preserves legacy invalid-timeout rejection',async()=>{
 const c=new WhiteboardController();
 for(const timeout of [0,-1,NaN,Infinity])await assert.rejects(c.prepareCompletion(timeout),/InvalidPreparationOptions/);
 await assert.rejects(c.prepareCompletion(5),/AttachTimeout/);
});
test('immediate join without explicit preparation waits for attachment and setup once',async()=>{
 const {e,b,c}=realPreparation({attached:false}),ready=[];
 c.configureSdk({appIdentifier:'app'},()=>ready.push('ready'));
 const call=b.dsInitBridge.callHandler;
 b.dsInitBridge.callHandler=(m,a,cb)=>call(m,a,m==='sdk.joinRoom'?v=>cb({...v,value:'{"isWritable":false,"observerId":1,"state":{}}'}):cb);
 const joining=c.joinRoom({roomUuid:'room',roomToken:'mock',uid:'uid',region:'cn-hz'});
 await flush();assert.equal(e.setups.length,0);assert.equal(e.joins.length,0);
 c.attachWhiteboard(b);await flush();await e.advance(0);
 assert.equal(e.setups.length,1);assert.equal(e.joins.length,0);assert.equal(ready.length,0);
 b.completeSetup();await joining;
 assert.equal(e.setups.length,1);assert.equal(e.joins.length,1);assert.deepEqual(ready,['ready']);
 assert.equal(c.getPreparationInfo().ready,true);
});
(async()=>{for(const {name,fn}of tests){await fn();console.log('PASS '+name);}console.log(tests.length+' preload controller tests passed');})().catch(e=>{console.error(e);process.exitCode=1;});
