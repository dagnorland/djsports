import 'dart:io';

import 'package:djsports/data/provider/fade_volume_provider.dart';
import 'package:djsports/data/repo/app_settings_repository.dart';
import 'package:djsports/features/spotify_connect/spotify_credentials_settings.dart';
import 'package:djsports/features/track_time/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsTab extends StatefulHookConsumerWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            globalInfoBox(
              context,
              "LET'S PLAY SETTINGS",
              _matchCenterSettingsSection(context),
            ),
            const Gap(20),
            globalInfoBox(
              context,
              'SPOTIFY ACCOUNT',
              const SpotifyCredentialsSettings(),
            ),
            const Gap(20),
          ],
        ),
      ),
    );
  }

  Widget _matchCenterSettingsSection(BuildContext context) {
    final sidebarPosition = AppSettings.sidebarPosition;
    final keyboardShortcuts = AppSettings.keyboardShortcutsEnabled;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.view_sidebar),
          title: const Text("Let's Play controls"),
          subtitle: Text(
            'On wide screens. Bottom needs a tall enough window – '
            'otherwise the controls go to the right.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<SidebarPosition>(
            segments: const [
              ButtonSegment(
                value: SidebarPosition.left,
                icon: Icon(Icons.align_horizontal_left),
                label: Text('Left'),
              ),
              ButtonSegment(
                value: SidebarPosition.right,
                icon: Icon(Icons.align_horizontal_right),
                label: Text('Right'),
              ),
              ButtonSegment(
                value: SidebarPosition.bottom,
                icon: Icon(Icons.align_vertical_bottom),
                label: Text('Bottom'),
              ),
            ],
            selected: {sidebarPosition},
            onSelectionChanged: (selection) async {
              await AppSettings.setSidebarPosition(selection.first);
              setState(() {});
            },
          ),
        ),
        SwitchListTile(
          title: const Text('Keyboard shortcuts in match center'),
          subtitle: Text(
            keyboardShortcuts
                ? 'Playlists: Hotspot 1-6  •  Match Q-Y  •  Fun A-H\n'
                      'Transport: P=play  •  ESC=pause  •  +=vol+  •  -=vol-'
                : 'Enable to use keyboard keys to trigger playlists',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          secondary: const Icon(Icons.keyboard),
          value: keyboardShortcuts,
          onChanged: (value) async {
            await AppSettings.setKeyboardShortcutsEnabled(value);
            setState(() {});
          },
        ),
        const _FadeVolumeSetting(),
        SwitchListTile(
          title: const Text('Show info messages'),
          subtitle: Text(
            'Pop-ups like "PAUSED", "FADED" and the track that started. '
            'Warnings and errors always show.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          secondary: const Icon(Icons.info_outline),
          value: AppSettings.showInfoToasts,
          onChanged: (value) async {
            await AppSettings.setShowInfoToasts(value);
            setState(() {});
          },
        ),
        if (Platform.isAndroid || Platform.isIOS)
          SwitchListTile(
            title: const Text('Show system volume popup'),
            subtitle: Text(
              'When djSports changes the volume (+/−, fade). Off keeps it '
              'from covering the Let\'s Play sidebar. On Android the '
              'hardware buttons always show it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            secondary: const Icon(Icons.volume_up),
            value: AppSettings.showSystemVolumeUI,
            onChanged: (value) async {
              await AppSettings.setShowSystemVolumeUI(value);
              setState(() {});
            },
          ),
      ],
    );
  }
}

/// Platform-specific helper text that explains what the fade actually
/// controls. On macOS the fade hits both the Mac master volume and the
/// Spotify Connect device volume (Web API), so it works for remote
/// speakers too. On iOS/Android the fade only adjusts system volume.
String _fadeHelperText(int ms) {
  if (Platform.isMacOS) {
    return 'Tap the fade pause button in Let\'s Play to fade out over '
        '$ms ms. Adjusts both Mac volume and the active Spotify Connect '
        'device.';
  }
  return 'Tap the fade pause button in Let\'s Play to fade out over '
      '$ms ms. Adjusts system volume — Spotify Connect remote devices '
      'are not affected.';
}

/// Slider that controls [AppSettings.fadeVolumeMs] via [fadeVolumeMsProvider].
///
/// Setting `0` hides the fade pause button in the Let's Play screen.
class _FadeVolumeSetting extends ConsumerWidget {
  const _FadeVolumeSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ms = ref.watch(fadeVolumeMsProvider);
    final enabled = ms > 0;

    // Android system volume is a 15-step discrete ladder — short fades
    // sound stepped. We don't hard-clamp the value (advanced users may
    // still want short fades) but we surface a hint.
    final showAndroidHint = Platform.isAndroid && enabled && ms < 750;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                enabled ? Icons.volume_off : Icons.volume_off_outlined,
                size: 22,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Fade volume on pause',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              Text(
                enabled ? '$ms ms' : 'Off',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).disabledColor,
                ),
              ),
            ],
          ),
          Slider(
            min: 0,
            max: AppSettings.fadeVolumeMaxMs.toDouble(),
            divisions: AppSettings.fadeVolumeMaxMs ~/ 100,
            value: ms.toDouble().clamp(
              0.0,
              AppSettings.fadeVolumeMaxMs.toDouble(),
            ),
            label: enabled ? '$ms ms' : 'Off',
            onChanged: (v) =>
                ref.read(fadeVolumeMsProvider.notifier).setMs(v.round()),
          ),
          Text(
            enabled
                ? _fadeHelperText(ms)
                : 'When enabled, shows an extra fade pause button in '
                      'Let\'s Play that ramps the volume to 0 before '
                      'pausing.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (showAndroidHint) ...[
            const Gap(4),
            Text(
              'Note: Android system volume has 15 discrete steps — fades '
              'under ~750 ms can sound stepped.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }
}
