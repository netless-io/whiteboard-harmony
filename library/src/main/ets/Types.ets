/**
 * 数据中心。
 */
export enum Region {
  /**
   * `cn` (`cn-hz`)：中国杭州。
   *
   * 该数据中心为其他数据中心服务区未覆盖的地区提供服务。
   */
  CN_HZ = "cn-hz",

  /**
   * `us` (`us-sv`)：美国硅谷。
   *
   * 该数据中心为北美洲、南美洲地区提供服务。
   */
  US_SV = "us-sv",

  /**
   * `sg`：新加坡。
   *
   * 该数据中心为新加坡、东亚、东南亚地区提供服务。
   */
  SG = "sg",

  /**
   * `in_mum`：印度孟买。
   *
   * 该数据中心为印度地区提供服务。
   */
  IN_MUM = "in-mum",

  /**
   * `eu`：欧洲。
   *
   * 该数据中心为欧洲地区提供服务。
   */
  EU = "eu"
}

/**
 * `MemberState` 类，用于设置互动白板实时房间的白板工具状态。
 */
export interface MemberState {
  /**
   * 白板工具名称
   */
  currentApplianceName?: Appliance;

  /**
   * 图形工具的类型。
   */
  shapeType?: ShapeType;

  /**
   * 线条颜色，为 RGB 格式，例如，[0, 0, 255] 表示蓝色。
   */
  strokeColor?: [number, number, number];

  /**
   * 线条粗细。
   */
  strokeWidth?: number;

  /**
   * 字体大小。Chrome 浏览器对于小于 12 的字体会自动调整为 12。
   */
  textSize?: number;

  /**
   * 文本颜色，为 RGB 格式，例如，[0, 0, 255] 表示蓝色。不设置情况与 strokeColor 使用相同
   */
  textColor?: [number, number, number];
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

/**
 * 白板工具名称。
 */
export enum Appliance {
  /**
   * 铅笔工具，用于绘制自由线条。
   */
  PENCIL = "pencil",

  /**
   * 选择工具，用于选择和移动对象。
   */
  SELECTOR = "selector",

  /**
   * 矩形工具，用于绘制矩形。
   */
  RECTANGLE = "rectangle",

  /**
   * 椭圆工具，用于绘制椭圆。
   */
  ELLIPSE = "ellipse",

  /**
   * 橡皮擦工具，用于擦除内容。
   */
  ERASER = "eraser",

  /**
   * 文本工具，用于添加文本。
   */
  TEXT = "text",

  /**
   * 直线工具，用于绘制直线。
   */
  STRAIGHT = "straight",

  /**
   * 箭头工具，用于绘制箭头。
   */
  ARROW = "arrow",

  /**
   * 手形工具，用于拖动视图或进行其他交互。
   */
  HAND = "hand",

  /**
   * 激光笔工具，用于高亮标记。
   */
  LASER_POINTER = "laserPointer",

  /**
   * 点击器工具，用于模拟点击操作。
   */
  CLICKER = "clicker",

  /**
   * 形状工具，用于绘制各种形状。
   */
  SHAPE = "shape",

  /**
   * 铅笔橡皮擦工具，用于擦除铅笔绘制的内容。
   */
  PENCIL_ERASER = "pencilEraser",

