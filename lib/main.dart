import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/example/auth.dart';
import 'package:djsports/features/djsports/djsports_home_page.dart';
import 'package:flutter/material.dart';
// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'package:audio_service/audio_service.dart';
import 'package:djsports/data/services/djaudio_handler.dart'; // Legg til denne importen
import 'package:flutter_native_splash/flutter_native_splash.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// MP3 play notes
// https://www.youtube.com/watch?v=DIqB8qEZW1U
// https://www.youtube.com/redirect?event=video_description&redir_token=QUFFLUhqbXlZRUZOVWZZZmY3T1JXOEJyb21pYzJmdS0yd3xBQ3Jtc0tuX0RMMDE4TjV2SW80WG9CcWRFLXlCTnR4RzhNekd0RTlXRG5iQmRzSk9XMENNeWNKeE42YWg0TWU1Nm9UeDZVbXU1WURXUUdyS2t3NkFMZkJmd2JiV0pFTWFieldxR2RxTXBYaXNLazJYeUFuS3prRQ&q=https%3A%2F%2Fdrp.li%2FIq9Bk&v=DIqB8qEZW1U

final audioHandlerProvider =
    Provider<AudioHandler>((ref) => throw UnimplementedError());

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);
  await dotenv.dotenv.load(fileName: '.env');

  // print all elements in dotenv
  dotenv.dotenv.env.forEach((key, value) {
    debugPrint('Starting app .  $key: $value');
  });

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

  final audioHandler = await AudioService.init(
    builder: () => DJAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.djsports.audio',
      androidNotificationChannelName: 'djSports Audio Service',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  /// Here I'm Using RiverPod for StateManagement so Wrapping MyApp with ProviderScope
  runApp(ProviderScope(overrides: [
    audioHandlerProvider.overrideWithValue(audioHandler),
  ], child: const DJSportsApp()));
}

class DJSportsApp extends ConsumerWidget {
  const DJSportsApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            // add a button to run a function with text Spotify Auth
            ElevatedButton(
              onPressed: () {
                // Navigate to the second screen using a named route.
                testAuth();
              },
              child: const Text('Spotify Auth'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
