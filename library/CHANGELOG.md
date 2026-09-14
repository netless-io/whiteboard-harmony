# 版本更新记录

## [0.2.8] - 2026.09.14

- 升级内嵌正式版 `Whiteboard-bridge`，包含 `@netless/appliance-plugin@1.1.43`。
- 同步 ImageBitmap simple Worker service render barrier 修复，并保持 MainThread、OffscreenTransfer 流程隔离。
- 升级内嵌 Bridge 运行时依赖至 `@netless/window-manager@1.0.21`、`@netless/app-slide@0.2.104`。
- `WindowAppParam` 新增强类型 `originSize`，序列化为 `attributes.originSize`。
- `WhiteboardController.addApp` 等待 Web App setup 完成，失败时 reject 并清理半初始化窗口；新增 `fitOriginSizeAndCamera`。

## [Unreleased]

- `dispatchDocsEvent` 扩展为 MainView、DocsViewer、Slide、Presentation 的统一异步入口，返回结构化接收结果；删除未发布的 `dispatchPageEvent` 草案命名。
- 新增 `originSize`、`pageScaleRange`、`getPageState` 和 `onUnifiedPageStateChange` 契约。DocsViewer 不支持 `scalePage`，返回 `eventNotSupported` 和明确原因。

## [0.2.7] - 2026.08.27

- 升级内嵌 `Whiteboard-bridge` 至提交 `f1dd751`，包含 `@netless/app-slide@0.2.103`。

## [0.2.6] - 2026.08.27

- 新增 Slide 页面状态变化回调 `onSlidePageStateChanged`，透传 `appId`、`page` 和 `pageCount`，页码从 1 开始。
- 修复 `setupFail` 回调对 Bridge JSON 字符串和对象参数的兼容处理。
- 修复 Harmony library 单元测试中的 ArkTS 类型错误，完整测试套件通过。

## [0.2.5] - 2026.08.21

- 修复 Harmony Bridge 回调参数为 JSON 字符串时无法正确解析的问题，确保 `onBackgroundImageLoad`、`onApplianceInitLoadingChange`、`onMessage` 和 Slide 错误事件能够正常分发。

## [0.2.4] - 2026.08.21

- `WhiteboardCallbacks` 新增 `sdkSetupFail`，用于在 SDK 初始化失败时通知业务侧重新初始化并重新加房，并与 Android、iOS 的公开接口命名保持一致。
- 公开导出 `SDKError`，提供初始化失败原因和 JS 堆栈信息。

## [0.2.3] - 2026.08.15

- 升级内嵌 `Whiteboard-bridge` 资源至提交 `42c7f0d`，将 `@netless/appliance-plugin` 从 `1.1.39` 升级至 `1.1.40`。
- 新增 `workerRenderModeBlacklist` 与 `workerCanvasContextBlacklist` 配置类型，支持按 Harmony ArkWeb 等运行时版本覆盖 Appliance Plugin Worker 渲染和 Canvas context 兼容性策略。
- 导出 `VersionWorkerBlacklist` 与 `WorkerBlacklistByRuntime`，供 Harmony 业务侧构造类型安全的 Worker 黑名单配置。

## [0.2.2] - 2026.08.14

- 升级内嵌 `Whiteboard-bridge` 资源至提交 `aa1dfd7`，包含 `appliance-plugin@1.1.39` 和 `window-manager@1.0.18`。
- 新增 `enableAppliancePlugin` 与 `appliancePluginOptions`，支持透传 cursor、同步、贝塞尔曲线和文本编辑器配置。
- Harmony demo 增加自定义 cursor 配置；模拟器验证时局部使用 2D canvas context。

## [0.2.1] - 2026.07.17

- 升级内嵌 `Whiteboard-bridge` jsbridge 资源，包含 `white-web-sdk@2.16.56`、本地日志上传链路、`window-manager@1.0.17` 以及 Presentation/Docs/Slide 课件能力更新。
- `WhiteboardOptions` 新增 `localLogOptions`，支持 Harmony 侧显式开启 WebView 内本地日志与上传配置。
- `WhiteboardCallbacks` 新增 `onLocalLogStateChange`，用于接收 bridge 侧本地日志运行状态变化。
- `WhiteboardOptions` 新增 `slideAppOptions`、`presentationAppOptions`，支持透传 Slide 缩放配置和 Presentation 内置课件配置。
- `WindowParams` 新增 `useBoxesStatus` 参数，用于开启每个窗口独立的状态管理；新增 `builtinAppOptions` 用于配置 window-manager 内置 App。
- 多窗口 API 补充 `dispatchDocsEvent` 的 `scalePage` 事件类型，用于统一缩放 DocsViewer、Slide 和 Presentation 课件页面。
- 更新 Harmony demo：开启本地日志、Slide `enableScale`、Presentation 课件插入、`scalePage` 操作按钮，以及固定高度滚动测试按钮区域。
- 补充单元测试覆盖本地日志 bridge 方法、内置 App 配置、`useBoxesStatus` 和课件配置透传。

## [0.2.0] - 2026.05.09

- 升级内嵌 `Whiteboard-bridge` jsbridge 资源。
- 对齐 Harmony 与 Android 已公开且 bridge 已支持的 `joinRoom`、`room`、多窗口和多页相关接口。
- 新增 `WhiteboardController` / 回调解析 / join 参数映射单元测试支持。

## [0.1.0] - 2024.12.09

- initial
