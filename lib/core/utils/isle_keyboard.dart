import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 차단 시트 등에서 키보드 확실히 내리기
class IsleKeyboard {
  IsleKeyboard._();

  static void hide() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }
}
