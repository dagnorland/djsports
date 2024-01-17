import 'package:djsports/data/provider/djplaylist_provider.dart';
import 'package:djsports/data/provider/djtrack_provider.dart';
import 'package:djsports/features/playlist/djplaylist_create.dart';
import 'package:djsports/features/playlist/widgets/djplaylist_view.dart';
import 'package:djsports/features/playlist/widgets/type_filter.dart';
import 'package:djsports/utils.dart';
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
    ///List of Todo  without Filter Provider
    final providerPlaylist = ref.watch(hivePlaylistData);
    debugPrint(providerPlaylist?.length.toString());

    final providerTrack = ref.watch(hiveTrackData);
    debugPrint(providerTrack?.length.toString());

    final data = ref.watch(typeFilteredDataProvider);
    debugPrint('data length ${data.length}');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "djsports",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: IconButton(
                onPressed: () {
                  ref.invalidate(typeFilteredDataProvider);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DJPlaylistEditScreen(
                        id: '',
                        isNew: true,
                        name: '',
                        type: Type.score.name,
                        spotifyUri: '',
                        index: 0,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.add_box_outlined,
                  color: Colors.green,
                  size: 30,
                )),
          ),
        ],
      ),
      body: Column(
        children: [
          const Flexible(child: TypeFilter()),
          const SizedBox(
            height: 20,
          ),
          data.isEmpty
              ? const Center(
                  child: Text("No data"),
                )
              : Expanded(
                  flex: 10,
                  child: ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      return DJPlaylistView(
                        name: data[index].name,
                        type: data[index].type,
                        spotifyUri: data[index].spotifyUri,
                        onEdit: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DJPlaylistEditScreen(
                                isNew: false,
                                id: data[index].id,
                                index: index,
                                name: data[index].name,
                                type: data[index].type,
                                spotifyUri: data[index].spotifyUri,
                              ),
                            ),
                          );
                        },
                        onDelete: () {
                          ref
                              .read(hivePlaylistData.notifier)
                              .removeDJPlaylist(data[index].id);
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
