import 'package:audio_service/audio_service.dart';
import 'package:djsports/data/models/audio_player_album.dart';
import 'package:djsports/data/provider/audio_player_providers.dart';
import 'package:djsports/data/services/djaudio_query.dart';
import 'package:djsports/features/djaudio_player/ui/home/home.dart';
import 'package:djsports/features/djaudio_player/ui/loading/loading.dart';
import 'package:djsports/features/djaudio_player/ui/permission/permission.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class DJAudioPlayerViewPage extends ConsumerStatefulWidget {
  const DJAudioPlayerViewPage({super.key});

  @override
  ConsumerState<DJAudioPlayerViewPage> createState() =>
      _DJAudioPlayerViewPageState();
}

class _DJAudioPlayerViewPageState extends ConsumerState<DJAudioPlayerViewPage> {
  bool loading = true;
  bool permission = false;

  late final List<AudioPlayerAlbum> albums;
  late final List<MediaItem> mediaItems;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    var storagePermission = Permission.audio;
    if (await storagePermission.status.isGranted) {
      _loadData();
    } else {
      var status = await storagePermission.request();
      if (status.isGranted) {
        _loadData();
      } else {
        setState(() {
          permission = false;
          loading = false;
        });
      }
    }
  }

  void _loadData() async {
    final audioApi = AudioQuery();
    albums = await audioApi.queryAlbums();
    mediaItems = await audioApi.queryMediaItems();
    ref.watch(songsProvider.notifier).state = mediaItems;
    ref.watch(albumsProvider.notifier).state = albums;
    setState(() {
      permission = true;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.backspace),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            title: const Text(
              'djAudioPlayer',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            actions: const [],
          ),
          body: loading
              ? const LoadingScreen()
              : permission
                  ? const HomeScreen()
                  : const PermissionScreen(),
        ));
  }
}
