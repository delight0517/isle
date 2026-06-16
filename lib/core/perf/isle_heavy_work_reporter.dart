/// 무거운 작업 진행 보고 (UI·로그용)
class IsleHeavyWorkReporter {
  IsleHeavyWorkReporter(this._onUpdate);

  final void Function(double progress, {String? stepLabel}) _onUpdate;

  void progress(double value, {String? stepLabel}) {
    _onUpdate(value.clamp(0.0, 1.0), stepLabel: stepLabel);
  }

  void step(String label) => _onUpdate(-1, stepLabel: label);
}
