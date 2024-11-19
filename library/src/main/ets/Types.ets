export interface MemberState {
  currentApplianceName?: Appliance;
  shapeType?: ShapeType;
  strokeColor?: [number, number, number];
  strokeWidth?: number;
  textSize?: number;
  textColor?: [number, number, number];
  textCanSelectText?: boolean;
}

/**
 * 表示房间成员的接口。
 */
export interface RoomMember {
  /**
   * 用户 ID，用于标识房间内的用户。同一房间中的每个用户具有唯一的用户 ID。
   */
  memberId?: number;

  /**
   * 互动模式用户的所有白板工具信息。
   */
  memberState?: MemberState;

  /**
   * 用户加入房间时携带的自定义用户信息。
   */
  payload?: object;
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

export function toRoomPhase(value: string): RoomPhase | null {
  const phaseKey = Object.keys(RoomPhase).find(key => RoomPhase[key] === value);
  return phaseKey ? RoomPhase[phaseKey] : null;
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

/**
 * 视角模式。
 */
export enum ViewMode {
  /**
   * （默认）自由模式。
   * 该模式下用户可以主动调整视角，不受其他用户视角模式设置的影响，也不会影响其他用户的视角模式设置。
   *
   * @note 当房间内不存在视角为主播模式的用户时，所有用户的视角都默认为自由模式。
   */
  Freedom = "freedom",

  /**
   * 跟随模式。
   * 该模式下用户的视角会跟随主播的视角。
   *
   * @note
   * - 当一个用户的视角设置为主播模式后，房间内其他所有用户（包括新加入房间的用户）的视角会被自动设置为跟随模式。
   * - 跟随模式的用户进行白板操作时，其视角会自动切换为自由模式。
   *   如有需要，可以调用 `disableOperations` 禁止用户操作，以锁定用户的视角模式。
   */
  Follower = "follower",

  /**
   * 主播模式。
   * 该模式下用户可以主动调整视角，并将自己的视角同步给房间内所有其他用户。
   *
   * @note
   * - 每个房间只能有一个主播模式视角的用户。
   * - 当一个用户的视角设置为主播模式后，房间内所有其他用户（包括新加入房间的用户）的视角会被自动设置为跟随模式。
   */
  Broadcaster = "broadcaster"
}

/**
 * ImageInformationWithUrl 接口表示图片在白板上的位置信息和 URL 地址。
 */
export interface ImageInformation {
  // 图片的中心在世界坐标系中的横向坐标
  centerX?: number;

  // 图片的中心在世界坐标系中的纵向坐标
  centerY?: number;

  // 图片的宽度，单位为像素
  width?: number;

  // 图片的高度，单位为像素
  height?: number;

  // 图片的 URL 地址
  url?: string;

  // 唯一标识
  uuid?: string;
}

/**
 * 表示场景状态的接口。
 */
export interface SceneState {
  /**
   * 当前场景组下的所有场景列表。
   */
  scenes?: Scene[];

  /**
   * 当前场景的路径。
   */
  scenePath?: string;

  /**
   * 当前场景的名称。
   */
  sceneName?: string;

  /**
   * 当前场景的目录。
   */
  contextPath?: string;

  /**
   * 当前场景在所属场景组中的索引号。
   */
  index?: number;
}

/**
 * 表示场景的接口。
 *
 * 根据 `Scene` 的实际定义补充该接口。
 */
export interface Scene {
  /**
   * 场景名称。
   */
  name?: string;

  /**
   * 在场景中展示的图片或动态 PPT 的参数配置。
   */
  ppt?: PptPage;
}

/**
 * 表示图片或动态 PPT 页的参数配置。
 */
export interface PptPage {
  /**
   * 图片的 URL 地址或动态 PPT 页的 URI 地址。
   * 支持的格式：
   * - 图片：URL 地址，可以是通过文档转换功能生成的 URL。
   * - 动态 PPT 页：通过文档转换功能生成的 URI 地址。
   */
  src: string;

  /**
   * 图片或动态 PPT 在白板中的宽度，单位为像素。
   */
  width: number;

  /**
   * 图片或动态 PPT 在白板中的高度，单位为像素。
   */
  height: number;

  /**
   * 图片或动态 PPT 的预览图 URL 地址。
   * 动态 PPT 的预览图 URL 地址可以通过文档转换任务的查询结果中 `preview` 字段获取。
   */
  preview?: string;
}


/**
 * 动画模式。
 */
export enum AnimationMode {
  /**
   * （默认）渐变模式。
   */
  Continuous = "continuous",

  /**
   * 瞬间切换模式。
   */
  Immediately = "immediately"
}


/**
 * 多窗口配置参数
 */
export class WindowParams {
  /**
   * 各个端本地显示多窗口内容时，高与宽比例，默认为 9:16
   */
  containerSizeRatio?: number;
  /**
   * 多窗口区域（主窗口）以外的空间显示 PS 棋盘背景，默认 true
   */
  chessboard?: boolean;
  /**
   * 驼峰形式的 CSS，透传给多窗口时，最小化 div 的 css
   */
  collectorStyles?: Record<string, string>;
  /**
   * 窗口样式覆盖
   */
  overwriteStyles?: string;
  /**
   * 是否在网页控制台打印日志
   */
  debug?: boolean;
  /**
   * 窗口配色模式
   */
  prefersColorScheme?: WindowPrefersColorScheme;
  /**
   * 是否全屏
   */
  fullscreen?: boolean;
  /**
   * 是否轮询
   */
  polling?: boolean;

  setContainerSizeRatio(containerSizeRatio: number): WindowParams {
    this.containerSizeRatio = containerSizeRatio;
    return this;
  }

  setChessboard(chessboard: boolean): WindowParams {
    this.chessboard = chessboard;
    return this;
  }

  setDebug(debug: boolean): WindowParams {
    this.debug = debug;
    return this;
  }

  setCollectorStyles(collectorStyles: Record<string, string>): WindowParams {
    this.collectorStyles = collectorStyles;
    return this;
  }

  setOverwriteStyles(overwriteStyles: string): WindowParams {
    this.overwriteStyles = overwriteStyles;
    return this;
  }

  setPrefersColorScheme(prefersColorScheme: WindowPrefersColorScheme): WindowParams {
    this.prefersColorScheme = prefersColorScheme;
    return this;
  }

  setFullscreen(fullscreen: boolean): WindowParams {
    this.fullscreen = fullscreen;
    return this;
  }

  setPolling(polling: boolean): WindowParams {
    this.polling = polling;
    return this;
  }
}

export enum WindowPrefersColorScheme {
  Light = "light",
  Dark = "dark",
  Auto = "auto",
}
