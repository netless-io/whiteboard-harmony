import { describe, it, expect } from '@ohos/hypium';
import { RoomPhase } from '@shengwang/whiteboard';
import { RoomPhaseGuard, RoomPhaseGuardResult } from '../main/ets/RoomPhaseGuard';

export default function localUnitTest() {
  describe('room_phase_guard_unit_tests', () => {
    it('reconnecting_shows_loading_without_rebuilding_room', 0, () => {
      const guard: RoomPhaseGuard = new RoomPhaseGuard();
      const result: RoomPhaseGuardResult = guard.onPhaseChanged(RoomPhase.RECONNECTING);

      expect(result.showLoading).assertTrue();
      expect(result.shouldRebuildRoom).assertFalse();
    });

    it('connected_hides_loading_and_resets_rebuild_state', 0, () => {
      const guard: RoomPhaseGuard = new RoomPhaseGuard();
      guard.onPhaseChanged(RoomPhase.DISCONNECTED);

      const connected: RoomPhaseGuardResult = guard.onPhaseChanged(RoomPhase.CONNECTED);
      const disconnectedAgain: RoomPhaseGuardResult = guard.onPhaseChanged(RoomPhase.DISCONNECTED);

      expect(connected.showLoading).assertFalse();
      expect(disconnectedAgain.shouldRebuildRoom).assertTrue();
    });

    it('disconnect_phases_trigger_only_one_concurrent_rebuild', 0, () => {
      const guard: RoomPhaseGuard = new RoomPhaseGuard();
      const disconnecting: RoomPhaseGuardResult = guard.onPhaseChanged(RoomPhase.DISCONNECTING);
      const disconnected: RoomPhaseGuardResult = guard.onPhaseChanged(RoomPhase.DISCONNECTED);

      expect(disconnecting.showLoading).assertTrue();
      expect(disconnecting.shouldRebuildRoom).assertTrue();
      expect(disconnected.shouldRebuildRoom).assertFalse();
    });

    it('reconnect_watchdog_retries_until_connected', 0, () => {
      const guard: RoomPhaseGuard = new RoomPhaseGuard();
      guard.onPhaseChanged(RoomPhase.DISCONNECTED);

      const timeout: RoomPhaseGuardResult = guard.onReconnectTimeout();

      expect(timeout.showLoading).assertTrue();
      expect(timeout.shouldRebuildRoom).assertTrue();
    });

    it('manual_exit_suppresses_disconnect_rebuild_and_watchdog', 0, () => {
      const guard: RoomPhaseGuard = new RoomPhaseGuard();
      guard.onPhaseChanged(RoomPhase.DISCONNECTED);
      guard.beginManualExit();

      const disconnected: RoomPhaseGuardResult = guard.onPhaseChanged(RoomPhase.DISCONNECTED);
      const timeout: RoomPhaseGuardResult = guard.onReconnectTimeout();

      expect(disconnected.showLoading).assertFalse();
      expect(disconnected.shouldRebuildRoom).assertFalse();
      expect(timeout.shouldRebuildRoom).assertFalse();
    });
  });
}
