import 'package:djsports/data/repo/app_settings_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Notifier mirroring [AppSettings.fadeVolumeMs] so the Let's Play screen
/// rebuilds when the user changes the fade duration in Settings.
///
/// `state` value semantics:
///   * `0`            — fade disabled, fade pause button hidden.
///   * `>0`           — fade-out duration in milliseconds when the fade
///                      pause button is pressed.
class FadeVolumeMsNotifier extends Notifier<int> {
  @override
  int build() => AppSettings.fadeVolumeMs;

  Future<void> setMs(int value) async {
    final clamped = value.clamp(0, AppSettings.fadeVolumeMaxMs);
    await AppSettings.setFadeVolumeMs(clamped);
    state = clamped;
  }
}

final fadeVolumeMsProvider = NotifierProvider<FadeVolumeMsNotifier, int>(
  FadeVolumeMsNotifier.new,
);
