export class MemberState {
  currentApplianceName?: Appliance;
  strokeColor?: [number, number, number];
  strokeWidth?: number;
  textSize?: number;
  textColor?: [number, number, number];
  textCanSelectText?: boolean;
  dottedLine?: boolean;
  pencilEraserSize?: number;
  shapeType?: ShapeType;
}

export enum Appliance {
  PENCIL = "pencil",
  SELECTOR = "selector",
  RECTANGLE = "rectangle",
  ELLIPSE = "ellipse",
  ERASER = "eraser",
  TEXT = "text",
  STRAIGHT = "straight",
  ARROW = "arrow",
  HAND = "hand",
  LASER_POINTER = "laserPointer",
  CLICKER = "clicker",
  SHAPE = "shape",
  PENCIL_ERASER = "pencilEraser",
  LASER_PENCIL = "laserPen",
}

export enum ShapeType {
  Triangle = "triangle",
  Rhombus = "rhombus",
  Pentagram = "pentagram",
  SpeechBalloon = "speechBalloon",
}


export interface RoomDelegate {
  fireCanUndoStepsUpdate(steps: number): void;

  onCanRedoStepsUpdate(steps: number): void;

  fireMagixEvent(event: AkkoEvent): void;

  fireHighFrequencyEvent(events: AkkoEvent[]): void;

  firePhaseChanged(phase: RoomPhase): void;

  fireKickedWithReason(reason: string): void;

  fireDisconnectWithError(error: Error): void;

  fireRoomStateChanged(state: string): void;

  fireCatchErrorWhenAppendFrame(userId: string, error: Error): void;
}

export interface AkkoEvent {
  // 定义事件条目的结构
}

export enum RoomPhase {
  /**
   * 连接中
   */
  CONNECTING = "connecting",

  /**
   * 已连接
   */
  CONNECTED = "connected",

  /**
   * 正在重连
   */
  RECONNECTING = "reconnecting",

  /**
   * 正在断开连接
   */
  DISCONNECTING = "disconnecting",

  /**
   * 已经断开连接
   */
  DISCONNECTED = "disconnected",
}

export class BroadcastState {
}

export class RoomState {
  private memberState: MemberState;
  private broadcastState: BroadcastState;

  constructor(memberState: MemberState, broadcastState: BroadcastState) {
    this.memberState = memberState;
    this.broadcastState = broadcastState;
  }

  /**
   * 获取互动白板实时房间内当前的白板工具状态。
   *
   * @return 白板工具状态，详见 MemberState。
   */
  getMemberState(): MemberState {
    return this.memberState;
  }

  /**
   * 获取互动白板实时房间内当前的视角状态。
   *
   * @return 视角状态，详见 BroadcastState。
   */
  getBroadcastState(): BroadcastState {
    return this.broadcastState;
  }
}