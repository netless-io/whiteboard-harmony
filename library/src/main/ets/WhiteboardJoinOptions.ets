import { RoomOptions, WhiteboardRoomOptions, WhiteboardSdkOptions, SdkOptions } from './WhiteboardOptions';

export function buildRoomOptions(options: WhiteboardRoomOptions): RoomOptions {
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
    undoCacheScenesCount: options.undoCacheScenesCount,
    windowParams: options.windowParams,
    appliancePluginOptions: options.appliancePluginOptions,
  };
}

/** Optional host values stay absent across JSON serialization, retaining their priority. */
export function buildSdkOptions(options: WhiteboardSdkOptions): SdkOptions {
  return {
    appIdentifier: options.appIdentifier,
    enableModelPreload: options.enableModelPreload,
    preloadBuiltinApps: options.preloadBuiltinApps === undefined ? undefined : [...options.preloadBuiltinApps],
    region: options.region,
    dynamicConfig: options.dynamicConfig,
    log: true,
    useMultiViews: options.useMultiViews,
    userCursor: options.userCursor,
    disableNewPencilStroke: false,
    enableAppliancePlugin: options.enableAppliancePlugin,
    appliancePluginOptions: options.appliancePluginOptions,
    presentationAppOptions: options.presentationAppOptions,
    slideAppOptions: options.slideAppOptions,
    enableSlideInterrupterAPI: options.enableSlideInterrupterAPI,
    loggerOptions: options.localLogOptions ? { localLog: options.localLogOptions } : undefined,
    backgroundImageLoadOptions: options.backgroundImageLoadOptions,
  };
}
