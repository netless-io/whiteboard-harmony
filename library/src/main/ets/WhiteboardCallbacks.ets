import { RoomPhase, RoomState } from './Types';

export class WhiteboardCallbacks {
  throwError?: (args: object) => void;
  onMessage?: (args: object) => void;
  onLogger?: (args: object) => void;
  onRoomReady?: () => void
  onRoomPhaseChanged?: (roomPhase: RoomPhase) => void;
  onRoomStateChanged?: (roomState: RoomState) => void;
  onCanUndoStepsUpdate?: (steps: number) => void;
  onCanRedoStepsUpdate?: (steps: number) => void;

  setThrowError(callback: (args: object) => void): WhiteboardCallbacks {
    this.throwError = callback;
    return this;
  }

  setOnLogger(callback: (args: object) => void): WhiteboardCallbacks {
    this.onLogger = callback;
    return this;
  }

  setOnRoomReady(callback: () => void): WhiteboardCallbacks {
    this.onRoomReady = callback;
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

  setOnCanUndoStepsChanged(callback: (steps: number) => void): WhiteboardCallbacks {
    this.onCanUndoStepsUpdate = callback;
    return this;
  }

  onOnCanRedoStepsUpdate(callback: (steps: number) => void): WhiteboardCallbacks {
    this.onCanRedoStepsUpdate = callback;
    return this;
  }
}