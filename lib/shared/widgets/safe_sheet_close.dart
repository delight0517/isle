import 'package:flutter/material.dart';

void dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}

Future<void> safeCloseSheet(BuildContext context) async {
  dismissKeyboard();
  await Future<void>.delayed(const Duration(milliseconds: 16));
  if (context.mounted) {
    Navigator.of(context).pop();
  }
}
