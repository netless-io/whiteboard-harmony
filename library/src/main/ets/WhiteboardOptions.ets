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

/**
 * Whiteboard 统一的配置项目
 */
export interface WhiteboardOptions {
  appIdentifier: string;
  userCursor?: boolean;
  userPayload?: object;
  useMultiViews?: boolean;
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
}
