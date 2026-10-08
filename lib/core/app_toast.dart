import 'package:djsports/data/repo/app_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// How important a toast is. Info toasts are hidden unless "Show info
/// messages" is on; warnings and errors always show.
enum ToastLevel { info, warning, error }

/// The one way the live screens (Let's Play, the control column) show a
/// toast, so the "Show info messages" setting applies everywhere.
void showAppToast(
  BuildContext context, {
  required Widget title,
  Widget? description,
  ToastLevel level = ToastLevel.info,
  Duration? duration,
}) {
  if (level == ToastLevel.info && !AppSettings.showInfoToasts) return;
  toastification.show(
    context: context,
    type: switch (level) {
      ToastLevel.info => ToastificationType.info,
      ToastLevel.warning => ToastificationType.warning,
      ToastLevel.error => ToastificationType.error,
    },
    title: title,
    description: description,
    autoCloseDuration:
        duration ?? Duration(seconds: level == ToastLevel.info ? 3 : 5),
    style: ToastificationStyle.flat,
    alignment: Alignment.topCenter,
  );
}
