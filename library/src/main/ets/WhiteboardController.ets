import { DsBridge } from './DsBridge';
import {
  AnimationMode,
  Appliance,
  ImageInformation,
  MemberState,
  RoomMember,
  RoomPhase,
  RoomState,
  SceneState,
  ShapeType,
  toRoomPhase,
  ViewMode,
  WindowPrefersColorScheme,
} from './Types';
import { util } from '@kit.ArkTS';
import { SDKError } from './JsInterfaces';
import { ColorMetrics } from '@kit.ArkUI';

export class WhiteboardController {
  private whiteboard?: DsBridge
  private writable = false
  attachWhiteboard = (whiteboard: DsBridge) => {
    this.whiteboard = whiteboard
  }
  detachWhiteboard = (whiteboard: DsBridge) => {
    this.whiteboard = undefined
  }

  /**
   * 设置用户在房间中是否为互动模式。
   *
   * @param writable 用户在房间中是否为互动模式：
   *  - `true`：互动模式，即具有读写权限。
   *  - `false`：订阅模式，即具有只读权限。
   *
   * @returns Promise
   *  如果方法调用成功，则返回用户在房间中的读写状态（`true` 或 `false`）。
   *  如果方法调用失败，则返回错误信息。
   */
  setWritable(writable: boolean): Promise<boolean> {
    interface WritableResult {
      isWritable: boolean
      observerId: string
    }

    return new Promise((resolve, reject) => {
      this.whiteboard?.callHandler("room.setWritable", [writable], (result: object) => {
        if (typeof result !== 'string') {
          return reject(new Error("Expected string result, but got a different type"));
        }
        const sdkError = SDKError.promiseError(result);
        if (sdkError) {
          reject(sdkError)
        }
        const resultObj: WritableResult = JSON.parse(result);
        this.writable = resultObj.isWritable;
        resolve(resultObj.isWritable)
      });
    });
  }

  getWritable(): boolean {
    return this.writable
  }

