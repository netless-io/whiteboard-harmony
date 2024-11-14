import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { RoomOptions, SdkOptions, WhiteboardOptions } from './WhiteboardOptions';
import { WhiteboardController } from './WhiteboardController';
import { DsBridge } from './DsBridge';
import { RoomJsInterface, SdkJsInterface } from './JsInterfaces';
import { WhiteboardCallbacks } from './WhiteboardCallbacks';

@Component
export struct Whiteboard {
  @Prop options: WhiteboardOptions
  @Prop controller: WhiteboardController
  @Prop callbacks: WhiteboardCallbacks
  private webController: webview.WebviewController = new webview.WebviewController();
  dsBridge: DsBridge = new DsBridge(this.webController)

  aboutToAppear(): void {
    try {
      webview.WebviewController.setWebDebuggingAccess(true);
    } catch (error) {
      console.error(`ErrorCode: ${(error as BusinessError).code},  Message: ${(error as BusinessError).message}`);
    }
  }

  build() {
    Column() {
      Web({ src: $rawfile("whiteboard/index.html"), controller: this.webController })
        .width("100%")
        .height("100%")
        .onControllerAttached(() => {
          this.webController.registerJavaScriptProxy(this.dsBridge, "_dsbridge", ["call"])
        })
        .onLoadIntercept((event) => {
          if (event) {
            console.log('onLoadIntercept url:' + event.data.getRequestUrl())
            console.log('url:' + event.data.getRequestUrl())
            console.log('isMainFrame:' + event.data.isMainFrame())
            console.log('isRedirect:' + event.data.isRedirect())
            console.log('isRequestGesture:' + event.data.isRequestGesture())
          }
          return false
        })
        .onOverrideUrlLoading((webResourceRequest: WebResourceRequest) => {
          if (webResourceRequest && webResourceRequest.getRequestUrl() == "about:blank") {
            return true;
          }
          return false;
        })
        .onPageBegin((event) => {
          if (event) {
            console.log('onPageBegin url:' + event.url);
          }
        })
        .onFirstContentfulPaint(event => {
          if (event) {
            console.log("onFirstContentfulPaint:" + "[navigationStartTick]:" +
            event.navigationStartTick + ", [firstContentfulPaintMs]:" +
            event.firstContentfulPaintMs);
          }
        })
        .onProgressChange((event) => {
          if (event) {
            console.log('newProgress:' + event.newProgress);
          }
        })
        .onPageEnd((event) => {
          if (event) {
            console.log('onPageEnd url:' + event.url);
          }
          const sdkJsInterface = new SdkJsInterface(this.callbacks)
          const roomJsInterface = new RoomJsInterface(this.callbacks)

          this.dsBridge.addJavascriptObject(sdkJsInterface, "sdk")
          this.dsBridge.addJavascriptObject(roomJsInterface, "room")

          let sdkOptions: SdkOptions = {
            appIdentifier: this.options.appIdentifier,
            log: true,
          }
          this.dsBridge.callHandler("sdk.newWhiteSdk", [sdkOptions]);
          let roomOptions: RoomOptions = {
            uuid: this.options.roomUuid,
            roomToken: this.options.roomToken,
            region: this.options.region,
            uid: this.options.uid,
            writable: true
          }
          this.dsBridge.callHandler("sdk.joinRoom", [roomOptions]);
          this.controller.attachWhiteboard(this.dsBridge)
        })
        .onPageVisible((event) => {
          console.log('onPageVisible url:' + event.url);
        })
        .onRenderExited((event) => {
          if (event) {
            console.log('onRenderExited reason:' + event.renderExitReason);
          }
        })
        .onDisAppear(() => {
          promptAction.showToast({
            message: 'The web is hidden',
            duration: 2000
          })
        })
    }
  }
}
