import 'package:djsports/features/track_time/tabs/playlists_tab.dart';
import 'package:djsports/features/track_time/tabs/settings_tab.dart';
import 'package:djsports/features/track_time/tabs/spotify_diagnostics_tab.dart';
import 'package:djsports/features/track_time/tabs/start_time_tab.dart';
import 'package:flutter/material.dart';

class TrackTimeCenterScreen extends StatelessWidget {
  const TrackTimeCenterScreen({super.key, this.refreshCallback});

  final VoidCallback? refreshCallback;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
              Tab(icon: Icon(Icons.queue_music), text: 'Playlists'),
              Tab(icon: Icon(Icons.timer), text: 'Start times'),
              Tab(icon: Icon(Icons.music_note), text: 'Spotify'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SettingsTab(),
            PlaylistsTab(),
            StartTimeTab(),
            SpotifyDiagnosticsTab(),
          ],
        ),
      ),
    );
  }
}
