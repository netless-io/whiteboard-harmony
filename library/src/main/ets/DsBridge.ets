import { Logger } from './Logger';
import { RoomOptions, SdkOptions } from './WhiteboardOptions';
import { util } from '@kit.ArkTS';

interface NativeJoinRoomOptions extends RoomOptions {
  __nativeTags?: Record<string, string>;
}

export class LifecycleScope {
  documentId: string = '';
  generation: number = 0;
}
class LifecycleMarker { __whiteScope: LifecycleScope = new LifecycleScope(); }
class LifecycleEnvelope { scope: LifecycleScope = new LifecycleScope(); value?: ESObject; }
class LifecycleState { state: string = ''; }
class LifecycleDocument { documentId: string = ''; }
class LifecycleErrorInfo { message: string = ''; }
class LifecycleErrorResult { __error: LifecycleErrorInfo = new LifecycleErrorInfo(); }
class Replacement {
  host: DsBridge;
  key: string;
  ready: Callback<object>;
  waiting: boolean = true;
  constructor(host: DsBridge, key: string, ready: Callback<object>) { this.host = host; this.key = key; this.ready = ready; }
}


export class DsBridge {
  private static readonly LOG_TAG = "DsBridge";
  private namespaceInterfaces: Map<string, object> = new Map<string, object>();
  private webView: WebviewController;
  private dsInitBridge: DsInitBridge;
  private scope: LifecycleScope = new LifecycleScope();
  private state: string = 'idle';
  private initialized: boolean = false;
  private invalid: boolean = false;
  private pending?: Callback<object>;
  private ready: (() => void)[] = [];
  private closeCallbacks?: Callback<object>[];
  private closeResult?: object;
  private static owners: Map<string, DsBridge> = new Map<string, DsBridge>();
  private static replacements: Map<string, Replacement> = new Map<string, Replacement>();
  private replacement?: Replacement;
  private identity?: string;
  private sdkOptions?: object;


  constructor(webView: WebviewController) {
    this.webView = webView;
    this.dsInitBridge = new DsInitBridge(this.webView, this)
    this.addJavascriptObject(this.dsInitBridge, "_dsb")
  }

  private printDebugInfo(error: string): void {
    Logger.error(`${DsBridge.LOG_TAG} DEBUG ERR MSG:\n${error.replace(/'/g, "\\'")}`);
  }

  // JSSdk call native entry
  public call(methodName: string, argStr: string): string {
    class Args {
      _dscbstub?: string | null
      data?: string | null
    }

    class Result {
      code: number = 0;
      data?: object
    }

    let error = "Js bridge called, but can't find a corresponding JavascriptInterface object, please check your code!";
    const nameStr = DsBridge.parseNamespace(methodName.trim());
    methodName = nameStr[1];
    const jsb: object | undefined = this.namespaceInterfaces.get(nameStr[0]);
    const ret: Result = { code: -1 };
    if (!jsb) {
      this.printDebugInfo(error + argStr);
      return JSON.stringify(ret);
    }

    let arg: string | null = null;
    let method: Function | undefined;

    try {
      const args: Args = JSON.parse(argStr)
      if (args._dscbstub) {
        // TODO: not support async
        Logger.error("_dscbstub is not supported ")
      }
      if (args.data && nameStr[0] !== '_dsb') {
        const envelope = args.data as ESObject as LifecycleEnvelope;
        if (!this.matches(envelope.scope) || this.invalid) return JSON.stringify(ret);
        if (nameStr[0] === 'sdk' && nameStr[1] === 'lifecycleState') {
          const next: string = (envelope.value as LifecycleState).state;
          if (next === 'blocked' || (next === 'idle' && this.closeResult !== undefined && !this.isError(this.closeResult))) this.state = next;
          return JSON.stringify(ret);
        }
        arg = envelope.value;
      } else if (args.data) {
        arg = args.data;
      }
    } catch (e) {
      error = `The argument of "${methodName}" must be a JSON object string!`;
      this.printDebugInfo(error);
      console.error(e);
      return JSON.stringify(ret);
    }

    const cls: object = jsb;

    try {
      method = cls[methodName] as Function;
    } catch (ex) {
      this.printDebugInfo(error);
      return JSON.stringify(ret);
    }

    if (!method) {
      error =
        `Not find method "${methodName}" implementation! Please check if the signature or namespace of the method is right.`;
      this.printDebugInfo(error);
      return JSON.stringify(ret);
    }

    try {
      ret.code = 0;
      ret.data = method(arg);
      return JSON.stringify(ret);
    } catch (e) {
      console.error(e);
      error = `Call failed: The parameter of "${methodName}" in Java is invalid.`;
      this.printDebugInfo(error);
      return JSON.stringify(ret);
    }
  }

