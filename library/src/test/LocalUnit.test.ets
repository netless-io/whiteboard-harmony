import { describe, it, expect } from '@ohos/hypium';
import { WhiteboardController } from '../main/ets/WhiteboardController';
import { DsBridge } from '../main/ets/DsBridge';
import { RoomJsInterface, SdkJsInterface } from '../main/ets/JsInterfaces';
import { SDKError } from '../main/ets/SDKError';
import { BackgroundImageSource, WhiteboardCallbacks } from '../main/ets/WhiteboardCallbacks';
import { buildRoomOptions } from '../main/ets/WhiteboardJoinOptions';
import {
  EventEntry,
  Region,
  RoomDisconnectError,
  RoomMember,
  RoomPhase,
  RoomState,
  Scene,
  SceneState,
  SlideErrorType,
  SlideListener,
  ViewMode,
  WindowDocsEvent,
  DispatchDocsEventResult,
  UnifiedPageStateChange,
  WindowParams,
  WindowPrefersColorScheme,
} from '../main/ets/Types';
import { HasBackgroundImageParams, RoomOptions, WhiteboardOptions } from '../main/ets/WhiteboardOptions';

class BridgeCallRecord {
  method: string
  args: Object[] | null
  handler?: Callback<object>

  constructor(method: string, args: Object[] | null, handler?: Callback<object>) {
    this.method = method;
    this.args = args;
    this.handler = handler;
  }
}

interface TestUserPayload {
  role: string
}

interface WritableResultPayload {
  isWritable: boolean
  observerId: string
}

interface ErrorPayload {
  message: string
  jsStack: string
}

interface ErrorWrapperPayload {
  __error: ErrorPayload
}

interface MemberStatePayload {
  currentApplianceName: string
  textSize: number
}

interface GlobalStatePayload {
  value: string
}

interface BroadcastStatePayload {
  mode: ViewMode
  broadcasterId: number
}

interface RoomStatePayload {
  globalState?: GlobalStatePayload
}

interface SceneMapPayload {
  key: string
  scenes: Scene[]
}

interface MagixPayload {
  eventName: string
  payload: object
}

interface HighFrequencyPayload extends EventEntry {
}

interface SlidePageStatePayload {
  appId: string
  page: number
  pageCount: number
}

interface LocalLogStatePayload {
  enabled: boolean
  enabledUpload: boolean
}

interface UploadLocalLogsPayload {
  status: string
  reason: string
}

interface SetupFailPayload {
  message: string
  jsStack: string
}

class TestSlideListener implements SlideListener {
  onSlidePageStateChanged?: (appId: string, page: number, pageCount: number) => void

  slideUrlInterrupter(url: string, complete: (result: string) => void): void {
    complete(url);
  }

  onSlideError(type: SlideErrorType, errorMsg: string, slideId: string, slideIndex: number): void {
  }
}

class FakeBridge {
  calls: BridgeCallRecord[] = [];

  callHandler(method: string, args: Object[] | null, handler?: Callback<object>): void {
    this.calls.push(new BridgeCallRecord(method, args, handler));
  }

  lastCall(): BridgeCallRecord {
    return this.calls[this.calls.length - 1];
  }

  respond(result: object | string | boolean | undefined): void {
    const call = this.lastCall();
    if (call.handler) {
      call.handler(result as object);
    }
  }
}

function toJsonString(value: object): string {
  return JSON.stringify(value);
}

class EmptyPayload {
}

function createWindowParams(): WindowParams {
  return new WindowParams()
    .setFullscreen(true)
    .setUseBoxesStatus(true)
    .setOriginSize({ width: 1280, height: 900 })
    .setPageScaleRange({ minScale: 0.5, maxScale: 4 })
    .setBuiltinAppOptions({
      presentation: {
        useScrollbar: true,
        debounceSync: false,
        maxCameraScale: 4,
      },
    });
}

