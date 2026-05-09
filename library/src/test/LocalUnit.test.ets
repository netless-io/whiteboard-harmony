import { describe, it, expect } from '@ohos/hypium';
import { WhiteboardController } from '../main/ets/WhiteboardController';
import { DsBridge } from '../main/ets/DsBridge';
import { RoomJsInterface } from '../main/ets/JsInterfaces';
import { WhiteboardCallbacks } from '../main/ets/WhiteboardCallbacks';
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
  ViewMode,
  WindowDocsEvent,
  WindowParams,
  WindowPrefersColorScheme,
} from '../main/ets/Types';
import { RoomOptions, WhiteboardOptions } from '../main/ets/WhiteboardOptions';

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
  return new WindowParams().setFullscreen(true);
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
    event: 'nextPage',
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
      expect(JSON.stringify(roomOptions.userPayload)).assertEqual(JSON.stringify({ role: 'teacher' }));
      expect(roomOptions.windowParams?.fullscreen).assertTrue();
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

    it('controller_forwards_text_and_docs_methods_to_bridge', 0, () => {
      const bridge: FakeBridge = new FakeBridge();
      const controller: WhiteboardController = new WhiteboardController();
      controller.attachWhiteboard(bridge as object as DsBridge);

      controller.updateText('text-1', 'hello');
      expect(bridge.lastCall().method).assertEqual('room.updateText');

      controller.setSyncMode(true);
      expect(bridge.lastCall().method).assertEqual('room.syncMode');

      controller.setPrefersColorScheme(WindowPrefersColorScheme.Dark);
      expect(bridge.lastCall().method).assertEqual('room.setPrefersColorScheme');

      controller.dispatchDocsEvent(createDocsEvent());
      expect(bridge.lastCall().method).assertEqual('room.dispatchDocsEvent');

      controller.insertText(10, 12, 'abc');
      expect(bridge.lastCall().method).assertEqual('room.insertText');
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
  });
}