  public addJavascriptObject(object: object, namespace: string | null) {
    namespace = namespace || "";
    if (object) {
      this.namespaceInterfaces.set(namespace, object);
    }
  }

  public removeJavascriptObject(namespace: string | null) {
    namespace = namespace || "";
    this.namespaceInterfaces.delete(namespace);
  }

  public static parseNamespace(method: string): [string, string] {
    const pos = method.lastIndexOf('.');
    let namespace = "";
    if (pos !== -1) {
      namespace = method.substring(0, pos);
      method = method.substring(pos + 1);
    }
    return [namespace, method];
  }

  public hasNativeMethod(args: object): boolean {
    interface Args {
      name: string;
      type: string;
    }

    const jsonObject = args as Args;
    const methodName = jsonObject.name.trim();
    const type = jsonObject.type.trim();
    const nameStr = DsBridge.parseNamespace(methodName);
    const jsb = this.namespaceInterfaces.get(nameStr[0]);

    if (jsb) {
      const cls = jsb.constructor;
      let asyn = false;
      let method: Function | undefined;

      try {
        method = cls.prototype[nameStr[1]];
        asyn = true;
      } catch {
        try {
          method = cls.prototype[nameStr[1]];
        } catch {
        }
      }
      if (method) {
        if (
          type === "all" ||
            (asyn && type === "asyn") ||
            (!asyn && type === "syn")
        ) {
          return true;
        }
      }
    }
    return false;
  }

  private matches(scope?: LifecycleScope): boolean {
    return scope !== undefined && scope.documentId === this.scope.documentId &&
      (scope.generation === 0 || scope.generation === this.scope.generation);
  }

  private error(message: string): object { const result: LifecycleErrorResult = new LifecycleErrorResult(); result.__error.message = message; return JSON.stringify(result) as ESObject; }

  /** Explicit initialization replaces the previous Room, including a detached component with the same identity. */
  initializeRoom(sdkOptions: object, roomOptions: object, ready: Callback<object>): boolean {
    const sdkSnapshot: SdkOptions = JSON.parse(JSON.stringify(sdkOptions)) as SdkOptions;
    const parameters: RoomOptions = JSON.parse(JSON.stringify(roomOptions)) as RoomOptions;
    if (!parameters.uuid || !parameters.roomToken || !parameters.uid) {ready(this.error('InvalidJoinParameters'));return false;}
    const key: string = JSON.stringify([sdkSnapshot.appIdentifier, parameters.uuid, parameters.uid]);
    Promise.resolve(true).then(() => {
      const request: Replacement = new Replacement(this, key, ready);
      const previous = DsBridge.replacements.get(key);
      const local = this.replacement;
      DsBridge.replacements.set(key, request); this.replacement = request;
      if (previous) previous.host.cancelReplacement(previous);
      if (local && local !== previous) this.cancelReplacement(local);
      this.closeRoom((value: object) => {
        if (!this.currentReplacement(request)) return;
        if (this.isError(value)) { this.finishReplacement(request, value); return; }
        const closed: Callback<object> = (result: object) => {
          if (!this.currentReplacement(request)) return;
          if (this.isError(result)) { this.finishReplacement(request, result); return; }
          request.waiting = false; DsBridge.replacements.delete(key); this.replacement = undefined;
          DsBridge.owners.set(key, this); this.identity = key;
          this.beginRoom(sdkSnapshot, parameters, ready);
        };
        // The target owner may have switched identity while this host was closing.
        const old: DsBridge | undefined = DsBridge.owners.get(key);
        if (old && old !== this) old.closeRoom(closed); else closed('{}' as ESObject);
      });
    });
    return true;
  }
  private isError(value: object): boolean { return typeof value === 'string' && (value as string).includes('"__error"'); }
  private currentReplacement(request: Replacement): boolean {
    return request.waiting && this.replacement === request && DsBridge.replacements.get(request.key) === request;
  }
  private cancelReplacement(request: Replacement): void {
    if (!request.waiting) return;
    request.waiting = false;
    if (DsBridge.replacements.get(request.key) === request) DsBridge.replacements.delete(request.key);
    if (this.replacement === request) this.replacement = undefined;
    request.ready(this.error('Cancelled'));
  }
  private finishReplacement(request: Replacement, error: object): void {
    if (!this.currentReplacement(request)) return;
    request.waiting = false; DsBridge.replacements.delete(request.key); this.replacement = undefined; request.ready(error);
  }
  private beginRoom(sdkOptions: object, roomOptions: object, ready: Callback<object>): void {
    if (this.invalid) { ready(this.error('HostInvalid')); return; }
    this.sdkOptions = sdkOptions;
    this.initialized = true;
    this.state = 'joining';
    this.scope.generation++;
    this.closeResult = undefined; this.closeCallbacks = undefined;
    this.pending = ready;
    const generation: number = this.scope.generation;
    setTimeout(() => {
      if (this.scope.generation !== generation || !this.pending || this.state !== 'joining') return;
      this.state = 'closing'; const pending = this.pending; this.pending = undefined;
      pending(this.error('JoinTimeout'));
      this.closeRoom(() => {});
    }, (roomOptions as RoomOptions).timeout ?? 45000);
    this.dsInitBridge.callHandler('sdk.getLifecycle', [], (result: object) => {
      if (this.invalid || generation !== this.scope.generation) return;
      const envelope = result as LifecycleEnvelope;
      const document = JSON.parse(envelope.value as string) as LifecycleDocument;
      this.scope.documentId = document.documentId;
      this.dsInitBridge.callHandler('sdk.newWhiteSdk', [sdkOptions], (setup: object) => {
      if (this.invalid || generation !== this.scope.generation) return;
      const setupValue = (setup as LifecycleEnvelope).value as object;
      if (this.pending && this.isError(setupValue)) { const pending = this.pending; this.pending = undefined; this.state = 'blocked'; pending?.(setupValue); return; }
      const queued: (() => void)[] = this.ready; this.ready = [];
      queued.forEach((work: () => void) => work());
      if (!this.pending || generation !== this.scope.generation) return;
      this.addNativeTags(roomOptions as NativeJoinRoomOptions);
      this.send('sdk.joinRoom', [roomOptions], (value: object) => {
        if (this.invalid || generation !== this.scope.generation || !this.pending) return;
        const pending = this.pending; this.pending = undefined;
        const error: boolean = typeof value === 'string' && (value as string).includes('"__error"');
        if (!error) this.state = 'active';
        else if (this.state !== 'idle' && this.state !== 'closing') this.state = 'blocked';
        pending(value);
      });
      });
    });
  }

