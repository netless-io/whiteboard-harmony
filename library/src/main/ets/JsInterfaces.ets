import { Logger } from './Logger';
import { AkkoEvent, SlideErrorType, SlideListener, toRoomPhase } from './Types';
import { WhiteboardCallbacks } from './WhiteboardCallbacks';

interface PostMessageCallback {
  onMessage(jsonObject: object): void;
}

interface CompletionHandler<T> {
  complete(result: T): void;
}

interface JSRespError {
  message: string;
  jsStack?: string;
}

class JsResponse {
  __error?: JSRespError
}

export class SDKError extends Error {
  private jsStack: string;

  constructor(message: string, jsStack: string = "Native Error") {
    super(message);
    this.jsStack = jsStack;
    this.name = "SDKError";
  }

  static parseError(object: JSRespError): SDKError {
    try {
      const msg = object.message;
      const jsStack = object.jsStack;
      return new SDKError(msg, jsStack);
    } catch (e) {
      return new SDKError("parseError" + e.message, e.jsStack);
    }
  }

  static promiseError(str: string): SDKError | null {
    try {
      const jsonObject: JsResponse = JSON.parse(str);
      return SDKError.promiseErrorFromJson(jsonObject);
    } catch (e) {
      return null;
    }
  }

  static promiseErrorFromJson(jsonObject: JsResponse): SDKError | null {
    if (jsonObject.__error) {
      const msg = jsonObject.__error.message || "Unknown exception";
      const jsStack = jsonObject.__error.jsStack || "Unknown stack";
      return new SDKError(msg, jsStack);
    }
    return null;
  }

  toString(): string {
    return `${super.toString()} jsStack: ${this.jsStack}`;
  }
}

export class SdkJsInterface {
  private whiteboardCallbacks?: WhiteboardCallbacks;
  private slideListener?: SlideListener;
  private postMessageCallback?: PostMessageCallback;

  constructor(callbacks?: WhiteboardCallbacks) {
    this.whiteboardCallbacks = callbacks;
  }

  setPostMessageCallback = (postMessageCallback: PostMessageCallback): void => {
    this.postMessageCallback = postMessageCallback;
  };
  setSlideListener = (slideListener: SlideListener): void => {
    this.slideListener = slideListener;
  };
  slideUrlInterrupter = (args: object, handler: CompletionHandler<string>): void => {
    const url = String(args);
    if (this.slideListener) {
      this.slideListener.slideUrlInterrupter(url, handler.complete);
    } else {
      handler.complete(url);
    }
  };
  throwError = (args: object): void => {
    Logger.info(`WhiteSDK throwError: ${args}`);
    this.whiteboardCallbacks?.throwError?.(args);
  };
  logger = (args: object): void => {
    Logger.info(`WhiteSDK logger: ${args}`);
    const jsonObject = this.convertToJsonOrNull(args);
    if (jsonObject) {
      this.whiteboardCallbacks?.onLogger?.(jsonObject);
    }
  };
  postMessage = (args: object): void => {
    Logger.info(`WhiteSDK postMessage: ${args}`);
    const jsonObject = this.convertToJsonOrNull(args);
    if (jsonObject) {
      this.whiteboardCallbacks?.onMessage?.(jsonObject);
      this.postMessageCallback?.onMessage(jsonObject);
      this.slideListener && this.handleSlideEvent(jsonObject as Record<string, Object>);
    }
  };
  private handleSlideEvent = (jsonObject: Record<string, Object>): void => {
    const type = jsonObject.type;
    if (type === "@slide/_error_") {
      const errorType = jsonObject.errorType as string;
      const errorMsg = jsonObject.errorMsg as string;
      const slideId = jsonObject.slideId as string;
      const slideIndex = jsonObject.slideIndex as number;
      this.slideListener?.onSlideError(
        this.convertToSlideErrorType(errorType),
        errorMsg,
        slideId,
        slideIndex
      );
    }
  };
  private convertToSlideErrorType = (errorType: string): SlideErrorType => {
    switch (errorType) {
      case "RESOURCE_ERROR":
        return SlideErrorType.RESOURCE_ERROR;
      case "RUNTIME_ERROR":
        return SlideErrorType.RUNTIME_ERROR;
      case "RUNTIME_WARN":
        return SlideErrorType.RUNTIME_WARN;
      case "CANVAS_CRASH":
        return SlideErrorType.CANVAS_CRASH;
      default:
        return SlideErrorType.UNKNOWN;
    }
  };
  onPPTMediaPlay = (args: object): void => {
    Logger.info("onPPTMediaPlay called");
  };
  onPPTMediaPause = (args: object): void => {
    Logger.info("onPPTMediaPause called");
  };
  setupFail = (args: object): void => {
    console.log(`setupFail called ${args}}`);
    const jsonObject = this.convertToJsonOrNull(args);
    if (jsonObject) {
      const sdkError = SDKError.parseError(jsonObject as JSRespError);
      this.whiteboardCallbacks?.onLogger?.(sdkError);
    }
  };
  private convertToJsonOrNull = (args: object): object | null => {
    try {
      return JSON.parse(String(args));
    } catch (e) {
      Logger.error("convertToJson exception", e);
      return null;
    }
  };
}

export class RoomJsInterface {
  private callbacks?: WhiteboardCallbacks;

  constructor(callbacks: WhiteboardCallbacks) {
    this.callbacks = callbacks;
  }

  setCallbacks = (callbacks: WhiteboardCallbacks): void => {
    this.callbacks = callbacks;
  };
  fireCanUndoStepsUpdate = (args: object): void => {
    Logger.info(`fireCanUndoStepsUpdate ${args}`);
  };
  fireCanRedoStepsUpdate = (args: object): void => {
    Logger.info(`fireCanRedoStepsUpdate ${args}`);
  };
  fireMagixEvent = (args: string): void => {
    Logger.info(`fireMagixEvent ${args}`);
    const event: AkkoEvent = JSON.parse(args);
  };
  fireHighFrequencyEvent = (args: string): void => {
    Logger.info(`fireHighFrequencyEvent ${args}`);
    const events: AkkoEvent[] = JSON.parse(String(args));
  };
  firePhaseChanged = (args: string): void => {
    Logger.info("Phase changed " + args);
    const phase = toRoomPhase(args)
    if (phase) {
      this.callbacks?.onRoomPhaseChanged?.(phase);
    } else {
      Logger.error("Invalid phase value:" + args);
    }
  };
  fireKickedWithReason = (args: string): void => {
    Logger.info("fireKickedWithReason " + args);
  };
  fireDisconnectWithError = (args: string): void => {
    Logger.info("fireDisconnectWithError " + args);
  };
  fireRoomStateChanged = (state: string): void => {
    Logger.info("room state changed from " + state);
    this.callbacks?.onRoomStateChanged?.(JSON.parse(state));
  };
  fireCatchErrorWhenAppendFrame = (args: string): void => {
    Logger.info("room fireCatchErrorWhenAppendFrame " + args);
  };
}
