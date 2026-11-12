import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Whiteboard, WhiteboardCallbacks, WhiteboardController, WhiteboardSdkOptions,
  WhiteboardRoomOptions, WindowParams, Region, WhitePreloadResult } from '@shengwang/whiteboard';

interface PrivateRoom { appIdentifier: string; uuid: string; roomToken: string; otherUuid: string; otherRoomToken: string; apiHosts?: string[]; }
interface MatrixCommand { id: string; action: string; slot: string; uid?: string; otherRoom?: boolean; preload?: boolean; multiViews?: boolean; apiMethod?: string; writable?: boolean; }
interface Reply { id: string; action: string; slot: string; ok: boolean; error: string; at: number; preloadCount: number; preloadState: string; businessReferenceReleased: boolean; controllerRetained: boolean; apiValue: string; }

/** Demo-only ordinary public join/exit automation. Default bundled Bridge, no preload. */
@Entry
@Component
struct DestroyedHostE2E {
  private a?: WhiteboardController = new WhiteboardController();
  private b?: WhiteboardController = new WhiteboardController();
  private c?: WhiteboardController = new WhiteboardController();
  private callbacksA: WhiteboardCallbacks = new WhiteboardCallbacks();
  private callbacksB: WhiteboardCallbacks = new WhiteboardCallbacks();
  private callbacksC: WhiteboardCallbacks = new WhiteboardCallbacks();
  private options: WhiteboardSdkOptions = { appIdentifier: '' };
  private room?: PrivateRoom;
  private apiValues: Map<string, string> = new Map<string, string>();
  private handled: Set<string> = new Set<string>();
  private preloadResults: Map<string, WhitePreloadResult> = new Map<string, WhitePreloadResult>();
  private preloadCounts: Map<string, number> = new Map<string, number>();
  private releasedControllers: Map<string, WeakRef<WhiteboardController>> = new Map<string, WeakRef<WhiteboardController>>();
  @State mountedA: boolean = false;
  @State mountedB: boolean = false;
  @State mountedC: boolean = false;
  @StorageLink('DestroyedHostCommand') @Watch('onCommand') command: string = '';

