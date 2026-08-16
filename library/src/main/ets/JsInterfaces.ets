import { Logger } from './Logger';
import {
  EventEntry,
  RoomDisconnectError,
  RoomKickedReason,
  RoomState,
  SlideErrorType,
  SlideListener,
  toRoomPhase,
} from './Types';
import { BackgroundImageLoadEvent, WhiteboardCallbacks } from './WhiteboardCallbacks';
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
      const message = args as Record<string, Object>;
      if (message.name === 'backgroundImageLoad') {
        try {
          this.whiteboardCallbacks?.onBackgroundImageLoad?.(args as BackgroundImageLoadEvent);
        } catch (err) {
          Logger.error(`WhiteSDK onBackgroundImageLoad callback failed: ${String(err)}`);
        }
      }
      this.whiteboardCallbacks?.onMessage?.(args);
      this.postMessageCallback?.onMessage(args);
      this.slideListener && this.handleSlideEvent(args as Record<string, Object>);
    } catch (err) {
      Logger.error(`WhiteSDK postMessage handle err: Code is ${err.code}, message is ${err.message}`)
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
    const jsonObject = this.convertToJsonOrNull(args);
    if (jsonObject) {
      const sdkError = SDKError.parseError(jsonObject as SDKErrorPayload);
      this.whiteboardCallbacks?.sdkSetupFail?.(sdkError);
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
