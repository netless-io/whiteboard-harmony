import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Whiteboard, WhiteboardCallbacks, WhiteboardController, WhiteboardSdkOptions,
  WhiteboardRoomOptions, WindowParams, WindowAppParam, WindowDocsEvent,
  DispatchDocsEventResult, Region, Appliance, WhitePreloadResult, PreparationInfo, SlideErrorType, VERSION } from '@shengwang/whiteboard';
import { DsBridge } from '@shengwang/whiteboard/src/main/ets/DsBridge';

// Example-only gate: mount the actual Whiteboard and capture its normal attachment,
// so optional network faults can be installed before the first SDK construction.
// Normal release cases forward immediately. No library behavior is replaced.
class ReleaseController extends WhiteboardController {
  deferred: boolean = false;
  private pending?: DsBridge;
  private readonly forwardAttach: (bridge: DsBridge) => boolean;
  constructor() {
    super();
    this.forwardAttach = this.attachWhiteboard;
    this.attachWhiteboard = (bridge: DsBridge): boolean => {
      if (!this.deferred) return this.forwardAttach(bridge);
      this.pending = bridge;
      return false;
    };
  }
  resumeAttachment(): void {
    if (!this.deferred) return;
    if (!this.pending) throw new Error('WebNotAttached');
    this.deferred = false;
    this.forwardAttach(this.pending);
    this.pending = undefined;
  }
}

interface PrivateRoom {
  appIdentifier: string;
  uuid: string;
  roomToken: string;
  apiHosts?: string[];
}
interface ReleaseCommand {
  id: string;
  action: string;
  uid?: string;
  payload?: string;
}
interface PreloadObservation extends WhitePreloadResult { count: number; }
interface CallbackObservation {
  kind: string;
  at: number;
  errorType?: string;
  message?: string;
  slideId?: string;
  slideIndex?: number;
  url?: string;
  jsStack?: string;
}
interface ConfigurationObservation {
  apps: string[] | string;
  sharedMediaVolume: boolean;
  modelOptionOmitted: boolean;
  appliance: string;
}
interface ReleaseStatus {
  sdkVersion: string;
  prepared: boolean;
  joined: boolean;
  roomReadyCount: number;
  explicitPrepareCalls: number;
  immediateJoinRequestedWithoutReady: boolean;
  preparation?: PreparationInfo;
  preload?: PreloadObservation;
  configuration: ConfigurationObservation;
  callbackEvents: CallbackObservation[];
}
interface CommandReply { id: string; action: string; ok: boolean; json: string; error: string; }
interface JoinAcknowledgement { joined: boolean; }
class SlideAttributes {
  taskId: string = '9340e8e067bc11ec8f582b1b98453394';
  url: string = 'https://convertcdn.netless.link/dynamicConvert';
}
class ReleaseSlideOptions {
  scenePath: string = '/harmony-release-slide-' + Date.now();
  title: string = 'Release fixture';
}

/** Demo-only release fixture. Private room credentials enter the sandbox at runtime. */
@Entry
@Component
struct ReleaseE2E {
  private controller: ReleaseController = new ReleaseController();
  private callbacks: WhiteboardCallbacks = new WhiteboardCallbacks();
  private sdkOptions: WhiteboardSdkOptions = { appIdentifier: '' };
  private room?: PrivateRoom;
  private prepared: boolean = false;
  private joined: boolean = false;
  private roomReadyCount: number = 0;
  private explicitPrepareCalls: number = 0;
  private immediateJoinRequestedWithoutReady: boolean = false;
  private preloadCount: number = 0;
  private preload?: PreloadObservation;
  private callbackEvents: CallbackObservation[] = [];
  private disposed: boolean = false;
  private handled: Set<string> = new Set<string>();
  private configuration: ConfigurationObservation = {
    apps: 'omitted: off', sharedMediaVolume: false,
    modelOptionOmitted: true, appliance: 'post-join'
  };
  @State mounted: boolean = false;
  @StorageLink('ReleaseE2ECommand') @Watch('onCommand') command: string = '';

  aboutToAppear(): void {
    this.callbacks.onPreloadStateChange = (result: WhitePreloadResult): void => {
      this.preloadCount++;
      this.preload = { state: result.state, message: result.message, count: this.preloadCount };
      this.record('event-preload', 'preload', JSON.stringify(this.preload));
    };
    this.callbacks.onRoomReady = (): void => { this.roomReadyCount++; };
    this.callbacks.onPPTMediaPlay = (): void => {
      this.callbackEvents.push({ kind: 'ppt-media-play', at: Date.now() });
    };
    this.callbacks.onPPTMediaPause = (): void => {
      this.callbackEvents.push({ kind: 'ppt-media-pause', at: Date.now() });
    };
    this.callbacks.onSlideError = (type: SlideErrorType, message: string, slideId: string, slideIndex: number): void => {
      this.callbackEvents.push({ kind: 'slide-error', at: Date.now(), errorType: String(type), message, slideId, slideIndex });
    };
    this.callbacks.onSlideResourceMaxRetries = (url: string, message: string, jsStack?: string): void => {
      this.callbackEvents.push({ kind: 'slide-resource-max-retries', at: Date.now(), url, message, jsStack });
    };
    this.callbacks.sdkSetupFail = (): void => {
      this.record('event-setup-failure', 'setup-failure', '', 'SdkSetupFailed');
    };
    this.record('event-page-ready', 'page-ready', JSON.stringify({ ready: true }));
    this.onCommand();
  }

