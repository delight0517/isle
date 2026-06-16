import 'package:flutter/material.dart';

extension IsleBuildContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  MediaQueryData get media => MediaQuery.of(this);
}