  private addNativeTags(parameters: NativeJoinRoomOptions): void {
    // Match Android: T0 is dispatch time after SDK readiness, in device local time.
    const now: Date = new Date();
    const pad = (value: number): string => value.toString().padStart(2, '0');
    const nativeTags: Record<string, string> = parameters.__nativeTags ?? {};
    nativeTags['traceId'] = util.generateRandomUUID();
    nativeTags['time'] = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
    parameters.__nativeTags = nativeTags;
  }

  private send(method: string, args: ESObject[] | null, handler?: Callback<object>): void {
    if (this.scope.documentId.length === 0) { this.ready.push(() => this.send(method, args, handler)); return; }
    const marker: LifecycleMarker = new LifecycleMarker();
    marker.__whiteScope.documentId = this.scope.documentId;
    marker.__whiteScope.generation = this.scope.generation;
    const response: Callback<object> | undefined = handler ? (result: object) => {
      const envelope = result as LifecycleEnvelope;
      if (!this.matches(envelope.scope) || this.invalid) { handler?.(this.error('StaleScope')); return; }
      handler(envelope.value);
    } : undefined;
    this.dsInitBridge.callHandler(method, [marker, ...(args ?? [])], response);
  }

  leaveRoom(handler: Callback<object>): void {
    Promise.resolve(true).then(() => {
      if (this.replacement) this.cancelReplacement(this.replacement);
      this.closeRoom(handler);
    });
  }
  private closeRoom(handler: Callback<object>): void {
    if (this.invalid) { handler(this.error('HostInvalid')); return; }
    if (this.closeResult !== undefined) { handler(this.closeResult); return; }
    if (this.closeCallbacks) { this.closeCallbacks.push(handler); return; }
    if (this.state === 'idle') { handler('{}' as ESObject); return; }
    this.state = 'closing'; this.closeCallbacks = [handler];
    const pending = this.pending; this.pending = undefined; pending?.(this.error('Cancelled'));
    const generation: number = this.scope.generation;
    setTimeout(() => this.finishLeave(generation, this.error('LeaveTimeout')), 20000);
    this.send('sdk.leaveRoom', [], (value: object) => this.finishLeave(generation, value));
  }
  private finishLeave(generation: number, value: object): void {
    if (generation !== this.scope.generation || this.closeResult !== undefined) return;
    this.closeResult = value;
    this.state = typeof value === 'string' && (value as string).includes('"__error"') ? 'blocked' : 'idle';
    if (this.state === 'idle' && this.identity && DsBridge.owners.get(this.identity) === this) DsBridge.owners.delete(this.identity);
    const callbacks = this.closeCallbacks; this.closeCallbacks = undefined;
    callbacks?.forEach((callback: Callback<object>) => callback(value));
  }
  invalidate(): void {
    if (this.invalid) return;
    this.invalid = true; this.state = 'blocked'; this.ready = [];
    if (this.replacement) this.finishReplacement(this.replacement, this.error('HostInvalid'));
    const pending = this.pending; this.pending = undefined; pending?.(this.error('HostInvalid'));
    const callbacks = this.closeCallbacks; this.closeCallbacks = undefined;
    callbacks?.forEach((callback: Callback<object>) => callback(this.error('HostInvalid')));
    this.dsInitBridge.invalidate();
  }
  pageBegin(): boolean {
    if (this.scope.documentId.length === 0 || this.invalid) return false;
    if (this.state !== 'idle' || this.closeResult === undefined ||
      (typeof this.closeResult === 'string' && (this.closeResult as string).includes('"__error"'))) {
      this.invalidate(); return false;
    }
    // An explicit refresh after a completed leave starts a new document, never a recovery retry.
    this.scope.documentId = ''; this.scope.generation++; this.initialized = false;
    this.closeResult = undefined; this.closeCallbacks = undefined; this.ready = [];
    this.dsInitBridge.invalidate();
    return true;
  }

