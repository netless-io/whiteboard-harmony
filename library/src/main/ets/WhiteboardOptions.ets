import { PresentationAppOptions, Region, WindowParams, SlideInvisibleBehavior } from './Types';
import { BackgroundImageSource, WhiteboardCallbacks } from './WhiteboardCallbacks';

/** Region -> public OSS latest.json URL for Harmony; missing regions/download failures keep local defaults. */
export type DynamicConfigOptions = Record<string, string>;

export type SlideSyncEventQueuePolicy = 'fifo' | 'latest-pending-render';
export type SlideNavigationButtonMode = 'page' | 'step';

export interface SlideAppOptions {
  /** 是否开启 Slide 课件媒体音量共享，默认 false。 */
  enableSharedMediaVolume?: boolean;
  /** 显示 Slide 渲染错误提示。默认 false，与 Android / iOS 一致。 */
  showRenderError?: boolean;
  /** 显示 Slide 调试控制面板，默认 false。 */
  debug?: boolean;
  /** 最大资源重试次数，默认 3；0 表示不重试。 */
  resourceMaxRetries?: number;
  /** 强制 Canvas 2D 渲染，默认 false。 */
  forceCanvas?: boolean;
  /** 动画背景色，例如 #ffffff。 */
  bgColor?: string;
  /** 隐藏后的行为，默认 frozen。 */
  invisibleBehavior?: SlideInvisibleBehavior;
  /** 是否允许缩放 Slide 内容，默认 false */
  enableScale?: boolean;
  /** 渲染分辨倍率，未设置时由内嵌 Bridge 根据 WebView UA 决定 */
  resolution?: number;
  /** 取值范围 0~4，未设置时由内嵌 Bridge 根据 WebView UA 决定 */
  maxResolutionLevel?: number;
  /** 最小 fps，未设置时由内嵌 Bridge 根据 WebView UA 决定 */
  minFPS?: number;
  /** 最大 fps，未设置时由内嵌 Bridge 根据 WebView UA 决定 */
  maxFPS?: number;
  /** 是否开启全局点击功能，默认 true */
  enableGlobalClick?: boolean;
  /** Slide 同步事件队列策略；未设置时由 Slide 使用 fifo */
  syncEventQueuePolicy?: SlideSyncEventQueuePolicy;
  /** 底部前后导航按钮按页或按动画步骤切换；未设置时按页切换。 */
  navigationButtonMode?: SlideNavigationButtonMode;
}

export interface LocalLogOptions {
  /** 是否开启 WebView 内本地日志。未设置时不启用，需要显式设置为 true。 */
  enabled?: boolean;
  /** 是否触发本地日志上传。该开关仅在 enabled 为 true 时生效，不影响本地日志写入。 */
  enabledUpload?: boolean;
}

export interface LoggerOptions {
  localLog?: LocalLogOptions;
}

export interface BackgroundImageLoadOptions {
  /** 背景图片加载重试次数。-1 表示无限重试（内部映射为 Infinity），取值范围为 -1 或 0~10。 */
  maxRetries?: number;
  /** 背景图片加载超时时间，单位为毫秒，取值范围 1000~120000。 */
  timeoutMs?: number;
  /** 背景图片加载失败后的重试间隔，单位为毫秒，取值范围 0~30000。 */
  retryIntervalMs?: number;
}

export interface ReloadBackgroundImageParams {
  source: BackgroundImageSource;
  viewId: string;
  scenePath?: string;
  url?: string;
}

export interface ReloadBackgroundImageResult {
  accepted: boolean;
  reloadedCount: number;
  reason?: 'viewNotFound' | 'sceneNotFocused' | 'resourceNotFound' | 'alreadyLoading';
}

export interface HasBackgroundImageParams {
  viewId: string;
  scenePath: string;
  imageUrl: string;
  sources: BackgroundImageSource[];
}

export interface ApplianceCursorOptions {
  enable: boolean;
  expirationTime: number;
  syncedLabel?: ApplianceCursorSyncedLabelOptions;
  appearance?: ApplianceCursorAppearanceMap;
}

export interface ApplianceCursorSyncedLabelOptions {
  enableShowName: boolean;
}

export interface ApplianceCursorAppearanceOptions {
  synced?: ApplianceCursorSyncedAppearanceOptions;
}

export interface ApplianceCursorAppearanceMap {
  pencil?: ApplianceCursorAppearanceOptions;
  clicker?: ApplianceCursorAppearanceOptions;
}

export interface ApplianceCursorSyncedAppearanceOptions {
  enableShowName?: boolean;
  images?: ApplianceCursorImagesOptions;
}

export interface ApplianceCursorImagesOptions {
  standardResolution: string;
}

export interface ApplianceSyncOptions {
  interval: number;
  smoothSync: boolean;
}

export interface ApplianceBezierOptions {
  enable: boolean;
  maxDrawCount: number;
}

export interface ApplianceTextEditorOptions {
  showFloatBar: boolean;
  canSelectorSwitch: boolean;
  rightBoundBreak: boolean;
}

export type VersionWorkerBlacklist = Record<string, number>;

export interface WorkerBlacklistByRuntime {
  androidWebView?: VersionWorkerBlacklist;
  iosWebView?: VersionWorkerBlacklist;
  harmonyArkWeb?: VersionWorkerBlacklist;
  web?: Record<string, VersionWorkerBlacklist>;
}

