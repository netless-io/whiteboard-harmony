// Actual Controller + scoped Bridge handlers + JSON transport. SDK objects are synthetic.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const helper = fs.readFileSync(path.join(__dirname, 'test-wire-contract.cjs'), 'utf8');
const mod = { exports: {} };
vm.runInNewContext(helper.slice(0, helper.indexOf('const tests = [];')) + '\nmodule.exports = {environment,compile,ts,bridgeRoot};',
  { module: mod, exports: mod.exports, require, __dirname, console, process, queueMicrotask, setTimeout, clearTimeout });
const h = mod.exports;
const read = name => fs.readFileSync(path.join(h.bridgeRoot, name), 'utf8');
function declaration(source, name) {
  const ast = h.ts.createSourceFile('bridge.ts', source, h.ts.ScriptTarget.Latest, true);
  return ast.statements.find(n => n.name?.text === name).getText(ast);
}
const plain = value => value === undefined ? undefined : JSON.parse(JSON.stringify(value));
const deadline = promise => Promise.race([promise, new Promise((_, reject) => {
  const timer = setTimeout(() => reject(new Error('API remained pending')), 1000); timer.unref();
})]);
async function environment(single = false) {
  const e = h.environment(); await e.join();
  const scenes = [{name:'init'}, {name:'second'}];
  const room = { phase:'connected', state:{sceneState:{index:0,scenes}, roomMembers:[],memberState:{},globalState:{},broadcastState:{}},
    entireScenes:() => ({'/':scenes}), setSceneIndex(index) { room.state.sceneState.index = index; }, setScenePath() {},
    insertText:() => 'text-id', isWritable:true, observerId:1, setWritable:async v => { room.isWritable = v; } };
  const manager = { apps:{'app-id':{kind:'Slide',options:{},state:{}}}, sceneState:room.state.sceneState,
    pageState:{index:0,length:2},boxState:'normal',cameraState:{centerX:0,centerY:0,scale:1},
    focusedView:{insertText:()=>'text-id'}, closeApp:async()=>{},nextPage:async()=>true,prevPage:async()=>false,
    setMainViewSceneIndex() {},setMainViewScenePath() {} };
  e.context.window.manager = single ? undefined : manager;
  e.context.__room = room; e.context.scopedCall = e.scoped.scopedCall;
  e.context.focusAppOuter = async () => false;
  const code = [declaration(read('src/utils/Funs.ts'),'createPageState'),
    ...['RoomAsyncBridge','RoomStateBridge'].map(n=>declaration(read('src/bridge/Room.ts'),n)),
    declaration(read('src/bridge/Displayer.ts'),'DisplayerBridge'),
    'globalThis.__api = {room:new RoomAsyncBridge(__room),state:new RoomStateBridge(__room),displayer:new DisplayerBridge(__room)};'].join('\n');
  e.life.inScope(e.native.scope, () => {
    vm.runInContext('(function(exports){' + h.compile(code) + '\n})({});', e.context);
    e.scoped.registerAsyn('room', e.context.__api.room);
    e.scoped.register('room.state', e.context.__api.state);
    e.scoped.register('displayer', e.context.__api.displayer);
  });
  return Object.assign(e,{room,manager});
}
const tests = [];
const test = (name, run) => tests.push({name,run});
const replyCount = e => e.wire.filter(x=>x.method==='_dsb.returnValue').length;
const lastValue = e => e.wire.filter(x=>x.method==='_dsb.returnValue').at(-1).args.data.data.value;
for (const single of [true,false]) test(`structured room state and entireScenes (${single?'single':'multi'})`, async()=>{
  const e = await environment(single);
  const state = plain(await deadline(e.controller.getRoomState()));
  assert.deepEqual(state.pageState,{index:0,length:2});
  if (!single) assert.equal(state.windowBoxState,'normal');
  assert.equal(typeof lastValue(e),'object');
  assert.deepEqual(plain(await deadline(e.controller.getEntireScenes())),{'/':[{name:'init'},{name:'second'}]});
  assert.equal(typeof lastValue(e),'object');
  await e.controller.leaveRoom();
});
test('apps absent and empty return JSON string empty dictionary; populated queries preserve protocol',async()=>{
  const e = await environment();
  assert.deepEqual(plain(await e.controller.queryApp('app-id')),e.manager.apps['app-id']);
  assert.equal(typeof lastValue(e),'string');
  for(const apps of [undefined,{}]) {
    e.manager.apps=apps; assert.deepEqual(plain(await deadline(e.controller.queryAllApps())),{});
    assert.equal(lastValue(e),'{}');
  }
  await assert.rejects(deadline(e.controller.queryApp('missing')),/not existed/);
  await e.controller.leaveRoom();
});
for (const api of ['queryApp','queryAllApps','closeApp']) test(`${api} rejects once without manager`,async()=>{
  const e = await environment(true), before=replyCount(e);
  await assert.rejects(deadline(e.controller[api](...(api==='queryAllApps'?[]:['app-id']))),/window manager not existed/);
  assert.equal(replyCount(e)-before,1); await e.controller.leaveRoom();
});
for (const [api,args] of [['getRoomPhase',[]],['setScenePath',['/init']],['setSceneIndex',[0]],['nextPage',[]],['prevPage',[]]]) {
  test(`${api} rejects before attachment and after detach`,async()=>{
    const e = h.environment();
    const fresh = new e.controller.constructor();
    await assert.rejects(deadline(fresh[api](...args)),/Whiteboard is not attached/);
    e.controller.detachWhiteboard(e.native);
    await assert.rejects(deadline(e.controller[api](...args)),/Whiteboard is not attached/);
    e.controller.attachWhiteboard(e.native); e.controller.detachWhiteboard(e.native);
    await assert.rejects(deadline(e.controller[api](...args)),/Whiteboard is not attached/);
  });
}
for (const api of ['closeApp','nextPage','prevPage']) for (const synchronous of [false,true]) test(`${api} ${synchronous?'sync throw':'async reject'} reaches Native exactly once`,async()=>{
  const e = await environment(), unhandled=[];
  const listener = err=>unhandled.push(String(err)); process.on('unhandledRejection',listener);
  try {
    e.manager[api] = synchronous ? ()=>{throw new Error('synthetic failure');} : async()=>{throw new Error('synthetic failure');};
    const before=replyCount(e);
    await assert.rejects(deadline(e.controller[api](...(api==='closeApp'?['app-id']:[]))),/synthetic failure/);
    await new Promise(r=>setImmediate(r));
    assert.equal(replyCount(e)-before,1); assert.deepEqual(unhandled,[]);
  } finally { process.off('unhandledRejection',listener); await e.controller.leaveRoom(); }
});
test('void close success, text ID and false boolean remain valid',async()=>{
  const e=await environment();
  assert.equal(await e.controller.closeApp('app-id'),true); assert.equal(lastValue(e),undefined);
  assert.equal(await e.controller.insertText(0,0,'hello'),'text-id');
  assert.equal(await e.controller.nextPage(),true); assert.equal(await e.controller.prevPage(),false);
  assert.equal(await e.controller.focusApp('app-id'),false);
  await e.controller.leaveRoom();
});
test('single-window page boundaries and scene setters retain their results',async()=>{
  const e=await environment(true);
  assert.equal(await e.controller.prevPage(),false);assert.equal(await e.controller.nextPage(),true);
  assert.equal(await e.controller.nextPage(),false);assert.equal(await e.controller.prevPage(),true);
  assert.equal(await e.controller.setSceneIndex(0),true);assert.equal(await e.controller.setScenePath('/init'),true);
  assert.equal(await e.controller.getRoomPhase(),'connected');await e.controller.leaveRoom();
});
for(const single of [true,false]) test(`insertText rejects synchronous SDK error (${single?'single':'multi'})`,async()=>{
  const e=await environment(single); const target=single?e.room:e.manager.focusedView;
  target.insertText=()=>{throw new Error('synthetic insertion denied');};
  await assert.rejects(deadline(e.controller.insertText(0,0,'text')),/synthetic insertion denied/);
  await e.controller.leaveRoom();
});
test('left room errors are not successful IDs, close results or type errors',async()=>{
  const e=await environment();await e.controller.leaveRoom();
  for(const api of ['closeApp','insertText','nextPage','prevPage','getRoomState','getEntireScenes','queryAllApps']) {
    await assert.rejects(deadline(e.controller[api](...(api==='insertText'?[0,0,'text']:['app-id']))),/StaleScope/);
  }
});
function fake(e, value) { e.controller.attachWhiteboard({cancelPendingJoins(){},callHandler(_m,_a,cb){cb(value);}}); }
test('legacy JSON strings and current object values both parse',async()=>{
  const e=h.environment();
  for(const stringify of [false,true]) for(const [api,value] of [
    ['getRoomState',{pageState:{index:0,length:1},windowBoxState:'normal'}],['getRoomState',{}],
    ['getEntireScenes',{'/':[{name:'init'}]}],['getEntireScenes',{}],
    ['queryAllApps',{}],['queryAllApps',{id:{kind:'Slide'}}],['getRoomMembers',[]],['getGlobalState',{}],
    ['focusApp',false]]) {
    fake(e,stringify?JSON.stringify(value):value);assert.deepEqual(plain(await deadline(e.controller[api]('id'))),value);
  }
});
test('malformed and invalid structures reject instead of returning invalid typed objects',async()=>{
  const e=h.environment();
  for(const api of ['getRoomState','getEntireScenes','queryAllApps']) {
    for(const value of [undefined,null,[],false,1,'null','[]','false','1','"text"','{invalid']) {
      fake(e,value);await assert.rejects(deadline(e.controller[api]()),err=>!err.message.includes('remained pending'));
    }
  }
  for(const [api,value] of [['getRoomState',{pageState:{index:0}}],['getRoomState',{pageState:null}],
    ['getEntireScenes',{'/':{name:'bad'}}],['getEntireScenes',{'/':[null]}],
    ['queryAllApps',{id:null}],['queryAllApps',{id:{kind:1}}],['closeApp',{}]]) {
    fake(e,value);await assert.rejects(deadline(e.controller[api]('id')));
  }
});
test('object and string __error are recognized before success/type checks',async()=>{
  const e=h.environment();
  for(const stringify of [false,true]) for(const api of ['getRoomState','getEntireScenes','queryAllApps','closeApp','insertText','nextPage','prevPage','getRoomPhase']) {
    const value={__error:{message:'contract failure',jsStack:'synthetic stack'}};
    fake(e,stringify?JSON.stringify(value):value);
    await assert.rejects(deadline(e.controller[api]('id')),/contract failure/);
  }
});
let completed=false;
process.on('beforeExit',()=>{if(!completed&&!process.exitCode){console.error('FAIL unresolved test');process.exitCode=1;}});
(async()=>{for(const t of tests){await t.run();console.log('PASS '+t.name);}completed=true;console.log(`${tests.length} API contract tests passed`);})().catch(e=>{console.error(e);process.exitCode=1;});
