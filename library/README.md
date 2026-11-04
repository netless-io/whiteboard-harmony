## 介绍

`whiteboard-harmony` 是一个适用于 HarmonyOS 的 Whiteboard SDK 包，提供了与 Whiteboard 服务交互的接口。

## 下载安装

```shell
ohpm install @shengwang/whiteboard
```

## 权限设置

```shell
ohos.permission.INTERNET
```

## API

### 加入房间

```shell
@Entry
@Component
struct Demo {
  whiteboardOptions: WhiteboardOptions = {
    appIdentifier: "APP_IDENTIFIER",
    roomUuid: "ROOM_UUID",
    roomToken: "ROOM_TOKEN",
    region: Region.CN_HZ,
    uid: "CLIENT_UID"
  }
  whiteboardController: WhiteboardController = new WhiteboardController();
  callbacks: WhiteboardCallbacks = new WhiteboardCallbacks()

  build() {
    Stack() {
      Whiteboard({ options: this.whiteboardOptions, controller: this.whiteboardController, callbacks: this.callbacks })
        .width('100%')
        .height('100%')
    }
  }
}
```

## 白板操作

### SDK 初始化失败回调

SDK 初始化失败后，加入实时房间可能一直无响应。通过 `sdkSetupFail` 监听该错误，并重新创建白板组件以完成 SDK 初始化和加房。

```typescript
const callbacks: WhiteboardCallbacks = new WhiteboardCallbacks();
callbacks.sdkSetupFail = (error: SDKError) => {
  console.error(`Whiteboard setup failed: ${error.message}`);
};
```

### Slide 事件与资源加载

多窗口 Slide 的回调可直接设置在传给 `Whiteboard` 的 `WhiteboardCallbacks` 上：

```typescript
const callbacks = new WhiteboardCallbacks()
  .setOnSlideError((type: SlideErrorType, message: string, slideId: string, slideIndex: number) => {
    console.error(`Slide ${slideId} index ${slideIndex}: ${type}, ${message}`);
  })
  .setOnSlideResourceMaxRetries((url: string, message: string, jsStack?: string) => {
    // 记录资源加载失败，并在业务界面提供重试或降级入口。
    console.error(`Slide resource failed: ${message}`);
  })
  .setSlideOpenUrl((url: string) => {
    // 由宿主决定是否打开该链接。
  })
  .setSlideUrlInterrupter((url: string, complete: (result: string) => void) => {
    // 可以异步查询本地缓存；完成后必须调用 complete。保留原地址时返回 url。
    complete(url);
  });
```

在 SDK 初始化前设置配置：

```typescript
const options: WhiteboardOptions = {
  appIdentifier: 'APP_IDENTIFIER',
  roomUuid: 'ROOM_UUID',
  roomToken: 'ROOM_TOKEN',
  uid: 'CLIENT_UID',
  region: Region.CN_HZ,
  useMultiViews: true,
  enableSlideInterrupterAPI: true,
  slideAppOptions: { resourceMaxRetries: 3, showRenderError: false }
};
// Whiteboard({ options, controller, callbacks })
```

| Harmony 回调 | 语义与参数 |
| --- | --- |
| `onSlideError(type, message, slideId, slideIndex)` | 通用渲染错误；包括 RESOURCE_ERROR、RUNTIME_ERROR、RUNTIME_WARN、CANVAS_CRASH，未知类型映射为 UNKNOWN。slideIndex 保留底层值，-1 表示未提供；不要当作从 1 开始的页面回调。 |
| `onSlideResourceMaxRetries(url, message, jsStack?)` | 指定资源加载失败且重试耗尽；前两个参数对齐 Android，额外保留 iOS NSError 中的 JS 堆栈。它与 onSlideError 是独立通知。 |
| `slideOpenUrl(url)` | 用户点击 Slide 链接，通知宿主处理。 |
| `slideUrlInterrupter(url, complete)` | 异步替换资源 URL，仅在 enableSlideInterrupterAPI=true 时启用；未设置处理器时返回原 URL。每次只采用首次 complete 的结果；处理器抛出异常时返回原 URL。 |
| `onSlidePageStateChanged(appId, page, pageCount)` | 页面状态变化，page 从 1 开始。 |

也可以实现导出的 `SlideListener` 接口，通过 `callbacks.setSlideListener(listener)` 挂载，传入
`undefined` 可移除监听器。接口方法均可选。直接回调和监听器同时设置时，通知事件各分发一次；
URL 拦截优先调用直接设置的 `slideUrlInterrupter`，避免两个处理器竞争异步结果。
`WhiteboardCallbacks.onMessage` 仍可接收原始 `@slide/_error_` 消息。

`slideAppOptions` 支持 `resourceMaxRetries`（默认 3，0 表示不重试）、`showRenderError`、
`debug`、`forceCanvas`、`bgColor`、`invisibleBehavior`，以及既有的缩放、帧率和导航配置。
隐藏行为可使用导出的 `SlideInvisibleBehavior.Frozen` / `Pause`。未传字段继续使用内嵌
Bridge / app-slide 的默认值；显式 false 和 0 会原样传递。资源重试次数不使用背景图的 -1 无限重试约定。

