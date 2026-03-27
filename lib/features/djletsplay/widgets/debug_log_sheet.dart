import 'package:djsports/data/models/spotify_connection_log.dart';
import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Bottom sheet showing the Spotify connection log + native state snapshot.
/// Open with [DebugLogSheet.show].
class DebugLogSheet extends ConsumerStatefulWidget {
  const DebugLogSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => const DebugLogSheet(),
    );
  }

  @override
  ConsumerState<DebugLogSheet> createState() => _DebugLogSheetState();
}

class _DebugLogSheetState extends ConsumerState<DebugLogSheet> {
  Map<String, String> _nativeInfo = {};
  List<String> _devices = [];
  bool _loading = false;

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(spotifyRemoteRepositoryProvider);
      final results = await Future.wait([
        repo.getNativeDebugInfo(),
        repo.getActiveDevices().catchError((_) => <String>[]),
      ]);
      if (mounted) {
        setState(() {
          _nativeInfo = results[0] as Map<String, String>;
          _devices = results[1] as List<String>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _nativeInfo = {'error': e.toString()});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenH * 0.8,
      child: Column(
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Debug Log',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                ValueListenableBuilder<int>(
                  valueListenable: SpotifyConnectionLog().changeCount,
                  builder: (ctx, v, child) => Text(
                    '${SpotifyConnectionLog().log.length} entries',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.clear_all, size: 14),
                  label: const Text('Clear', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    SpotifyConnectionLog().clear();
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Native state snapshot
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Native State',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 24,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.greenAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          icon: _loading
                              ? const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.greenAccent,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 12),
                          label: const Text(
                            'Refresh',
                            style: TextStyle(fontSize: 10),
                          ),
                          onPressed: _loading ? null : _refresh,
                        ),
                      ),
                    ],
                  ),
                  if (_nativeInfo.isEmpty && !_loading)
                    const Text(
                      'Loading…',
                      style: TextStyle(
                        color: Colors.white38,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    )
                  else
                    ..._nativeInfo.entries.map(
                      (e) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 150,
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontFamily: 'monospace',
                                fontSize: 10,
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
                                    ? Colors.white38
                                    : Colors.cyanAccent,
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Spotify devices
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.devices,
                        color: Colors.white70,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Spotify Devices',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_loading)
                    const Text(
                      'Loading…',
                      style: TextStyle(
                        color: Colors.white38,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    )
                  else if (_devices.isEmpty)
                    const Text(
                      'No active devices found',
                      style: TextStyle(
                        color: Colors.white38,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    )
                  else
                    ..._devices.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              d.contains('●')
                                  ? Icons.play_circle
                                  : Icons.radio_button_unchecked,
                              size: 10,
                              color: d.contains('●')
                                  ? Colors.greenAccent
                                  : Colors.white38,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                d,
                                style: TextStyle(
                                  color: d.contains('●')
                                      ? Colors.greenAccent
                                      : Colors.white60,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: d.contains('●')
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Log entries
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: SpotifyConnectionLog().changeCount,
              builder: (context2, v, _) {
                final entries =
                    SpotifyConnectionLog().log.reversed.toList();
                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'No log entries yet',
                      style: TextStyle(
                        color: Colors.white38,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _LogEntry(entries[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogEntry extends StatelessWidget {
  const _LogEntry(this.entry);
  final SpotifyConnectionLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String dot;
    switch (entry.status) {
      case SpotifyConnectionStatus.connectedSpotifyRemoteApp:
        color = Colors.greenAccent;
        dot = '●';
      case SpotifyConnectionStatus.connectedSpotify:
        color = Colors.orange;
        dot = '●';
      case SpotifyConnectionStatus.tokenExpired:
        color = Colors.amber;
        dot = '●';
      case SpotifyConnectionStatus.notConnected:
        color = Colors.redAccent;
        dot = '●';
    }
    final ts = '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}.'
        '${(entry.timestamp.millisecond ~/ 10).toString().padLeft(2, '0')}';

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
          Text(dot, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.message,
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
}
