import { promptAction, router } from '@kit.ArkUI'
import {
  WindowParams,
  Appliance,
  ApplianceInitLoadingChangeEvent,
  AppliancePluginOptions,
  BackgroundImageLoadEvent,
  Region,
  ShapeType,
  Whiteboard,
  WhiteboardCallbacks,
  WhiteboardController,
  WhiteboardOptions,
} from '@shengwang/whiteboard'

const demoAppliancePluginOptions: AppliancePluginOptions = {
  extras: {
    useWorker: 'mainThread',
    useSimple: true,
    useBackgroundThread: true,
    canvasOpt: {
      contextType: '2d',
    },
    cursor: {
      enable: true,
      expirationTime: 500,
      syncedLabel: {
        enableShowName: true,
      },
      appearance: {
        pencil: {
          synced: {
            enableShowName: false,
          },
        },
        clicker: {
          synced: {
            images: {
              standardResolution: "https://api.iconify.design/mdi:video-wireless-outline.svg?color=%237f7f7f",
            },
          },
        },
      },
    },
    syncOpt: {
      interval: 100,
      smoothSync: false,
    },
    bezier: {
      enable: false,
      maxDrawCount: 200,
    },
    textEditor: {
      showFloatBar: false,
      canSelectorSwitch: false,
      rightBoundBreak: true,
    },
  },
}

@Entry
@Component
struct MultipleBoard {
  @State writeable: boolean = false
  whiteboardOptions: WhiteboardOptions = {
    appIdentifier: "123/123",
    roomUuid: "cd1221809b8111f1aaeead87383431cf",
    roomToken: "NETLESSROOM_YWs9VWtNUk92M1JIN2I2Z284dCZleHBpcmVBdD0xNzg3MTk4MTIyMTI2Jm5vbmNlPWNkMzdhYWUwLTliODEtMTFmMS1iYzM4LWQ3Yjg5YzgwZTNlMSZyb2xlPTEmc2lnPTExNTk0NTVmMTVkYjE5MmY0NDgyMmVmYTlkNDQxNjBmODM3ZTVhNGQwYzRkNzlhNjc4MTFlNzAxZjUwODhhNmMmdXVpZD1jZDEyMjE4MDliODExMWYxYWFlZWFkODczODM0MzFjZg",
    region: Region.CN_HZ,
    uid: "123",
    useMultiViews: true,
    enableAppliancePlugin: true,
    writable: false,
    backgroundImageLoadOptions: {
      maxRetries: 3,
    },
    appliancePluginOptions: demoAppliancePluginOptions,
    localLogOptions: {
      enabled: true,
      enabledUpload: true,
    },
    slideAppOptions: {
      resolution: 1,
      maxResolutionLevel: 2,
      minFPS: 5,
      maxFPS: 15,
      enableGlobalClick: false,
      enableScale: true,
    },
    presentationAppOptions: {
      maxCameraScale: 4,
      useScrollbar: true,
    },
    windowParams: new WindowParams()
      .setContainerSizeRatio(0.75)
      .setChessboard(true)
      .setDebug(true)
      .setOverwriteStyles(".netless-app-slide-wb-view {clip-path: none !important;}"),
  }
  whiteboardController: WhiteboardController = new WhiteboardController();
  callbacks: WhiteboardCallbacks = new WhiteboardCallbacks()
    .setThrowError((args) => console.error('[Whiteboard] Error:', args))
    .setOnLogger((args) => console.log('[Whiteboard] Logger:', args))
    .setOnLocalLogStateChange((state) => {
      console.log('[Whiteboard] Local log state changed:', JSON.stringify(state))
    })
    .setOnApplianceInitLoadingChange((event: ApplianceInitLoadingChangeEvent) => {
      console.log('[Whiteboard] appliance init loading change:', JSON.stringify(event))
      this.showToast(`appliance ${event.phase} ${event.status}`)
    })
    .setOnRoomPhaseChanged((roomPhase) => {
      console.log('[Whiteboard] Room phase changed:', roomPhase)
      this.showToast(`room phase ${roomPhase}`)
    })
    .setOnRoomReady(() => {
      // 此时房间状态有效，如果需要在加入房间时候操作，在此处处理
    })
    .setOnRoomStateChanged((roomState) => {
      console.log('[Whiteboard] Room state changed:', JSON.stringify(roomState))
    })
    .setOnBackgroundImageLoad(async (event: BackgroundImageLoadEvent) => {
      console.log('[Whiteboard] backgroundImageLoad:', JSON.stringify(event))
      if (event.state !== 'failed') {
        return
      }
      // mainView 可直接比较；appId 对应的路径由 reload API 在插件内原子校验。
      if (event.viewId === 'mainView') {
        const roomState = await this.whiteboardController.getRoomState()
        if (roomState.sceneState?.scenePath !== event.scenePath) {
          return
        }
      }
      const result = await this.whiteboardController.reloadBackgroundImage({
        source: event.source,
        viewId: event.viewId,
        scenePath: event.scenePath,
      })
      console.log('[Whiteboard] reloadBackgroundImage:', JSON.stringify(result))
    })

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Whiteboard({ options: this.whiteboardOptions, controller: this.whiteboardController, callbacks: this.callbacks })
        .width('100%')
        .height('100%')

