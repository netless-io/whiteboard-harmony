# 普通入房与显式预加载（0.2.13）

与 Android 2.16.136、iOS 2.16.149 对齐；内嵌 Bridge 0a3fd1f，Web SDK 2.16.63、Appliance 1.1.49、WindowManager 1.0.29、Slide 0.2.109。

| 参数 | 默认值与作用 |
| --- | --- |
| enableModelPreload | 省略/false 关闭；显式 true 才准备模型 JS |
| dynamicConfig | 省略不预取；配置 Region → Harmony OSS JSON URL 自动预取 |
| preloadBuiltinApps | 省略/[] 关闭；非空列表显式准备 Slide/Presentation/MediaPlayer/DocsViewer 类 |
| enableAppliancePlugin | 省略/false 关闭教具；true 默认仍入房后初始化 |
| enablePreLoadAppliancePlugin | 大小写固定；默认 false，且需上一项 true 才提前准备探针及必要 Worker |
| appliancePluginOptions | extras 中配置 useWorker/useSimple 等；首份配置在同一 JS 文档中生效 |

模型预加载需要后端支持：目前后台 dev 可用，生产环境灰度完成后才可开启。App 类准备不创建实例、不加载课件内容。

## 普通入口

```typescript
const controller = new WhiteboardController();
const sdk: WhiteboardSdkOptions = {
  appIdentifier, region: Region.CN_HZ, useMultiViews: true,
  enableAppliancePlugin: true // 只启用教具，后置初始化。
};
// 点击时挂载 Whiteboard({ options: sdk, controller, callbacks, autoJoin: false })。
// 无需先 prepareCompletion，可立即 joinRoom；内部等待同一实际 Web 节点附着。
await controller.joinRoom(roomOptions);
```

未配置四类可选准备时，不创建可选任务聚合、不发送 sdk.observePreload、不提前请求模型/动态配置/Worker 或探针。SDK 构造原有 regions 请求保留；正常入房后按 Room → WindowManager → 所需 Worker → 教具执行。

## 候课与入房复用

```typescript
const sdk: WhiteboardSdkOptions = {
  appIdentifier, region: Region.CN_HZ, useMultiViews: true,
  enableAppliancePlugin: true, enablePreLoadAppliancePlugin: true,
  preloadBuiltinApps: ['Slide', 'Presentation']
};
callbacks.onPreloadStateChange = result => {
  // 已开启可选准备的单次 success/warn；warn 仍可继续正常入房。
  // 不代表可绘制或课件像素首帧，不要求等待此回调再入房。
};
// 候课时挂载，同一个 Whiteboard、Controller、Web 文档始终保留。
await controller.prepareCompletion();
// 可选的基础准备通知；仅表示 JS SDK 已创建。诊断另读 getPreparationInfo()。
// 点击进入课堂后显示原 Web 节点，禁止重新创建或条件销毁它。
await controller.joinRoom(roomOptions);
```

构造阶段无新增 15 秒截止时间；显式 prepareCompletion 默认 15 秒，Native join 默认 45 秒。模型/动态配置在 join 时沿用 Web SDK 既有 120 秒/5 秒等待，失败或超时回退原加载。基础准备与可选准备独立。

Worker mainThread 不准备源码或 Blob；auto 且 useSimple 省略/true 仅 Full，false 为 Full+Sub。源码与 Blob URL 复用于同一 JS 文档，leaveRoom 不撤销；View/文档销毁时释放。探针临时 Worker 完成后终止，绘制 Worker 随离房销毁。

entry 的普通/预加载入口均为 LaunchPreloadBenchmark：普通点击时挂载并立即 join；预加载候课保留原节点，完成后点击复用。凭据由私有 JSON 注入 sandbox，支持生产和指定 apiHosts，不编入 SDK/HAP。ReleaseE2E 为 Example-only 夹具；延迟附着仅用于在首个 SDK 构造前安装故障观察，不修改 SDK 实现。
