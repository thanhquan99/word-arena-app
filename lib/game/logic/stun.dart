/// Escalating stun after a wasted mission (Game_Rule section 4).
///
/// Pure logic — no timers here, just the durations. The bloc owns the clock.
library;

const _firstMiss = Duration(milliseconds: 1500);
const _repeatMiss = Duration(seconds: 3);

/// After this many misses in a row the game starts offering easier missions,
/// so a struggling player is not stunned into quitting.
const missesBeforeEasing = 3;

class StunTracker {
  int _streak = 0;

  int get streak => _streak;

  /// True once the player has missed [missesBeforeEasing] times in a row.
  bool get shouldLowerTier => _streak >= missesBeforeEasing;

  /// Records a mission where nothing was completed; returns how long to stun.
  ///
  /// [forceMax] skips the ladder and applies the long stun immediately — the
  /// `stun` mission effect (Game_Rule section 8.2), which is the price paid for
  /// taking a risky mission.
  Duration recordMiss({bool forceMax = false}) {
    _streak++;
    if (forceMax) return _repeatMiss;
    return _streak == 1 ? _firstMiss : _repeatMiss;
  }

  /// Records a mission where at least one objective landed.
  ///
  /// Any success clears the streak — the escalation is there to slow down a
  /// run of total failures, not to punish someone who is partly getting it.
  void recordSuccess() {
    _streak = 0;
  }
}
