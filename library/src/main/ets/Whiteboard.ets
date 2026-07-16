import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { RoomOptions, SdkOptions, WhiteboardOptions } from './WhiteboardOptions';
import { WhiteboardController } from './WhiteboardController';
import { DsBridge } from './DsBridge';
import { RoomJsInterface, SDKError, SdkJsInterface } from './JsInterfaces';
import { WhiteboardCallbacks } from './WhiteboardCallbacks';
import { Logger } from './Logger';
import { buildRoomOptions } from './WhiteboardJoinOptions';

@Component
export struct Whiteboard {
  @Prop options: WhiteboardOptions
  @Prop controller: WhiteboardController
  @Prop callbacks: WhiteboardCallbacks
  @Prop webDebug: boolean = true
  private webController = new webview.WebviewController();
  private dsBridge = new DsBridge(this.webController)

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
          const sdkJsInterface = new SdkJsInterface(this.callbacks)
          const roomJsInterface = new RoomJsInterface(this.callbacks)

          this.dsBridge.addJavascriptObject(sdkJsInterface, "sdk")
          this.dsBridge.addJavascriptObject(roomJsInterface, "room")

          let sdkOptions: SdkOptions = {
            appIdentifier: this.options.appIdentifier,
            log: true,
            useMultiViews: this.options.useMultiViews ?? false,
            userCursor: this.options.userCursor ?? false,
            disableNewPencilStroke: false,
            enableAppliancePlugin: false,
            presentationAppOptions: this.options.presentationAppOptions,
            slideAppOptions: this.options.slideAppOptions,
            loggerOptions: this.options.localLogOptions ? {
              localLog: this.options.localLogOptions
            } : undefined
          }
          this.dsBridge.callHandler("sdk.newWhiteSdk", [sdkOptions]);

          let roomOptions: RoomOptions = buildRoomOptions(this.options)
          this.dsBridge.callHandler("sdk.joinRoom", [roomOptions], (result: object) => {
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
          this.controller.attachWhiteboard(this.dsBridge)
        })
        .onPageVisible((event) => {
          Logger.info('onPageVisible url:' + event.url);
        })
        .onRenderExited((event) => {
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
