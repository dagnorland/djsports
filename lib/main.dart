import 'package:djsports/data/models/audio_player_album.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/provider/audio_player_providers.dart';
import 'package:djsports/data/services/djaudio_query.dart';
import 'package:djsports/features/djsports/djsports_home_page.dart';
import 'package:flutter/material.dart';
// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'package:audio_service/audio_service.dart';
import 'package:djsports/data/services/djaudio_handler.dart'; // Legg til denne importen
import 'package:permission_handler/permission_handler.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// MP3 play notes
// https://www.youtube.com/watch?v=DIqB8qEZW1U
// https://www.youtube.com/redirect?event=video_description&redir_token=QUFFLUhqbXlZRUZOVWZZZmY3T1JXOEJyb21pYzJmdS0yd3xBQ3Jtc0tuX0RMMDE4TjV2SW80WG9CcWRFLXlCTnR4RzhNekd0RTlXRG5iQmRzSk9XMENNeWNKeE42YWg0TWU1Nm9UeDZVbXU1WURXUUdyS2t3NkFMZkJmd2JiV0pFTWFieldxR2RxTXBYaXNLazJYeUFuS3prRQ&q=https%3A%2F%2Fdrp.li%2FIq9Bk&v=DIqB8qEZW1U

class AudioServiceSingleton {
  static final AudioServiceSingleton _instance =
      AudioServiceSingleton._internal();
  late final AudioHandler _audioHandler;

  static AudioServiceSingleton get instance => _instance;

  factory AudioServiceSingleton() {
    return _instance;
  }

  AudioServiceSingleton._internal();

  Future<void> init() async {
    _audioHandler = await AudioService.init(
      builder: () => DJAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.mycompany.myapp.audio',
        androidNotificationChannelName: 'Audio Service Demo',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  AudioHandler get audioHandler => _audioHandler;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.dotenv.load(fileName: '.env');

  // Legg til denne linjen for å be om tillatelser
  await requestStoragePermissions();

  /// Initilize Hive Database
  await Hive.initFlutter();

  /// Register Adapater Which we have generated Class Name Like Model Class name+Adapter
  Hive.registerAdapter(DJPlaylistAdapter());
  Hive.registerAdapter(DJTrackAdapter());

  // parameter to delete all data from database
  const deleteAllData =
      bool.fromEnvironment('DELETE_ALL_DATA', defaultValue: false);
  if (deleteAllData) {
    await Hive.deleteBoxFromDisk('djplaylist');
    await Hive.deleteBoxFromDisk('djtrack');
  }

  /// Give  Database Name anything you want, here todos is My database Name
  await Hive.openBox<DJPlaylist>('djplaylist');
  await Hive.openBox<DJTrack>('djtrack');

  await AudioServiceSingleton.instance.init();

  /// Here I'm Using RiverPod for StateManagement so Wrapping MyApp with ProviderScope
  runApp(const ProviderScope(child: DJSportsApp()));
}

class DJSportsApp extends ConsumerStatefulWidget {
  const DJSportsApp({super.key});

  @override
  ConsumerState<DJSportsApp> createState() => _DJSportsAppState();
}

class _DJSportsAppState extends ConsumerState<DJSportsApp> {
  bool permission = false;
  bool loading = true;
  late final List<AudioPlayerAlbum> albums;
  late final List<MediaItem> mediaItems;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    var storagePermission = Permission.storage;
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
    ref.watch(songsProvider.state).state = mediaItems;
    ref.watch(albumsProvider.state).state = albums;
    setState(() {
      permission = true;
      loading = false;
    });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'djSports',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        //
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        primaryColor: Colors.blue.withOpacity(0.7),
        primaryColorLight: Colors.blueAccent.withOpacity(0.5),

        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

Future<void> requestStoragePermissions() async {
  if (await Permission.accessMediaLocation.request().isGranted) {
    // Tillatelse gitt
    debugPrint('Lagringstillatelse gitt');
  } else if (await Permission.accessMediaLocation
      .request()
      .isPermanentlyDenied) {
    // Tillatelse permanent avslått, åpne app-innstillinger
    await openAppSettings();
  } else {
    // Tillatelse avslått
    //await openAppSettings();
    debugPrint('Lagringstillatelse avslått');
  }
}
