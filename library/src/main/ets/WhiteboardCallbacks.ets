import { RoomPhase, RoomState } from './Types';

export class WhiteboardCallbacks {
  throwError?: (args: object) => void;
  onMessage?: (args: object) => void;
  onLogger?: (args: object) => void;
  onRoomPhaseChanged?: (roomPhase: RoomPhase) => void;
  onRoomStateChanged?: (roomState: RoomState) => void;

  setThrowError(callback: (args: object) => void): WhiteboardCallbacks {
    this.throwError = callback;
    return this;
  }

  setOnLogger(callback: (args: object) => void): WhiteboardCallbacks {
    this.onLogger = callback;
    return this;
  }

  setOnRoomPhaseChanged(callback: (roomPhase: RoomPhase) => void): WhiteboardCallbacks {
    this.onRoomPhaseChanged = callback;
    return this;
  }

  setOnRoomStateChanged(callback: (roomState: RoomState) => void): WhiteboardCallbacks {
    this.onRoomStateChanged = callback;
    return this;
  }
}