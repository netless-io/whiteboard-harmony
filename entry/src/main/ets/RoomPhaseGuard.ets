import { RoomPhase } from '@shengwang/whiteboard'

export class RoomPhaseGuardResult {
  showLoading: boolean
  shouldRebuildRoom: boolean

  constructor(showLoading: boolean, shouldRebuildRoom: boolean) {
    this.showLoading = showLoading
    this.shouldRebuildRoom = shouldRebuildRoom
  }
}

/** Keeps reconnection policy independent from ArkUI so it can be unit tested. */
export class RoomPhaseGuard {
  private manualExit: boolean = false
  private rebuildInFlight: boolean = false
  private loading: boolean = true

  onPhaseChanged(phase: RoomPhase): RoomPhaseGuardResult {
    if (this.manualExit) {
      return new RoomPhaseGuardResult(false, false)
    }

    switch (phase) {
      case RoomPhase.CONNECTED:
        this.loading = false
        this.rebuildInFlight = false
        return new RoomPhaseGuardResult(false, false)
      case RoomPhase.DISCONNECTING:
      case RoomPhase.DISCONNECTED:
        this.loading = true
        return new RoomPhaseGuardResult(true, this.beginRebuild())
      case RoomPhase.CONNECTING:
      case RoomPhase.RECONNECTING:
      default:
        this.loading = true
        return new RoomPhaseGuardResult(true, false)
    }
  }

  onReconnectTimeout(): RoomPhaseGuardResult {
    if (this.manualExit || !this.rebuildInFlight) {
      return new RoomPhaseGuardResult(this.loading, false)
    }
    this.rebuildInFlight = false
    return new RoomPhaseGuardResult(true, this.beginRebuild())
  }

  beginManualExit(): void {
    this.manualExit = true
    this.rebuildInFlight = false
    this.loading = false
  }

  isManualExit(): boolean {
    return this.manualExit
  }

  private beginRebuild(): boolean {
    if (this.rebuildInFlight) {
      return false
    }
    this.rebuildInFlight = true
    return true
  }
}
