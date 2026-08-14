import { PresentationAppOptions, Region, WindowParams } from './Types';
import { WhiteboardCallbacks } from './WhiteboardCallbacks';

export interface SlideAppOptions {
  /** 是否允许缩放 Slide 内容，默认 false */
  enableScale?: boolean;
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

export interface AppliancePluginExtrasOptions {
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
