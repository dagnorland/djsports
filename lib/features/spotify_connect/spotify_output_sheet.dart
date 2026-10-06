import 'dart:io';

import 'package:djsports/data/models/spotify_device.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Runs [play]; when it fails because no usable Spotify device exists
/// (`[Error][NoDevice]`), asks the user where to play, remembers the choice and
/// retries once. Returns the final play result string.
Future<String> playWithDevicePrompt(
  BuildContext context,
  WidgetRef ref,
  Future<String> Function() play,
) async {
  final result = await play();
  if (!isNoDeviceResult(result) || !context.mounted) return result;
  final chosen = await showSpotifyDevicePicker(
    context,
    message: playResultMessage(result),
  );
  if (!chosen) return result;
  return play();
}

bool isNoDeviceResult(String result) => result.contains('[NoDevice]');

bool isPremiumResult(String result) => result.contains('[Premium]');

/// The human part of a play result, without `[Error][…]` tags.
String playResultMessage(String result) =>
    result.replaceAll(RegExp(r'^(\[\w+\])+\s*'), '');

/// Dialog: "Where should djSports play?". Returns true when a device was
/// picked (and saved as the preferred device).
Future<bool> showSpotifyDevicePicker(
  BuildContext context, {
  String? message,
}) async {
  final picked = await showDialog<bool>(
    context: context,
    builder: (_) => _DevicePickerDialog(message: message),
  );
  return picked ?? false;
}

void showSpotifyOutputSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const SpotifyOutputSheet(),
  );
}

String get _localLabel => Platform.isMacOS ? 'This Mac' : 'This iPhone';

// ── Status chip ───────────────────────────────────────────────────────────

/// AppBar indicator: Spotify icon coloured by status, optionally with
/// "account → device". Tap opens the Spotify output sheet.
class SpotifyStatusChip extends ConsumerWidget {
  const SpotifyStatusChip({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(spotifyRemoteRepositoryProvider);
    return ValueListenableBuilder<SpotifySession>(
      valueListenable: repo.sessionNotifier,
      builder: (context, session, _) {
        final view = _StatusView.of(session);
        final icon = FaIcon(
          FontAwesomeIcons.spotify,
          color: view.color,
          size: 20,
        );
        return Tooltip(
          message: view.tooltip,
          child: compact
              ? IconButton(
                  icon: icon,
                  onPressed: () => showSpotifyOutputSheet(context),
                )
              : TextButton.icon(
                  icon: icon,
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      view.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: view.color, fontSize: 13),
                    ),
                  ),
                  onPressed: () => showSpotifyOutputSheet(context),
                ),
        );
      },
    );
  }
}

class _StatusView {
  const _StatusView(this.color, this.label, this.tooltip);

  factory _StatusView.of(SpotifySession s) {
    final who = s.account?.label ?? '';
    final green = Colors.green.shade700;
    final amber = Colors.orange.shade800;
    final red = Colors.red.shade700;
    if (s.account != null && !s.account!.premiumOrUnknown) {
      return _StatusView(
        red,
        '$who · Premium required',
        'Spotify Premium '
            'is required to control playback',
      );
    }
    final target = s.targetDevice;
    final where = target == null
        ? ''
        : s.isLocal(target)
        ? _localLabel
        : target.name;
    switch (s.status) {
      case SpotifyTargetStatus.notConnected:
        return _StatusView(red, 'Spotify', 'Not connected – tap to connect');
      case SpotifyTargetStatus.unknown:
        return _StatusView(
          Colors.grey,
          who.isEmpty ? 'Spotify' : who,
          'Checking Spotify devices…',
        );
      case SpotifyTargetStatus.preferred:
      case SpotifyTargetStatus.active:
      case SpotifyTargetStatus.thisDevice:
        return _StatusView(
          green,
          '$who → $where',
          'Spotify account: $who\nPlays on: $where',
        );
      case SpotifyTargetStatus.otherAccountSuspected:
        return _StatusView(
          amber,
          '$who → ? (other account)',
          'Spotify on this device seems to be signed in with another '
              'account than $who',
        );
      case SpotifyTargetStatus.willAsk:
        return _StatusView(
          amber,
          '$who → no device',
          'No Spotify device available – djSports will ask on play',
        );
    }
  }

