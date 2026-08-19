import { PresentationAppOptions, Region, WindowParams } from './Types';
import { BackgroundImageSource, WhiteboardCallbacks } from './WhiteboardCallbacks';

export interface SlideAppOptions {
  /** 是否允许缩放 Slide 内容，默认 false */
  enableScale?: boolean;
  /** 渲染分辨倍率，默认 1 */
  resolution?: number;
  /** 取值范围 0~4 */
  maxResolutionLevel?: number;
  /** 最小 fps，默认 25 */
  minFPS?: number;
  /** 最大 fps，默认 40 */
  maxFPS?: number;
  /** 是否开启全局点击功能，默认 true */
  enableGlobalClick?: boolean;
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
  maxRetries?: number;
  timeoutMs?: number;
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
  windowParams?: WindowParams;
  appliancePluginOptions?: AppliancePluginOptions;
}