  private clean(message: string): string {
    let result: string = message.replace(/NETLESSROOM_[A-Za-z0-9_+/=-]+/g, '[REDACTED]');
    if (this.room?.roomToken) result = result.split(this.room.roomToken).join('[REDACTED]');
    return result;
  }
  private record(id: string, action: string, json: string, error: string = ''): void {
    const reply: CommandReply = { id, action, ok: error.length === 0, json, error: this.clean(error) };
    console.info('WHITE_RELEASE_E2E ' + JSON.stringify(reply));
  }
  private status(): ReleaseStatus {
    return { sdkVersion: VERSION, prepared: this.prepared, joined: this.joined,
      roomReadyCount: this.roomReadyCount, explicitPrepareCalls: this.explicitPrepareCalls,
      immediateJoinRequestedWithoutReady: this.immediateJoinRequestedWithoutReady,
      preparation: this.controller.getPreparationInfo(), preload: this.preload, configuration: this.configuration,
      callbackEvents: this.callbackEvents };
  }
  private initializeWithoutPreparation(overrides?: WhiteboardSdkOptions): void {
    if (this.mounted) throw new Error('AlreadyInitialized');
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let file: string = context.filesDir + '/release-e2e.private.json';
    if (!fs.accessSync(file)) file = '/data/storage/el2/base/files/release-e2e.private.json';
    const room: PrivateRoom = JSON.parse(fs.readTextSync(file)) as PrivateRoom;
    if (!room.appIdentifier || !room.uuid || !room.roomToken) throw new Error('InvalidPrivateRoomFixture');
    this.room = room;
    const emptyApps: boolean = AppStorage.get<boolean>('ReleaseE2EEmptyApps') ?? false;
    const shared: boolean = AppStorage.get<boolean>('ReleaseE2ESharedVolume') ?? false;
    const preload: boolean = AppStorage.get<boolean>('ReleaseE2EPreload') ?? false;
    // Default ordinary mode leaves all optional preparation off.
    this.sdkOptions = { appIdentifier: room.appIdentifier, region: Region.CN_HZ,
      useMultiViews: true, enableAppliancePlugin: true,
      slideAppOptions: { enableScale: true, enableGlobalClick: false,
        syncEventQueuePolicy: 'latest-pending-render' } };
    if (room.apiHosts) this.sdkOptions.apiHosts = [...room.apiHosts];
    if (preload) {
      this.sdkOptions.enablePreLoadAppliancePlugin = true;
      this.sdkOptions.preloadBuiltinApps = ['Slide', 'Presentation'];
    }
    if (emptyApps) this.sdkOptions.preloadBuiltinApps = [];
    if (shared && this.sdkOptions.slideAppOptions) this.sdkOptions.slideAppOptions.enableSharedMediaVolume = true;
    if (overrides) {
      if (overrides.enableModelPreload !== undefined) this.sdkOptions.enableModelPreload = overrides.enableModelPreload;
      if (overrides.enableAppliancePlugin !== undefined) this.sdkOptions.enableAppliancePlugin = overrides.enableAppliancePlugin;
      if (overrides.enablePreLoadAppliancePlugin !== undefined) this.sdkOptions.enablePreLoadAppliancePlugin = overrides.enablePreLoadAppliancePlugin;
      if (overrides.useMultiViews !== undefined) this.sdkOptions.useMultiViews = overrides.useMultiViews;
      if (overrides.preloadBuiltinApps !== undefined) this.sdkOptions.preloadBuiltinApps = overrides.preloadBuiltinApps;
      if (overrides.dynamicConfig !== undefined) this.sdkOptions.dynamicConfig = overrides.dynamicConfig;
      if (overrides.appliancePluginOptions !== undefined) this.sdkOptions.appliancePluginOptions = overrides.appliancePluginOptions;
    }
    this.controller.deferred = AppStorage.get<boolean>('ReleaseE2EDeferred') ?? false;
    this.configuration = { apps: emptyApps ? [] : preload ? ['Slide', 'Presentation'] : 'omitted: off',
      sharedMediaVolume: shared, modelOptionOmitted: true, appliance: preload ? 'preload' : 'post-join' };
    this.mounted = true;
  }
  private async initialize(overrides?: WhiteboardSdkOptions): Promise<ReleaseStatus> {
    this.initializeWithoutPreparation(overrides);
    if (this.controller.deferred) return this.status();
    this.explicitPrepareCalls++;
    await this.controller.prepareCompletion(60000);
    if (this.disposed) throw new Error('HostInvalid');
    this.prepared = true;
    return this.status();
  }
  private async join(uid: string): Promise<JoinAcknowledgement> {
    if (!this.room || !this.mounted || !uid) throw new Error('NotInitializedOrMissingUid');
    const params: WindowParams = new WindowParams();
    params.forceMaximized = true;
    params.lazySetupInMaximizedMode = true;
    params.maxCachedAppsInMaximizedMode = 4;
    params.originSize = { width: 1280, height: 720 };
    const room: WhiteboardRoomOptions = { roomUuid: this.room.uuid, roomToken: this.room.roomToken,
      uid, region: Region.CN_HZ, writable: true, disableCameraTransform: false,
      undoCacheScenesCount: 32, timeout: 45000, windowParams: params };
    await this.controller.joinRoom(room);
    this.joined = true;
    this.prepared = this.controller.getPreparationInfo()?.ready ?? false;
    // Hilog has a per-line limit. Room state may contain many historical scenes;
    // only acknowledge the actual resolved join, never print the full state.
    return { joined: this.joined };
  }
  private async sequence(events: WindowDocsEvent[]): Promise<DispatchDocsEventResult[]> {
    const pending: Promise<DispatchDocsEventResult>[] = [];
    for (let index: number = 0; index < events.length; index++) {
      pending.push(this.controller.dispatchDocsEvent(events[index]));
      if (index + 1 < events.length) await new Promise<void>((resolve): void => { setTimeout(resolve, 100); });
    }
    return Promise.all(pending);
  }
  private async execute(command: ReleaseCommand): Promise<string> {
    if (command.action === 'initialize') return JSON.stringify(await this.initialize(
      command.payload ? JSON.parse(command.payload) as WhiteboardSdkOptions : undefined));
    if (command.action === 'initializeAndJoinWithoutPrepare') {
      // Mount and dispatch join in this call stack, before any explicit readiness wait.
      this.initializeWithoutPreparation();
      this.immediateJoinRequestedWithoutReady = this.controller.getPreparationInfo()?.ready !== true;
      await this.join(command.uid ?? '');
      return JSON.stringify(this.status());
    }
    if (command.action === 'status') return JSON.stringify(this.status());
    if (command.action === 'prepare') {
      this.controller.resumeAttachment();
      this.explicitPrepareCalls++;
      await this.controller.prepareCompletion(60000);
      this.prepared = true;
      return JSON.stringify(this.controller.getPreparationInfo());
    }
    if (command.action === 'enableUndo') {
      this.controller.disableSerialization(false);
      return JSON.stringify({ enabled: true });
    }
    if (command.action === 'join') return JSON.stringify(await this.join(command.uid ?? ''));
    if (command.action === 'leave') {
      await this.controller.leaveRoom(); this.joined = false; return JSON.stringify({ left: true });
    }
    if (command.action === 'pencil') {
      this.controller.setAppliance(Appliance.PENCIL);
      this.controller.setStrokeColor('#1e50dc');
      this.controller.setStrokeWidth(4);
      return JSON.stringify({ requested: true });
    }
    if (command.action === 'addSlide') {
      const app: WindowAppParam = { kind: 'Slide',
        options: new ReleaseSlideOptions(),
        attributes: new SlideAttributes(), originSize: { width: 1280, height: 720 } };
      return JSON.stringify(await this.controller.addApp(app));
    }
    if (command.action === 'docs') {
      return JSON.stringify(await this.controller.dispatchDocsEvent(JSON.parse(command.payload ?? '{}') as WindowDocsEvent));
    }
    if (command.action === 'docsSequence') {
      return JSON.stringify(await this.sequence(JSON.parse(command.payload ?? '[]') as WindowDocsEvent[]));
    }
    throw new Error('UnknownReleaseAction');
  }
  private onCommand(): void {
    if (!this.command || this.disposed) return;
    let command: ReleaseCommand;
    try { command = JSON.parse(this.command) as ReleaseCommand; } catch (_) { return; }
    if (!command.id || this.handled.has(command.id)) return;
    this.handled.add(command.id);
    this.execute(command).then((json: string): void => {
      this.record(command.id, command.action, json);
    }).catch((error: Error): void => { this.record(command.id, command.action, '', error.message); });
  }
  aboutToDisappear(): void {
    this.disposed = true;
    this.controller.cancelPreparation();
    this.controller.leaveRoom().catch(() => {});
  }
  build() {
    Stack() {
      if (this.mounted) {
        Whiteboard({ options: this.sdkOptions, controller: this.controller,
          callbacks: this.callbacks, autoJoin: false, webDebug: true })
          .id('release-e2e-board').width('100%').height('100%')
      } else {
        Text('Release E2E: waiting for private runtime fixture')
      }
    }.width('100%').height('100%')
  }
}
