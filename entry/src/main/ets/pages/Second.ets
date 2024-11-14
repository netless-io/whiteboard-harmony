import { router } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { Whiteboard, WhiteboardCallbacks, WhiteboardController, WhiteboardOptions } from 'whiteboard'

@Entry
@Component
struct Second {
  controller: WhiteboardController = new WhiteboardController();
  @State message: string = 'Hi there'
  @Prop whiteboardOptions: WhiteboardOptions = {
    appIdentifier: "123/123",
    roomUuid: "056e9dd0a33e11ef844c9de7e0348444",
    roomToken: "NETLESSROOM_YWs9eTBJOWsxeC1IVVo4VGh0NyZub25jZT0xNzMxNjY3MjI1MDY3MDAmcm9sZT0wJnNpZz0yZmE2NjFlNmY1Yjk4MDJkNWNkMDA4NjhhYjIyZjk3ZTY5YWEyNzU1N2U2ZjU4NmEyYWQ2OTE4ZmZiZTJhYThkJnV1aWQ9MDU2ZTlkZDBhMzNlMTFlZjg0NGM5ZGU3ZTAzNDg0NDQ",
    region: "cn-hz",
    uid: "123"
  }
  callbacks = new WhiteboardCallbacks()
    .setThrowError((args) => console.error('[>> Test] Error:', args))
    .setOnLogger((args) => console.log('[>> Test] Logger:', args))
    .setOnRoomPhaseChanged((roomPhase) => console.log('[>> Test] Room phase changed:', roomPhase))
    .setOnRoomStateChanged((roomState) => console.log('[>> Test] Room state changed:', JSON.stringify(roomState)));

  build() {
    Column() {
      Button() {
        Text('Back')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
      }
      .type(ButtonType.Capsule)
      .margin({
        top: 20
      })
      .backgroundColor('#0D9FFB')
      .width('40%')
      .height('5%')
      .onClick(() => {
        try {
          router.back()
          console.info('Succeeded in returning to the first page.')
        } catch (err) {
          let code = (err as BusinessError).code;
          let message = (err as BusinessError).message;
          console.error(`Failed to return to the first page. Code is ${code}, message is ${message}`)
        }
      })

      Whiteboard({ options: this.whiteboardOptions, controller: this.controller, callbacks: this.callbacks })
        .width('100%')
        .height('100%')
    }
    .width('100%')
  }
}