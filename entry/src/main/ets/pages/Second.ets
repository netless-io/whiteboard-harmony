import { promptAction, router } from '@kit.ArkUI'
import {
  Appliance,
  RoomPhase,
  ShapeType,
  Whiteboard,
  WhiteboardCallbacks,
  WhiteboardController,
  WhiteboardOptions,
  VERSION as WhiteboardVersion,
  Region
} from '@shengwang/whiteboard'

@Entry
@Component
struct Second {
  @State writeable: boolean = true
  whiteboardOptions: WhiteboardOptions = {
    appIdentifier: "123/123",
    roomUuid: "056e9dd0a33e11ef844c9de7e0348444",
    roomToken: "NETLESSROOM_YWs9eTBJOWsxeC1IVVo4VGh0NyZub25jZT0xNzMxNjY3MjI1MDY3MDAmcm9sZT0wJnNpZz0yZmE2NjFlNmY1Yjk4MDJkNWNkMDA4NjhhYjIyZjk3ZTY5YWEyNzU1N2U2ZjU4NmEyYWQ2OTE4ZmZiZTJhYThkJnV1aWQ9MDU2ZTlkZDBhMzNlMTFlZjg0NGM5ZGU3ZTAzNDg0NDQ",
    region: Region.CN_HZ,
    uid: "123"
  }
  whiteboardController: WhiteboardController = new WhiteboardController();
  callbacks: WhiteboardCallbacks = new WhiteboardCallbacks()
    .setThrowError((args) => console.error('[>> Test] Error:', args))
    .setOnLogger((args) => console.log('[>> Test] Logger:', args))
    .setOnRoomPhaseChanged((roomPhase) => {
      console.log('[Whiteboard] Room phase changed:', roomPhase)
      this.showToast(`room phase ${roomPhase}`)
      if (roomPhase == RoomPhase.CONNECTED) {
        const isWritable = this.whiteboardController.getWritable()
        if (isWritable) {

        }
      }
    })
    .setOnRoomStateChanged((roomState) => console.log('[>> Test] Room state changed:', JSON.stringify(roomState)));
  colorIndex = -1
  colors: string[] = [
    '#F5655C',
    '#FFB554',
    '#64BB5C',
    '#357BF6',
  ]
  applianceIndex = -1
  appliances: object[] = [
    [Appliance.PENCIL, null],
    [Appliance.SELECTOR, null],
    [Appliance.RECTANGLE, null],
    [Appliance.SHAPE, ShapeType.Rhombus],
    [Appliance.ERASER, null],
    [Appliance.TEXT, null],
  ]

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Whiteboard({ options: this.whiteboardOptions, controller: this.whiteboardController, callbacks: this.callbacks })
        .width('100%')
        .height('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        TestButton("Back", () => {
          try {
            router.back()
          } catch (err) {
            console.error(`Failed to return to the first page. Code is ${err.message}`)
          }
        })

        TestButton("Writable", async () => {
          this.whiteboardController.setWritable(!this.writeable).then((value) => {
            this.writeable = value
          })
        })

        TestButton("Clean", async () => {
          this.whiteboardController.cleanScene()
        })

        TestButton("Colors", async () => {
          this.colorIndex = ++this.colorIndex % this.colors.length
          this.whiteboardController.setStrokeColor(this.colors[this.colorIndex])
        })

        TestButton("Appliances", async () => {
          this.applianceIndex = ++this.applianceIndex % this.appliances.length
          const pair = this.appliances[this.applianceIndex] as [Appliance, ShapeType]
          this.whiteboardController.setAppliance(pair[0], pair[1])
        })

        TestButton("Selector", async () => {
          this.whiteboardController.setAppliance(Appliance.SELECTOR)
        })

        TestButton("Copy&Paste", async () => {
          this.whiteboardController.copy()
          this.whiteboardController.paste()
        })
      }.margin({ top: 20 }) // Flex
    }
  }

  private showToast(message: string) {
    promptAction.showToast({ message, duration: 2000 })
  }
}

@Builder
function TestButton(text: string, event: (event: ClickEvent) => void) {
  Button() {
    Text(text)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
  }
  .type(ButtonType.Capsule)
  .padding(4)
  .margin(4)
  .backgroundColor('#0D9FFB')
  .onClick(event)
}