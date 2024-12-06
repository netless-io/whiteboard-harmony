import { promptAction, router } from '@kit.ArkUI'
import {
  Appliance,
  Region,
  RoomPhase,
  Scene,
  ShapeType,
  Whiteboard,
  WhiteboardCallbacks,
  WhiteboardController,
  WhiteboardOptions,
  WindowAppParam,
  WindowAppSyncAttrs
} from '@shengwang/whiteboard'

@Entry
@Component
struct MultipleBoard {
  @State writeable: boolean = true
  @State appId: string | undefined = undefined
  whiteboardOptions: WhiteboardOptions = {
    appIdentifier: "123/123",
    roomUuid: "056e9dd0a33e11ef844c9de7e0348444",
    roomToken: "NETLESSROOM_YWs9eTBJOWsxeC1IVVo4VGh0NyZub25jZT0xNzMxNjY3MjI1MDY3MDAmcm9sZT0wJnNpZz0yZmE2NjFlNmY1Yjk4MDJkNWNkMDA4NjhhYjIyZjk3ZTY5YWEyNzU1N2U2ZjU4NmEyYWQ2OTE4ZmZiZTJhYThkJnV1aWQ9MDU2ZTlkZDBhMzNlMTFlZjg0NGM5ZGU3ZTAzNDg0NDQ",
    region: Region.CN_HZ,
    uid: "123",
    useMultiViews: true,
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

        TestButton("MediaPlayer", async () => {
          const param: WindowAppParam = {
            kind: "MediaPlayer",
            options: { title: "player" } as ESObject,
            attributes: { src: "https://white-pan.oss-cn-shanghai.aliyuncs.com/101/oceans.mp4" } as ESObject,
          }
          await this.whiteboardController.addApp(param)
        })

        TestButton("DocsViewer", async () => {
          const json: string =
            "[{\"name\":\"1\",\"ppt\":{\"height\":1010.0,\"src\":\"https://convertcdn.netless.link/staticConvert/0764816000c411ecbfbbb9230f6dd80f/1.png\",\"width\":714.0}},{\"name\":\"2\",\"ppt\":{\"height\":1010.0,\"src\":\"https://convertcdn.netless.link/staticConvert/0764816000c411ecbfbbb9230f6dd80f/2.png\",\"width\":714.0}},{\"name\":\"3\",\"ppt\":{\"height\":1010.0,\"src\":\"https://convertcdn.netless.link/staticConvert/0764816000c411ecbfbbb9230f6dd80f/3.png\",\"width\":714.0}},{\"name\":\"4\",\"ppt\":{\"height\":1010.0,\"src\":\"https://convertcdn.netless.link/staticConvert/0764816000c411ecbfbbb9230f6dd80f/4.png\",\"width\":714.0}}]";

          const scenes = JSON.parse(json) as Scene[]
          const scenePath = "/static"
          const title = "Doc"

          const param: WindowAppParam = {
            kind: "DocsViewer",
            options: { scenePath, scenes, title } as ESObject,
          }
          this.whiteboardController.addApp(param)
        })

        TestButton("NewDynamic", async () => {
          const prefixUrl = "https://conversion-demo-cn.oss-cn-hangzhou.aliyuncs.com/demo/dynamicConvert";
          const taskUuid = "3e3a2b8845194f998e6e05adab70e1a1";

          const scenePath = `/dynamic/${taskUuid}`
          const title = "Dynamic"

          const param: WindowAppParam = {
            kind: "Slide",
            options: { scenePath, title } as ESObject,
            attributes: { taskId: taskUuid, url: prefixUrl } as ESObject
          }
          this.whiteboardController.addApp(param)
        })

        TestButton("CloseApp", async () => {
          try {
            const apps: Record<string, WindowAppSyncAttrs> = await this.whiteboardController.queryAllApps()
            const lastKey = Object.keys(apps)[Object.keys(apps).length - 1]
            this.whiteboardController.closeApp(lastKey)
          } catch (e) {
          }
        })

        TestButton("FocusApp", async () => {
          try {
            const apps: Record<string, WindowAppSyncAttrs> = await this.whiteboardController.queryAllApps()
            const lastKey = Object.keys(apps)[Object.keys(apps).length - 1]
            this.whiteboardController.focusApp(lastKey)
          } catch (err) {
            console.error(`Failed to jump to the second page. Code is ${err.code}, message is ${err.message}`)
          }
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