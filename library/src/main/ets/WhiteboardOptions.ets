import { WhiteboardCallbacks } from "./WhiteboardCallbacks";

export interface WhiteboardOptions {
  appIdentifier: string;
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
}

export interface RoomOptions {
  uuid: string;
  roomToken: string;
  region: string;
  uid: string;
  writable?: boolean;
}