function createWhiteboardOptions(): WhiteboardOptions {
  const payload: TestUserPayload = { role: 'teacher' };
  return {
    appIdentifier: 'app-id',
    roomUuid: 'room-uuid',
    roomToken: 'room-token',
    uid: 'uid-1',
    region: Region.CN_HZ,
    writable: false,
    disableCameraTransform: true,
    disableDeviceInputs: true,
    disableOperations: true,
    floatBar: true,
    timeout: 9000,
    undoCacheScenesCount: 32,
    presentationAppOptions: {
      useScrollbar: true,
      debounceSync: false,
    },
    slideAppOptions: {
      enableScale: true,
      syncEventQueuePolicy: 'latest-pending-render',
    },
    localLogOptions: {
      enabled: true,
      enabledUpload: false,
    },
    userPayload: payload,
    windowParams: createWindowParams(),
  };
}

function createWritableResult(): WritableResultPayload {
  return { isWritable: true, observerId: '1' };
}

function createErrorWrapper(): ErrorWrapperPayload {
  return {
    __error: {
      message: 'boom',
      jsStack: 'stack',
    },
  };
}

function createMemberStatePayload(): MemberStatePayload {
  return {
    currentApplianceName: 'text',
    textSize: 24,
  };
}

function createGlobalStatePayload(): GlobalStatePayload {
  return {
    value: 'math',
  };
}

function createBroadcastStatePayload(): BroadcastStatePayload {
  return {
    mode: ViewMode.Broadcaster,
    broadcasterId: 7,
  };
}

function createRoomStatePayload(value: string): RoomStatePayload {
  return {
    globalState: {
      value: value,
    },
  };
}

function createRoomMembersPayload(): RoomMember[] {
  return [
    { memberId: 101 },
    { memberId: 102 },
  ];
}

function createSceneStatePayload(): SceneState {
  return {
    scenePath: '/test/scene-1',
    index: 0,
  };
}

function createSceneList(): Scene[] {
  return [{ name: 'scene-1' }];
}

function createSceneMapPayload(): SceneMapPayload[] {
  return [{
    key: '/test',
    scenes: createSceneList(),
  }];
}

function createMagixPayload(): MagixPayload {
  const payload: EmptyPayload = new EmptyPayload();
  return {
    eventName: 'ping',
    payload: payload,
  };
}

function createHighFrequencyPayload(): HighFrequencyPayload[] {
  const payload: EmptyPayload = new EmptyPayload();
  return [{
    eventName: 'move',
    payload: payload,
    scope: 'room',
    authorId: 'u1',
  }];
}

function createDocsEvent(): WindowDocsEvent {
  return {
    event: 'scalePage',
    options: { target: 'DocsViewer-1', scale: 2 },
  };
}

function encodeSceneMapPayload(items: SceneMapPayload[]): string {
  const result: Record<string, Scene[]> = {};
  items.forEach((item: SceneMapPayload) => {
    result[item.key] = item.scenes;
  });
  return JSON.stringify(result);
}

