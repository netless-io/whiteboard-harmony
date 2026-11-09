import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { router } from '@kit.ArkUI';
import { Whiteboard, WhiteboardCallbacks, WhiteboardController, WhiteboardSdkOptions,
  WhiteboardRoomOptions, WindowParams, Region, SlideInvisibleBehavior } from '@shengwang/whiteboard';

interface BenchmarkRoom {
  appIdentifier: string;
  uuid: string;
  roomToken: string;
  apiHosts?: string[];
}
interface BenchmarkRoute { mode?: string; }
interface BenchmarkEvent {
  stage: string;
  runId: string;
  mode: string;
  deviceEpochMs: number;
  detail?: string;
}

/** Debug benchmark entry. Credentials are injected into the app sandbox, never the HAP. */
@Entry
@Component
struct LaunchPreloadBenchmark {
  private controller: WhiteboardController = new WhiteboardController();
  private callbacks: WhiteboardCallbacks = new WhiteboardCallbacks();
  private sdkOptions: WhiteboardSdkOptions = { appIdentifier: '' };
  private credentials?: BenchmarkRoom;
  private runId: string = '';
  private mode: string = 'direct';
  private disposed: boolean = false;
  @State status: string = '读取本地测试房间配置…';
  @State mounted: boolean = false;
  @State prepared: boolean = false;
  @State joining: boolean = false;
  @State joined: boolean = false;
  private baseReady: boolean = false;
  private optionalReady: boolean = false;
  @StorageLink('LaunchBenchAction') @Watch('onAction') private action: string = '';

  private record(stage: string, detail?: string): void {
    const event: BenchmarkEvent = { stage, runId: this.runId, mode: this.mode,
      deviceEpochMs: Date.now(), detail };
    console.info('HB_INIT_BENCH ' + JSON.stringify(event));
  }

