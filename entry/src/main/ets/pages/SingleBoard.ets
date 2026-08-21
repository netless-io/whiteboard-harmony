import { promptAction, router } from '@kit.ArkUI'
import {
  Appliance,
  Region,
  RoomPhase,
  ShapeType,
  Whiteboard,
  WhiteboardCallbacks,
  WhiteboardController,
  WhiteboardOptions
} from '@shengwang/whiteboard'

@Entry
@Component
struct SingleBoard {
  @State writeable: boolean = true
  whiteboardOptions: WhiteboardOptions = {
    appIdentifier: "123/123",
    roomUuid: "cd1221809b8111f1aaeead87383431cf",
    roomToken: "NETLESSROOM_YWs9VWtNUk92M1JIN2I2Z284dCZleHBpcmVBdD0xNzg3Mzc4Mzk0OTY3Jm5vbmNlPTg4MzQzNjcwLTlkMjUtMTFmMS1iYzM4LWQ3Yjg5YzgwZTNlMSZyb2xlPTEmc2lnPWZkYjI5MjRkNmMwYTkxMmMzZWQ5YmU5OGZmMTZlNjA3ZDQyYjgxMzljNzA4NTVjMzVkOGM5NzlmOGJjMmY0NTUmdXVpZD1jZDEyMjE4MDliODExMWYxYWFlZWFkODczODM0MzFjZg",
    region: Region.CN_HZ,
    uid: "123",
    undoCacheScenesCount: 32
  }
  whiteboardController: WhiteboardController = new WhiteboardController();
  callbacks: WhiteboardCallbacks = new WhiteboardCallbacks()
    .setThrowError((args) => console.error('[Whiteboard] Error:', args))
    .setOnLogger((args) => console.log('[Whiteboard] Logger:', args))
    .setOnRoomPhaseChanged((roomPhase) => {
      console.log('[Whiteboard] Room phase changed:', roomPhase)
      this.showToast(`room phase ${roomPhase}`)
    })
    .setOnRoomReady(() => {
      // 此时房间状态有效，如果需要在加入房间时候操作，在此处处理
    })
    .setOnRoomStateChanged((roomState) => console.log('[Whiteboard] Room state changed:', JSON.stringify(roomState)))

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
    [Appliance.SHAPE, ShapeType.RHOMBUS],
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
