import { Logger } from './Logger';

export class DsBridge {
  private static readonly LOG_TAG = "DsBridge";
  private namespaceInterfaces: Map<string, object> = new Map<string, object>();
  private webView: WebviewController;
  private dsInitBridge: DsInitBridge;

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
      if (args.data) {
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

  callHandler(method: string, args: Object[] | null, handler?: Callback<object>): void {
    this.dsInitBridge.callHandler(method, args, handler);
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
  public dsinit = (): void => {
    this.dispatchStartupQueue();
  };
  private dispatchJavascriptCall = (call: Call): void => {
    console.log("dispatchJavascriptCall", JSON.stringify(call));
    this.webController.runJavaScript(`window._handleMessageFromNative(${JSON.stringify(call)})`);
  };
  public returnValue = (obj: CallResponse): void => {
    const id = obj.id;
    const complete = obj.complete;
    const data = obj.data;

    try {
      const handler = this.handlerMap.get(id);
      if (handler) {
        handler(data);
        if (complete) {
          this.handlerMap.delete(id);
        }
      }
    } catch (e) {
      Logger.error("js callback handle error", e);
    }
  };
  public callHandler = (method: string, args: object[] | null, handler?: Callback<object>): void => {
    const call = new Call(method, ++this.callID, args ?? []);

    if (handler) {
      this.handlerMap.set(call.callbackId, handler);
    }

    this.callList ? this.callList.push(call) : this.dispatchJavascriptCall(call);
  };
}