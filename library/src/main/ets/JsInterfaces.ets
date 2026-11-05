import { Logger } from './Logger';
import {
  EventEntry,
  RoomDisconnectError,
  RoomKickedReason,
  RoomState,
  SlideErrorType,
  SlideListener,
  UnifiedPageStateChange,
  toRoomPhase,
} from './Types';
import {
  ApplianceInitLoadingChangeEvent,
  BackgroundImageLoadEvent,
  WhiteboardCallbacks,
} from './WhiteboardCallbacks';
import { SDKError, SDKErrorPayload } from './SDKError';

export { SDKError } from './SDKError';

interface PostMessageCallback {
  onMessage(jsonObject: object): void;
}

interface CompletionHandler<T> {
  complete(result: T): void;
}

function parseJsonOrNull<T>(input: string): T | null {
  try {
    return JSON.parse(input) as T;
  } catch (error) {
    Logger.error("parse json failed", error);
    return null;
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
  private getSlideListener(): SlideListener | undefined {
    return this.slideListener ?? this.whiteboardCallbacks?.slideListener;
  }
  private notify(callback: () => void): void {
    try {
      callback();
    } catch (error) {
      Logger.error('WhiteSDK callback failed: ' + String(error));
    }
  }
  private slidePayload(args: string | object): Record<string, Object> | null {
    const value = typeof args === 'string' ? parseJsonOrNull<Record<string, Object>>(args) : args;
    return value !== null && typeof value === 'object' && !Array.isArray(value)
      ? value as Record<string, Object> : null;
  }
  slideUrlInterrupter = (args: object, handler: CompletionHandler<string>): void => {
    const url = String(args);
    let completed: boolean = false;
    const complete = (result: string): void => {
      if (completed) return;
      completed = true;
      handler.complete(typeof result === 'string' ? result : url);
    };
    const listener = this.getSlideListener();
    try {
      if (this.whiteboardCallbacks?.slideUrlInterrupter) {
        this.whiteboardCallbacks.slideUrlInterrupter(url, complete);
      } else if (listener?.slideUrlInterrupter) {
        listener.slideUrlInterrupter(url, complete);
      } else {
        complete(url);
      }
    } catch (error) {
      Logger.error('WhiteSDK slideUrlInterrupter failed: ' + String(error));
      complete(url);
    }
  };
  slideOpenUrl = (args: object): void => {
    if (typeof args !== 'string') return;
    this.notify(() => this.getSlideListener()?.slideOpenUrl?.(args));
    this.notify(() => this.whiteboardCallbacks?.slideOpenUrl?.(args));
  };
  slideResourceMaxRetries = (args: string | object): void => {
    const payload = this.slidePayload(args);
    if (!payload) return;
    const url: string = typeof payload.url === 'string' ? payload.url : '';
    const message: string = typeof payload.message === 'string' ? payload.message : '';
    const jsStack: string = typeof payload.jsStack === 'string' ? payload.jsStack : '';
    this.notify(() => this.getSlideListener()?.onSlideResourceMaxRetries?.(url, message, jsStack));
    this.notify(() => this.whiteboardCallbacks?.onSlideResourceMaxRetries?.(url, message, jsStack));
  };
  slidePageStateChanged = (args: string | object): void => {
    const jsonObject: Record<string, Object> | null = this.slidePayload(args);
    if (!jsonObject) {
      Logger.error('WhiteSDK slidePageStateChanged received invalid JSON');
      return;
    }

    const appId = jsonObject.appId;
    const page = jsonObject.page;
    const pageCount = jsonObject.pageCount;
    if (typeof appId !== 'string' || appId.length === 0
      || typeof page !== 'number' || !Number.isInteger(page) || page < 1
      || typeof pageCount !== 'number' || !Number.isInteger(pageCount) || pageCount < 1) {
      Logger.error('WhiteSDK slidePageStateChanged received invalid payload');
      return;
    }

    Logger.info(`WhiteSDK slidePageStateChanged received ${JSON.stringify({ appId, page, pageCount })}`);
    this.notify(() => this.getSlideListener()?.onSlidePageStateChanged?.(appId, page, pageCount));
    this.notify(() => this.whiteboardCallbacks?.onSlidePageStateChanged?.(appId, page, pageCount));
  };
  unifiedPageStateChange = (args: string | object): void => {
    const state = this.convertToJsonOrNull(args) as UnifiedPageStateChange | null;
    if (state) {
      this.whiteboardCallbacks?.onUnifiedPageStateChange?.(state);
    }
  };
  throwError = (args: object): void => {
    Logger.info(`WhiteSDK throwError: ${args}`);
    this.whiteboardCallbacks?.throwError?.(args);
  };
  logger = (args: object): void => {
    Logger.info(`WhiteSDK logger: ${args}`);
    this.whiteboardCallbacks?.onLogger?.(args);
  };
  localLogStateChange = (args: object): void => {
    Logger.info(`WhiteSDK localLogStateChange: ${args}`);
    this.whiteboardCallbacks?.onLocalLogStateChange?.(args);
  };
  postMessage = (args: object): void => {
    Logger.info(`WhiteSDK postMessage: ${args}`);
    try {
      if (!args) {
        return;
      }
      const message = typeof args === 'string'
        ? parseJsonOrNull<Record<string, Object>>(args)
        : args as Record<string, Object>;
      if (!message) {
        return;
      }
      if (message.name === 'backgroundImageLoad') {
        try {
          const event = typeof args === 'string'
            ? parseJsonOrNull<BackgroundImageLoadEvent>(args)
            : args as BackgroundImageLoadEvent;
          if (event) {
            this.whiteboardCallbacks?.onBackgroundImageLoad?.(event);
          }
        } catch (err) {
          Logger.error(`WhiteSDK onBackgroundImageLoad callback failed: ${String(err)}`);
        }
      }
      if (message.name === 'applianceInitLoadingChange') {
        try {
          const event = typeof args === 'string'
            ? parseJsonOrNull<ApplianceInitLoadingChangeEvent>(args)
            : args as ApplianceInitLoadingChangeEvent;
          if (event) {
            this.whiteboardCallbacks?.onApplianceInitLoadingChange?.(event);
          }
        } catch (err) {
          Logger.error('WhiteSDK onApplianceInitLoadingChange callback failed: ' + String(err));
        }
      }
      this.notify(() => this.whiteboardCallbacks?.onMessage?.(message));
      this.notify(() => this.postMessageCallback?.onMessage(message));
      this.handleSlideEvent(message);
    } catch (err) {
      Logger.error(`WhiteSDK postMessage handle err: Code is ${err.code}, message is ${err.message}`)
    }
  };
  private handleSlideEvent = (jsonObject: Record<string, Object>): void => {
    const type = jsonObject.type;
    if (type === "@slide/_error_") {
      const errorType = this.convertToSlideErrorType(String(jsonObject.errorType));
      const errorMsg: string = typeof jsonObject.errorMsg === 'string' ? jsonObject.errorMsg : '';
      const slideId: string = typeof jsonObject.slideId === 'string' ? jsonObject.slideId : '';
      const slideIndex: number = typeof jsonObject.slideIndex === 'number' && Number.isInteger(jsonObject.slideIndex)
        ? jsonObject.slideIndex : -1;
      this.notify(() => this.getSlideListener()?.onSlideError?.(errorType, errorMsg, slideId, slideIndex));
      this.notify(() => this.whiteboardCallbacks?.onSlideError?.(errorType, errorMsg, slideId, slideIndex));
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
    this.notify(() => this.whiteboardCallbacks?.onPPTMediaPlay?.());
  };
  onPPTMediaPause = (args: object): void => {
    Logger.info("onPPTMediaPause called");
    this.notify(() => this.whiteboardCallbacks?.onPPTMediaPause?.());
  };
  setupFail = (args: object | string): void => {
    const jsonObject = this.convertToJsonOrNull(args);
    if (jsonObject) {
      const sdkError = SDKError.parseError(jsonObject as SDKErrorPayload);
      this.whiteboardCallbacks?.sdkSetupFail?.(sdkError);
    }
  };
  private convertToJsonOrNull = (args: object | string): object | null => {
    if (typeof args === 'object') {
      return args;
    }
    try {
      return JSON.parse(args);
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
  fireCanUndoStepsUpdate = (steps: number): void => {
    Logger.info(`fireCanUndoStepsUpdate ${steps}`);
    this.callbacks?.onCanUndoStepsUpdate?.(steps)
  };
  fireCanRedoStepsUpdate = (steps: number): void => {
    Logger.info(`fireCanRedoStepsUpdate ${steps}`);
    this.callbacks?.onCanRedoStepsUpdate?.(steps)
  };
  fireMagixEvent = (args: string): void => {
    Logger.info(`fireMagixEvent ${args}`);
    const event: EventEntry | null = parseJsonOrNull<EventEntry>(args);
    if (event) {
      this.callbacks?.onMagixEvent?.(event);
    }
  };
  fireHighFrequencyEvent = (args: string): void => {
    Logger.info(`fireHighFrequencyEvent ${args}`);
    const events: EventEntry[] | null = parseJsonOrNull<EventEntry[]>(String(args));
    if (events) {
      this.callbacks?.onHighFrequencyEvent?.(events);
    }
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
    this.callbacks?.onKickedWithReason?.(args as RoomKickedReason);
  };
  fireDisconnectWithError = (args: string): void => {
    Logger.info("fireDisconnectWithError " + args);
    this.callbacks?.onDisconnectWithError?.({ message: args } as RoomDisconnectError);
  };
  fireRoomStateChanged = (state: string): void => {
    Logger.info("room state changed from " + state);
    const roomState: RoomState | null = parseJsonOrNull<RoomState>(state);
    if (roomState) {
      this.callbacks?.onRoomStateChanged?.(roomState);
    }
  };
  fireCatchErrorWhenAppendFrame = (args: string): void => {
    Logger.info("room fireCatchErrorWhenAppendFrame " + args);
  };
}
