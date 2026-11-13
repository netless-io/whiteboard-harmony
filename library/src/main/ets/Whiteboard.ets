import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { BackgroundImageLoadOptions, RoomOptions, SdkOptions, WhiteboardOptions, WhiteboardSdkOptions } from './WhiteboardOptions';
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
  @Prop options: WhiteboardSdkOptions | WhiteboardOptions
  // Controller is an identity-bearing handle. @Prop would clone its mutable fields.
  controller: WhiteboardController = new WhiteboardController()
  @Prop @Watch('onCallbacksChanged') callbacks: WhiteboardCallbacks
  @Prop autoJoin: boolean = true
  @Prop webDebug: boolean = true
  private webController = new webview.WebviewController();
  private dsBridge = new DsBridge(this.webController)
  private pageInitialized: boolean = false

  onCallbacksChanged(): void { this.dsBridge.setPreloadCallback(this.callbacks.onPreloadStateChange); }

  aboutToAppear(): void {
    this.dsBridge.setDocumentRecovery(() => this.webController.loadUrl($rawfile('whiteboard/index.html')));
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
    this.dsBridge.destroy()
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
          this.dsBridge.setPreloadCallback(this.callbacks.onPreloadStateChange)
          const roomJsInterface = new RoomJsInterface(this.callbacks)

          validateBackgroundImageLoadOptions(this.options.backgroundImageLoadOptions)

          this.dsBridge.addJavascriptObject(sdkJsInterface, "sdk")
          this.dsBridge.addJavascriptObject(roomJsInterface, "room")

          const sdkOptions: SdkOptions = buildSdkOptions(this.options)
          this.controller.configureSdk(sdkOptions, (writable: boolean) => {
            this.controller.setInitialWritable(writable)
            this.callbacks.onRoomReady?.()
          })
          if (!this.controller.attachWhiteboard(this.dsBridge)) return;
          if (this.autoJoin) {
            this.controller.joinRoom(this.options as WhiteboardOptions).catch((error: Error) => Logger.error('join room error', error))
          } else {
            this.dsBridge.prepareInBackground(sdkOptions)
          }
        })
        .onPageVisible((event) => {
          Logger.info('onPageVisible url:' + event.url);
        })
        .onRenderExited((event) => {
          this.dsBridge.destroy();
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
