import 'package:flutter/widgets.dart';

enum AppFormFactor { compact, medium, expanded }

abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
  static const double maxContentWidth = 1440;

  static AppFormFactor fromWidth(double width) {
    if (width >= expanded) return AppFormFactor.expanded;
    if (width >= medium) return AppFormFactor.medium;
    return AppFormFactor.compact;
  }
}

extension AppResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  AppFormFactor get formFactor => AppBreakpoints.fromWidth(screenWidth);

  bool get isCompact => formFactor == AppFormFactor.compact;
  bool get isMedium => formFactor == AppFormFactor.medium;
  bool get isExpanded => formFactor == AppFormFactor.expanded;
}
