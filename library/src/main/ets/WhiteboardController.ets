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

  setAppliance(appliance: Appliance, shapeType?: ShapeType) {
    let state: MemberState = {
      currentApplianceName: appliance,
      shapeType: shapeType,
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  setStrokeColor(color: ResourceColor) {
    const metrics = ColorMetrics.resourceColor(color)
    let state: MemberState = {
      strokeColor: [metrics.red, metrics.green, metrics.blue],
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  setStrokeWidth(width: number) {
    let state: MemberState = {
      strokeWidth: width,
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  setTextSize(size: number) {
    let state: MemberState = {
      textSize: size,
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  setTextColor(color: ResourceColor) {
    const metrics = ColorMetrics.resourceColor(color)
    let state: MemberState = {
      textColor: [metrics.red, metrics.green, metrics.blue],
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  setMemberState(state: MemberState) {
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }

  copy(): void {
    this.whiteboard?.callHandler("room.sync.copy", []);
  }

  paste(): void {
    this.whiteboard?.callHandler("room.sync.paste", []);
  }

  duplicate(): void {
    this.whiteboard?.callHandler("room.sync.duplicate", []);
  }

  deleteOperation(): void {
    this.whiteboard?.callHandler("room.sync.delete", []);
  }

  disableSerialization(disable: boolean): void {
    this.whiteboard?.callHandler("room.sync.disableSerialization", [disable]);
  }

  redo(): void {
    this.whiteboard?.callHandler("room.redo", [])
  }

  undo(): void {
    this.whiteboard?.callHandler("room.undo", [])
  }

  setViewMode(viewMode: ViewMode): void {
    this.whiteboard?.callHandler("room.setViewMode", [viewMode]);
  }

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

  insertImage(info: ImageInformation): void {
    if (!info.uuid) {
      info.uuid = util.generateRandomUUID();
    }
    this.whiteboard?.callHandler("room.insertImage", [info]);
    this.whiteboard?.callHandler("room.completeImageUpload", [info.uuid, info.url!!])
  }

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

  putScenes(dir: string, scenes: Scene[], index: number) {
    this.whiteboard?.callHandler("room.putScenes", [dir, scenes, index])
  }

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
   *                - `true`: 禁止用户调整视角。
   *                - `false`: (默认) 允许用户调整视角。
   */
  disableCameraTransform(disable: boolean) {
    this.whiteboard?.callHandler("displayer.setDisableCameraTransform", [disable])
  }
}