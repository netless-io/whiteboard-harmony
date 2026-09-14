import { promptAction, router } from '@kit.ArkUI'
import {
  WindowParams,
  Appliance,
  ApplianceInitLoadingChangeEvent,
  AppliancePluginOptions,
  BackgroundImageLoadEvent,
  DispatchDocsEventResult,
  ImageInformation,
  PptPage,
  Region,
  RoomPhase,
  Scene,
  ShapeType,
  Whiteboard,
  WhiteboardCallbacks,
  WhiteboardController,
  WhiteboardOptions,
  WindowAppParam,
  WindowDocsEvent,
  WindowOriginSize,
} from '@shengwang/whiteboard'
import { RoomPhaseGuard, RoomPhaseGuardResult } from '../RoomPhaseGuard'
import { RoomId, RoomToken } from '../common/constant'

const ROOM_REBUILD_DELAY_MS: number = 300
const ROOM_RECONNECT_WATCHDOG_MS: number = 50000

const ORIGIN_WIDTH: number = 1280
const ORIGIN_HEIGHT: number = 720
const SLIDE_TASK_UUID: string = '3e3a2b8845194f998e6e05adab70e1a1'
const SLIDE_PREFIX_URL: string = 'https://conversion-demo-cn.oss-cn-hangzhou.aliyuncs.com/demo/dynamicConvert'

interface DemoAppOptions {
  scenePath: string;
  title: string;
  scenes?: Scene[];
}

interface DemoSlideAttributes {
  taskId: string;
  url: string;
}