### **更改读写模式**

```
setWritable(writable: boolean): Promise<boolean>
```

### **获取房间状态相关数据**

- `getRoomState(): Promise<RoomState>`
- `getRoomPhase(): Promise<RoomPhase>`
- `getRoomMembers(): Promise<RoomMember[]>`
- `getMemberState(): Promise<MemberState>`
- `getGlobalState(): Promise<GlobalState>`
- `getBroadcastState(): Promise<BroadcastState>`

### **设置教具**

`setAppliance(appliance: Appliance, shapeType?: ShapeType)`

参数说明

| 参数名         | 类型          | 是否必填 | 描述            |
|-------------|-------------|------|---------------|
| `appliance` | `Appliance` | 是    | 教具名称，用于设置工具类型 |
| `shapeType` | `ShapeType` | 否    | 形状类型，仅对某些教具有效 |

#### 返回值

`void`：无返回值。

#### 示例

```typescript
// 设置为画笔工具
setAppliance(Appliance.PENCIL);

// 设置为特定形状工具
setAppliance(Appliance.SHAPE, ShapeType.RHOMBUS);
```

---

这种方式包括方法签名、参数表格、返回值说明以及代码示例，适合技术文档的风格，清晰易读。

### 视角

#### 切换视角模式

```
setViewMode(viewMode: ViewMode): void
```

> 通常情况下，教师端设置 ViewMode.Broadcaster ，学生端无需无需设置。同时在学生端设置
> WhiteboardController.disableCameraTransform(true) 限制视角操作，能达到学生随时跟随老师的视角

## 多窗口 API

`WhiteboardOptions.windowParams` 主要配置多窗口本地显示参数；其中 `originSize` 在实时房间可写端会重置并同步 MainView camera-size contract。`WindowParams.useBoxesStatus` 用于开启每个窗口独立的状态管理；开启后窗口最大化、最小化状态会按窗口分别同步，同一房间内多端建议保持一致。

```typescript
const windowParams = new WindowParams()
  .setUseBoxesStatus(true)
  .setOriginSize({ width: 1280, height: 900 })
  .setPageScaleRange({ minScale: 0.5, maxScale: 4 });
```

`originSize` 是 MainView 的归一化参考尺寸；可写端首次设置或传入不同尺寸时，WindowManager 会重置并同步 MainView 的 origin/active camera-size contract。它不会隐式改写 Slide/Presentation App 参数。`pageScaleRange` 是可选的相对适配尺寸倍率范围，未配置的边界不施加业务限制。

### App

```typescript
const appParam: WindowAppParam = {
  kind: 'Slide',
  options: { title: 'Projector App' },
  attributes: { taskId, url },
  // Slide / Presentation 的参考尺寸写入 attributes.originSize。
  originSize: { width: 1280, height: 900 },
};

try {
  const appId = await controller.addApp(appParam);
} catch (error) {
  // Web App setup 失败，未完成初始化的窗口已被清理。
}
```

`addApp` 会等待 Web App 的 `setup()` 完成，失败时 reject 并清理未完成初始化的窗口；公开方法名和调用签名保持兼容。`WindowParams.originSize` 只作用于 MainView，不会隐式传给 Slide / Presentation。

配置 MainView `originSize` 后，可调用 `fitOriginSizeAndCamera()` 恢复参考尺寸和初始相机状态。

1. `addApp`
2. `fitOriginSizeAndCamera`
3. `closeApp`
4. `focusApp`
5. `queryApp`
6. `queryAllApps`
7. `dispatchDocsEvent`

`dispatchDocsEvent` 统一控制 MainView、DocsViewer、Slide 和 Presentation，返回结构化的命令接收结果：

```typescript
const result: DispatchDocsEventResult = await whiteboardController.dispatchDocsEvent({
  event: 'scalePage',
  options: { target: 'mainView', scale: 1.5 },
});

if (!result.accepted) {
  console.error(`${result.reason}: ${result.message}`);
}
```

`target` 可为 `mainView` 或具体 appId，省略时跟随当前焦点且无焦点时回退 MainView；`page` 为 1-based。`scale` 是相对于适配尺寸的倍率，`1` 表示适配尺寸，不是底层 camera scale。DocsViewer 不支持 `scalePage`，会返回 `eventNotSupported` 和明确原因。

可通过 `getPageState({ target })` 查询当前状态，并通过统一回调观察实际页码、相对倍率或异步命令失败：

```typescript
callbacks.setOnUnifiedPageStateChange((state: UnifiedPageStateChange) => {
  console.info(`${state.target}: ${state.status}, ${state.changeType}`);
});

const state: UnifiedPageState = await whiteboardController.getPageState({ target: 'mainView' });
```

### Page

1. `addPage`
2. `removePage`
3. `prevPage`
4. `nextPage`

### 其他

- `insertText`
- `updateText`
- `setSyncMode`

更多参考官方文档

## 如何贡献

如果您在使用过程中发现任何问题，可以向我们提交 issue 或 PR。

## 许可

该仓库使用 [MIT](./LICENSE) 许可协议。