  aboutToAppear(): void {
    console.info('DESTROYED_HOST_E2E READY');
  }
  private loadRoom(): void {
    if (this.room) return;
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    let file: string = context.filesDir + '/release-e2e.private.json';
    if (!fs.accessSync(file)) file = '/data/storage/el2/base/files/release-e2e.private.json';
    this.room = JSON.parse(fs.readTextSync(file)) as PrivateRoom;
    this.options = { appIdentifier: this.room.appIdentifier, region: Region.CN_HZ, useMultiViews: true, apiHosts: this.room.apiHosts };
  }
  private controller(slot: string): WhiteboardController {
    if (slot === 'A') return this.a!;
    if (slot === 'B') return this.b!;
    if (slot === 'C') return this.c!;
    throw new Error('InvalidSlot');
  }
  private async execute(command: MatrixCommand): Promise<void> {
    const slot: string = command.slot;
    if (command.action === 'mount') {
      this.loadRoom();
      this.options = { appIdentifier: this.room!.appIdentifier, region: Region.CN_HZ, useMultiViews: command.multiViews !== false,
        apiHosts: this.room!.apiHosts, enableModelPreload: command.preload === true,
        preloadBuiltinApps: command.preload ? ['Slide', 'Presentation'] : undefined };
      this.releasedControllers.delete(slot);
      this.preloadResults.delete(slot); this.preloadCounts.set(slot, 0);
      const callbacks: WhiteboardCallbacks = new WhiteboardCallbacks();
      callbacks.onPreloadStateChange = (result: WhitePreloadResult): void => {
        this.preloadResults.set(slot, result); this.preloadCounts.set(slot, (this.preloadCounts.get(slot) ?? 0) + 1);
      };
      if (slot === 'A') { this.callbacksA = callbacks; this.a = new WhiteboardController(); this.mountedA = true; }
      else if (slot === 'B') { this.callbacksB = callbacks; this.b = new WhiteboardController(); this.mountedB = true; }
      else if (slot === 'C') { this.callbacksC = callbacks; this.c = new WhiteboardController(); this.mountedC = true; }
      else throw new Error('InvalidSlot');
      return;
    }
    if (command.action === 'unmount') {
      if (slot === 'A') this.mountedA = false;
      else if (slot === 'B') this.mountedB = false;
      else if (slot === 'C') this.mountedC = false;
      else throw new Error('InvalidSlot');
      await new Promise<void>((resolve): void => { setTimeout(resolve, 200); });
      return;
    }
    if (command.action === 'dropController') {
      this.releasedControllers.set(slot, new WeakRef<WhiteboardController>(this.controller(slot)));
      if (slot === 'A') this.a = undefined;
      else if (slot === 'B') this.b = undefined;
      else if (slot === 'C') this.c = undefined;
      else throw new Error('InvalidSlot');
      return;
    }
    if (command.action === 'observeController') {
      if (!this.releasedControllers.has(slot)) throw new Error('ControllerNotDropped');
      return;
    }
    const controller: WhiteboardController = this.controller(slot);
    if (command.action === 'prepareSdk') { await controller.prepareCompletion(45000); return; }
    if (command.action === 'prepare') {
      await controller.prepareCompletion(45000);
      const deadline: number = Date.now() + 55000;
      while (!this.preloadResults.has(slot)) {
        if (Date.now() > deadline) throw new Error('OptionalPreloadTimeout');
        await new Promise<void>((resolve): void => { setTimeout(resolve, 50); });
      }
      const result: WhitePreloadResult = this.preloadResults.get(slot)!;
      if (result.state !== 'success') throw new Error('PreloadWarn: ' + result.message);
      if (this.preloadCounts.get(slot) !== 1) throw new Error('DuplicatePreloadCallback');
      return;
    }
    if (command.action === 'join') {
      if (!this.room || !command.uid) throw new Error('MissingRoomOrUid');
      const params: WhiteboardRoomOptions = { roomUuid: command.otherRoom ? this.room.otherUuid : this.room.uuid,
        roomToken: command.otherRoom ? this.room.otherRoomToken : this.room.roomToken,
        uid: command.uid, region: Region.CN_HZ, writable: command.writable === true, timeout: 45000, windowParams: new WindowParams() };
      await controller.joinRoom(params);
      return;
    }
    if (command.action === 'apiInvoke') {
      let value: ESObject;
      if (command.apiMethod === 'nextPage') value = await controller.nextPage();
      else if (command.apiMethod === 'prevPage') value = await controller.prevPage();
      else if (command.apiMethod === 'closeApp') value = await controller.closeApp('contract-missing-app');
      else if (command.apiMethod === 'queryApp') value = await controller.queryApp('contract-missing-app');
      else if (command.apiMethod === 'queryAllApps') value = await controller.queryAllApps();
      else if (command.apiMethod === 'insertText') value = await controller.insertText(0, 0, 'contract-test');
      else if (command.apiMethod === 'getRoomPhase') value = await controller.getRoomPhase();
      else if (command.apiMethod === 'setScenePath') value = await controller.setScenePath('/init');
      else if (command.apiMethod === 'setSceneIndex') value = await controller.setSceneIndex(0);
      else throw new Error('InvalidApiMethod');
      this.apiValues.set(command.id, JSON.stringify(value));
      return;
    }
    if (command.action === 'apiContract') {
      const state = await controller.getRoomState();
      if (!state.pageState || !Number.isFinite(state.pageState.index) || !Number.isFinite(state.pageState.length)) {
        throw new Error('InvalidPageState');
      }
      const scenes = await controller.getEntireScenes();
      if (Array.isArray(scenes) || typeof scenes !== 'object' || scenes === null) throw new Error('InvalidScenes');
      if (command.multiViews !== false) {
        const apps = await controller.queryAllApps();
        if (Array.isArray(apps) || typeof apps !== 'object' || apps === null) throw new Error('InvalidApps');
      } else {
        let rejected: boolean = false;
        try { await controller.queryAllApps(); } catch (error) { rejected = (error as Error).message.includes('window manager not existed'); }
        if (!rejected) throw new Error('MissingManagerDidNotReject');
      }
      const next: boolean = await controller.nextPage();
      const prev: boolean = await controller.prevPage();
      if (typeof next !== 'boolean' || typeof prev !== 'boolean') throw new Error('InvalidPageResult');
      return;
    }
    if (command.action === 'leave') { await controller.leaveRoom(); return; }
    if (command.action === 'disconnect') { await controller.disconnect(); return; }
    throw new Error('InvalidAction');
  }
  private reply(command: MatrixCommand, error?: Error): void {
    let message: string = error?.message ?? '';
    if (this.room?.roomToken) message = message.split(this.room.roomToken).join('[REDACTED]');
    const result: Reply = { id: command.id, action: command.action, slot: command.slot,
      ok: !error, error: message, at: Date.now(), preloadCount: this.preloadCounts.get(command.slot) ?? 0,
      preloadState: this.preloadResults.get(command.slot)?.state ?? '',
      businessReferenceReleased: this.releasedControllers.has(command.slot) &&
        (command.slot === 'A' ? this.a === undefined : command.slot === 'B' ? this.b === undefined : this.c === undefined),
      controllerRetained: this.releasedControllers.get(command.slot)?.deref() !== undefined, apiValue: this.apiValues.get(command.id) ?? '' };
    this.apiValues.delete(command.id);
    console.info('DESTROYED_HOST_E2E ' + JSON.stringify(result));
  }
  private onCommand(): void {
    if (!this.command) return;
    let command: MatrixCommand;
    try { command = JSON.parse(this.command) as MatrixCommand; } catch (_) { return; }
    if (!command.id || this.handled.has(command.id)) return;
    this.handled.add(command.id);
    this.execute(command).then((): void => this.reply(command)).catch((error: Error): void => this.reply(command, error));
  }
  build() {
    Row() {
      if (this.mountedA) { Whiteboard({ options: this.options, controller: this.a!, callbacks: this.callbacksA, autoJoin: false, webDebug: true }).width('33%').height('100%').id('matrix-A') }
      if (this.mountedB) { Whiteboard({ options: this.options, controller: this.b!, callbacks: this.callbacksB, autoJoin: false, webDebug: true }).width('33%').height('100%').id('matrix-B') }
      if (this.mountedC) { Whiteboard({ options: this.options, controller: this.c!, callbacks: this.callbacksC, autoJoin: false, webDebug: true }).width('33%').height('100%').id('matrix-C') }
    }.width('100%').height('100%')
  }
}
