import 'package:flutter/material.dart';

/// 시트 닫을 때 키보드도 함께 내림
Future<T?> showIsleModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  bool useSafeArea = true,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    builder: (ctx) {
      return _SheetKeyboardDismiss(child: Builder(builder: builder));
    },
  ).whenComplete(() {
    FocusManager.instance.primaryFocus?.unfocus();
  });
}

class _SheetKeyboardDismiss extends StatelessWidget {
  const _SheetKeyboardDismiss({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.deferToChild,
      child: child,
    );
  }
}