  /**
   * 激光铅笔工具，用于绘制类似激光笔的效果。
   */
  LASER_PENCIL = "laserPen",
}

/**
 * 图形工具扩展，教具 APPLIANCE 设置成 SHAPE 时配置
 */
export enum ShapeType {
  /**
   * `TRIANGLE`：（默认）三角形。
   */
  TRIANGLE = "triangle",
  /**
   * `RHOMBUS`：菱形。
   */
  RHOMBUS = "rhombus",
  /**
   * `PENTAGRAM`：五角星。
   */
  PENTAGRAM = "pentagram",
  /**
   * `SPEECH_BALLOON`：对话气泡。
   */
  SPEECH_BALLOON = "speechBalloon",
}

/** `AkkoEvent` 类，用于设置自定义事件。 */
export interface AkkoEvent {
  eventName: string;
  payload: object;
}

/**
 * `EventEntry` 类，用于获取自定义事件。
 */
export interface EventEntry {
  eventName: string;
  payload: object;
  scope: string;
  authorId: string;
}

/**
 * `EventListener` 接口类，用于监听自定义事件。
 */
export interface EventListener {
  onEvent(event: EventEntry): void
}

/**
 * `FrequencyEventListener` 接口类。该类包含你想要注册监听的高频事件回调。
 */
export interface FrequencyEventListener {
  onEvent(events: EventEntry[]): void
}

/**
 * 房间连接状态。
 */
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

/**
 * 视角状态，包含视角为主播模式的用户信息。
 */
export interface BroadcastState {
  mode: ViewMode;
  broadcasterId: number;
  broadcasterInformation: RoomMember;
}

/**
 * `CameraState` 类，描述视角状态。
 */
export interface CameraState {
  centerX: number;
  centerY: number;
  scale: number;
}

/**
 * 房间状态类。
 */
export interface RoomState extends SharedState {
  // 当前的白板工具状态
  memberState: MemberState;

  // 房间内当前的视角状态
  broadcastState: BroadcastState;
}

/**
 * 为互动白板实时房间和回放房间共有的状态类
 */
interface SharedState {
  roomMembers: RoomMember[];
  sceneState: SceneState;
  windowBoxState: string;
  pageState: PageState;
  cameraState: CameraState;
}

/**
 * 多窗口模式下，主窗口页面状态。
 */
export interface PageState {
  /**
   * 当前主窗口页面索引
   */
  index: number;

  /**
   * 当前主窗口页面数量
   */
  length: number;
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
 * ImageInformation 接口表示图片在白板上的位置信息和 URL 地址。
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
 * 移动或缩放视角时的动画模式。
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

export interface WindowAppParam {
  kind: string;
  options?: object;
  attributes?: object;
}

export interface WindowAppSyncAttrs {
  kind: string;
  src: string;
  options?: object;
  state?: object;
  title?: string;
}

export interface AddPageParam {
  after?: boolean;  // 可选属性，表示是否在后面添加
  scene?: Scene;    // 可选属性，表示场景对象
}

export interface RemovePageParam {
  index?: number
}

export interface SlideListener {
  /**
   * 拦截 Slide 资源 URL 回调。
   */
  slideUrlInterrupter(url: string, complete: (result: string) => void): void;

  /**
   * Slide 加载错误回调。
   */
  onSlideError(type: SlideErrorType, errorMsg: string, slideId: string, slideIndex: number): void;
}

export enum SlideErrorType {
  /**
   * ResourceError: 当 PPT 依赖的远程资源（如 JSON、PNG）不可用时触发，
   * 触发后当前页无法交互。
   * 恢复手段：重新渲染当前页或者跳转到下一页。
   */
  RESOURCE_ERROR = "RESOURCE_ERROR",

  /**
   * RuntimeError: 未知的异常导致触发，触发后当前页无法交互。
   * 恢复手段：跳转到下一页。
   */
  RUNTIME_ERROR = "RUNTIME_ERROR",

  /**
   * RuntimeWarn: 动画过程中出现未知的警告，触发后动画当前帧表现异常，
   * 但不影响下一帧和页面交互。
   * 恢复手段：无需特殊处理。
   */
  RUNTIME_WARN = "RUNTIME_WARN",

  /**
   * CanvasCrash: 由于内存不足，或者 canvas 被意外移除（在未调用 slide.destroy() 的情况下移除 canvas 元素）
   * 导致触发，触发后 canvas 元素白屏。
   * 恢复手段：刷新网页，或者销毁 slide 对象并重新创建。
   */
  CANVAS_CRASH = "CANVAS_CRASH",

  /**
   * 未知错误类型
   */
  UNKNOWN = "UNKNOWN"
}

export enum SlideInvisibleBehavior {
  /**
   * 冻结：表示行为为 "frozen"。
   */
  Frozen = "frozen",

  /**
   * 暂停：表示行为为 "pause"。
   */
  Pause = "pause"
}
