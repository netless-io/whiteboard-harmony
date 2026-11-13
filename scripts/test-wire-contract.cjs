// Offline transport integration: actual ArkTS JSON transport + pinned Bridge handlers.
// No WebView/device/network runtime is claimed. All credentials below are synthetic.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const bridgeRoot = process.env.WHITEBOARD_BRIDGE_ROOT || path.resolve(__dirname, '../../Whiteboard-bridge');
const revision = process.env.WHITEBOARD_BRIDGE_REVISION;
const ts = require(require.resolve('typescript', { paths: [bridgeRoot] }));
const pinned = name => revision ? execFileSync('git', ['show', `${revision}:src/bridge/${name}.ts`], { cwd: bridgeRoot, encoding: 'utf8' }) : fs.readFileSync(path.join(bridgeRoot, 'src/bridge', name + '.ts'), 'utf8');
const sources = Object.fromEntries(['index', 'Lifecycle', 'SDK', 'Room'].map(name => [name, pinned(name)]));
const compile = code => ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS } }).outputText;
const plain = value => JSON.parse(JSON.stringify(value));
function member(source, name) {
  const ast = ts.createSourceFile('bridge.ts', source, ts.ScriptTarget.Latest, true);
  let found;
  function visit(node) {
    if (ts.isPropertyDeclaration(node) && node.name?.getText(ast) === name) found = node.initializer.getText(ast);
    ts.forEachChild(node, visit);
  }
  visit(ast); assert.ok(found, `pinned handler ${name}`); return found;
}
function declaration(source, name) {
  const ast = ts.createSourceFile('bridge.ts', source, ts.ScriptTarget.Latest, true);
  return ast.statements.find(node => ts.isFunctionDeclaration(node) && node.name.text === name).getText(ast);
}
function environment({ closeError, holdJoin = false, holdClose = false } = {}) {
  const wire = [], received = [], callbacks = [], timers = new Set(), roomLogs = [], closeReplies = [];
  const context = vm.createContext({ console, JSON, Promise, Date, Math, Error, Map, setTimeout(fn, delay) {
    if (!delay) { queueMicrotask(fn); return 0; }
    const timer = { fn, delay }; timers.add(timer); return timer;
  }, clearTimeout(timer) { timers.delete(timer); } });
  context.window = {};
  const cache = new Map();
  function load(key, source) {
    if (cache.has(key)) return cache.get(key).exports;
    const mod = { exports: {} }; cache.set(key, mod);
    vm.runInContext(`(function(require,module,exports){${compile(source)}\n})`, context)(requireModule, mod, mod.exports);
    return mod.exports;
  }
  function requireModule(name) {
    if (name === '@kit.ArkTS') return { util: { generateRandomUUID: randomUUID } };
    if (name === '@kit.ArkUI') return { ColorMetrics: {} };
    if (name === 'uuid') return { v4: randomUUID };
    if (name === './Logger') return { Logger: { error() {}, info() {} } };
    if (name === './Lifecycle') return load('Lifecycle', sources.Lifecycle);
    if (name === '../bridge') return scoped;
    if (name === '@netless/webview-bridge') return load('transport', fs.readFileSync(path.join(bridgeRoot, 'node_modules/@netless/webview-bridge/src/bridge.ts'), 'utf8'));
    if (name.startsWith('./')) return load(name, fs.readFileSync(path.join(__dirname, '../library/src/main/ets', name.slice(2) + '.ets'), 'utf8'));
    throw new Error(`unexpected import ${name}`);
  }
  const { DsBridge } = requireModule('./DsBridge');
  const native = new DsBridge({ runJavaScript(code) {
    if (code.startsWith('window._handleMessageFromNative(')) {
      const call = JSON.parse(code.slice('window._handleMessageFromNative('.length, -1));
      wire.push({ direction: 'Native->Bridge', call });
    } else {
      wire.push({ direction: 'Native->Bridge', script: code });
    }
    return vm.runInContext(code, context);
  } });
  context.window._dsbridge = { call(method, args) {
    wire.push({ direction: 'Bridge->Native', method, args: JSON.parse(args) });
    return native.call(method, args);
  } };
  const scoped = load('scoped', sources.index);
  const life = load('Lifecycle', sources.Lifecycle);
  Object.assign(context, life);
  context.dispatchDocsEventOuter = async (_manager, event, options) => {
    received.push({ method: 'dispatchDocsEvent', args: plain([event, options]) });
    return { accepted: false, reason: 'stateUnavailable', message: 'render pending' };
  };
  context.getPageStateOuter = async (_manager, options) => {
    received.push({ method: 'getPageState', args: plain([options]) });
    if (options.target === 'error') throw new Error('page lookup failed');
    return { target: 'Slide', appId: 'slide-fixture', page: 2, pageCount: 12, scale: 1 };
  };
  context.window.manager = { addApp: async params => { received.push({ method: 'addApp', args: plain([params]) }); return 'slide-fixture'; } };
  vm.runInContext(compile(declaration(sources.Room, 'addWindowApp') + '\n' + declaration(sources.Room, 'addAppAndRespond')), context);
  function handler(source, name) { return vm.runInContext(compile('globalThis.__selected = ' + member(source, name)), context), context.__selected; }
  let closeCount = 0;
  const joinReplies = [];
  const sdk = {
    getLifecycle: handler(sources.SDK, 'getLifecycle'),
    newWhiteSdk(options, cb) { received.push({ method: 'newWhiteSdk', args: plain([options]) }); cb('{}'); },
    joinRoom(options, cb) {
      received.push({ method: 'joinRoom', args: plain([options]) });
      const task = life.lifecycle.begin('room', life.currentScope(), cb);
      task.object = { phase: 'connected', logger: { error:message=>roomLogs.push(message) }, disconnect: async () => { closeCount++; if (holdClose) await new Promise(resolve=>closeReplies.push(resolve)); if (closeError) throw new Error(closeError); task.object.phase = 'disconnected'; } };
      const complete = () => { task.settle(); life.lifecycle.activate(task, holdJoin ? JSON.stringify({ isWritable: true, observerId: 1, state: {} }) : '{}'); };
      if (holdJoin) joinReplies.push(complete); else complete();
      life.inScope(task.scope, () => scoped.registerAsyn('room', Object.fromEntries(['disconnect', 'dispatchDocsEvent', 'getPageState', 'addApp'].map(name => [name, handler(sources.Room, name)]))));
    },
    leaveRoom: handler(sources.SDK, 'leaveRoom'),
    continueAfterLeaveFailure: handler(sources.SDK, 'continueAfterLeaveFailure'),
  };
  scoped.registerAsyn('sdk', sdk);
  const { SdkJsInterface } = requireModule('./JsInterfaces');
  const { WhiteboardCallbacks } = requireModule('./WhiteboardCallbacks');
  const nativeCallbacks = new WhiteboardCallbacks()
    .setOnSlidePageStateChanged((...args) => callbacks.push(['slide', ...args]))
    .setOnUnifiedPageStateChange(value => callbacks.push(['unified', plain(value)]));
  const sdkInterface = new SdkJsInterface(nativeCallbacks);
  native.addJavascriptObject(sdkInterface, 'sdk');
  const callbackSource = revision
    ? execFileSync('git', ['show', `${revision}:src/native/SDKCallbackHandler.ts`], { cwd: bridgeRoot, encoding: 'utf8' })
    : fs.readFileSync(path.join(bridgeRoot, 'src/native/SDKCallbackHandler.ts'), 'utf8');
  const { SDKCallbackHandler } = load('SDKCallbackHandler', callbackSource);
  const sdkEvents = new SDKCallbackHandler();
  const { WhiteboardController } = requireModule('./WhiteboardController');
  const controller = new WhiteboardController(); controller.attachWhiteboard(native);
  const builders = requireModule('./WhiteboardJoinOptions');
  const options = { appIdentifier: 'synthetic-app', roomUuid: 'synthetic-room', roomToken: 'synthetic-token', uid: randomUUID(), region: 'cn-hz' };
  async function join(overrides = {}) {
    const input = { ...options, ...overrides };
    const sdkOptions = builders.buildSdkOptions(input), roomOptions = builders.buildRoomOptions(input);
    const before = JSON.stringify([sdkOptions, roomOptions]);
    const result = await new Promise(resolve => native.initializeRoom(sdkOptions, roomOptions, resolve));
    assert.equal(result, '{}'); assert.equal(JSON.stringify([sdkOptions, roomOptions]), before);
    return input;
  }
  return { native, controller, join, wire, received, callbacks, nativeCallbacks, sdkInterface, sdkEvents,
    scoped, life, context, joinReplies, roomLogs, closeReplies, timeoutLeave() { for(const timer of [...timers]) if(timer.delay===20000) {timers.delete(timer);timer.fn();} }, get closeCount() { return closeCount; } };
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
for(const api of ['leaveRoom','disconnect'])test(`actual JSON ${api} failure stays observable and next join retires both lifecycle scopes`,async()=>{
 const e=environment({closeError:'synthetic old close failure'});await e.join();const old=e.life.lifecycle.task;
 await assert.rejects(e.controller[api](),/synthetic old close failure/);assert.equal(e.roomLogs.length,1);
 await e.join();assert.equal(e.native.state,'active');assert.equal(e.life.lifecycle.state,'active');assert.notEqual(e.life.lifecycle.task,old);
 assert.equal(e.received.filter(x=>x.method==='joinRoom').length,2);assert.equal(e.closeCount,1);
 e.life.lifecycle.phase(old,'error');assert.equal(e.life.lifecycle.state,'active');e.native.destroy();return e;
});
test('actual JSON replacement after Native leave deadline continues; late JS close cannot poison new Room',async()=>{
 const e=environment({holdClose:true});await e.join();const joining=e.join();
 for(let i=0;i<30;i++)await Promise.resolve();assert.equal(e.closeCount,1);e.timeoutLeave();await joining;
 assert.equal(e.roomLogs.length,1);assert.equal(e.life.lifecycle.state,'active');assert.equal(e.native.state,'active');
 e.closeReplies[0]();for(let i=0;i<30;i++)await Promise.resolve();assert.equal(e.native.state,'active');assert.equal(e.life.lifecycle.state,'active');
 e.native.destroy();return e;
});
test('actual JSON preserves explicit false, nested options, enums, omission and native T0', async () => {
  const e = environment();
  await e.join({ writable: false, disableDeviceInputs: false, useMultiViews: false,
    dynamicConfig: { 'cn-hz': 'https://example.invalid/latest.json' },
    windowParams: { fullscreen: false, forceMaximized: true, originSize: { width: 1280, height: 720 } },
    slideAppOptions: { enableScale: false, navigationButtonMode: 'step', syncEventQueuePolicy: 'latest-pending-render' },
    appliancePluginOptions: { cursor: { enable: false, expirationTime: 1000 } }, localLogOptions: { enabled: false } });
  const sdk = e.received.find(x => x.method === 'newWhiteSdk').args[0];
  const room = e.received.find(x => x.method === 'joinRoom').args[0];
  assert.equal(sdk.useMultiViews, false); assert.equal(sdk.loggerOptions.localLog.enabled, false);
  assert.equal(sdk.region, 'cn-hz');
  assert.deepEqual(sdk.slideAppOptions, { enableScale: false, navigationButtonMode: 'step', syncEventQueuePolicy: 'latest-pending-render', showRenderError: false });
  assert.equal(sdk.dynamicConfig['cn-hz'], 'https://example.invalid/latest.json');
  assert.ok(!Object.hasOwn(sdk, 'backgroundImageLoadOptions'));
  assert.equal(room.isWritable, false); assert.equal(room.disableDeviceInputs, false);
  assert.deepEqual(room.windowParams, { fullscreen: false, forceMaximized: true, originSize: { width: 1280, height: 720 } });
  assert.equal(room.appliancePluginOptions.cursor.enable, false);
  assert.equal(sdk.appliancePluginOptions.cursor.enable, false);
  assert.match(room.__nativeTags.time, /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/); assert.match(room.__nativeTags.traceId, /^[\da-f-]{36}$/);
  assert.ok(!Object.hasOwn(room, '__whiteScope'));
  assert.ok(e.wire.some(x => x.call?.method === 'sdk.joinRoom' && JSON.parse(x.call.data)[0].__whiteScope.generation === 1));
  await e.controller.disconnect(); return e;
});
test('SDK region survives actual JSON transport; Room region remains an explicit override', async () => {
  const e = environment();
  const buildersSource = fs.readFileSync(path.join(__dirname, '../library/src/main/ets/WhiteboardJoinOptions.ets'), 'utf8');
  const module = { exports: {} };
  vm.runInNewContext(compile(buildersSource), { module, exports: module.exports });
  const sdkOptions = module.exports.buildSdkOptions({ appIdentifier: 'synthetic-app', region: 'sg' });
  const absent = plain(module.exports.buildSdkOptions({ appIdentifier: 'synthetic-app' }));
  assert.ok(!Object.hasOwn(absent, 'region'), 'omitted region must retain the Web SDK default');
  e.controller.configureSdk(sdkOptions, () => {});
  const preparing = e.controller.prepareCompletion();
  await preparing;
  assert.equal(e.received.find(x => x.method === 'newWhiteSdk').args[0].region, 'sg');
  await e.controller.joinRoom({ roomUuid: 'synthetic-room', roomToken: 'synthetic-token', uid: randomUUID(), region: 'us-sv' });
  assert.equal(e.received.find(x => x.method === 'joinRoom').args[0].region, 'us-sv');
  await e.controller.disconnect(); return e;
});
test('apiHosts keeps omission and copies the host array through actual Native JSON', async () => {
  const e = environment();
  const source = fs.readFileSync(path.join(__dirname, '../library/src/main/ets/WhiteboardJoinOptions.ets'), 'utf8');
  const mod = { exports: {} };
  vm.runInNewContext(compile(source), { module: mod, exports: mod.exports });
  const absent = plain(mod.exports.buildSdkOptions({ appIdentifier: 'synthetic-app' }));
  assert.ok(!Object.hasOwn(absent, 'apiHosts'));
  const hosts = ['api.netless.group'];
  const options = mod.exports.buildSdkOptions({ appIdentifier: 'synthetic-app', apiHosts: hosts });
  hosts[0] = 'example.invalid';
  e.controller.configureSdk(options, () => {});
  await e.controller.prepareCompletion();
  assert.deepEqual(e.received.find(x => x.method === 'newWhiteSdk').args[0].apiHosts, ['api.netless.group']);
  await e.controller.disconnect(); return e;
});
test('model preload opt-in preserves omission/false/true across Native JSON', async () => {
  const e = environment();
  const source = fs.readFileSync(path.join(__dirname, '../library/src/main/ets/WhiteboardJoinOptions.ets'), 'utf8');
  const mod = { exports: {} };
  vm.runInNewContext(compile(source), { module: mod, exports: mod.exports });
  for (const enabled of [undefined, false, true]) {
    const options = mod.exports.buildSdkOptions({ appIdentifier: 'synthetic-app', enableModelPreload: enabled });
    const payload = plain(options);
    assert.equal(payload.enableModelPreload, enabled);
    assert.equal(Object.hasOwn(payload, 'enableModelPreload'), enabled !== undefined);
    e.controller.configureSdk(options, () => {});
    await e.controller.prepareCompletion();
    assert.equal(e.received.filter(x => x.method === 'newWhiteSdk').at(-1).args[0].enableModelPreload, enabled);
  }
  return e;
});
test('App preload list preserves omission, empty selection and exact kind names in Native JSON', async () => {
  const e = environment();
  const source = fs.readFileSync(path.join(__dirname, '../library/src/main/ets/WhiteboardJoinOptions.ets'), 'utf8');
  const mod = { exports: {} };
  vm.runInNewContext(compile(source), { module: mod, exports: mod.exports });
  for (const kinds of [undefined, [], ['Slide', 'Presentation'], ['DocsViewer', 'MediaPlayer']]) {
    const input = { appIdentifier: 'synthetic-app', preloadBuiltinApps: kinds };
    const options = mod.exports.buildSdkOptions(input);
    if (kinds) assert.notEqual(options.preloadBuiltinApps, kinds, 'mapper owns its list snapshot');
    const payload = plain(options);
    assert.equal(Object.hasOwn(payload, 'preloadBuiltinApps'), kinds !== undefined);
    assert.deepEqual(payload.preloadBuiltinApps, kinds);
    e.controller.configureSdk(options, () => {});
    await e.controller.prepareCompletion();
    assert.deepEqual(e.received.filter(x => x.method === 'newWhiteSdk').at(-1).args[0].preloadBuiltinApps, kinds);
  }
  return e;
});
test('real detached join callback cannot announce roomReady on a new prepared component', async () => {
  const a = environment({ holdJoin: true }), b = environment(), ready = [];
  const controller = a.controller;
  controller.configureSdk({ appIdentifier: 'synthetic-app', region: 'sg' }, () => ready.push('A'));
  const joining = controller.joinRoom({ roomUuid: 'synthetic-room', roomToken: 'synthetic-token', uid: randomUUID(), region: 'sg' });
  const rejected = assert.rejects(joining, /HostInvalid/);
  for (let turn = 0; turn < 30; turn++) await Promise.resolve();
  assert.equal(a.joinReplies.length, 1);
  controller.detachWhiteboard(a.native); await rejected;
  controller.configureSdk({ appIdentifier: 'synthetic-app', region: 'sg' }, () => ready.push('B'));
  controller.attachWhiteboard(b.native); await controller.prepareCompletion();
  assert.equal(b.native.state, 'idle'); assert.equal(b.native.preparationInfo().ready, true);
  a.joinReplies[0]();
  for (let turn = 0; turn < 20; turn++) await Promise.resolve();
  assert.deepEqual(ready, []); assert.equal(controller.getWritable(), false);
  assert.equal(b.native.state, 'idle'); assert.equal(a.native.state, 'active');
  // Detach cancels the public wait; the old native owner still follows its
  // explicit leave contract rather than claiming an unconfirmed transport close.
  await new Promise(resolve => a.native.leaveRoom(resolve));
  return a;
});
test('actual pinned Room handlers preserve page command, rejection, query and addApp async JSON', async () => {
  const e = environment(); await e.join();
  assert.deepEqual(plain(await e.controller.dispatchDocsEvent({ event: 'jumpToPage', options: { target: 'slide-fixture', page: 12 } })), { accepted: false, reason: 'stateUnavailable', message: 'render pending' });
  assert.deepEqual(plain(await e.controller.getPageState({ target: 'slide-fixture' })), { target: 'Slide', appId: 'slide-fixture', page: 2, pageCount: 12, scale: 1 });
  const param = { kind: 'Slide', options: { title: 'fixture' }, attributes: { taskId: 'fixture', url: 'https://example.invalid/slide' }, originSize: { width: 1280, height: 720 } };
  assert.equal(await e.controller.addApp(param), 'slide-fixture');
  assert.deepEqual(e.received.find(x => x.method === 'dispatchDocsEvent').args, ['jumpToPage', { target: 'slide-fixture', page: 12 }]);
  assert.deepEqual(e.received.find(x => x.method === 'addApp').args[0].attributes.originSize, param.originSize);
  assert.ok(!Object.hasOwn(param.attributes, 'originSize'));
  await assert.rejects(e.controller.getPageState({ target: 'error' }), /page lookup failed.*jsStack/s);
  await e.controller.disconnect(); return e;
});
test('real event envelopes decode string/object payload and ignore old generation/document', async () => {
  const e = environment(); await e.join();
  const value = { appId: 'slide-fixture', page: 2, pageCount: 12 };
  const emit = e.scoped.scopedCall(plain(e.native.scope));
  emit('sdk.slidePageStateChanged', value); emit('sdk.slidePageStateChanged', JSON.stringify(value));
  emit('sdk.unifiedPageStateChange', { target: 'Slide', ...value, status: 'success', changeType: 'page' });
  e.scoped.scopedCall({ documentId: 'old', generation: 1 })('sdk.slidePageStateChanged', value);
  e.scoped.scopedCall({ ...plain(e.native.scope), generation: 99 })('sdk.slidePageStateChanged', value);
  assert.equal(e.callbacks.length, 3); assert.deepEqual(e.callbacks[0], ['slide', 'slide-fixture', 2, 12]);
  assert.equal(e.callbacks[2][1].status, 'success'); await e.controller.disconnect(); return e;
});
test('real Bridge retry and link callbacks reach public Harmony callbacks and optional listener', async () => {
  const e = environment(); await e.join();
  const direct = [], listener = [];
  e.nativeCallbacks.setOnSlideResourceMaxRetries((...args) => direct.push(['retry', ...args]))
    .setSlideOpenUrl(url => direct.push(['link', url]))
    .setSlideListener({
      onSlideResourceMaxRetries(...args) { listener.push(['retry', ...args]); },
      slideOpenUrl(url) { listener.push(['link', url]); },
    });
  const url = 'https://example.invalid/slide-1.json?q="quoted"&newline=\n中文';
  const error = new Error('resource timeout'); error.stack = 'synthetic JS stack\nnext line';
  e.sdkEvents.onSlideResourceMaxRetries(url, error);
  e.sdkEvents.slideOpenUrl(url);
  assert.deepEqual(direct, [['retry', url, 'resource timeout', error.stack], ['link', url]]);
  assert.deepEqual(listener, direct);
  const raw = e.wire.find(x => x.method === 'sdk.slideResourceMaxRetries').args.data;
  assert.deepEqual(raw.value, { url, message: error.message, jsStack: error.stack });
  for (const value of [{ url }, JSON.stringify({ url }), {}, '[]', 'null', '1', '{bad']) {
    e.scoped.call('sdk.slideResourceMaxRetries', value);
  }
  assert.deepEqual(direct.slice(2), [['retry', url, '', ''], ['retry', url, '', ''], ['retry', '', '', '']]);
  const before = direct.length;
  for (const scope of [{ documentId: 'stale', generation: 1 }, { ...plain(e.native.scope), generation: 99 }]) {
    e.scoped.scopedCall(scope)('sdk.slideResourceMaxRetries', { url, message: 'stale' });
    e.scoped.scopedCall(scope)('sdk.slideOpenUrl', url);
  }
  assert.equal(direct.length, before);
  e.nativeCallbacks.setSlideListener(undefined);
  e.sdkEvents.onSlideResourceMaxRetries(url, error);
  assert.deepEqual(direct.at(-1), ['retry', url, 'resource timeout', error.stack]);
  assert.equal(listener.length, before, 'removing listener leaves direct callback active');
  await e.controller.disconnect(); return e;
});
test('Slide errors preserve enum, message, ID and zero/unknown indices through real message JSON', async () => {
  const e = environment(); await e.join();
  const direct = [], listener = [], messages = [];
  e.nativeCallbacks.setOnSlideError((...args) => direct.push(args))
    .setSlideListener({ onSlideError(...args) { listener.push(args); throw new Error('host listener failure'); } });
  e.nativeCallbacks.onMessage = value => { messages.push(plain(value)); throw new Error('host message failure'); };
  for (const type of ['RESOURCE_ERROR', 'RUNTIME_ERROR', 'RUNTIME_WARN', 'CANVAS_CRASH', 'NEW_ERROR']) {
    const value = { type: '@slide/_error_', errorType: type, errorMsg: 'render failed', slideId: 'slide-id', slideIndex: 0 };
    e.scoped.call('sdk.postMessage', value);
    e.scoped.call('sdk.postMessage', JSON.stringify({ ...value, slideIndex: -1 }));
  }
  assert.equal(direct.length, 10); assert.equal(messages.length, 10); assert.deepEqual(listener, direct);
  assert.deepEqual(direct[0], ['RESOURCE_ERROR', 'render failed', 'slide-id', 0]);
  assert.deepEqual(direct[9], ['UNKNOWN', 'render failed', 'slide-id', -1]);
  e.scoped.call('sdk.postMessage', { type: 'unrelated' });
  e.scoped.scopedCall({ documentId: 'stale', generation: 1 })('sdk.postMessage', { type: '@slide/_error_' });
  assert.equal(direct.length, 10);
  e.nativeCallbacks.setSlideListener(undefined);
  e.scoped.call('sdk.postMessage', { type: '@slide/_error_' });
  assert.deepEqual(direct.at(-1), ['UNKNOWN', '', '', -1]);
  await e.controller.disconnect(); return e;
});
test('Slide URL interception round-trips asynchronously, once, with fallback and callback cleanup', async () => {
  const e = environment(); await e.join();
  const url = 'https://example.invalid/slide.json';
  assert.equal(await e.sdkEvents.slideUrlInterrupter(url), url, 'no listener returns original URL');
  let complete;
  e.nativeCallbacks.setSlideListener({ slideUrlInterrupter(_url, reply) { complete = reply; } });
  const pending = e.sdkEvents.slideUrlInterrupter(url);
  assert.equal(typeof complete, 'function');
  const replacement = 'https://example.invalid/cache?q="quote"\n中文';
  complete(replacement); complete('duplicate');
  assert.equal(await pending, replacement);
  assert.equal(Object.keys(e.context.window).filter(key => key.startsWith('asyncCall_')).length, 0);
  e.nativeCallbacks.setSlideUrlInterrupter((_url, reply) => reply('direct-wins'));
  assert.equal(await e.sdkEvents.slideUrlInterrupter(url), 'direct-wins');
  e.nativeCallbacks.setSlideUrlInterrupter(() => { throw new Error('host callback failure'); });
  assert.equal(await e.sdkEvents.slideUrlInterrupter(url), url);
  // A completion from an old Room/document must never execute JS in the new one.
  e.nativeCallbacks.setSlideUrlInterrupter((_url, reply) => { complete = reply; });
  const oldScope = plain(e.native.scope);
  e.life.inScope(oldScope, () => e.sdkEvents.slideUrlInterrupter(url));
  const before = e.wire.length;
  e.native.scope.generation++;
  complete('stale');
  assert.equal(e.wire.length, before);
  e.native.scope.generation = oldScope.generation;
  e.sdkEvents.slideUrlInterrupter(url);
  e.native.invalidate();
  const invalidated = e.wire.length;
  complete('invalidated');
  assert.equal(e.wire.length, invalidated);
  return e;
});
test('Slide options preserve explicit false/zero, nested fields and omission across Native JSON', async () => {
  const e = environment();
  const slideAppOptions = { resourceMaxRetries: 0, showRenderError: false, debug: false, forceCanvas: false,
    bgColor: '#ffffff', invisibleBehavior: 'pause', enableGlobalClick: false, enableSharedMediaVolume: false };
  await e.join({ enableSlideInterrupterAPI: true, slideAppOptions });
  const sdk = e.received.find(x => x.method === 'newWhiteSdk').args[0];
  assert.equal(sdk.enableSlideInterrupterAPI, true);
  assert.deepEqual(sdk.slideAppOptions, slideAppOptions);
  await e.controller.disconnect();
  const other = environment(); await other.join({ enableSlideInterrupterAPI: false });
  const disabled = other.received.find(x => x.method === 'newWhiteSdk').args[0];
  assert.equal(disabled.enableSlideInterrupterAPI, false);
  assert.deepEqual(disabled.slideAppOptions, { showRenderError: false });
  await other.controller.disconnect();
  const enabled = environment(); await enabled.join({ slideAppOptions: { enableSharedMediaVolume: true } });
  assert.deepEqual(enabled.received.find(x => x.method === 'newWhiteSdk').args[0].slideAppOptions, { enableSharedMediaVolume: true, showRenderError: false });
  await enabled.controller.disconnect(); return e;
});
test('Slide showRenderError defaults false in actual JSON and preserves explicit true without mutating input', async () => {
  let e;
  for (const input of [undefined, {}, { showRenderError: undefined, resourceMaxRetries: 0 }, { showRenderError: false }, { showRenderError: true }]) {
    e = environment();
    const original = JSON.stringify(input);
    const buildersSource = fs.readFileSync(path.join(__dirname, '../library/src/main/ets/WhiteboardJoinOptions.ets'), 'utf8');
    const mod = { exports: {} }; vm.runInNewContext(compile(buildersSource), { module: mod, exports: mod.exports });
    const options = mod.exports.buildSdkOptions({ appIdentifier: 'synthetic-app', slideAppOptions: input });
    e.controller.configureSdk(options, () => {}); await e.controller.prepareCompletion();
    const actual = e.received.find(x => x.method === 'newWhiteSdk').args[0].slideAppOptions;
    assert.equal(actual.showRenderError, input?.showRenderError ?? false);
    if (input?.resourceMaxRetries === 0) assert.equal(actual.resourceMaxRetries, 0);
    assert.equal(JSON.stringify(input), original);
    assert.ok(!Object.hasOwn(actual, 'forceCanvas'), 'unrelated omitted settings remain absent');
  }
  return e;
});
test('real pinned PPT mediaCall reaches optional no-argument host callbacks with exact scoped JSON', async () => {
  const e = environment(); await e.join();
  const seen = [];
  e.nativeCallbacks.setOnPPTMediaPlay((...args) => seen.push(['play', args]))
    .setOnPPTMediaPause((...args) => seen.push(['pause', args]));
  const events = e.life.inScope(plain(e.native.scope), () => new e.sdkEvents.constructor(true));
  events.onPPTMediaPlay('shape-a', 'audio'); events.onPPTMediaPause('shape-a', 'audio');
  events.onPPTMediaPlay('shape-b', 'video'); events.onPPTMediaPause('shape-b', 'video');
  assert.deepEqual(seen, [['play', []], ['pause', []], ['play', []], ['pause', []]]);
  const wire = e.wire.filter(x => ['sdk.onPPTMediaPlay', 'sdk.onPPTMediaPause'].includes(x.method));
  assert.equal(wire.length, 4);
  assert.deepEqual(wire[0].args.data, { scope: plain(e.native.scope), value: { shapeId: 'shape-a', type: 'audio' } });
  assert.deepEqual(wire[3].args.data, { scope: plain(e.native.scope), value: { shapeId: 'shape-b', type: 'video' } });
  const count = seen.length;
  for (const scope of [{ documentId: 'old', generation: 1 }, { ...plain(e.native.scope), generation: 99 }]) {
    for (const method of ['sdk.onPPTMediaPlay', 'sdk.onPPTMediaPause']) e.scoped.scopedCall(scope)(method, { shapeId: 'stale', type: 'audio' });
  }
  assert.equal(seen.length, count);
  await e.controller.disconnect(); return e;
});
test('PPT media host exceptions, missing listeners and invalidated events remain isolated', async () => {
  const e = environment(); await e.join(); let play = 0, pause = 0;
  const events = e.life.inScope(plain(e.native.scope), () => new e.sdkEvents.constructor(true));
  assert.doesNotThrow(() => events.onPPTMediaPlay('shape', 'audio'));
  e.nativeCallbacks.setOnPPTMediaPlay(() => { play++; throw new Error('synthetic host play failure'); })
    .setOnPPTMediaPause(() => { pause++; throw new Error('synthetic host pause failure'); });
  assert.doesNotThrow(() => events.onPPTMediaPlay('shape', 'video'));
  assert.doesNotThrow(() => events.onPPTMediaPause('shape', 'video'));
  assert.deepEqual([play, pause], [1, 1]);
  e.nativeCallbacks.setOnPPTMediaPlay().setOnPPTMediaPause();
  events.onPPTMediaPlay('shape', 'audio'); events.onPPTMediaPause('shape', 'audio');
  assert.deepEqual([play, pause], [1, 1]);
  e.nativeCallbacks.setOnPPTMediaPlay(() => play++).setOnPPTMediaPause(() => pause++);
  e.native.invalidate(); events.onPPTMediaPlay('shape', 'audio'); events.onPPTMediaPause('shape', 'audio');
  assert.deepEqual([play, pause], [1, 1]); return e;
});
for (const api of ['disconnect', 'leaveRoom', 'room.disconnect', 'Bridge room.disconnect']) {
  test(`${api} completes real cleanup once and remains idempotent`, async () => {
    const e = environment(); await e.join();
    if (api === 'leaveRoom') e.controller.detachWhiteboard(e.native);
    const close = () => api === 'room.disconnect'
      ? new Promise(resolve => e.native.callHandler('room.disconnect', [], resolve))
      : api === 'Bridge room.disconnect'
        ? new Promise(resolve => e.native.send('room.disconnect', [], resolve))
        : e.controller[api]();
    const first = await close();
    assert.deepEqual(plain(typeof first === 'string' ? JSON.parse(first) : first), { closed: true });
    const second = await close();
    assert.deepEqual(plain(typeof second === 'string' ? JSON.parse(second) : second), { closed: true });
    assert.equal(e.closeCount, 1);
    // Direct low-level send deliberately bypasses the Native owner interceptor.
    if (api !== 'Bridge room.disconnect') assert.equal(e.native.state, 'idle');
    assert.equal(e.life.lifecycle.state, 'idle'); return e;
  });
}
for (const api of ['disconnect', 'leaveRoom']) {
  test(`${api} rejects real cleanup error and keeps failure cached`, async () => {
    const e = environment({ closeError: 'synthetic close failed' }); await e.join();
    await assert.rejects(e.controller[api](), /synthetic close failed/);
    await assert.rejects(e.controller[api](), /synthetic close failed/);
    assert.equal(e.closeCount, 1); assert.equal(e.native.state, 'blocked'); assert.equal(e.life.lifecycle.state, 'blocked'); return e;
  });
}
let completed = false;
process.on('beforeExit', () => {
  if (!completed && !process.exitCode) {
    console.error('FAIL transport contract test has an unresolved Promise'); process.exitCode = 1;
  }
});
(async () => {
  const evidence = { bridge: revision, kind: 'offline transport integration; not device E2E', tests: [] };
  const selected = process.env.WHITEBOARD_WIRE_TEST_FILTER ? tests.filter(test => new RegExp(process.env.WHITEBOARD_WIRE_TEST_FILTER).test(test.name)) : tests;
  for (const { name, run } of selected) {
    const e = await run(); console.log('PASS ' + name);
    evidence.tests.push({ name, status: 'PASS', closeCount: e.closeCount, wire: e.wire, received: e.received, callbacks: e.callbacks });
    if (process.env.WHITEBOARD_WIRE_EVIDENCE) fs.writeFileSync(process.env.WHITEBOARD_WIRE_EVIDENCE, JSON.stringify(evidence, null, 2) + '\n');
  }
  if (process.env.WHITEBOARD_WIRE_EVIDENCE) fs.writeFileSync(process.env.WHITEBOARD_WIRE_EVIDENCE, JSON.stringify(evidence, null, 2) + '\n');
  console.log(`${selected.length} selected transport contract tests passed`);
  completed = true;
})().catch(error => { console.error(error); process.exitCode = 1; });

(async () => {
 const module = {exports:{}};
 vm.runInNewContext(compile(fs.readFileSync(path.join(__dirname,'../library/src/main/ets/WhiteboardJoinOptions.ets'),'utf8')), {module,exports:module.exports,require:()=>({}),JSON});
 for(const enabled of [undefined,false,true]) {
  const options=module.exports.buildSdkOptions({appIdentifier:'synthetic-app',enableAppliancePlugin:true,enablePreLoadAppliancePlugin:enabled});
  const payload=plain(options);assert.equal(Object.hasOwn(payload,'enablePreLoadAppliancePlugin'),enabled!==undefined);
  assert.equal(payload.enablePreLoadAppliancePlugin,enabled);
  const e=environment();e.controller.configureSdk(options,()=>{});await e.controller.prepareCompletion();
  assert.equal(e.received.filter(x=>x.method==='newWhiteSdk').at(-1).args[0].enablePreLoadAppliancePlugin,enabled);
 }
 console.log('PASS actual Native/Bridge appliance preload flag JSON: omitted / false / true');
})().catch(error=>{console.error(error);process.exitCode=1;});
