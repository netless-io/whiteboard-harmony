import { DsBridge } from './DsBridge';
import { Appliance, MemberState, ShapeType } from './Types';

export class WhiteboardController {
  whiteboard?: DsBridge

  attachWhiteboard(whiteboard: DsBridge) {
    this.whiteboard = whiteboard
  }

  setWriteable(writable: boolean): Promise<boolean> {
    return new Promise((resolve, reject) => {
      this.whiteboard?.callHandler("room.setWritable", [writable], (result: object) => {
        if (typeof result === 'boolean') {
          resolve(result);
        } else {
          reject(new Error("Expected boolean result, but got a different type"));
        }
      });
    });
  }

  setAppliance(appliance: Appliance, shapeType?: ShapeType) {
    let state: MemberState = {
      currentApplianceName: appliance,
      shapeType: shapeType,
    }
    this.whiteboard?.callHandler("room.setMemberState", [state])
  }
}