  aboutToAppear(): void {
    this.runId = AppStorage.get<string>('LaunchBenchRunId') ?? 'manual-' + Date.now();
    const params: BenchmarkRoute = router.getParams() as BenchmarkRoute;
    this.mode = params?.mode ?? AppStorage.get<string>('LaunchBenchMode') ?? 'direct';
    AppStorage.setOrCreate<string>('LaunchBenchMode', this.mode);
    this.callbacks.onRoomReady = (): void => this.record('NATIVE_JOIN_SUCCESS');
    this.callbacks.sdkSetupFail = (error): void => this.record('ERROR', error.toString());
    this.callbacks.onPreloadStateChange = (result): void => {
      // The shared Demo also works without the isolated legacy JS benchmark proxy.
      if (this.mode !== 'preload' || this.disposed) return;
      this.record('NATIVE_PRELOAD_COMPLETE', JSON.stringify(result));
      this.optionalReady = true;
      this.markPrepared(result.state === 'warn' ? result.message : '');
    };
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      this.record('SANDBOX_INFO', JSON.stringify({ filesDir: context.filesDir, cacheDir: context.cacheDir }));
      let configPath: string = context.filesDir + '/launch-preload.private.json';
      if (!fs.accessSync(configPath)) configPath = '/data/storage/el2/base/files/launch-preload.private.json';
      this.credentials = JSON.parse(fs.readTextSync(configPath)) as BenchmarkRoom;
      if (!this.credentials.appIdentifier || !this.credentials.uuid || !this.credentials.roomToken) throw new Error('Invalid local room configuration');
      this.sdkOptions = {
        appIdentifier: this.credentials.appIdentifier,
        region: Region.CN_HZ, useMultiViews: true, userCursor: false, enableAppliancePlugin: true,
        slideAppOptions: { enableScale: true, enableGlobalClick: false, enableSharedMediaVolume: false,
          forceCanvas: false, debug: false, showRenderError: false,
          invisibleBehavior: SlideInvisibleBehavior.Frozen, syncEventQueuePolicy: 'latest-pending-render' }
      };
      if (this.credentials.apiHosts) this.sdkOptions.apiHosts = [...this.credentials.apiHosts];
      if (this.mode === 'preload') {
        // Model preloading remains off until explicitly selected against a ready backend.
        this.sdkOptions.enablePreLoadAppliancePlugin = true;
        this.sdkOptions.preloadBuiltinApps = ['Slide', 'Presentation'];
        this.sdkOptions.appliancePluginOptions = {};
        this.record('T-1');
        this.mounted = true;
        // Base JS readiness is optional and separate from the optional-work callback.
        this.controller.prepareCompletion().then(() => {
          if (this.disposed) return;
          this.baseReady = true;
          this.markPrepared();
        }).catch((error: Error) => { this.status = error.message; this.record('ERROR', error.message); });
        this.status = '预加载中，等待 App 类及教具准备完成…';
      } else {
        this.sdkOptions.preloadBuiltinApps = [];
        this.status = '普通入口：点击时创建白板并加入房间';
      }
      this.record('PAGE_READY');
    } catch (_) {
      this.status = '缺少有效的本地测试配置';
      this.record('ERROR', this.status);
    }
  }

  private markPrepared(warning: string = ''): void {
    if (this.prepared || this.disposed || this.mode !== 'preload' || !this.baseReady || !this.optionalReady) return;
    this.prepared = true;
    this.status = warning ? '预加载完成（有警告），可继续进入房间' : '预加载 Ready，等待进入房间';
    this.record('PRELOAD_READY', warning || undefined);
  }

  private onAction(): void {
    if (this.action === 'leave') this.leave();
  }

  private async enter(): Promise<void> {
    if (!this.credentials || this.joining || this.joined || this.disposed ||
      (this.mode === 'preload' && !this.prepared)) return;
    this.record('CLICK');
    this.joining = true;
    this.status = '正在加入测试房间…';
    if (this.mode === 'direct') {
      this.record('SDK_CONSTRUCT_BEGIN');
      this.mounted = true;
    }
    const windowParams: WindowParams = new WindowParams();
    windowParams.forceMaximized = true;
    windowParams.lazySetupInMaximizedMode = true;
    windowParams.maxCachedAppsInMaximizedMode = 4;
    windowParams.useBoxesStatus = false;
    windowParams.originSize = { width: 1280, height: 720 };
    const room: WhiteboardRoomOptions = {
      roomUuid: this.credentials.uuid, roomToken: this.credentials.roomToken,
      uid: 'launch-aligned-config-benchmark', region: Region.CN_HZ, writable: true,
      timeout: 45000, windowParams
    };
    if (this.mode === 'direct') room.appliancePluginOptions = {};
    this.record('T0');
    try {
      await this.controller.joinRoom(room);
      if (this.disposed) return;
      this.joined = true;
      this.status = '已加入测试房间';
    } catch (error) {
      this.record('ERROR', (error as Error).message);
      this.status = '加入房间失败';
    } finally { this.joining = false; }
  }

  private async leave(): Promise<void> {
    try {
      await this.controller.leaveRoom();
      this.joined = false;
      this.status = '已退出房间';
      this.record('LEFT');
    } catch (error) { this.record('ERROR', (error as Error).message); }
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.controller.cancelPreparation();
    this.controller.leaveRoom().catch(() => {});
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.mounted) {
        Whiteboard({ options: this.sdkOptions, controller: this.controller,
          callbacks: this.callbacks, autoJoin: false })
          .width('100%').height('100%').opacity(this.joined ? 1 : 0.01)
      }
      Column({ space: 16 }) {
        Text('Harmony 普通与预加载入房').fontSize(24)
        Text(this.status).fontSize(18)
        Button(this.mode === 'preload' ? '预加载进入测试房间' : '普通进入测试房间')
          .id('launch-benchmark-join')
          .enabled(!this.joining && !this.joined && (this.mode === 'direct' || this.prepared))
          .onClick(() => { this.enter(); })
        Button('退出测试房间').enabled(this.joined).onClick(() => { this.leave(); })
      }.padding(16).width('100%')
    }.width('100%').height('100%')
  }
}
