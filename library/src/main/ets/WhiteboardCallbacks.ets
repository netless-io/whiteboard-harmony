import {
  EventEntry,
  RoomDisconnectError,
  RoomKickedReason,
  RoomPhase,
  RoomState,
} from './Types';

export class WhiteboardCallbacks {
  /**
   * 错误回调函数，处理错误信息。
   * @param args 错误信息对象
   */
  throwError?: (args: object) => void;

  /**
   * 消息回调函数，用于处理接收到的消息。
   * @param args 消息对象
   */
  onMessage?: (args: object) => void;

  /**
   * 日志回调函数，用于记录日志。
   * @param args 日志信息对象
   */
  onLogger?: (args: object) => void;

  /**
   * 房间准备就绪回调函数，房间准备好后调用。
   */
  onRoomReady?: () => void;

  /**
   * 房间状态变更回调函数，当房间阶段发生变化时调用。
   * @param roomPhase 房间阶段
   */
  onRoomPhaseChanged?: (roomPhase: RoomPhase) => void;

  /**
   * 房间状态变化回调函数，当房间状态变化时调用。
   * @param roomState 房间状态
   */
  onRoomStateChanged?: (roomState: RoomState) => void;

  /**
   * 可撤销步骤更新回调函数，当可撤销步骤发生变化时调用。
   * @param steps 当前可撤销的步骤数
   */
  onCanUndoStepsUpdate?: (steps: number) => void;

  /**
   * 可重做步骤更新回调函数，当可重做步骤发生变化时调用。
   * @param steps 当前可重做的步骤数
   */
  onCanRedoStepsUpdate?: (steps: number) => void;

  /**
   * 自定义事件回调函数。
   * @param event 自定义事件
   */
  onMagixEvent?: (event: EventEntry) => void;

  /**
   * 高频事件回调函数。
   * @param events 高频事件列表
   */
  onHighFrequencyEvent?: (events: EventEntry[]) => void;

  /**
   * 房间断连错误回调函数。
   * @param error 断连错误
   */
  onDisconnectWithError?: (error: RoomDisconnectError) => void;

  /**
   * 被踢下线回调函数。
   * @param reason 原因
   */
  onKickedWithReason?: (reason: RoomKickedReason) => void;

  /**
   * 设置错误回调函数。
   * @param callback 错误回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setThrowError(callback: (args: object) => void): WhiteboardCallbacks {
    this.throwError = callback;
    return this;
  }

  /**
   * 设置日志回调函数。
   * @param callback 日志回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setOnLogger(callback: (args: object) => void): WhiteboardCallbacks {
    this.onLogger = callback;
    return this;
  }

  /**
   * 设置房间准备就绪回调函数。
   * @param callback 房间准备就绪的回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setOnRoomReady(callback: () => void): WhiteboardCallbacks {
    this.onRoomReady = callback;
    return this;
  }

  /**
   * 设置房间阶段变更回调函数。
   * @param callback 房间阶段变更的回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setOnRoomPhaseChanged(callback: (roomPhase: RoomPhase) => void): WhiteboardCallbacks {
    this.onRoomPhaseChanged = callback;
    return this;
  }

  /**
   * 设置房间状态变化回调函数。
   * @param callback 房间状态变化的回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setOnRoomStateChanged(callback: (roomState: RoomState) => void): WhiteboardCallbacks {
    this.onRoomStateChanged = callback;
    return this;
  }

  /**
   * 设置可撤销步骤更新回调函数。
   * @param callback 可撤销步骤更新的回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setOnCanUndoStepsChanged(callback: (steps: number) => void): WhiteboardCallbacks {
    this.onCanUndoStepsUpdate = callback;
    return this;
  }

  /**
   * 设置可重做步骤更新回调函数。
   * @param callback 可重做步骤更新的回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setOnCanRedoStepsChanged(callback: (steps: number) => void): WhiteboardCallbacks {
    this.onCanRedoStepsUpdate = callback;
    return this;
  }

  /**
   * 设置自定义事件回调函数。
   * @param callback 自定义事件回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setOnMagixEvent(callback: (event: EventEntry) => void): WhiteboardCallbacks {
    this.onMagixEvent = callback;
    return this;
  }

  /**
   * 设置高频事件回调函数。
   * @param callback 高频事件回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setOnHighFrequencyEvent(callback: (events: EventEntry[]) => void): WhiteboardCallbacks {
    this.onHighFrequencyEvent = callback;
    return this;
  }

  /**
   * 设置房间断连错误回调函数。
   * @param callback 房间断连错误回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setOnDisconnectWithError(callback: (error: RoomDisconnectError) => void): WhiteboardCallbacks {
    this.onDisconnectWithError = callback;
    return this;
  }

  /**
   * 设置被踢下线回调函数。
   * @param callback 被踢下线回调函数
   * @returns 当前的 WhiteboardCallbacks 实例
   */
  setOnKickedWithReason(callback: (reason: RoomKickedReason) => void): WhiteboardCallbacks {
    this.onKickedWithReason = callback;
    return this;
  }
}
