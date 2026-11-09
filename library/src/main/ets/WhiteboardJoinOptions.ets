import { RoomOptions, WhiteboardRoomOptions, WhiteboardSdkOptions, SdkOptions, SlideAppOptions } from './WhiteboardOptions';

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

/** Optional host values stay absent, except the shared Native defaults applied below. */
export function buildSdkOptions(options: WhiteboardSdkOptions): SdkOptions {
  const slideAppOptions: SlideAppOptions = options.slideAppOptions
    ? JSON.parse(JSON.stringify(options.slideAppOptions)) as SlideAppOptions : {};
  slideAppOptions.showRenderError = options.slideAppOptions?.showRenderError ?? false;
  return {
    appIdentifier: options.appIdentifier,
    apiHosts: options.apiHosts === undefined ? undefined : [...options.apiHosts],
    enableModelPreload: options.enableModelPreload,
    preloadBuiltinApps: options.preloadBuiltinApps === undefined ? undefined : [...options.preloadBuiltinApps],
    region: options.region,
    dynamicConfig: options.dynamicConfig,
    log: true,
    useMultiViews: options.useMultiViews,
    userCursor: options.userCursor,
    disableNewPencilStroke: false,
    enableAppliancePlugin: options.enableAppliancePlugin,
    enablePreLoadAppliancePlugin: options.enablePreLoadAppliancePlugin,
    appliancePluginOptions: options.appliancePluginOptions,
    presentationAppOptions: options.presentationAppOptions,
    slideAppOptions: slideAppOptions,
    enableSlideInterrupterAPI: options.enableSlideInterrupterAPI,
    loggerOptions: options.localLogOptions ? { localLog: options.localLogOptions } : undefined,
    backgroundImageLoadOptions: options.backgroundImageLoadOptions,
  };
}
