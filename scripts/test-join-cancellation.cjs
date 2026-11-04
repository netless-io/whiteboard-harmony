const fs = require('fs'), vm = require('vm'), path = require('path'), assert = require('assert');
const root = path.resolve(__dirname, '..');
const ts = require(require.resolve('typescript', {paths: [path.join(root, '../Whiteboard-bridge')]}));
const ownerTests = fs.readFileSync(path.join(root, 'scripts/test-lifecycle-owner.cjs'), 'utf8');
const ownerMod = {exports: {}};
vm.runInNewContext(ownerTests.slice(0, ownerTests.indexOf('const params=')) + '\nmodule.exports = environment;', {module: ownerMod, exports: ownerMod.exports, require, __dirname: path.join(root, 'scripts'), process, console});
const environment = ownerMod.exports;
function load(name) {
 const mod = {exports:{}};
 const code = ts.transpileModule(fs.readFileSync(path.join(root, 'library/src/main/ets', name + '.ets'), 'utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
 vm.runInNewContext(code, {module:mod,exports:mod.exports,require(id){if(id==='./JsInterfaces')return load('SDKError');if(id==='./WhiteboardJoinOptions')return load('WhiteboardJoinOptions');return {};},JSON,Promise,Date,setTimeout,clearTimeout,Number,Error});
 return mod.exports;
}
const {WhiteboardController} = load('WhiteboardController');
const room = {roomUuid:'room',roomToken:'mock',uid:'uid',region:'sg',timeout:1000};
function setup(attached=true) {
 const e=environment(),b=e.host(),c=new WhiteboardController(),ready=[];
 const call=b.dsInitBridge.callHandler;
 b.dsInitBridge.callHandler=(m,a,cb)=>call(m,a,m==='sdk.joinRoom' ? value=>cb({...value,value:'{"isWritable":false,"observerId":1,"state":{}}'}) : cb);
 c.configureSdk({appIdentifier:'app'},()=>ready.push('ready'));if(attached)c.attachWhiteboard(b);
 return {e,b,c,ready};
}
(async()=>{
 let passed=0;
 for(const turn of [0,1]) {
  const {e,b,c,ready}=setup();const p=c.joinRoom(room), rejected=assert.rejects(p,/Cancelled/);
  if(turn)await Promise.resolve();
  await c.leaveRoom();await rejected;await e.advance(0);
  assert.equal(e.joins.length,0);assert.equal(b.state,'idle');assert.equal(ready.length,0);assert.equal(c.joinCancels.length,0);
  await c.joinRoom({...room,uid:'new'});assert.equal(e.joins.length,1);assert.equal(ready.length,1);passed++;
 }
 for(const turn of [0,1]) {
  const {e,b,c,ready}=setup();const p=c.joinRoom(room),rejected=assert.rejects(p,/HostInvalid/);
  if(turn)await Promise.resolve();c.detachWhiteboard(b);c.attachWhiteboard(b);
  await rejected;await e.advance(0);assert.equal(e.joins.length,0);assert.equal(ready.length,0);passed++;
 }
 {
  const {e,b,c}=setup(false);const p=c.joinRoom(room),rejected=assert.rejects(p,/Cancelled/);
  await assert.rejects(c.leaveRoom(),/not attached/);await rejected;
  assert.equal(c.attachWaiters.length,0);assert.equal(c.joinCancels.length,0);
  c.attachWhiteboard(b);await e.advance(0);assert.equal(e.joins.length,0);await c.joinRoom(room);assert.equal(e.joins.length,1);passed++;
 }
 {
  const {e,b,c}=setup(false);const p=c.joinRoom(room);c.attachWhiteboard(b);await p;assert.equal(e.joins.length,1);passed++;
 }
 for(const invalid of [false,true]) {
  const {e,b}=setup();const results=[];
  b.initializeRoom({appIdentifier:'app'},{uuid:'room',roomToken:'mock',uid:'uid'},v=>results.push(v));
  if(invalid)b.invalidate();else b.leaveRoom(()=>{});
  await e.advance(0);assert.equal(e.joins.length,0);assert.equal(results.length,1);assert.match(results[0],invalid?/HostInvalid/:/Cancelled/);passed++;
 }
 console.log(passed+' actual Controller + DsBridge cancellation regressions passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
