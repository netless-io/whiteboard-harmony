// Executes the real controller and option mapper with a controlled host transport.
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert');
const ts=require(require.resolve('typescript',{paths:[path.join(__dirname,'../../Whiteboard-bridge')]}));
const root=path.join(__dirname,'../library/src/main/ets');
function load(name){
 const mod={exports:{}};
 const code=ts.transpileModule(fs.readFileSync(path.join(root,name+'.ets'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
 vm.runInNewContext(code,{module:mod,exports:mod.exports,require(id){
  if(id==='./JsInterfaces')return load('SDKError');
  if(id==='./WhiteboardJoinOptions')return load('WhiteboardJoinOptions');
  return {};
 },JSON,Promise,Date,setTimeout,clearTimeout,Number,Error});
 return mod.exports;
}
const {WhiteboardController}=load('WhiteboardController');
function host(){return {
 cancelPendingJoins(){},leaveRoom(cb){cb("{}");},calls:0,joins:[],info:{ready:false,viewId:'view',documentId:'doc',setupCount:1,generation:0,roomState:'idle',elapsedMs:10},
 prepare(sdk,timeout,cb){this.calls++;this.sdk=sdk;this.reply=()=>{this.info.ready=true;cb('{}')};},
 preparationInfo(){return this.info;},cancelPreparation(){this.info.ready=false;this.cancelled=true;},
 initializeRoom(sdk,room,cb){this.joins.push(room);this.joinReply=cb;if(!this.holdJoin)cb('{"isWritable":false,"observerId":1,"state":{}}');},
};}
const tests=[];const test=(name,fn)=>tests.push({name,fn});
const flush=async()=>{for(let n=0;n<8;n++)await Promise.resolve();};
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
(async()=>{for(const {name,fn}of tests){await fn();console.log('PASS '+name);}console.log(tests.length+' preload controller tests passed');})().catch(e=>{console.error(e);process.exitCode=1;});
