/// per-schedule commitment lock FSM (블루프린트 §2-B)
enum ScheduleLockPhase {
  unlocked,
  locked,
  countdown,
  editWindow,
}