  final Color color;
  final String label;
  final String tooltip;
}

// ── Output sheet ──────────────────────────────────────────────────────────

class SpotifyOutputSheet extends ConsumerStatefulWidget {
  const SpotifyOutputSheet({super.key});

  @override
  ConsumerState<SpotifyOutputSheet> createState() => _SpotifyOutputSheetState();
}

class _SpotifyOutputSheetState extends ConsumerState<SpotifyOutputSheet> {
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _run(() => ref.read(spotifyRemoteRepositoryProvider).refreshDevices());
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await action();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(spotifyRemoteRepositoryProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ValueListenableBuilder<SpotifySession>(
          valueListenable: repo.sessionNotifier,
          builder: (context, session, _) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Spotify output',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _AccountCard(session: session),
                if (session.suspectsOtherAccount)
                  _MismatchBanner(session: session),
                const SizedBox(height: 12),
                _DeviceList(
                  session: session,
                  busy: _busy,
                  onRefresh: () => _run(repo.refreshDevices),
                ),
                if (_error.isNotEmpty) _ErrorText(_error),
                const SizedBox(height: 12),
                _SheetActions(
                  connected: session.connected,
                  onConnect: () => _run(() async {
                    await repo.connect();
                  }),
                  onSwitchAccount: () => _run(() async {
                    await repo.reGrantSpotify();
                  }),
                  onOpenSpotify: () => _run(() async {
                    await repo.launchSpotify();
                    await Future<void>.delayed(const Duration(seconds: 2));
                    await repo.refreshDevices();
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.session});

  final SpotifySession session;

  @override
  Widget build(BuildContext context) {
    final account = session.account;
    final textTheme = Theme.of(context).textTheme;
    if (!session.connected || account == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.person_off_outlined),
          title: const Text('Not logged in to Spotify'),
          subtitle: Text(
            session.connected ? 'Loading account…' : 'Tap Connect below',
          ),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: Text('Logged in as ${account.label}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (account.email.isNotEmpty) Text(account.email),
            Text('User id: ${account.id}', style: textTheme.bodySmall),
          ],
        ),
        trailing: _ProductBadge(product: account.product),
      ),
    );
  }
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge({required this.product});

  final String product;

  @override
  Widget build(BuildContext context) {
    if (product.isEmpty) return const SizedBox.shrink();
    final premium = product == 'premium';
    return Chip(
      label: Text(premium ? 'Premium' : 'Premium required'),
      backgroundColor: premium ? Colors.green.shade100 : Colors.red.shade100,
    );
  }
}

class _MismatchBanner extends StatelessWidget {
  const _MismatchBanner({required this.session});

  final SpotifySession session;

  @override
  Widget build(BuildContext context) {
    final who = session.account?.label ?? 'this account';
    return Card(
      color: Colors.orange.shade50,
      child: ListTile(
        leading: Icon(Icons.warning_amber, color: Colors.orange.shade800),
        title: const Text('Spotify on this Mac uses another account?'),
        subtitle: Text(
          'Spotify is running here, but "${session.localDeviceName}" is not '
          'in $who\'s device list. Sign the Spotify app in as $who, or use '
          '"Switch Spotify account" to log djSports in with the account the '
          'Spotify app uses.',
        ),
      ),
    );
  }
}

class _DeviceList extends ConsumerWidget {
  const _DeviceList({
    required this.session,
    required this.busy,
    required this.onRefresh,
  });

