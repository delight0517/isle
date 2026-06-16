import 'package:flutter/material.dart';

class IsleText {
  IsleText._();

  static TextStyle display({Color? color}) => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.56,
        color: color,
      );
  static TextStyle title({Color? color}) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.22,
        color: color,
      );
  static TextStyle subtitle({Color? color}) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle body({Color? color}) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: color,
      );
  static TextStyle caption({Color? color}) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
      );
  static TextStyle badge({Color? color}) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: color,
      );
}
