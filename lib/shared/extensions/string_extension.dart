extension IsleString on String {
  bool get isBlank => trim().isEmpty;
  String? get nullIfEmpty => isBlank ? null : this;
}
