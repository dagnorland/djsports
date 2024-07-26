import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/features/playlist/djplaylist_edit_create.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_view.dart';
import 'package:djsports/features/playlist/widgets/type_filter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends StatefulHookConsumerWidget {
  const HomePage({super.key});
  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final playlistList = ref.watch(typeFilteredDataProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'djsports',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor),
              child: Text(
                'New playlist',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(color: Colors.white),
              ),
              onPressed: () {
                ref.invalidate(typeFilteredDataProvider);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DJPlaylistEditScreen(
                      id: '',
                      isNew: true,
                      name: '',
                      type: DJPlaylistType.score.name,
                      spotifyUri: '',
                      trackIds: const [],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Flexible(child: TypeFilter()),
          const SizedBox(
            height: 20,
          ),
          playlistList.isEmpty
              ? const Center(
                  child: Text("No data"),
                )
              : Expanded(
                  flex: 10,
                  child: ListView.builder(
                    itemCount: playlistList.length,
                    itemBuilder: (context, index) {
                      return DJPlaylistView(
                        name: playlistList[index].name,
                        type: playlistList[index].type,
                        spotifyUri: playlistList[index].spotifyUri,
                        trackIds: playlistList[index].trackIds,
                        onEdit: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DJPlaylistEditScreen(
                                isNew: false,
                                id: playlistList[index].id,
                                name: playlistList[index].name,
                                type: playlistList[index].type,
                                spotifyUri: playlistList[index].spotifyUri,
                                trackIds: [...playlistList[index].trackIds],
                                refreshCallback: () {
                                  setState(() {});
                                },
                              ),
                            ),
                          );
                        },
                        onDelete: () {
                          ref.read(hivePlaylistData.notifier).removeDJPlaylist(
                              ref.read(hiveTrackData.notifier),
                              playlistList[index].id);
                        },
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
