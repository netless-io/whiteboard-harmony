import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<boolean>('ReleaseE2EEnabled', want.parameters?.['releaseE2E'] === 'true');
    AppStorage.setOrCreate<boolean>('ReleaseE2EPreload', want.parameters?.['releasePreload'] === 'true');
    AppStorage.setOrCreate<boolean>('ReleaseE2EEmptyApps', want.parameters?.['releaseEmptyApps'] === 'true');
    AppStorage.setOrCreate<boolean>('ReleaseE2ESharedVolume', want.parameters?.['releaseSharedVolume'] === 'true');
    AppStorage.setOrCreate<string>('ReleaseE2ECommand', '');
    AppStorage.setOrCreate<boolean>('LaunchBenchEnabled', want.parameters?.['launchPreloadBench'] === 'true');
    AppStorage.setOrCreate<string>('LaunchBenchMode', want.parameters?.['benchMode'] === 'preload' ? 'preload' : 'direct');
    AppStorage.setOrCreate<string>('LaunchBenchRunId', String(want.parameters?.['benchRunId'] ?? 'manual-' + Date.now()));
    AppStorage.setOrCreate<string>('LaunchBenchReady', '');
    AppStorage.setOrCreate<string>('LaunchBenchAction', '');
    AppStorage.setOrCreate<boolean>('WhitePreloadProbe', want.parameters?.['preloadProbe'] === 'true');
    AppStorage.setOrCreate<boolean>('WhiteWorkerProbe', want.parameters?.['workerProbe'] === 'true');
    AppStorage.setOrCreate<string>('WhiteWorkerProbeAction', '');
    const workerMode = want.parameters?.['workerMode'];
    AppStorage.setOrCreate<string>('WhiteWorkerProbeMode',
      workerMode === 'dual' ? 'dual' : (workerMode === 'mainThread' ? 'mainThread' : 'simple'));
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    if (AppStorage.get<boolean>('ReleaseE2EEnabled')) {
      const command = want.parameters?.['releaseCommand'];
      if (typeof command === 'string') AppStorage.set<string>('ReleaseE2ECommand', command);
    }
    if (AppStorage.get<boolean>('LaunchBenchEnabled')) {
      AppStorage.set<string>('LaunchBenchAction', '');
      if (want.parameters?.['benchAction'] === 'leave') AppStorage.set<string>('LaunchBenchAction', 'leave');
    }
    if (AppStorage.get<boolean>('WhiteWorkerProbe')) {
      const action = want.parameters?.['workerAction'];
      AppStorage.set<string>('WhiteWorkerProbeAction', '');
      if (action === 'join') AppStorage.set<string>('WhiteWorkerProbeAction', 'join');
      if (action === 'leave') AppStorage.set<string>('WhiteWorkerProbeAction', 'leave');
    }
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent(AppStorage.get<boolean>('ReleaseE2EEnabled') ? 'pages/ReleaseE2E' :
      (AppStorage.get<boolean>('LaunchBenchEnabled') ? 'pages/LaunchPreloadBenchmark' :
      (AppStorage.get<boolean>('WhitePreloadProbe') || AppStorage.get<boolean>('WhiteWorkerProbe') ? 'pages/PreloadBoard' : 'pages/Index')), (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
