import 'package:djsports/data/models/apple_music_log.dart';
import 'package:djsports/data/provider/apple_music_provider.dart';
import 'package:djsports/data/repo/apple_music_repository.dart';
import 'package:djsports/features/track_time/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AppleMusicDiagnosticsTab extends StatefulHookConsumerWidget {
  const AppleMusicDiagnosticsTab({super.key});

  @override
  ConsumerState<AppleMusicDiagnosticsTab> createState() =>
      _AppleMusicDiagnosticsTabState();
}

class _AppleMusicDiagnosticsTabState
    extends ConsumerState<AppleMusicDiagnosticsTab> {
  bool _running = false;
  String _lastResult = '';
  String _authStatus = '—';
  bool _isSubscribed = false;
  bool _isAuthorized = false;

  final _playlistIdController = TextEditingController(
    text: 'pl.u-KVXBYRWuldBBP',
  );
  final _searchController = TextEditingController(text: 'Darude Sandstorm');

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _playlistIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final repo = ref.read(appleMusicRepositoryProvider);
    setState(() {
      _isAuthorized = repo.isAuthorized;
      _isSubscribed = repo.isSubscribed;
      _authStatus = repo.isAuthorized ? 'authorized' : 'not authorized';
    });
  }

  void _done(String result) {
    if (mounted) {
      setState(() {
        _lastResult = result;
        _running = false;
      });
      _refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(appleMusicRepositoryProvider);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            globalInfoBox(
              context,
              'APPLE MUSIC STATUS',
              _statusCard(repo),
            ),
            const Gap(20),
            globalInfoBox(
              context,
              'APPLE MUSIC DIAGNOSTIC',
              _diagSection(context),
            ),
            const Gap(20),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(AppleMusicRepository repo) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _stateRow('authorized', _isAuthorized ? 'true' : 'false',
              _isAuthorized ? Colors.green : Colors.red),
          _stateRow('subscribed', _isSubscribed ? 'true' : 'false',
              _isSubscribed ? Colors.green : Colors.orange),
          _stateRow('authStatus', _authStatus, Colors.black54),
          if (repo.lastError.isNotEmpty)
            _stateRow('lastError', repo.lastError, Colors.red.shade700),
        ],
      ),
    );
  }

  Widget _stateRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  Widget _diagSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apple Music testing and troubleshooting.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.pink.shade700,
            ),
          ),
          const Gap(12),
          _diagButton(
            context,
            'Step 1: Get Authorization Status',
            Icons.info_outline,
            _stepGetStatus,
          ),
          const Gap(6),
          _diagButton(
            context,
            'Step 2: Authorize / Connect',
            Icons.lock_open,
            _stepAuthorize,
          ),
          const Gap(6),
          _diagButton(
            context,
            'Step 3: Check Subscription',
            Icons.subscriptions_outlined,
            _stepCheckSubscription,
          ),
          const Gap(12),
          const Divider(),
          const Gap(6),
          Text(
            'Search:',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search query',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const Gap(6),
          _diagButton(
            context,
            'Step 4: Search Catalog',
            Icons.search,
            _stepSearch,
          ),
          const Gap(12),
          const Divider(),
          const Gap(6),
          Text(
            'Playlist Sync:',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          TextField(
            controller: _playlistIdController,
            decoration: const InputDecoration(
              labelText: 'Apple Music playlist ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const Gap(6),
          _diagButton(
            context,
            'Step 5: Sync Playlist',
            Icons.sync,
            _stepSyncPlaylist,
          ),
          if (_lastResult.isNotEmpty) ...[
            const Gap(12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                'Last result:\n$_lastResult',
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
          _logHeader(),
          const Gap(6),
          _logView(),
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
          backgroundColor: _running
              ? Colors.pink.withOpacity(0.3)
              : Colors.pink.shade700,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          alignment: Alignment.centerLeft,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: _running ? null : onPressed,
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

  Widget _logHeader() {
    return Row(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: AppleMusicLog().changeCount,
          builder: (context, value, _) => Text(
            'Log  (${AppleMusicLog().log.length} entries)',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            AppleMusicLog().clear();
            setState(() {});
          },
          icon: const Icon(Icons.clear_all, size: 16),
          label: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _logView() {
    return ValueListenableBuilder<int>(
      valueListenable: AppleMusicLog().changeCount,
      builder: (context, _, _a) {
        final entries = AppleMusicLog().log.reversed.toList();
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
          height: 300,
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(6),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (ctx, i) => _logEntry(entries[i]),
          ),
        );
      },
    );
  }

  Widget _logEntry(AppleMusicLogEntry e) {
    final isError = e.level == AppleMusicLogLevel.error;
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
          Text(
            isError ? '✖' : '●',
            style: TextStyle(
              color: isError ? Colors.redAccent : Colors.greenAccent,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText(
              e.message,
              style: TextStyle(
                color: isError ? Colors.orangeAccent : Colors.white,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _stepGetStatus() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final repo = ref.read(appleMusicRepositoryProvider);
      // Access bridge directly via connect which calls getAuthorizationStatus
      final ok = await repo.connect();
      _done('authStatus check done — authorized=$ok '
          'subscribed=${repo.isSubscribed}');
    } catch (e) {
      _done('Error: $e');
    }
  }

  Future<void> _stepAuthorize() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final repo = ref.read(appleMusicRepositoryProvider);
      final ok = await repo.connect();
      _done(ok
          ? 'Authorized + subscribed OK'
          : 'Failed — authorized=${repo.isAuthorized} '
              'subscribed=${repo.isSubscribed} '
              'error=${repo.lastError}');
    } catch (e) {
      _done('Error: $e');
    }
  }

  Future<void> _stepCheckSubscription() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final repo = ref.read(appleMusicRepositoryProvider);
      final ok = await repo.connect();
      _done('subscribed=${repo.isSubscribed} authorized=${repo.isAuthorized} '
          'connect=$ok');
    } catch (e) {
      _done('Error: $e');
    }
  }

  Future<void> _stepSearch() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final repo = ref.read(appleMusicRepositoryProvider);
      final results = await repo.search(_searchController.text.trim());
      if (results.isEmpty) {
        _done('Search returned 0 results. '
            'lastError=${repo.lastError}');
      } else {
        final preview = results
            .take(3)
            .map((t) => '  • ${t.name} — ${t.artist}')
            .join('\n');
        _done('Got ${results.length} results:\n$preview');
      }
    } catch (e) {
      _done('Error: $e');
    }
  }

  Future<void> _stepSyncPlaylist() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final repo = ref.read(appleMusicRepositoryProvider);
      final id = _playlistIdController.text.trim();
      final result = await repo.syncPlaylist(id);
      if (result.tracks.isEmpty) {
        _done('Playlist "${result.playlistName}" returned 0 tracks. '
            'error=${repo.lastError}');
      } else {
        final preview = result.tracks
            .take(3)
            .map((t) => '  • ${t.name} — ${t.artist}')
            .join('\n');
        _done('Playlist "${result.playlistName}": '
            '${result.tracks.length} tracks\n$preview');
      }
    } catch (e) {
      _done('Error: $e');
    }
  }
}