export default function localUnitTest() {
  describe('whiteboard_harmony_unit_tests', () => {
    it('buildRoomOptions_maps_joinRoom_parameters', 0, () => {
      const roomOptions: RoomOptions = buildRoomOptions(createWhiteboardOptions());

      expect(roomOptions.uuid).assertEqual('room-uuid');
      expect(roomOptions.roomToken).assertEqual('room-token');
      expect(roomOptions.uid).assertEqual('uid-1');
      expect(roomOptions.isWritable).assertFalse();
      expect(roomOptions.disableCameraTransform).assertTrue();
      expect(roomOptions.disableDeviceInputs).assertTrue();
      expect(roomOptions.disableOperations).assertTrue();
      expect(roomOptions.floatBar).assertTrue();
      expect(roomOptions.timeout).assertEqual(9000);
      expect(roomOptions.undoCacheScenesCount).assertEqual(32);
      expect(JSON.stringify(roomOptions.userPayload)).assertEqual(JSON.stringify({ role: 'teacher' }));
      expect(roomOptions.windowParams?.fullscreen).assertTrue();
      expect(roomOptions.windowParams?.useBoxesStatus).assertTrue();
      expect(roomOptions.windowParams?.builtinAppOptions?.presentation?.useScrollbar).assertTrue();
      expect(roomOptions.windowParams?.builtinAppOptions?.presentation?.debounceSync).assertFalse();
      expect(roomOptions.windowParams?.builtinAppOptions?.presentation?.maxCameraScale).assertEqual(4);
      const sdkOptions = createWhiteboardOptions().presentationAppOptions;
      expect(sdkOptions?.useScrollbar).assertTrue();
      expect(sdkOptions?.debounceSync).assertFalse();
      expect(createWhiteboardOptions().slideAppOptions?.enableScale).assertTrue();
      expect(createWhiteboardOptions().slideAppOptions?.syncEventQueuePolicy).assertEqual('latest-pending-render');
      expect(createWhiteboardOptions().localLogOptions?.enabled).assertTrue();
      expect(createWhiteboardOptions().localLogOptions?.enabledUpload).assertFalse();
    });

    it('setWritable_resolves_and_updates_local_writable_state', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);

      const promise: Promise<boolean> = controller.setWritable(true);
      bridge.respond(toJsonString(createWritableResult()));
      const writable: boolean = await promise;
      expect(writable).assertTrue();
      expect(controller.getWritable()).assertTrue();
      done();
    });

    it('setWritable_rejects_on_bridge_error_payload', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);

      const promise: Promise<boolean> = controller.setWritable(false);
      bridge.respond(toJsonString(createErrorWrapper()));

      let errorMessage: string = '';
      try {
        await promise;
      } catch (error) {
        const sdkError: Error = error as Error;
        errorMessage = sdkError.message;
      }
      expect(errorMessage).assertContain('boom');
      done();
    });

    it('disconnect_resolves_when_bridge_returns_no_payload', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);

      const promise: Promise<object> = controller.disconnect();
      bridge.respond(undefined);
      await promise;

      expect(bridge.lastCall().method).assertEqual('room.disconnect');
      done();
    });

    it('detachWhiteboard_does_not_detach_a_newer_bridge', 0, async (done: Function) => {
      const oldBridge: FakeBridge = new FakeBridge();
      const newBridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(oldBridge as object as DsBridge);
      controller.attachWhiteboard(newBridge as object as DsBridge);

      controller.detachWhiteboard(oldBridge as object as DsBridge);
      const promise: Promise<boolean> = controller.setWritable(true);
      newBridge.respond(toJsonString(createWritableResult()));
      await promise;

      expect(newBridge.lastCall().method).assertEqual('room.setWritable');
      done();
    });

    it('controller_forwards_text_and_docs_methods_to_bridge', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);

      controller.updateText('text-1', 'hello');
      expect(bridge.lastCall().method).assertEqual('room.updateText');

      controller.setSyncMode(true);
      expect(bridge.lastCall().method).assertEqual('room.syncMode');

      controller.setPrefersColorScheme(WindowPrefersColorScheme.Dark);
      expect(bridge.lastCall().method).assertEqual('room.setPrefersColorScheme');

      const docsResultPromise: Promise<DispatchDocsEventResult> = controller.dispatchDocsEvent(createDocsEvent());
      expect(bridge.lastCall().method).assertEqual('room.dispatchDocsEvent');
      expect(JSON.stringify(bridge.lastCall().args)).assertEqual(JSON.stringify([
        'scalePage',
        { target: 'DocsViewer-1', scale: 2 },
      ]));
      bridge.respond(toJsonString({
        accepted: false,
        reason: 'eventNotSupported',
        message: 'DocsViewer does not support scalePage',
      }));
      const docsResult: DispatchDocsEventResult = await docsResultPromise;
      expect(docsResult.accepted).assertFalse();
      if (!docsResult.accepted) {
        expect(docsResult.reason).assertEqual('eventNotSupported');
        expect(docsResult.message).assertEqual('DocsViewer does not support scalePage');
      }

      controller.insertText(10, 12, 'abc');
      expect(bridge.lastCall().method).assertEqual('room.insertText');
      done();
    });

    it('getPageState_forwards_target_and_parses_state', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);

      const statePromise = controller.getPageState({ target: 'Presentation-1' });
      expect(bridge.lastCall().method).assertEqual('room.getPageState');
      expect(JSON.stringify(bridge.lastCall().args)).assertEqual(JSON.stringify([
        { target: 'Presentation-1' },
      ]));
      bridge.respond(toJsonString({
        target: 'Presentation',
        appId: 'Presentation-1',
        page: 2,
        pageCount: 6,
        scale: 1.5,
      }));

      const state = await statePromise;
      expect(state.target).assertEqual('Presentation');
      expect(state.appId).assertEqual('Presentation-1');
      expect(state.scale).assertEqual(1.5);
      done();
    });

    it('local_log_methods_forward_to_sdk_bridge', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);

      const statePromise: Promise<object> = controller.getLocalLogState();
      expect(bridge.lastCall().method).assertEqual('sdk.getLocalLogState');
      const statePayload: LocalLogStatePayload = { enabled: true, enabledUpload: false };
      bridge.respond(toJsonString(statePayload));
      const state: object = await statePromise;
      expect(JSON.stringify(state)).assertEqual(JSON.stringify({ enabled: true, enabledUpload: false }));

      const uploadPromise: Promise<object> = controller.uploadLocalLogs();
      expect(bridge.lastCall().method).assertEqual('sdk.uploadLocalLogs');
      const uploadPayload: UploadLocalLogsPayload = { status: 'skipped', reason: 'uploadDisabled' };
      bridge.respond(toJsonString(uploadPayload));
      const uploadResult: object = await uploadPromise;
      expect(JSON.stringify(uploadResult)).assertEqual(JSON.stringify({ status: 'skipped', reason: 'uploadDisabled' }));

      done();
    });

    it('hasBackgroundImage_forwards_query_and_parses_boolean', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);
      const params: HasBackgroundImageParams = {
        viewId: 'mainView',
        scenePath: '/scene-1',
        imageUrl: 'https://example.com/background.webp?token=value#fragment',
        sources: ['appliance' as BackgroundImageSource],
      };

      const promise: Promise<boolean> = controller.hasBackgroundImage(params);
      expect(bridge.lastCall().method).assertEqual('sdk.hasBackgroundImage');
      expect(JSON.stringify(bridge.lastCall().args?.[0])).assertEqual(JSON.stringify(params));
      bridge.respond(true);
      expect(await promise).assertTrue();
      done();
    });

    it('hasBackgroundImage_rejects_bridge_error', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);
      const promise: Promise<boolean> = controller.hasBackgroundImage({
        viewId: 'mainView',
        scenePath: '/scene-1',
        imageUrl: 'https://example.com/background.webp',
        sources: ['appliance' as BackgroundImageSource],
      });
      bridge.respond(toJsonString(createErrorWrapper()));
      let message: string = '';
      try {
        await promise;
      } catch (error) {
        message = (error as Error).message;
      }
      expect(message).assertContain('boom');
      done();
    });

    it('controller_get_methods_parse_json_payload', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);

      const memberPromise: Promise<object> = controller.getMemberState();
      bridge.respond(toJsonString(createMemberStatePayload()));
      const memberState: object = await memberPromise;
      expect((memberState as MemberStatePayload).textSize).assertEqual(24);

      const globalPromise: Promise<object> = controller.getGlobalState();
      bridge.respond(toJsonString(createGlobalStatePayload()));
      const globalState: object = await globalPromise;
      expect(JSON.stringify(globalState)).assertEqual(JSON.stringify(createGlobalStatePayload()));

      const broadcastPromise: Promise<object> = controller.getBroadcastState();
      bridge.respond(toJsonString(createBroadcastStatePayload()));
      const broadcastState: object = await broadcastPromise;
      expect((broadcastState as BroadcastStatePayload).broadcasterId).assertEqual(7);

      const roomStatePromise: Promise<RoomState> = controller.getRoomState();
      bridge.respond(toJsonString(createRoomStatePayload('geometry')));
      const roomState: RoomState = await roomStatePromise;
      expect(JSON.stringify(roomState)).assertEqual(JSON.stringify(createRoomStatePayload('geometry')));

      const roomMembersPromise: Promise<RoomMember[]> = controller.getRoomMembers();
      bridge.respond(toJsonString(createRoomMembersPayload()));
      const roomMembers: RoomMember[] = await roomMembersPromise;
      expect(roomMembers.length).assertEqual(2);

      const sceneStatePromise: Promise<SceneState> = controller.getSceneState();
      bridge.respond(toJsonString(createSceneStatePayload()));
      const sceneState: SceneState = await sceneStatePromise;
      expect(sceneState.scenePath as string).assertEqual('/test/scene-1');

      const entireScenesPromise: Promise<Record<string, Scene[]>> = controller.getEntireScenes();
      bridge.respond(encodeSceneMapPayload(createSceneMapPayload()));
      const entireScenes: Record<string, Scene[]> = await entireScenesPromise;
      expect(entireScenes['/test'].length).assertEqual(1);

      done();
    });

    it('room_controller_action_methods_forward_to_bridge', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);

      const roomPhasePromise: Promise<RoomPhase> = controller.getRoomPhase();
      bridge.respond('connected');
      const roomPhase: RoomPhase = await roomPhasePromise;
      expect(roomPhase).assertEqual('connected');

      controller.copy();
      expect(bridge.lastCall().method).assertEqual('room.sync.copy');

      controller.paste();
      expect(bridge.lastCall().method).assertEqual('room.sync.paste');

      controller.duplicate();
      expect(bridge.lastCall().method).assertEqual('room.sync.duplicate');

      controller.deleteOperation();
      expect(bridge.lastCall().method).assertEqual('room.sync.delete');

      controller.disableSerialization(true);
      expect(bridge.lastCall().method).assertEqual('room.sync.disableSerialization');

      controller.redo();
      expect(bridge.lastCall().method).assertEqual('room.redo');

      controller.undo();
      expect(bridge.lastCall().method).assertEqual('room.undo');

      controller.setViewMode(ViewMode.Follower);
      expect(bridge.lastCall().method).assertEqual('room.setViewMode');

      done();
    });

    it('closeApp_resolves_true_regardless_of_bridge_callback_payload_shape', 0, async (done: Function) => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);

      const promise: Promise<boolean> = controller.closeApp('app-1');
      bridge.respond(undefined);
      const result: boolean = await promise;
      expect(result).assertTrue();
      done();
    });

    it('RoomJsInterface_forwards_room_callbacks', 0, () => {
      let phase: string = '';
      let kicked: string = '';
      let disconnectMessage: string = '';
      let undoSteps: number = 0;
      let redoSteps: number = 0;
      let magixEventName: string = '';
      let highFrequencyCount: number = 0;
      let roomStateValue: string = '';

      const callbacks: WhiteboardCallbacks = new WhiteboardCallbacks()
        .setOnRoomPhaseChanged((value: RoomPhase) => {
          phase = value;
        })
        .setOnKickedWithReason((reason: string) => {
          kicked = reason;
        })
        .setOnDisconnectWithError((error: RoomDisconnectError) => {
          disconnectMessage = error.message;
        })
        .setOnCanUndoStepsChanged((steps: number) => {
          undoSteps = steps;
        })
        .setOnCanRedoStepsChanged((steps: number) => {
          redoSteps = steps;
        })
        .setOnMagixEvent((event: EventEntry) => {
          magixEventName = event.eventName;
        })
        .setOnHighFrequencyEvent((events: EventEntry[]) => {
          highFrequencyCount = events.length;
        })
        .setOnRoomStateChanged((state: RoomState) => {
          roomStateValue = JSON.stringify(state);
        });

      const roomJsInterface: RoomJsInterface = new RoomJsInterface(callbacks);
      roomJsInterface.firePhaseChanged('connected');
      roomJsInterface.fireKickedWithReason('duplicate-login');
      roomJsInterface.fireDisconnectWithError('timeout');
      roomJsInterface.fireCanUndoStepsUpdate(3);
      roomJsInterface.fireCanRedoStepsUpdate(2);
      roomJsInterface.fireMagixEvent(toJsonString(createMagixPayload()));
      roomJsInterface.fireHighFrequencyEvent(toJsonString(createHighFrequencyPayload()));
      roomJsInterface.fireRoomStateChanged(toJsonString(createRoomStatePayload('algebra')));

      expect(phase).assertEqual('connected');
      expect(kicked).assertEqual('duplicate-login');
      expect(disconnectMessage).assertEqual('timeout');
      expect(undoSteps).assertEqual(3);
      expect(redoSteps).assertEqual(2);
      expect(magixEventName).assertEqual('ping');
      expect(highFrequencyCount).assertEqual(1);
      expect(roomStateValue).assertEqual(JSON.stringify(createRoomStatePayload('algebra')));
    });

    it('SdkJsInterface_forwards_white_setup_failure', 0, () => {
      let setupError: SDKError | undefined;
      let loggerCallCount: number = 0;
      const callbacks: WhiteboardCallbacks = new WhiteboardCallbacks();
      callbacks.sdkSetupFail = (error: SDKError) => {
        setupError = error;
      };
      callbacks.onLogger = () => {
        loggerCallCount += 1;
      };

      const sdkJsInterface: SdkJsInterface = new SdkJsInterface(callbacks);
      const setupFailPayload: SetupFailPayload = {
        message: 'invalid app identifier',
        jsStack: 'setup stack',
      };
      sdkJsInterface.setupFail(toJsonString(setupFailPayload));
      sdkJsInterface.setupFail(setupFailPayload);

      expect(setupError?.message).assertEqual('invalid app identifier');
      expect(setupError?.jsStack).assertEqual('setup stack');
      expect(loggerCallCount).assertEqual(0);
    });

    it('SdkJsInterface_forwards_slide_page_state_changed', 0, () => {
      let callbackAppId: string = '';
      let callbackPage: number = 0;
      let callbackPageCount: number = 0;
      const slideListener: TestSlideListener = new TestSlideListener();
      slideListener.onSlidePageStateChanged = (appId: string, page: number, pageCount: number) => {
        callbackAppId = appId;
        callbackPage = page;
        callbackPageCount = pageCount;
      };
      let callbackFromWhiteboard: number = 0;
      const callbacks: WhiteboardCallbacks = new WhiteboardCallbacks()
        .setOnSlidePageStateChanged(() => {
          callbackFromWhiteboard += 1;
        });
      const sdkJsInterface: SdkJsInterface = new SdkJsInterface(callbacks);
      sdkJsInterface.setSlideListener(slideListener);

      const payload: SlidePageStatePayload = {
        appId: 'Slide-app-1',
        page: 2,
        pageCount: 8,
      };
      sdkJsInterface.slidePageStateChanged(toJsonString(payload));

      expect(callbackAppId).assertEqual('Slide-app-1');
      expect(callbackPage).assertEqual(2);
      expect(callbackPageCount).assertEqual(8);
      expect(callbackFromWhiteboard).assertEqual(1);
    });

    it('SdkJsInterface_forwards_unified_page_scale_state', 0, () => {
      let received: UnifiedPageStateChange | undefined = undefined;
      const callbacks: WhiteboardCallbacks = new WhiteboardCallbacks()
        .setOnUnifiedPageStateChange((state: UnifiedPageStateChange) => {
          received = state;
        });
      const sdkJsInterface: SdkJsInterface = new SdkJsInterface(callbacks);
      sdkJsInterface.unifiedPageStateChange(toJsonString({
        target: 'DocsViewer',
        appId: 'DocsViewer-1',
        page: 2,
        pageCount: 3,
        scale: 1.25,
        status: 'success',
        changeType: 'scale',
      }));

      expect(received?.target).assertEqual('DocsViewer');
      expect(received?.scale).assertEqual(1.25);
      if (received?.status === 'success') {
        expect(received.changeType).assertEqual('scale');
      }
    });

    it('SdkJsInterface_ignores_invalid_slide_page_state_payload', 0, () => {
      let callbackCount: number = 0;
      const slideListener: TestSlideListener = new TestSlideListener();
      slideListener.onSlidePageStateChanged = () => {
        callbackCount += 1;
      };
      const sdkJsInterface: SdkJsInterface = new SdkJsInterface();
      sdkJsInterface.setSlideListener(slideListener);

      const payload: SlidePageStatePayload = {
        appId: 'Slide-app-1',
        page: 0,
        pageCount: 8,
      };
      sdkJsInterface.slidePageStateChanged(toJsonString(payload));

      expect(callbackCount).assertEqual(0);
    });
  });
}
