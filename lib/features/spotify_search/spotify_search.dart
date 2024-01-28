import 'package:spotify/spotify.dart';
import 'package:djsports/data/services/spotify_search_service.dart';
import 'package:djsports/features/spotify_search/spotify_search_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@Deprecated('Use SpotifySearchDelegate instead')
class SpotifySearchPage extends ConsumerWidget {
  const SpotifySearchPage({super.key});

  void _showSearch(BuildContext context, WidgetRef ref) async {
    final service = ref.read(searchServiceProvider);
    final searchDelegate = SpotifySearchDelegate(service);
    final track = await showSearch<Track?>(
      context: context,
      delegate: searchDelegate,
    );
    //service.dispose();
    if (track != null) {
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Selected track: ${track.name}'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spotify Search'),
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor),
          child: Text(
            'Search',
            style: Theme.of(context)
                .textTheme
                .titleLarge!
                .copyWith(color: Colors.white),
          ),
          onPressed: () => _showSearch(context, ref),
        ),
      ),
    );
  }
}
