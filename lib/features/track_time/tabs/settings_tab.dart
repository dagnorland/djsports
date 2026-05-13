import 'dart:io';

import 'package:djsports/data/provider/fade_volume_provider.dart';
import 'package:djsports/data/provider/theme_color_provider.dart';
import 'package:djsports/data/repo/app_settings_repository.dart';
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
              'DISPLAY SETTINGS',
              _displaySettingsSection(context),
            ),
            const Gap(20),
            globalInfoBox(
              context,
              'LETS PLAY SETTINGS',
              _matchCenterSettingsSection(context),
            ),
            const Gap(20),
          ],
        ),
      ),
    );
  }

  Widget _displaySettingsSection(BuildContext context) {
    final currentColor = ref.watch(themeColorProvider);
    return Column(
      children: [
        _ThemeColorPicker(
          currentColor: currentColor,
          onColorSelected: (Color color) =>
              ref.read(themeColorProvider.notifier).setColor(color),
        ),
      ],
    );
  }

  Widget _matchCenterSettingsSection(BuildContext context) {
    final sidebarOnRight = AppSettings.sidebarOnRight;
    final keyboardShortcuts = AppSettings.keyboardShortcutsEnabled;
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Sidebar on right (if not on bottom)'),
          subtitle: Text(
            sidebarOnRight
                ? 'Controls are on the right side'
                : 'Controls are on the left side',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          secondary: Icon(
            sidebarOnRight
                ? Icons.align_horizontal_right
                : Icons.align_horizontal_left,
          ),
          value: sidebarOnRight,
          onChanged: (value) async {
            await AppSettings.setSidebarOnRight(value);
            setState(() {});
          },
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Standalone color-picker widget
// ---------------------------------------------------------------------------

class _ThemeColorPicker extends StatelessWidget {
  const _ThemeColorPicker({
    required this.currentColor,
    required this.onColorSelected,
  });

  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.palette_outlined, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('App color', style: TextStyle(fontSize: 15)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: kThemeColors.map((entry) {
              final selected = currentColor.value == entry.color.value;
              return Tooltip(
                message: entry.name,
                child: GestureDetector(
                  onTap: () => onColorSelected(entry.color),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: entry.color,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.black, width: 2.5)
                          : Border.all(color: Colors.black12, width: 1),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