export interface ApplianceCanvasOptions {
  /** 画布上下文类型，例如 "2d" */
  contextType?: string;
}

export interface AppliancePluginExtrasOptions {
  /** 是否使用 worker，默认 "auto" */
  useWorker?: 'auto' | 'mainThread';
  /** 是否使用简单模式，默认 true */
  useSimple?: boolean;
  /** 是否使用背景 Svg 功能，默认 false */
  useBackgroundThread?: boolean;
  /** 画布配置项 */
  canvasOpt?: ApplianceCanvasOptions;
  cursor?: ApplianceCursorOptions;
  syncOpt?: ApplianceSyncOptions;
  bezier?: ApplianceBezierOptions;
  textEditor?: ApplianceTextEditorOptions;
  /** Allow the ImageBitmap readback fallback used by the Android demo entry. */
  allowImageBitmapFallback?: boolean;
  workerRenderModeBlacklist?: WorkerBlacklistByRuntime;
  workerCanvasContextBlacklist?: WorkerBlacklistByRuntime;
}

export interface AppliancePluginOptions {
  extras?: AppliancePluginExtrasOptions;
}

/**
 * Whiteboard 统一的配置项目
 */
/** Candidate-room configuration contains no room credentials. Keep the actual Web node mounted. */
export type BuiltinAppPreloadKind = 'Slide' | 'Presentation' | 'MediaPlayer' | 'DocsViewer';

export interface WhiteboardSdkOptions {
  appIdentifier: string;
  /** 自定义 API hosts；省略时保留 Web SDK 的默认环境。 */
  apiHosts?: string[];
  /** 提前查询并下载房间模型，默认 false；仅对已完成服务端准备的项目和区域显式开启。 */
  enableModelPreload?: boolean;
  /** SDK 构造时后台准备 App 类。省略默认 Slide / Presentation；[] 关闭。
   * 不创建实例或加载课件内容，独立于 enableModelPreload。
   */
  preloadBuiltinApps?: BuiltinAppPreloadKind[];
  /** Region used during candidate-room preparation; a Room may override it. */
  region?: Region;
  dynamicConfig?: DynamicConfigOptions;
  userCursor?: boolean;
  useMultiViews?: boolean;
  /** SDK 初始化时启用教具渲染准备，独立于 enableModelPreload，无需传 appliancePluginOptions。
   * 未被配置覆盖时 useWorker 默认 "auto"，按能力、缓存和页面可见性决定是否执行探针。
   */
  enableAppliancePlugin?: boolean;
  /** 可选的 SDK 级教具配置；省略时使用插件默认值和动态配置，Room 可按字段覆盖。 */
  appliancePluginOptions?: AppliancePluginOptions;
  presentationAppOptions?: PresentationAppOptions;
  slideAppOptions?: SlideAppOptions;
  /** 开启 Slide 资源 URL 异步拦截，默认 false。 */
  enableSlideInterrupterAPI?: boolean;
  localLogOptions?: LocalLogOptions;
  backgroundImageLoadOptions?: BackgroundImageLoadOptions;
}
export interface WhiteboardRoomOptions {
  roomUuid: string;
  roomToken: string;
  uid: string;
  region: Region;
  userPayload?: object;
  writable?: boolean;
  disableCameraTransform?: boolean;
  disableDeviceInputs?: boolean;
  disableOperations?: boolean;
  floatBar?: boolean;
  timeout?: number;
  undoCacheScenesCount?: number;
  windowParams?: WindowParams;
  appliancePluginOptions?: AppliancePluginOptions;
}
/** Existing automatic-join integrations stay source compatible. */
export interface WhiteboardOptions extends WhiteboardSdkOptions, WhiteboardRoomOptions {
  region: Region;
  callbacks?: WhiteboardCallbacks;
}
export interface PreparationInfo {
  ready: boolean;
  viewId: string;
  documentId: string;
  setupCount: number;
  elapsedMs: number;
  generation: number;
  roomState: string;
}

export interface SdkOptions {
  dynamicConfig?: DynamicConfigOptions;
  enableModelPreload?: boolean;
  preloadBuiltinApps?: BuiltinAppPreloadKind[];
  appIdentifier: string;
  apiHosts?: string[];
  region?: Region;
  log: boolean;
  useMultiViews?: boolean;
  userCursor?: boolean;
  disableNewPencilStroke: boolean;
  enableAppliancePlugin?: boolean;
  appliancePluginOptions?: AppliancePluginOptions;
  presentationAppOptions?: PresentationAppOptions;
  slideAppOptions?: SlideAppOptions;
  enableSlideInterrupterAPI?: boolean;
  loggerOptions?: LoggerOptions;
  backgroundImageLoadOptions?: BackgroundImageLoadOptions;
}

export interface RoomOptions {
  uuid: string;
  roomToken: string;
  uid: string;
  region: Region;
  userPayload?: object;
  isWritable?: boolean;
  disableDeviceInputs?: boolean;
  disableOperations?: boolean;
  floatBar?: boolean;
  disableCameraTransform?: boolean;
  timeout?: number;
  undoCacheScenesCount?: number;
  windowParams?: WindowParams;
  appliancePluginOptions?: AppliancePluginOptions;
}
