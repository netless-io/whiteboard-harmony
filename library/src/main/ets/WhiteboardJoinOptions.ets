import { RoomOptions, WhiteboardOptions } from './WhiteboardOptions';

export function buildRoomOptions(options: WhiteboardOptions): RoomOptions {
  return {
    uuid: options.roomUuid,
    roomToken: options.roomToken,
    region: options.region,
    uid: options.uid,
    userPayload: options.userPayload,
    isWritable: options.writable ?? true,
    disableCameraTransform: options.disableCameraTransform,
    disableDeviceInputs: options.disableDeviceInputs,
    disableOperations: options.disableOperations,
    floatBar: options.floatBar,
    timeout: options.timeout,
    windowParams: options.windowParams,
  };
}
