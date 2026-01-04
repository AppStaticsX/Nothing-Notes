import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:toastification/toastification.dart';

enum Severity { error, warning, info, success }

Future<void> showSnackBar(
  BuildContext context,
  String message,
  Severity severity, {
  Alignment alignment = Alignment.bottomCenter,
  bool showIcon = true,
  bool showProgressIndicator = false,
}) async {
  IconData iconData;
  Color iconColor;

  switch (severity) {
    case Severity.error:
      iconData = Iconsax.warning_2;
      iconColor = Colors.red;
      break;
    case Severity.warning:
      iconData = Iconsax.danger;
      iconColor = Colors.yellow;
      break;
    case Severity.info:
      iconData = Iconsax.info_circle;
      iconColor = Colors.blue;
      break;
    case Severity.success:
      iconData = Iconsax.tick_circle;
      iconColor = Colors.green;
      break;
  }

  toastification.show(
    context: context,
    title: Text(
      message,
      maxLines: 5,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white, fontSize: 16),
      textScaler: const TextScaler.linear(1),
    ),
    borderSide: const BorderSide(color: Colors.white54, width: 0.5),
    borderRadius: SmoothBorderRadius(cornerRadius: 20, cornerSmoothing: 1),
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    type: ToastificationType.defaultValues[severity.index],
    style: ToastificationStyle.flat,
    autoCloseDuration: const Duration(seconds: 3),
    applyBlurEffect: true,
    backgroundColor: const Color(0xFF1C1C1C),
    icon: showIcon ? Icon(iconData, size: 25, color: iconColor) : null,
    showProgressBar: showProgressIndicator,
    progressBarTheme: ProgressIndicatorThemeData(
      color: iconColor,
      linearTrackColor: iconColor.withValues(alpha: 0.3),
    ),
    closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
    closeOnClick: true,
    dragToClose: true,
  );
}