      Row() {
        Button(this.writeable ? '移除可写' : '获取可写')
          .fontSize(16)
          .type(ButtonType.Capsule)
          .backgroundColor('#0D9FFB')
          .margin({ left: 10, top: 10 })
          .onClick(() => {
            const next = !this.writeable
            this.whiteboardController.setWritable(next).then((value) => {
              this.writeable = value
              this.showToast(`setWritable ${value}`)
            }).catch((error: Error) => {
              console.error('[Whiteboard] setWritable failed:', error.message)
              this.showToast('setWritable failed')
            })
          })

        Blank()

        Button('退出房间')
          .fontSize(16)
          .type(ButtonType.Capsule)
          .backgroundColor('#F5655C')
          .margin({ right: 10, top: 10 })
          .onClick(() => {
            this.whiteboardController.disconnect().then(() => {
              console.log('[Whiteboard] disconnect success')
              router.back()
            }).catch((error: Error) => {
              console.error('[Whiteboard] disconnect failed:', error.message)
              router.back()
            })
          })
      }
      .width('100%')
      .hitTestBehavior(HitTestMode.Transparent)

      if (this.writeable) {
        Column() {
          List({ space: 8 }) {
            ListItem() {
              ToolButton('Pencil', () => {
                this.whiteboardController.setAppliance(Appliance.PENCIL)
              })
            }
            ListItem() {
              ToolButton('Text', () => {
                this.whiteboardController.setAppliance(Appliance.TEXT)
              })
            }
            ListItem() {
              ToolButton('Selector', () => {
                this.whiteboardController.setAppliance(Appliance.SELECTOR)
              })
            }
            ListItem() {
              ToolButton('Eraser', () => {
                this.whiteboardController.setAppliance(Appliance.ERASER)
              })
            }
            ListItem() {
              ToolButton('Star', () => {
                this.whiteboardController.setAppliance(Appliance.SHAPE, ShapeType.PENTAGRAM)
              })
            }
            ListItem() {
              ToolButton('Clicker', () => {
                this.whiteboardController.setAppliance(Appliance.CLICKER)
              })
            }
            ListItem() {
              ToolButton('Head', () => {
                this.whiteboardController.setAppliance(Appliance.HAND)
              })
            }
          }
          .listDirection(Axis.Horizontal)
          .width('100%')
          .height(120)
          .padding({ left: 8, right: 8, bottom: 10 })
          .backgroundColor('#CCFFFFFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
  }

  private showToast(message: string) {
    promptAction.showToast({ message, duration: 2000 })
  }
}

@Builder
function ToolButton(text: string, event: (event: ClickEvent) => void) {
  Button() {
    Text(text)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
  }
  .type(ButtonType.Capsule)
  .padding(4)
  .margin(4)
  .backgroundColor('#0D9FFB')
  .onClick(event)
}
