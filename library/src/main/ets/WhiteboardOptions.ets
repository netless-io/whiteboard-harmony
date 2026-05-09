import { Region, WindowParams } from './Types';
import { WhiteboardCallbacks } from './WhiteboardCallbacks';

/**
 * Whiteboard 统一的配置项目
 */
export interface WhiteboardOptions {
  appIdentifier: string;
  userCursor?: boolean;
  userPayload?: object;
  useMultiViews?: boolean;
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
