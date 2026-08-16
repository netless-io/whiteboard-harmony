import { promptAction, router } from '@kit.ArkUI'
import {
  AddPageParam,
  Appliance,
  AppliancePluginExtrasOptions,
  AppliancePluginOptions,
  BackgroundImageLoadEvent,
  Region,
  RoomPhase,
  Scene,
  ShapeType,
  Whiteboard,
  WhiteboardCallbacks,
  WhiteboardController,
  WhiteboardOptions,
  WindowAppParam,
  WindowAppSyncAttrs,
  WindowParams,
  WindowDocsEventType
} from '@shengwang/whiteboard'

interface DemoCanvasOptions {
  contextType: string;
}

interface DemoAppliancePluginExtrasOptions extends AppliancePluginExtrasOptions {
  canvasOpt: DemoCanvasOptions;
}

interface DemoAppliancePluginOptions extends AppliancePluginOptions {
  extras: DemoAppliancePluginExtrasOptions;
}

const demoAppliancePluginOptions: DemoAppliancePluginOptions = {
  extras: {
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
  @State writeable: boolean = true
  @State appId: string | undefined = undefined
  presentationScenesJson: string =
    "[{\"name\":\"1\",\"ppt\":{\"height\":1010.0,\"src\":\"https://convertcdn.netless.link/staticConvert/0764816000c411ecbfbbb9230f6dd80f/1.png\",\"width\":714.0}},{\"name\":\"2\",\"ppt\":{\"height\":1010.0,\"src\":\"https://convertcdn.netless.link/staticConvert/0764816000c411ecbfbbb9230f6dd80f/2.png\",\"width\":714.0}},{\"name\":\"3\",\"ppt\":{\"height\":1010.0,\"src\":\"https://convertcdn.netless.link/staticConvert/0764816000c411ecbfbbb9230f6dd80f/3.png\",\"width\":714.0}},{\"name\":\"4\",\"ppt\":{\"height\":1010.0,\"src\":\"https://convertcdn.netless.link/staticConvert/0764816000c411ecbfbbb9230f6dd80f/4.png\",\"width\":714.0}}]"
  whiteboardOptions: WhiteboardOptions = {
    appIdentifier: "123/123",
    roomUuid: "0e4723c0986811f188c52bd9b24f5d77",
    roomToken: "NETLESSROOM_YWs9VWtNUk92M1JIN2I2Z284dCZleHBpcmVBdD0xNzg2ODU3MjExMTQwJm5vbmNlPTBlNmY2YzQwLTk4NjgtMTFmMS1iYzM4LWQ3Yjg5YzgwZTNlMSZyb2xlPTEmc2lnPWNhMjg3Y2IwNTJlZjI3OGQ2NDY3YTZlYzQ1NDU5ZmE5Mjg4YmM4N2Y3NjE3MDVhZWQ0MGZjYzc4NDUyNWY5NDAmdXVpZD0wZTQ3MjNjMDk4NjgxMWYxODhjNTJiZDliMjRmNWQ3Nw",
    region: Region.CN_HZ,
    uid: "123",
    useMultiViews: true,
    enableAppliancePlugin: true,
    backgroundImageLoadOptions: {
      maxRetries: 1,
    },
    appliancePluginOptions: demoAppliancePluginOptions,
    localLogOptions: {
      enabled: true,
      enabledUpload: true,
    },
    slideAppOptions: {
      enableScale: true,
    },
    presentationAppOptions: {
      maxCameraScale: 4,
      useScrollbar: true,
    },
    windowParams: new WindowParams()
      .setContainerSizeRatio(0.75)
      .setChessboard(true)
      .setDebug(true),
  }
  whiteboardController: WhiteboardController = new WhiteboardController();
  callbacks: WhiteboardCallbacks = new WhiteboardCallbacks()
    .setThrowError((args) => console.error('[Whiteboard] Error:', args))
    .setOnLogger((args) => console.log('[Whiteboard] Logger:', args))
    .setOnLocalLogStateChange((state) => {
      console.log('[Whiteboard] Local log state changed:', JSON.stringify(state))
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

      Scroll() {
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

          TestButton("Presentation", async () => {
            this.insertPresentationCourseware()
          })

          TestButton("ScalePage 2x", async () => {
            this.dispatchScalePage(2.0)
          })

          TestButton("ScalePage 1x", async () => {
            this.dispatchScalePage(1.0)
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

          TestButton("AddPage", async () => {
            // 默认在插入到最后页面，使用 { after: true } 插入到当前页面后
            this.whiteboardController.addPage({ after: true })

            //不主动切换页面，需要调用页面变更
            this.whiteboardController.nextPage()
          })

          TestButton("RemovePage", async () => {
            this.whiteboardController.removePage()
          })

          TestButton("PrevPage", async () => {
            this.dispatchPageEventAndResetScale("prevPage")
          })

          TestButton("NextPage", async () => {
            this.dispatchPageEventAndResetScale("nextPage")
          })

          TestButton("LogState", async () => {
            this.whiteboardController.getLocalLogState().then((state) => {
              console.log('[Whiteboard] Local log state:', JSON.stringify(state))
              this.showToast('getLocalLogState success')
            }).catch((error: Error) => {
              console.error('[Whiteboard] getLocalLogState failed:', error.message)
              this.showToast('getLocalLogState failed')
            })
          })

          TestButton("UploadLogs", async () => {
            this.whiteboardController.uploadLocalLogs().then((result) => {
              console.log('[Whiteboard] uploadLocalLogs:', JSON.stringify(result))
              this.showToast('uploadLocalLogs success')
            }).catch((error: Error) => {
              console.error('[Whiteboard] uploadLocalLogs failed:', error.message)
              this.showToast('uploadLocalLogs failed')
            })
          })
        }
        .width('100%')
      }
      .height(180)
      .width('100%')
      .backgroundColor('#CCFFFFFF')
      .margin({ top: 20 })
    }
  }

  private showToast(message: string) {
    promptAction.showToast({ message, duration: 2000 })
  }

  private insertPresentationCourseware(): void {
    const scenes = JSON.parse(this.presentationScenesJson) as Scene[]
    const param: WindowAppParam = {
      kind: "Presentation",
      options: {
        scenePath: `/presentation/${Date.now()}`,
        scenes,
        title: "Presentation App"
      } as ESObject,
    }

    this.whiteboardController.addApp(param).then((appId) => {
      this.appId = appId
      console.log('[Whiteboard] Presentation app inserted:', appId)
      this.showToast('Presentation inserted')
    }).catch((error: Error) => {
      console.error('[Whiteboard] Presentation insert failed:', error.message)
      this.showToast('Presentation failed')
    })
  }

  private dispatchScalePage(scale: number): void {
    this.whiteboardController.dispatchDocsEvent({
      event: "scalePage",
      options: { scale },
    }).then((result) => {
      console.log(`[Whiteboard] scalePage ${scale} result:`, result)
      this.showToast(`scalePage ${scale}`)
    }).catch((error: Error) => {
      console.error('[Whiteboard] scalePage failed:', error.message)
      this.showToast('scalePage failed')
    })
  }

  private dispatchPageEventAndResetScale(event: WindowDocsEventType): void {
    this.whiteboardController.dispatchDocsEvent({ event }).then((result) => {
      console.log(`[Whiteboard] ${event} result:`, result)
      if (result) {
        this.dispatchScalePage(1.0)
      }
    }).catch((error: Error) => {
      console.error(`[Whiteboard] ${event} failed:`, error.message)
      this.showToast(`${event} failed`)
    })
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
