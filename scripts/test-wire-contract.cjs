// Offline transport integration: actual ArkTS JSON transport + pinned Bridge handlers.
// No WebView/device/network runtime is claimed. All credentials below are synthetic.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const bridgeRoot = process.env.WHITEBOARD_BRIDGE_ROOT || path.resolve(__dirname, '../../Whiteboard-bridge');
const revision = process.env.WHITEBOARD_BRIDGE_REVISION || '30bf490';
const ts = require(require.resolve('typescript', { paths: [bridgeRoot] }));
const pinned = name => execFileSync('git', ['show', `${revision}:src/bridge/${name}.ts`], { cwd: bridgeRoot, encoding: 'utf8' });
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
function environment({ closeError } = {}) {
  const wire = [], received = [], callbacks = [], timers = new Set();
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
    if (name === '@netless/webview-bridge') return load('transport', fs.readFileSync(path.join(bridgeRoot, 'node_modules/@netless/webview-bridge/src/bridge.ts'), 'utf8'));
    if (name.startsWith('./')) return load(name, fs.readFileSync(path.join(__dirname, '../library/src/main/ets', name.slice(2) + '.ets'), 'utf8'));
    throw new Error(`unexpected import ${name}`);
  }
  const { DsBridge } = requireModule('./DsBridge');
  const native = new DsBridge({ runJavaScript(code) {
    const call = JSON.parse(code.slice('window._handleMessageFromNative('.length, -1));
    wire.push({ direction: 'Native->Bridge', call });
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
  const sdk = {
    getLifecycle: handler(sources.SDK, 'getLifecycle'),
    newWhiteSdk(options, cb) { received.push({ method: 'newWhiteSdk', args: plain([options]) }); cb('{}'); },
    joinRoom(options, cb) {
      received.push({ method: 'joinRoom', args: plain([options]) });
      const task = life.lifecycle.begin('room', life.currentScope(), cb);
      task.object = { phase: 'connected', disconnect: async () => { closeCount++; if (closeError) throw new Error(closeError); } };
      task.settle(); life.lifecycle.activate(task, '{}');
      life.inScope(task.scope, () => scoped.registerAsyn('room', Object.fromEntries(['disconnect', 'dispatchDocsEvent', 'getPageState', 'addApp'].map(name => [name, handler(sources.Room, name)]))));
    },
    leaveRoom: handler(sources.SDK, 'leaveRoom'),
  };
  scoped.registerAsyn('sdk', sdk);
  const { SdkJsInterface } = requireModule('./JsInterfaces');
  native.addJavascriptObject(new SdkJsInterface({
    onSlidePageStateChanged(...args) { callbacks.push(['slide', ...args]); },
    onUnifiedPageStateChange(value) { callbacks.push(['unified', plain(value)]); },
  }), 'sdk');
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
  return { native, controller, join, wire, received, callbacks, scoped, life, context, get closeCount() { return closeCount; } };
}
const tests = [];
const test = (name, run) => tests.push({ name, run });
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
  assert.deepEqual(sdk.slideAppOptions, { enableScale: false, navigationButtonMode: 'step', syncEventQueuePolicy: 'latest-pending-render' });
  assert.equal(sdk.dynamicConfig['cn-hz'], 'https://example.invalid/latest.json');
  assert.ok(!Object.hasOwn(sdk, 'backgroundImageLoadOptions'));
  assert.equal(room.isWritable, false); assert.equal(room.disableDeviceInputs, false);
  assert.deepEqual(room.windowParams, { fullscreen: false, forceMaximized: true, originSize: { width: 1280, height: 720 } });
  assert.equal(room.appliancePluginOptions.cursor.enable, false);
  assert.match(room.__nativeTags.time, /^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/); assert.match(room.__nativeTags.traceId, /^[\da-f-]{36}$/);
  assert.ok(!Object.hasOwn(room, '__whiteScope'));
  assert.ok(e.wire.some(x => x.call?.method === 'sdk.joinRoom' && JSON.parse(x.call.data)[0].__whiteScope.generation === 1));
  await e.controller.disconnect(); return e;
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
})().catch(error => { console.error(error); process.exitCode = 1; });
