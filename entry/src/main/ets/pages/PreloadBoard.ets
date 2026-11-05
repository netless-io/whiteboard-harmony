import { Whiteboard, WhiteboardCallbacks, WhiteboardController, WhiteboardSdkOptions, WhiteboardRoomOptions, WindowParams, PreparationInfo, Region } from '@shengwang/whiteboard';
import { AppIdentifier } from '../common/constant';
import { PreloadRoomUuid, PreloadRoomToken } from '../common/preload.local';

interface PreloadDemoRecord {
  event: string;
  timeMs: number;
  sincePrepareRequestMs: number;
  native?: PreparationInfo;
}

@Entry
@Component
struct PreloadBoard {
  private controller: WhiteboardController = new WhiteboardController();
  private sdkOptions: WhiteboardSdkOptions = { appIdentifier: AppIdentifier, useMultiViews: true, enableAppliancePlugin: true, appliancePluginOptions: { extras: { useWorker: "auto", useSimple: true, allowImageBitmapFallback: true } } };
  private callbacks: WhiteboardCallbacks = new WhiteboardCallbacks();
  @State status: string = '正在准备白板…';
  @State prepared: boolean = false;
  @State joined: boolean = false;
  @StorageLink('WhiteWorkerProbeAction') @Watch('onWorkerProbeAction') private workerAction: string = '';
  private joining: boolean = false;
  private disposed: boolean = false;
  private prepareRequestedAt: number = 0;

  private onWorkerProbeAction(): void {
    if (!AppStorage.get<boolean>('WhiteWorkerProbe')) return;
    if (this.workerAction === 'join' && this.prepared) this.enterClass();
    if (this.workerAction === 'leave' && this.joined) this.leaveClass();
  }

  private record(event: string): void {
    const record: PreloadDemoRecord = { event: event, timeMs: new Date().getTime(), sincePrepareRequestMs: new Date().getTime() - this.prepareRequestedAt, native: this.controller.getPreparationInfo() };
    console.info('WHITE_PRELOAD_DEMO ' + JSON.stringify(record));
  }
  aboutToAppear(): void {
    if (AppStorage.get<boolean>('WhiteWorkerProbe')) {
      const mode = AppStorage.get<string>('WhiteWorkerProbeMode');
      this.sdkOptions.appliancePluginOptions = { extras: { useWorker: mode === 'mainThread' ? 'mainThread' : 'auto', useSimple: mode !== 'dual', allowImageBitmapFallback: true } };
    }
    this.prepareRequestedAt = new Date().getTime(); this.record('prepare_request');
    this.controller.prepareCompletion().then(() => {
      if (this.disposed) return;
      this.prepared = true; this.status = '白板已准备，等待进入课堂'; this.record('prepared');
      if (AppStorage.get<boolean>('WhitePreloadProbe')) setTimeout(() => { if (!this.disposed) this.enterClass(); }, 2000);
    }).catch((error: Error) => { this.status = error.message; this.record('prepare_error'); });
  }
  aboutToDisappear(): void {
    this.disposed = true; this.controller.cancelPreparation();
    this.controller.leaveRoom().catch((error: Error) => console.error('Preload leave failed: ' + error.message));
  }
  private async enterClass(): Promise<void> {
    if (this.joining || this.joined || this.disposed) return;
    this.joining = true; this.status = '正在进入课堂…'; this.record('join_entry');
    try {
      const room: WhiteboardRoomOptions = { roomUuid: PreloadRoomUuid, roomToken: PreloadRoomToken,
        uid: 'harmony-preload-' + new Date().getTime(), region: Region.CN_HZ, writable: false, windowParams: new WindowParams() };
      await this.controller.joinRoom(room);
      this.joined = true; this.status = '已进入课堂'; this.record('room_ready');
      if (AppStorage.get<boolean>('WhitePreloadProbe')) setTimeout(() => { this.leaveClass(); }, 5000);
    } catch (error) { this.status = (error as Error).message; this.record('join_error'); }
    finally { this.joining = false; }
  }
  private async leaveClass(): Promise<void> {
    try { await this.controller.leaveRoom(); this.joined = false; this.joining = false; this.status = '已退出课堂'; this.record('left'); }
    catch (error) { this.status = (error as Error).message; this.record('leave_error'); }
  }
  build() {
    Column() {
      Text(this.status).fontSize(20).padding(12)
      Row() {
        Button('进入测试课堂').enabled(this.prepared && !this.joining && !this.joined).onClick(() => { this.enterClass(); })
        Button('退出课堂').enabled(this.joined).onClick(() => { this.leaveClass(); })
      }
      // This Web node stays mounted while waiting, joining and teaching.
      Whiteboard({ options: this.sdkOptions, controller: this.controller, callbacks: this.callbacks, autoJoin: false }).layoutWeight(1)
    }.width('100%').height('100%')
  }
}
