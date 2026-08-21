import { promptAction, router } from '@kit.ArkUI'
import {
  WindowParams,
  Appliance,
  ApplianceInitLoadingChangeEvent,
  AppliancePluginOptions,
  BackgroundImageLoadEvent,
  Region,
  RoomPhase,
  ShapeType,
  Whiteboard,
  WhiteboardCallbacks,
  WhiteboardController,
  WhiteboardOptions,
} from '@shengwang/whiteboard'
import { RoomPhaseGuard, RoomPhaseGuardResult } from '../RoomPhaseGuard'

const ROOM_REBUILD_DELAY_MS: number = 300
const ROOM_RECONNECT_WATCHDOG_MS: number = 50000

const demoAppliancePluginOptions: AppliancePluginOptions = {
  extras: {
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
  @State whiteboardMounted: boolean = true
  @State roomLoading: boolean = true
  private roomPhaseGuard: RoomPhaseGuard = new RoomPhaseGuard()
  private rebuildTimer: number = -1
  private reconnectWatchdogTimer: number = -1
  whiteboardOptions: WhiteboardOptions = {
    appIdentifier: "123/123",
    roomUuid: "",
    roomToken: "",
    region: Region.CN_HZ,
    uid: "123",
    useMultiViews: true,
    enableAppliancePlugin: true,
    writable: false,
    undoCacheScenesCount: 32,
    backgroundImageLoadOptions: {
      maxRetries: 3,
    },
    appliancePluginOptions: demoAppliancePluginOptions,
    localLogOptions: {
      enabled: true,
      enabledUpload: true,
    },
    slideAppOptions: {
      enableGlobalClick: false,
      enableScale: true,
      syncEventQueuePolicy: 'latest-pending-render',
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
    .setOnRoomPhaseChanged((roomPhase: RoomPhase) => {
      console.log('[Whiteboard] Room phase changed:', roomPhase)
      this.showToast(`room phase ${roomPhase}`)
      this.handleRoomPhaseChanged(roomPhase)
    })
    .setOnRoomReady(() => {
      // 此时房间状态有效，如果需要在加入房间时候操作，在此处处理
      this.writeable = this.whiteboardController.getWritable()
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
      if (this.whiteboardMounted) {
        Whiteboard({ options: this.whiteboardOptions, controller: this.whiteboardController, callbacks: this.callbacks })
          .width('100%')
          .height('100%')
      }

      if (this.roomLoading) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#FFFFFF')
          Text('正在连接白板...')
            .fontSize(16)
            .fontColor('#FFFFFF')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#66000000')
        .hitTestBehavior(HitTestMode.Block)
      }

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
            this.beginManualExit()
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

      if (this.writeable && !this.roomLoading) {
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

  aboutToDisappear(): void {
    this.beginManualExit()
  }

  private handleRoomPhaseChanged(roomPhase: RoomPhase): void {
    const result: RoomPhaseGuardResult = this.roomPhaseGuard.onPhaseChanged(roomPhase)
    this.roomLoading = result.showLoading

    if (roomPhase === RoomPhase.CONNECTED) {
      this.clearReconnectWatchdog()
    }
    if (result.shouldRebuildRoom) {
      this.rebuildRoom()
    }
  }

  private rebuildRoom(): void {
    if (this.roomPhaseGuard.isManualExit()) {
      return
    }

    this.clearRebuildTimer()
    this.clearReconnectWatchdog()
    this.whiteboardMounted = false
    this.rebuildTimer = setTimeout(() => {
      this.rebuildTimer = -1
      if (this.roomPhaseGuard.isManualExit()) {
        return
      }
      console.info('[Whiteboard] rebuilding room with a new Whiteboard instance')
      this.whiteboardMounted = true
      this.reconnectWatchdogTimer = setTimeout(() => {
        this.reconnectWatchdogTimer = -1
        const result: RoomPhaseGuardResult = this.roomPhaseGuard.onReconnectTimeout()
        this.roomLoading = result.showLoading
        if (result.shouldRebuildRoom) {
          console.warn('[Whiteboard] reconnect watchdog timed out, retrying')
          this.rebuildRoom()
        }
      }, ROOM_RECONNECT_WATCHDOG_MS)
    }, ROOM_REBUILD_DELAY_MS)
  }

  private beginManualExit(): void {
    this.roomPhaseGuard.beginManualExit()
    this.clearRebuildTimer()
    this.clearReconnectWatchdog()
    this.roomLoading = false
  }

  private clearRebuildTimer(): void {
    if (this.rebuildTimer !== -1) {
      clearTimeout(this.rebuildTimer)
      this.rebuildTimer = -1
    }
  }

  private clearReconnectWatchdog(): void {
    if (this.reconnectWatchdogTimer !== -1) {
      clearTimeout(this.reconnectWatchdogTimer)
      this.reconnectWatchdogTimer = -1
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