  /**
   * 设置教具类型
   *
   * @param appliance 教具类型
   * @param shapeType 形状
   */
  setAppliance(appliance: Appliance, shapeType?: ShapeType) {
    let state: MemberState = {
      currentApplianceName: appliance,
      shapeType: shapeType,
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  /**
   * 设置画笔颜色
   *
   * @param color
   */
  setStrokeColor(color: ResourceColor) {
    const metrics = ColorMetrics.resourceColor(color)
    let state: MemberState = {
      strokeColor: [metrics.red, metrics.green, metrics.blue],
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  /**
   * 设置画笔粗细
   *
   * @param width
   */
  setStrokeWidth(width: number) {
    let state: MemberState = {
      strokeWidth: width,
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  /**
   * 设置字大小
   *
   * @param size
   */
  setTextSize(size: number) {
    let state: MemberState = {
      textSize: size,
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  /**
   * 设置字颜色
   *
   * @remarks
   * 默认状态下，文字的颜色和画笔颜色保持一致
   *
   * @param color
   */
  setTextColor(color: ResourceColor) {
    const metrics = ColorMetrics.resourceColor(color)
    let state: MemberState = {
      textColor: [metrics.red, metrics.green, metrics.blue],
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  /**
   * 修改房间内的白板工具状态。
   */
  setMemberState(state: MemberState) {
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  /**
   * 复制选中内容。
   */
  copy(): void {
    this.whiteboard?.callHandler("room.sync.copy", []);
  }

  /**
   * 粘贴复制的内容。
   */
  paste(): void {
    this.whiteboard?.callHandler("room.sync.paste", []);
  }

  /**
   * 复制并粘贴选中的内容。
   */
  duplicate(): void {
    this.whiteboard?.callHandler("room.sync.duplicate", []);
  }

  /**
   * 删除选中的内容。
   */
  deleteOperation(): void {
    this.whiteboard?.callHandler("room.sync.delete", []);
  }

  /**
   * 开启/禁止本地序列化。
   *
   * 设置 `disableSerialization(true)` 后，undo redo 计数不生效、以下方法将不生效：
   * - `redo`
   * - `undo`
   * @param disable 默认为 true
   */
  disableSerialization(disable: boolean): void {
    this.whiteboard?.callHandler("room.sync.disableSerialization", [disable]);
  }

  /**
   * 重做，即回退撤销操作。
   *
   * @note 该方法仅当 disableSerialization 设为 `false` 时生效。
   */
  redo(): void {
    this.whiteboard?.callHandler("room.redo", [])
  }

  /**
   * 撤销上一步操作。
   *
   * @note 该方法仅当 disableSerialization 设为 `false` 时生效。
   */
  undo(): void {
    this.whiteboard?.callHandler("room.undo", [])
  }

  /**
   * 切换视角模式。
   */
  setViewMode(viewMode: ViewMode): void {
    this.whiteboard?.callHandler("room.setViewMode", [viewMode]);
  }

  /**
   * 主动断开与互动白板实时房间实例的连接。
   */
  disconnect(): Promise<object> {
    return new Promise((resolve, reject) => {
      this.whiteboard?.callHandler("room.disconnect", [], (result: object) => {
        if (typeof result === 'string') {
          resolve(JSON.parse(result))
        } else {
          reject(new Error("Expected boolean result, but got a different type"));
        }
      });
    });
  }

  /**
   * 插入图片显示区域。
   */
  insertImage(info: ImageInformation): void {
    if (!info.uuid) {
      info.uuid = util.generateRandomUUID();
    }
    this.whiteboard?.callHandler("room.insertImage", [info]);
    this.whiteboard?.callHandler("room.completeImageUpload", [info.uuid, info.url!!])
  }


  /**
   * 获取房间的所有状态。
   */
  getRoomState(): Promise<RoomState> {
    return new Promise((resolve, reject) => {
      this.whiteboard?.callHandler("room.state.getRoomState", [], (result: object) => {
        if (typeof result === 'string') {
          resolve(JSON.parse(result))
        } else {
          reject(new Error("Expected string result, but got a different type"));
        }
      });
    });
  }

  /**
   * 获取房间的连接状态。
   */
  getRoomPhase(): Promise<RoomPhase> {
    return new Promise((resolve, reject) => {
      this.whiteboard?.callHandler("room.getRoomPhase", [], (result: object) => {
        if (typeof result === 'string') {
          const phase = toRoomPhase(result)
          if (phase) {
            resolve(phase)
          } else {
            reject(new Error(`can not convert to room phase: ${result}`))
          }
        } else {
          reject(new Error("Expected string result, but got a different type"));
        }
      });
    });
  }

  /**
   * 获取房间的用户列表。
   *
   * @remarks
   * 房间的用户列表仅包含互动模式（具有读写权限）的用户，不包含订阅模式（只读权限）的用户。
   *
   * @return 用户列表
   */
  getRoomMembers(): Promise<RoomMember[]> {
    return new Promise((resolve, reject) => {
      this.whiteboard?.callHandler("room.getRoomMembers", [], (result: object) => {
        if (typeof result === 'string') {
          resolve(JSON.parse(result))
        } else {
          reject(new Error("Expected string result, but got a different type"));
        }
      });
    });
  }

  /**
   * 获取房间当前场景组下的场景状态。
   *
   * @note
   * - 该方法为异步调用。
   * - 调用以下方法修改或新增场景后，你可以通过 {@link #getSceneState(Promise<SceneState> promise) getSceneState} 立即获取最新的场景状态。
   *   - {@link #setScenePath(String path) setScenePath}[1/2]
   *   - {@link #setScenePath(String path, Promise<Boolean> promise) setScenePath}[2/2]
   *   - {@link #putScenes(String, Scene[], int)}
   *
   * @param promise `Promise<SceneState>` 接口实例，详见 {@link com.herewhite.sdk.domain.Promise Promise}。你可以通过该接口获取 `getSceneState` 的调用结果：
   *                - 如果方法调用成功，则返回场景状态，详见 {@link com.herewhite.sdk.domain.SceneState SceneState}。
   *                - 如果方法调用失败，则返回错误信息。
   *
   */
  getSceneState(): Promise<SceneState> {
    return new Promise((resolve, reject) => {
      this.whiteboard?.callHandler("room.getSceneState", [], (result: object) => {
        if (typeof result === 'string') {
          resolve(JSON.parse(result))
        } else {
          reject(new Error("Expected string result, but got a different type"));
        }
      });
    });
  }

  /**
   * 获取当前房间内所有场景的信息。
   *
   * @param promise `Promise<Map<String, Scene[]>>` 接口实例，详见 {@link com.herewhite.sdk.domain.Promise Promise}。你可以通过该接口获取 `getEntireScenes` 方法的调用结果：
   *                - 如果方法调用成功，将返回当前房间内所有场景的信息。
   *                - 如果方法调用失败，将返回错误信息。
   */
  getEntireScenes(): Promise<Record<string, Scene[]>> {
    return new Promise((resolve, reject) => {
      this.whiteboard?.callHandler("displayer.entireScenes", [], (result: object) => {
        if (typeof result === 'string') {
          resolve(JSON.parse(result))
        } else {
          reject(new Error("Expected string result, but got a different type"));
        }
      });
    });
  }

  /**
   * 切换至指定的场景。
   * 方法调用成功后，房间内的所有用户看到的白板都会切换到指定场景。
   */
  setScenePath(path: string): Promise<boolean> {
    return new Promise((resolve, reject) => {
      this.whiteboard?.callHandler("room.setScenePath", [path], (result: object) => {
        if (typeof result === 'string') {
          const error = SDKError.promiseError(result)
          if (error) {
            reject(error)
          } else {
            resolve(true)
          }
        } else {
          reject(new Error("Expected string result, but got a different type"));
        }
      })
    });
  }

  /**
   * 切换至当前场景组下的指定场景。
   *
   * 方法调用成功后，房间内的所有用户看到的白板都会切换到指定场景。
   * 指定的场景必须在当前场景组中，否则方法调用会失败。
   *
   * @param index - 目标场景在当前场景组下的索引号。
   * @returns 一个 `Promise<boolean>`，用于获取 `setSceneIndex` 的调用结果：
   *   - 如果方法调用成功，则返回 `true`。
   *   - 如果方法调用失败，则抛出错误信息。
   */
  setSceneIndex(index: number): Promise<boolean> {
    return new Promise((resolve, reject) => {
      this.whiteboard?.callHandler("room.setSceneIndex", [index], (result: object) => {
        if (typeof result === 'string') {
          const error = SDKError.promiseError(result)
          if (error) {
            reject(error)
          } else {
            resolve(true)
          }
        } else {
          reject(new Error("Expected string result, but got a different type"));
        }
      })
    });
  }

  /**
   * 在指定场景组下插入多个场景。
   *
   * @remarks
   * 调用该方法插入多个场景后不会切换到新插入的场景。如果要切换至新插入的场景，需要调用 `setScenePath`。
   *
   * @param dir - 场景组名称，必须以 `/` 开头。不能为场景路径。
   * @param scenes - 由多个场景构成的数组。单个场景的字段详见 {@link Scene}。
   * @param index - 待插入的多个场景中，第一个场景在该场景组的索引号。
   *   - 如果传入的索引号大于该场景组已有场景总数，新插入的场景会排在现有场景的最后。
   *   - 场景的索引号从 0 开始。
   */
  putScenes(dir: string, scenes: Scene[], index: number) {
    this.whiteboard?.callHandler("room.putScenes", [dir, scenes, index])
  }

  /**
   * 移动场景。
   *
   * 成功移动场景后，场景路径也会改变。
   *
   * @remarks
   * - 该方法只能移动场景，不能移动场景组，即 `sourcePath` 只能是场景路径，不能是场景组路径。
   * - 该方法支持改变指定场景在当前所属场景组下的位置，也支持将指定场景移至其他场景组。
   *
   * @param sourcePath - 需要移动的场景原路径。必须为场景路径，不能是场景组的路径。
   * @param targetDirOrPath - 目标场景组路径或目标场景路径：
   *   - 当 `targetDirOrPath` 设置为目标场景组路径时，表示将指定场景移至其他场景组中，场景路径会发生改变，但是场景名称不变。
   *   - 当 `targetDirOrPath` 设置为目标场景路径时，表示改变指定场景在当前场景组的位置，场景路径和场景名称都会发生改变。
   */
  moveScene(srcPath: string, dstPath: string) {
    this.whiteboard?.callHandler("room.moveScene", [srcPath, dstPath])
  }

  removeScenes(dirOrPath: string) {
    this.whiteboard?.callHandler("room.removeScenes", [dirOrPath])
  }

  /**
   * 清除当前场景的所有内容。
   *
   * @param retainPpt 是否保留 PPT 内容：
   *                  - `true`：保留 PPT。
   *                  - `false`：连 PPT 一起清空。
   */
  cleanScene(retainPpt?: boolean) {
    this.whiteboard?.callHandler("room.cleanScene", [retainPpt ?? true])
  }

  /**
   * 刷新白板的界面。
   * <p>
   * 当 `WhiteboardView` 出现改变时，需要手动调用该方法刷新白板的界面。
   */
  refreshViewSize() {
    this.whiteboard?.callHandler("displayer.refreshViewSize", [])
  }

  /**
   * 根据指定的动画模式调整视角，以保证完整显示 PPT 的内容。
   *
   * @param mode 视角调整时的动画模式。
   */
  scalePptToFit(mode?: AnimationMode) {
    this.whiteboard?.callHandler("displayer.scalePptToFit", [mode ?? AnimationMode.Continuous])
  }

  /**
   * 禁止/允许用户调整视角。
   *
   * 该方法用于禁止或允许用户通过触屏手势移动或缩放视角。
   *
   * @param disable 是否禁止用户调整视角：
   *  - `true`: 禁止用户调整视角。
   *  - `false`: (默认) 允许用户调整视角。
   */
  disableCameraTransform(disable: boolean) {
    this.whiteboard?.callHandler("room.disableCameraTransform", [disable])
  }

  /**
   * 禁止/允许用户操作白板工具。
   *
   * @param disable 是否禁止用户操作白板工具：
   *  - `true`：禁止用户操作白板工具操作。
   *  - `false`：（默认）允许用户操作白板工具输入操作。
   */
  disableDeviceInputs(disable: boolean) {
    this.whiteboard?.callHandler("room.disableDeviceInputs", [disable])
  }

  /**
   * 多窗口模式下，禁止/允许窗口操作。
   *
   * @param disable - 是否禁止窗口操作：
   *   - `true`：禁止窗口操作。
   *   - `false`：（默认）允许窗口操作。
   */
  disableWindowOperation(disable: boolean) {
    this.whiteboard?.callHandler("room.disableWindowOperation", [disable])
  }

  /**
   * 设置多窗口显示比例
   *
   * @param ratio 高与宽比例, 初始化默认值 9:16
   */
  setContainerSizeRatio(ratio: number) {
    // bridge.callHandler("room.setContainerSizeRatio", new Object[]{ratio});
    this.whiteboard?.callHandler("room.setContainerSizeRatio", [ratio])
  }

  /**
   * 设置设置暗色模式
   *
   * @param colorScheme
   */
  setPrefersColorScheme(colorScheme: WindowPrefersColorScheme) {
    this.whiteboard?.callHandler("room.setPrefersColorScheme", [colorScheme])
  }
}