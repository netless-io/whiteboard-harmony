import { PresentationAppOptions, Region, WindowParams } from './Types';
import { BackgroundImageSource, WhiteboardCallbacks } from './WhiteboardCallbacks';

export type SlideSyncEventQueuePolicy = 'fifo' | 'latest-pending-render';

export interface SlideAppOptions {
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
  workerRenderModeBlacklist?: WorkerBlacklistByRuntime;
  workerCanvasContextBlacklist?: WorkerBlacklistByRuntime;
}

export interface AppliancePluginOptions {
  extras?: AppliancePluginExtrasOptions;
}

/**
 * Whiteboard 统一的配置项目
 */
export interface WhiteboardOptions {
  appIdentifier: string;
  userCursor?: boolean;
  userPayload?: object;
  useMultiViews?: boolean;
  enableAppliancePlugin?: boolean;
  appliancePluginOptions?: AppliancePluginOptions;
  /** Window Manager 内置 Presentation 的本地配置 */
  presentationAppOptions?: PresentationAppOptions;
  slideAppOptions?: SlideAppOptions;
  localLogOptions?: LocalLogOptions;
  windowParams?: WindowParams;
  roomUuid: string;
  roomToken: string;
  uid: string;
  region: Region;
  writable?: boolean;
  disableCameraTransform?: boolean;
  disableDeviceInputs?: boolean;
  disableOperations?: boolean;
  floatBar?: boolean;
  timeout?: number;
  /** 撤销/重做最多保留的场景缓存数量 */
  undoCacheScenesCount?: number;
  callbacks?: WhiteboardCallbacks;
  backgroundImageLoadOptions?: BackgroundImageLoadOptions;
}

export interface SdkOptions {
  appIdentifier: string;
  log: boolean;
  useMultiViews: boolean;
  userCursor: boolean;
  disableNewPencilStroke: boolean;
  enableAppliancePlugin: boolean;
  presentationAppOptions?: PresentationAppOptions;
  slideAppOptions?: SlideAppOptions;
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