  callHandler(method: string, args: ESObject[] | null, handler?: Callback<object>): void {
    if (method === 'sdk.joinRoom' && this.sdkOptions && args?.[0]) {
      this.initializeRoom(this.sdkOptions, args[0] as object, handler ?? (() => {})); return;
    }
    if (method === 'sdk.replayRoom' || method === 'sdk.newWhiteSdk' || method === 'sdk.joinRoom') {
      handler?.(this.error(this.state === 'active' ? 'AlreadyJoined' : 'Busy')); return;
    }
    if (method === 'room.disconnect') { this.leaveRoom(handler ?? (() => {})); return; }
    if (this.invalid || (this.state !== 'active' && this.state !== 'joining')) { handler?.(this.error('StaleScope')); return; }
    this.send(method, args, handler);
  }

}

// 字段约定
class Call {
  callbackId: number;
  data: string;
  method: string;

  constructor(method: string, id: number, args: object[] = []) {
    this.data = JSON.stringify(args);
    this.callbackId = id;
    this.method = method;
  }
}

// 字段约定
interface CallResponse {
  id: number;
  complete: boolean;
  data: object;
}

export class DsInitBridge {
  dsBridge: DsBridge;
  webController: WebviewController;
  private callID: number = 0;
  private callList: Call[] | null = [];
  private handlerMap: Map<number, Callback<object>> = new Map();

  constructor(webController: WebviewController, dsBridge: DsBridge) {
    this.webController = webController;
    this.dsBridge = dsBridge;
  }

  hasNativeMethod = (obj: object): boolean => this.dsBridge.hasNativeMethod(obj);
  dispatchStartupQueue = (): void => {
    this.callList?.forEach(info => this.dispatchJavascriptCall(info));
    this.callList = null;
  };
  invalidate(): void { this.callList = []; this.handlerMap.clear(); }
  public dsinit = (): void => {
    this.dispatchStartupQueue();
  };
  private dispatchJavascriptCall = (call: Call): void => {
    this.webController.runJavaScript(`window._handleMessageFromNative(${JSON.stringify(call)})`);
  };
  public returnValue = (obj: CallResponse): void => {
    const id = obj.id;
    const complete = obj.complete;
    const data = obj.data;

    try {
      const handler = this.handlerMap.get(id);
      if (handler) {
        if (complete) this.handlerMap.delete(id);
        handler(data);
      }
    } catch (e) {
      Logger.error("js callback handle error", e);
    }
  };
  public callHandler = (method: string, args: ESObject[] | null, handler?: Callback<object>): void => {
    const call = new Call(method, ++this.callID, args ?? []);

    if (handler) {
      this.handlerMap.set(call.callbackId, handler);
    }

    this.callList ? this.callList.push(call) : this.dispatchJavascriptCall(call);
  };
}
