import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { BackgroundImageLoadOptions, RoomOptions, SdkOptions, WhiteboardOptions } from './WhiteboardOptions';
import { WhiteboardController } from './WhiteboardController';
import { DsBridge } from './DsBridge';
import { RoomJsInterface, SDKError, SdkJsInterface } from './JsInterfaces';
import { WhiteboardCallbacks } from './WhiteboardCallbacks';
import { Logger } from './Logger';
import { buildRoomOptions, buildSdkOptions } from './WhiteboardJoinOptions';

function validateBackgroundImageLoadOptions(options?: BackgroundImageLoadOptions): void {
  if (!options) {
    return;
  }
  if (options.maxRetries !== undefined &&
    options.maxRetries !== -1 &&
    (!Number.isInteger(options.maxRetries) || options.maxRetries < 0 || options.maxRetries > 10)) {
    throw new Error('maxRetries must be -1 or an integer from 0 to 10');
  }
  if (options.timeoutMs !== undefined && (options.timeoutMs < 1000 || options.timeoutMs > 120000)) {
    throw new Error('timeoutMs must be from 1000 to 120000');
  }
  if (options.retryIntervalMs !== undefined &&
    (options.retryIntervalMs < 0 || options.retryIntervalMs > 30000)) {
    throw new Error('retryIntervalMs must be from 0 to 30000');
  }
}

@Component
export struct Whiteboard {
  @Prop options: WhiteboardOptions
  @Prop controller: WhiteboardController
  @Prop callbacks: WhiteboardCallbacks
  @Prop webDebug: boolean = true
  private webController = new webview.WebviewController();
  private dsBridge = new DsBridge(this.webController)
  private pageInitialized: boolean = false

  aboutToAppear(): void {
    try {
      webview.WebviewController.setWebDebuggingAccess(this.webDebug);
    } catch (error) {
      console.error(`ErrorCode: ${(error as BusinessError).code},  Message: ${(error as BusinessError).message}`);
    }

    interface LoggerItem {
      level,
      message,
      error
    }

    Logger.setLogCallback((level, message, error) => {
      this.callbacks.onLogger?.({ level, message, error } as LoggerItem)
    })
  }

  aboutToDisappear(): void {
    this.controller.detachWhiteboard(this.dsBridge)
  }

  build() {
    Column() {
      Web({ src: $rawfile("whiteboard/index.html"), controller: this.webController })
        .mediaPlayGestureAccess(false)
        .textZoomRatio(100)
        .domStorageAccess(true)
        .fileAccess(false)
        .javaScriptAccess(true)
        .overviewModeAccess(true)
        .metaViewport(true)
        .width("100%")
        .height("100%")
        .onControllerAttached(() => {
          this.webController.registerJavaScriptProxy(this.dsBridge, "_dsbridge", ["call"])
        })
        .onOverrideUrlLoading((webResourceRequest: WebResourceRequest) => {
          if (webResourceRequest && webResourceRequest.getRequestUrl() == "about:blank") {
            return true;
          }
          return false;
        })
        .onPageBegin((event) => {
          if (this.dsBridge.pageBegin()) this.pageInitialized = false;
          if (event) {
            Logger.info('onPageBegin url:' + event.url);
          }
        })
        .onFirstContentfulPaint(event => {
          if (event) {
            Logger.info(`onFirstContentfulPaint [navigationStartTick]: ${event.navigationStartTick}, [firstContentfulPaintMs]: ${event.firstContentfulPaintMs}`)
          }
        })
        .onProgressChange((event) => {
          if (event) {
            Logger.info('newProgress:' + event.newProgress);
          }
        })
        .onPageEnd((event) => {
          if (event) {
            Logger.info('onPageEnd url:' + event.url);
          }
          if (this.pageInitialized) return;
          this.pageInitialized = true;
          const sdkJsInterface = new SdkJsInterface(this.callbacks)
          const roomJsInterface = new RoomJsInterface(this.callbacks)

          validateBackgroundImageLoadOptions(this.options.backgroundImageLoadOptions)

          this.dsBridge.addJavascriptObject(sdkJsInterface, "sdk")
          this.dsBridge.addJavascriptObject(roomJsInterface, "room")

          let sdkOptions: SdkOptions = buildSdkOptions(this.options)
          let roomOptions: RoomOptions = buildRoomOptions(this.options)
          if (!this.controller.attachWhiteboard(this.dsBridge)) return;
          this.dsBridge.initializeRoom(sdkOptions, roomOptions, (result: object) => {
            interface JoinRoomResult {
              state: object,
              observerId: number,
              isWritable: boolean,
            }

            if (typeof result === 'string') {
              const sdkError = SDKError.promiseError(result)
              if (sdkError) {
                Logger.error("join room error", sdkError)
              } else {
                const resultObj: JoinRoomResult = JSON.parse(result)
                Logger.info(`join room successfully ${resultObj.state}`)
                this.controller.setInitialWritable(resultObj.isWritable)
                this.callbacks.onRoomReady?.()
              }
            } else {
              Logger.error("join room failed ${result}")
            }
          });
        })
        .onPageVisible((event) => {
          Logger.info('onPageVisible url:' + event.url);
        })
        .onRenderExited((event) => {
          this.dsBridge.invalidate();
          if (event) {
            Logger.info('onRenderExited reason:' + event.renderExitReason);
          }
        })
        .onDisAppear(() => {
          Logger.info('onDisAppear')
        })
    }
  }
}
