import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:djsports/features/track_time/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SpotifyDiagnosticsTab extends StatefulHookConsumerWidget {
  const SpotifyDiagnosticsTab({super.key});

  @override
  ConsumerState<SpotifyDiagnosticsTab> createState() =>
      _SpotifyDiagnosticsTabState();
}

class _SpotifyDiagnosticsTabState extends ConsumerState<SpotifyDiagnosticsTab> {
  bool _diagRunning = false;
  String _diagLastResult = '';
  Map<String, String> _nativeDebugInfo = {};
  bool _nativeDebugLoading = false;
  final _diagTestUriController = TextEditingController(
    text: 'spotify:track:4uLU6hMCjMI75M1A2tKUQC',
  );

  @override
  void dispose() {
    _diagTestUriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(spotifyRemoteRepositoryProvider);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            globalInfoBox(
              context,
              'SPOTIFY ACCOUNT',
              _accountSection(repo),
            ),
            const Gap(20),
            globalInfoBox(
              context,
              'SPOTIFY DIAGNOSTIC',
              _diagSection(context, repo),
            ),
            const Gap(20),
          ],
        ),
      ),
    );
  }

  Widget _accountSection(SpotifyRemoteRepository repo) {
    return ValueListenableBuilder<String>(
      valueListenable: repo.spotifyUserIdNotifier,
      builder: (context, userId, _) {
        final displayName = repo.spotifyUserDisplayName;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _accountRow(
                icon: Icons.person_outline,
                label: 'Display name',
                value: displayName.isEmpty ? '— not connected' : displayName,
                valueColor: displayName.isEmpty ? Colors.black38 : Colors.black87,
              ),
              const SizedBox(height: 8),
              _accountRow(
                icon: Icons.badge_outlined,
                label: 'User ID',
                value: userId.isEmpty ? '— not connected' : userId,
                valueColor: userId.isEmpty ? Colors.black38 : Colors.black54,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _accountRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black45),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(fontSize: 13, color: valueColor),
          ),
        ),
      ],
    );
  }

  Widget _diagSection(BuildContext context, SpotifyRemoteRepository repo) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spotify testing and troubleshooting. Use with caution.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const Gap(8),
          _diagStateCard(context, repo),
          const Gap(8),
          _nativeDebugCard(context),
          const Gap(12),
          sectionButton(
            context,
            label: 'Reset all  (clear session + caches)',
            icon: Icons.restart_alt,
            disabled: _diagRunning,
            destructive: true,
            onPressed: _diagReset,
          ),
          const Gap(8),
          sectionButton(
            context,
            label: 'Change Spotify account  (new login)',
            icon: Icons.switch_account,
            disabled: _diagRunning,
            onPressed: _diagReGrant,
          ),
          const Gap(12),
          const Divider(),
          const Gap(6),
          Text(
            'Step-by-step connect:',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(8),
          _diagButton(
            context,
            'Step 1: Get Access Token',
            Icons.key,
            _diagGetToken,
          ),
          const Gap(6),
          _diagButton(
            context,
            'Step 2: Connect Remote',
            Icons.link,
            _diagConnectRemote,
          ),
          const Gap(6),
          _diagButton(
            context,
            'Full Connect  (step 1 + 2)',
            Icons.wifi,
            _diagFullConnect,
          ),
          const Gap(6),
          _diagButton(
            context,
            'Force Full Reconnect',
            Icons.refresh,
            _diagForceReconnect,
          ),
          const Gap(12),
          const Divider(),
          const Gap(6),
          Text(
            'Playback:',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(8),
          TextField(
            controller: _diagTestUriController,
            decoration: const InputDecoration(
              labelText: 'Test track Spotify URI',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const Gap(6),
          _diagButton(
            context,
            'Step 3: Play Track',
            Icons.play_arrow,
            _diagPlay,
          ),
          const Gap(6),
          _diagButton(
            context,
            'Step 4: Seek to 30 s',
            Icons.fast_forward,
            _diagSeek,
          ),
          const Gap(6),
          _diagButton(context, 'Step 5: Pause', Icons.pause, _diagPause),
          const Gap(6),
          _diagButton(
            context,
            'Step 6: Resume',
            Icons.play_circle,
            _diagResume,
          ),
          if (_diagLastResult.isNotEmpty) ...[
            const Gap(12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Last result:\n$_diagLastResult',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ],
          const Gap(12),
          const Divider(),
          const Gap(6),
          _diagLogHeader(context),
          const Gap(6),
          _diagLogView(context),
        ],
      ),
    );
  }

  Widget _diagStateCard(BuildContext context, SpotifyRemoteRepository repo) {
    String tokenInfo;
    if (repo.lastValidAccessToken.isEmpty) {
      tokenInfo = '(none)';
    } else {
      final t = repo.lastValidAccessToken;
      tokenInfo = '${t.substring(0, t.length.clamp(0, 16))}…';
    }

    String connTime;
    if (repo.lastConnectionTime.year == 1970) {
      connTime = 'never';
    } else {
      final age = DateTime.now().difference(repo.lastConnectionTime);
      if (age.inSeconds < 60) {
        connTime = '${age.inSeconds}s ago';
      } else {
        connTime = '${age.inMinutes}m ago';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current State',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(6),
          _diagStateRow(
            'hasToken',
            repo.hasSpotifyAccessToken ? 'true' : 'false',
            repo.hasSpotifyAccessToken ? Colors.green : Colors.red,
          ),
          _diagStateRow(
            'isConnectedRemote',
            repo.isConnectedRemote ? 'true' : 'false',
            repo.isConnectedRemote ? Colors.green : Colors.red,
          ),
          _diagStateRow(
            'isPlaying',
            repo.isPlaying ? 'true' : 'false',
            Colors.black54,
          ),
          _diagStateRow('token', tokenInfo, Colors.black54),
          _diagStateRow('lastConnection', connTime, Colors.black54),
          if (repo.spotifyUserDisplayName.isNotEmpty ||
              repo.spotifyUserEmail.isNotEmpty)
            _diagStateRow(
              'account',
              [
                if (repo.spotifyUserDisplayName.isNotEmpty)
                  repo.spotifyUserDisplayName,
                if (repo.spotifyUserEmail.isNotEmpty) repo.spotifyUserEmail,
              ].join('  '),
              Colors.green.shade700,
            ),
          if (repo.spotifyActiveDevices.isNotEmpty)
            _diagStateRow(
              'devices',
              repo.spotifyActiveDevices.join(', '),
              Colors.blue.shade700,
            )
          else if (repo.spotifyUserEmail.isNotEmpty)
            _diagStateRow(
              'devices',
              '⚠️ none found — Spotify may be logged in on a different account',
              Colors.orange.shade800,
            ),
          if (repo.lastConnectError.isNotEmpty)
            _diagStateRow(
              'lastError',
              repo.lastConnectError,
              Colors.red.shade700,
            ),
        ],
      ),
    );
  }

  Widget _diagStateRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nativeDebugCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Native State Snapshot',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.greenAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: _nativeDebugLoading
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.greenAccent,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 14),
                  label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                  onPressed: _nativeDebugLoading ? null : _fetchNativeDebugInfo,
                ),
              ),
            ],
          ),
          if (_nativeDebugInfo.isEmpty && !_nativeDebugLoading)
            const Text(
              'Tap Refresh to snapshot native state',
              style: TextStyle(
                color: Colors.white54,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            )
          else
            ..._nativeDebugInfo.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          color: e.value.contains('⚠️')
                              ? Colors.orangeAccent
                              : e.value == 'true'
                              ? Colors.greenAccent
                              : e.value == 'false'
                              ? Colors.white54
                              : Colors.cyanAccent,
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _diagLogHeader(BuildContext context) {
    return Row(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: SpotifyConnectionLog().changeCount,
          builder: (context, value, child) => Text(
            'Log  (${SpotifyConnectionLog().log.length} entries)',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            SpotifyConnectionLog().clear();
            setState(() {});
          },
          icon: const Icon(Icons.clear_all, size: 16),
          label: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _diagLogView(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SpotifyConnectionLog().changeCount,
      builder: (context, value, child) {
        final entries = SpotifyConnectionLog().log.reversed.toList();
        if (entries.isEmpty) {
          return Container(
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'No log entries yet',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          );
        }
        return Container(
          height: 320,
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(6),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (ctx, i) => _diagLogEntry(entries[i]),
          ),
        );
      },
    );
  }

  Widget _diagLogEntry(SpotifyConnectionLogEntry e) {
    Color statusColor;
    String statusIcon;
    switch (e.status) {
      case SpotifyConnectionStatus.connectedSpotifyRemoteApp:
        statusColor = Colors.greenAccent;
        statusIcon = '●';
      case SpotifyConnectionStatus.connectedSpotify:
        statusColor = Colors.orange;
        statusIcon = '●';
      case SpotifyConnectionStatus.tokenExpired:
        statusColor = Colors.amber;
        statusIcon = '●';
      case SpotifyConnectionStatus.notConnected:
        statusColor = Colors.redAccent;
        statusIcon = '●';
    }
    final ts =
        '${e.timestamp.hour.toString().padLeft(2, '0')}:'
        '${e.timestamp.minute.toString().padLeft(2, '0')}:'
        '${e.timestamp.second.toString().padLeft(2, '0')}.'
        '${(e.timestamp.millisecond ~/ 10).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ts,
            style: const TextStyle(
              color: Colors.grey,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(statusIcon, style: TextStyle(color: statusColor, fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              e.message,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _diagRunning
              ? Colors.teal.withOpacity(0.3)
              : Colors.teal.shade700,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: _diagRunning ? null : onPressed,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _diagDone(String result) {
    if (mounted) {
      setState(() {
        _diagLastResult = result;
        _diagRunning = false;
      });
    }
  }

  Future<void> _fetchNativeDebugInfo() async {
    setState(() => _nativeDebugLoading = true);
    try {
      final info = await ref
          .read(spotifyRemoteRepositoryProvider)
          .getNativeDebugInfo();
      setState(() => _nativeDebugInfo = info);
    } catch (e) {
      setState(() => _nativeDebugInfo = {'error': e.toString()});
    } finally {
      setState(() => _nativeDebugLoading = false);
    }
  }

  Future<void> _diagReset() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      _diagDone(await repo.resetAll());
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagReGrant() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final ok = await repo.reGrantSpotify();
      _diagDone(
        ok
            ? 'Re-granted OK — account: ${repo.spotifyUserDisplayName} '
                  '${repo.spotifyUserEmail}'
            : 'Re-grant FAILED  error=${repo.lastConnectError}',
      );
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagGetToken() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final ok = await repo.connectAccessToken();
      final t = repo.lastValidAccessToken;
      final prefix = t.substring(0, t.length.clamp(0, 12));
      _diagDone(
        ok
            ? 'Token OK  prefix=$prefix'
            : 'Token FAILED  error=${repo.lastConnectError}',
      );
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagConnectRemote() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final ok = await repo.connectToSpotifyRemote();
      _diagDone(
        ok
            ? 'Remote connected!'
            : 'Remote FAILED  error=${repo.lastConnectError}',
      );
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagFullConnect() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final ok = await repo.connect();
      _diagDone(
        ok
            ? 'Full connect OK'
            : 'Full connect FAILED  '
                  'hasToken=${repo.hasSpotifyAccessToken} '
                  'remote=${repo.isConnectedRemote}',
      );
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagForceReconnect() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final ok = await repo.forceFullReconnect();
      _diagDone(
        ok
            ? 'Force reconnect OK'
            : 'Force reconnect FAILED  error=${repo.lastConnectError}',
      );
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagPlay() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      _diagDone(await repo.playTrack(_diagTestUriController.text.trim()));
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagSeek() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      await repo.playTrackByUriAndJumpStart(
        _diagTestUriController.text.trim(),
        30000,
      );
      _diagDone('Play+seek to 30s done');
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagPause() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      await repo.pausePlayer();
      _diagDone('Pause sent');
    } catch (e) {
      _diagDone('Error: $e');
    }
  }

  Future<void> _diagResume() async {
    if (_diagRunning) return;
    setState(() => _diagRunning = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      await repo.resumePlayer();
      _diagDone('Resume sent');
    } catch (e) {
      _diagDone('Error: $e');
    }
  }
}
