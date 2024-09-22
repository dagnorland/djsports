import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:flutter/material.dart';

// Localization
//models

// Riverpod
import 'package:hooks_riverpod/hooks_riverpod.dart';
//Providers

class SpotifyConnectScreen extends StatefulHookConsumerWidget {
  const SpotifyConnectScreen({
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<SpotifyConnectScreen> {
  final clientIdController = TextEditingController();
  final redirectUrlController = TextEditingController();
  final scopeController = TextEditingController();
  final responseController = TextEditingController();
  bool lastConnectResult = false;

  @override
  void initState() {
    clientIdController.text = '';
    redirectUrlController.text = '';
    scopeController.text =
        "app-remote-control,user-modify-playback-state,playlist-read-private";
    responseController.text = "";
    super.initState();
  }

  Future<void> _spotifyConnectRemoteService(
      BuildContext context, WidgetRef ref) async {
    // how to use SpotifyRemoteService to connect to Spotify
    responseController.text = 'New try...';
    final spotifyRemoteService = ref.read(spotifyRemoteRepositoryProvider);
    final connected = await spotifyRemoteService.connectAccessToken();
    final connectedToSpotifyRemote =
        await spotifyRemoteService.connectToSpotifyRemote();
    debugPrint('connectedToSpotifyRemote: $connectedToSpotifyRemote');
    final accessToken = await spotifyRemoteService.getSpotifyAccessToken();
    responseController.text = "Connected : $connected $accessToken";
    if (connected) {
      responseController.text = "..trying to play...";
      final result = await spotifyRemoteService
          .playTrack("spotify:track:3n3Ppam7vgaVa1iaRUc9Lp");
      responseController.text =
          "Result: $result, Connected : $connected $accessToken";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.black,
              size: 30,
            )),
        actions: [
          TextButton(
              onPressed: () {
                _spotifyConnectRemoteService(context, ref);
              },
              child: const Text(
                "Connect RS",
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              )),
        ],
        title: Text(
          "Connect to Spotify",
          style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: TextField(
                  controller: clientIdController,
                  decoration: InputDecoration(
                    labelText: 'ClientId',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: Theme.of(context).primaryColor, width: 2),
                    ),
                    hintText: ' Enter client id',
                  ),
                )),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: TextField(
                controller: redirectUrlController,
                onChanged: (value) => setState(() {
                  redirectUrlController.text = redirectUriValidate(value);
                }),
                decoration: InputDecoration(
                  labelText: 'Spotify redirect uri',
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  hintText: ' Spotify redirect uri',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: TextField(
                controller: scopeController,
                onChanged: (value) => setState(() {
                  scopeController.text = value;
                }),
                decoration: InputDecoration(
                  labelText: 'Spotify app scope',
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  hintText: ' Spotify app scope',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: TextField(
                controller: responseController,
                onChanged: (value) => setState(() {
                  responseController.text = value;
                }),
                decoration: InputDecoration(
                  labelText: 'connect response',
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  hintText: ' connect response',
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String redirectUriValidate(String value) {
    return value;
  }
}