function createDemoAppliancePluginOptions(allowImageBitmapFallback: boolean): AppliancePluginOptions {
  return {
    extras: {
      allowImageBitmapFallback,
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
}

@Entry
@Component
struct MultipleBoard {
  @State writeable: boolean = false
  @State whiteboardMounted: boolean = true
  @State roomLoading: boolean = true
  @State allowImageBitmapFallback: boolean = false
  private roomPhaseGuard: RoomPhaseGuard = new RoomPhaseGuard()
  private rebuildTimer: number = -1
  private reconnectWatchdogTimer: number = -1
  whiteboardOptions: WhiteboardOptions = {
    appIdentifier: "123/123",
    roomUuid: RoomId,
    roomToken: RoomToken,
    region: Region.CN_HZ,
    uid: "123",
    useMultiViews: true,
    enableAppliancePlugin: true,
    writable: false,
    undoCacheScenesCount: 32,
    backgroundImageLoadOptions: {
      maxRetries: 3,
    },
    appliancePluginOptions: createDemoAppliancePluginOptions(false),
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
      .setOriginSize({ width: ORIGIN_WIDTH, height: ORIGIN_HEIGHT })
      .setOverwriteStyles(
        ".netless-app-slide-wb-view {clip-path: none !important;}" +
          ".telebox-box.telebox-blur.telebox-maximized " +
          ".netless-app-presentation-content {display: none !important;}"
      ),
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
    .setOnSlidePageStateChanged((appId: string, page: number, pageCount: number) => {
      console.info('[Whiteboard] onSlidePageStateChanged:', JSON.stringify({ appId, page, pageCount }))
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

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    this.allowImageBitmapFallback = params?.['allowImageBitmapFallback'] === true
    this.whiteboardOptions.appliancePluginOptions =
      createDemoAppliancePluginOptions(this.allowImageBitmapFallback)
  }

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
              ToolButton('Slide', () => this.addSlide())
            }
            ListItem() {
              ToolButton('Presentation', () => this.addPresentation())
            }
            ListItem() {
              ToolButton('scalePage 2x', () => this.dispatchDocsEvent({ event: 'scalePage', options: { scale: 2 } }))
            }
            ListItem() {
              ToolButton('prevPage', () => this.dispatchDocsEvent({ event: 'prevPage' }))
            }
            ListItem() {
              ToolButton('nextPage', () => this.dispatchDocsEvent({ event: 'nextPage' }))
            }
            ListItem() {
              ToolButton('prevStep', () => this.dispatchDocsEvent({ event: 'prevStep' }))
            }
            ListItem() {
              ToolButton('nextStep', () => this.dispatchDocsEvent({ event: 'nextStep' }))
            }
            ListItem() {
              ToolButton('insertImage', () => this.insertImage())
            }
            ListItem() {
              ToolButton('Undo', () => this.whiteboardController.undo())
            }
            ListItem() {
              ToolButton('Redo', () => this.whiteboardController.redo())
            }
            ListItem() {
              ToolButton('Clear', () => {
                this.whiteboardController.cleanScene(true)
              })
            }
            ListItem() {
              ToolButton('fitOrigin', () => this.whiteboardController.fitOriginSizeAndCamera())
            }
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

  private showToast(message: string): void {
    promptAction.showToast({ message, duration: 2000 })
  }

  private originSize(): WindowOriginSize {
    return { width: ORIGIN_WIDTH, height: ORIGIN_HEIGHT }
  }

  private addSlide(): void {
    const options: DemoAppOptions = {
      scenePath: `/${SLIDE_TASK_UUID}/${Date.now()}`,
      title: 'Slide 1280x720',
    }
    const attributes: DemoSlideAttributes = {
      taskId: SLIDE_TASK_UUID,
      url: SLIDE_PREFIX_URL,
    }
    const appParam: WindowAppParam = {
      kind: 'Slide',
      options,
      attributes,
      originSize: this.originSize(),
    }
    this.whiteboardController.addApp(appParam).then((appId: string) => {
      console.info('[Whiteboard] add Slide success:', appId)
      this.showToast('Slide added')
      this.queryPageState('addSlide')
    }).catch((error: Error) => {
      console.error('[Whiteboard] add Slide failed:', error.message)
      this.showToast('Slide failed')
    })
  }

  private addPresentation(): void {
    const scenes: Scene[] = [
      {
        name: '1',
        ppt: {
          src: 'https://convertcdn.netless.link/staticConvert/18140800fe8a11eb8cb787b1c376634e/1.png',
          width: 714,
          height: 1010,
        } as PptPage,
      },
      {
        name: '2',
        ppt: {
          src: 'https://convertcdn.netless.link/staticConvert/18140800fe8a11eb8cb787b1c376634e/2.png',
          width: 714,
          height: 1010,
        } as PptPage,
      },
    ]
    const options: DemoAppOptions = {
      scenePath: '/presentation-e2e',
      scenes,
      title: 'Presentation 1280x720',
    }
    const appParam: WindowAppParam = {
      kind: 'Presentation',
      options,
      originSize: this.originSize(),
    }
    this.whiteboardController.addApp(appParam).then((appId: string) => {
      console.info('[Whiteboard] add Presentation success:', appId)
      this.showToast('Presentation added')
      this.queryPageState('addPresentation')
    }).catch((error: Error) => {
      console.error('[Whiteboard] add Presentation failed:', error.message)
      this.showToast('Presentation failed')
    })
  }

  private dispatchDocsEvent(event: WindowDocsEvent): void {
    this.whiteboardController.dispatchDocsEvent(event).then((result: DispatchDocsEventResult) => {
      console.info('[Whiteboard] dispatchDocsEvent result:', JSON.stringify(result))
      this.showToast(result.accepted ? `${event.event} accepted` : `${event.event} rejected`)
      this.queryPageState(event.event)
    }).catch((error: Error) => {
      console.error('[Whiteboard] dispatchDocsEvent failed:', error.message)
      this.showToast(`${event.event} failed`)
    })
  }

  private queryPageState(source: string): void {
    this.whiteboardController.getPageState().then((state) => {
      console.info('[Whiteboard] getPageState:', JSON.stringify({ source, state }))
    }).catch((error: Error) => {
      console.error('[Whiteboard] getPageState failed:', error.message)
    })
  }

  private insertImage(): void {
    const info: ImageInformation = {
      centerX: 0,
      centerY: 0,
      width: 100,
      height: 200,
      url: 'https://p5.ssl.qhimg.com/t01a2bd87890397464a.png',
    }
    this.whiteboardController.insertImage(info)
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
