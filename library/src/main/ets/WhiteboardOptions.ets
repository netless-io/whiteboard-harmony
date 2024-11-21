import { WindowParams } from './Types';
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
  region: string;
  writable?: boolean;
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
  region: string;
  isWritable?: boolean;
  disableOperations?: boolean;
  floatBar?: boolean;
  disableCameraTransform?: boolean;
  timeout?: number;
  windowParams?: WindowParams;
}