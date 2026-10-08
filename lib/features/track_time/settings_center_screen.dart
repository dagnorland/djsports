import 'package:djsports/features/track_time/tabs/apple_music_diagnostics_tab.dart';
import 'package:djsports/features/track_time/tabs/playlists_tab.dart';
import 'package:djsports/features/track_time/tabs/settings_tab.dart';
import 'package:djsports/features/track_time/tabs/spotify_diagnostics_tab.dart';
import 'package:djsports/features/track_time/tabs/start_time_tab.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TrackTimeCenterScreen extends StatelessWidget {
  const TrackTimeCenterScreen({super.key, this.refreshCallback});

  final VoidCallback? refreshCallback;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              refreshCallback?.call();
            },
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 30),
          ),
          title: const Text(
            'Settings',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          // Playlists and Start times are old and on their way out: tucked
          // away under ⋮ instead of taking a tab each.
          actions: [
            PopupMenuButton<_LegacyPage>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              tooltip: 'More',
              onSelected: (page) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _LegacyScreen(page: page)),
              ),
              itemBuilder: (_) => [
                for (final page in _LegacyPage.values)
                  PopupMenuItem(
                    value: page,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(page.icon),
                      title: Text(page.title),
                      subtitle: const Text('Legacy – will be removed'),
                    ),
                  ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
              Tab(icon: FaIcon(FontAwesomeIcons.spotify), text: 'Spotify'),
              Tab(icon: FaIcon(FontAwesomeIcons.apple), text: 'Apple Music'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SettingsTab(),
            SpotifyDiagnosticsTab(),
            AppleMusicDiagnosticsTab(),
          ],
        ),
      ),
    );
  }
}

/// The old Settings tabs, now under ⋮ → their own page.
enum _LegacyPage {
  playlists('Playlists', Icons.queue_music),
  startTimes('Start times', Icons.timer);

  const _LegacyPage(this.title, this.icon);

  final String title;
  final IconData icon;
}

class _LegacyScreen extends StatelessWidget {
  const _LegacyScreen({required this.page});

  final _LegacyPage page;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('${page.title} (legacy)'),
      ),
      body: switch (page) {
        _LegacyPage.playlists => const PlaylistsTab(),
        _LegacyPage.startTimes => const StartTimeTab(),
      },
    );
  }
}