  final SpotifySession session;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    final target = session.targetDevice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Play on',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh devices',
                onPressed: onRefresh,
              ),
          ],
        ),
        _DeviceTile(
          icon: Icons.auto_mode,
          title: 'Spotify\'s active device',
          subtitle: session.activeDevice == null
              ? 'None active – djSports will ask'
              : 'Now: ${session.activeDevice!.name}',
          selected: session.preferredDeviceId.isEmpty,
          onTap: () => repo.setPreferredDevice(null),
        ),
        if (session.preferredDeviceId.isNotEmpty &&
            session.preferredDevice == null)
          _DeviceTile(
            icon: Icons.portable_wifi_off,
            title: session.preferredDeviceName.isEmpty
                ? 'Selected device'
                : session.preferredDeviceName,
            subtitle: 'Not available right now – djSports will ask',
            selected: true,
            onTap: () {},
          ),
        for (final device in session.devices)
          _DeviceTile(
            icon: _iconFor(device),
            title: device.name,
            subtitle: [
              if (session.isLocal(device)) _localLabel,
              device.type,
              if (device.isActive) 'active',
              if (device.isRestricted) 'restricted',
              if (device == target && session.preferredDeviceId.isEmpty)
                'will play here',
            ].join(' · '),
            selected: device.id == session.preferredDeviceId,
            onTap: () => repo.setPreferredDevice(device),
          ),
        if (session.devicesLoaded && session.devices.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'No Spotify devices found for this account. Open Spotify on '
              'the device you want to use, then refresh.',
            ),
          ),
      ],
    );
  }
}

IconData _iconFor(SpotifyDevice device) {
  switch (device.type.toLowerCase()) {
    case 'computer':
      return Icons.computer;
    case 'smartphone':
      return Icons.smartphone;
    case 'tablet':
      return Icons.tablet;
    case 'speaker':
      return Icons.speaker;
    case 'tv':
      return Icons.tv;
    default:
      return Icons.devices_other;
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Colors.green.shade700 : null,
      ),
      onTap: onTap,
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({
    required this.connected,
    required this.onConnect,
    required this.onSwitchAccount,
    required this.onOpenSpotify,
  });

  final bool connected;
  final VoidCallback onConnect;
  final VoidCallback onSwitchAccount;
  final VoidCallback onOpenSpotify;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!connected)
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Connect'),
            onPressed: onConnect,
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.switch_account),
          label: const Text('Switch Spotify account'),
          onPressed: onSwitchAccount,
        ),
        OutlinedButton.icon(
          icon: const FaIcon(FontAwesomeIcons.spotify, size: 16),
          label: const Text('Open Spotify'),
          onPressed: onOpenSpotify,
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SelectableText.rich(
        TextSpan(
          text: message,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

// ── Play-time device picker ───────────────────────────────────────────────

class _DevicePickerDialog extends ConsumerStatefulWidget {
  const _DevicePickerDialog({this.message});

  final String? message;

  @override
  ConsumerState<_DevicePickerDialog> createState() =>
      _DevicePickerDialogState();
}

class _DevicePickerDialogState extends ConsumerState<_DevicePickerDialog> {
  bool _busy = false;

  Future<void> _refresh({bool openSpotify = false}) async {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    setState(() => _busy = true);
    if (openSpotify) {
      await repo.launchSpotify();
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    await repo.refreshDevices();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(spotifyRemoteRepositoryProvider);
    return ValueListenableBuilder<SpotifySession>(
      valueListenable: repo.sessionNotifier,
      builder: (context, session, _) {
        final who = session.account?.label ?? 'your account';
        return AlertDialog(
          title: const Text('Where should djSports play?'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.message != null) Text(widget.message!),
                  Text('Spotify account: $who'),
                  if (session.suspectsOtherAccount)
                    _MismatchBanner(session: session),
                  const SizedBox(height: 8),
                  if (_busy) const LinearProgressIndicator(),
                  for (final device in session.devices)
                    ListTile(
                      leading: Icon(_iconFor(device)),
                      title: Text(device.name),
                      subtitle: Text(
                        [
                          if (session.isLocal(device)) _localLabel,
                          device.type,
                          if (device.isActive) 'active',
                        ].join(' · '),
                      ),
                      onTap: () async {
                        await repo.setPreferredDevice(device);
                        if (context.mounted) Navigator.pop(context, true);
                      },
                    ),
                  if (session.devices.isEmpty && !_busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No Spotify devices found. Open Spotify (signed in '
                        'with the same account) and refresh.',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => _refresh(openSpotify: true),
              child: const Text('Open Spotify'),
            ),
            TextButton(
              onPressed: _busy ? null : _refresh,
              child: const Text('Refresh'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
