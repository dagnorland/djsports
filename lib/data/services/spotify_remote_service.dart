import 'package:djsports/data/repo/spotify_remote_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:rxdart/rxdart.dart';

class SpotifyRemoteService {
  SpotifyRemoteService({required this.remoteRepository}) {
    // Implementation based on: https://youtu.be/7O1UO5rEpRc
    // ReactiveConf 2018 - Brian Egan & Filip Hracek: Practical Rx with Flutter
    _connected = _connect.switchMap((status) async* {
      yield await remoteRepository.connect();
    }); // discard previous events
  }
  final SpotifyRemoteRepository remoteRepository;

  // Input stream (search terms)
  final _connect = BehaviorSubject<bool>();
  void connectToSpotifyRemote(bool status) {
    _connect.add(status);
  }

  // Output stream (search results)
  late Stream<bool> _connected;
  Stream<bool> get results => _connected;
  void dispose() {
    _connect.close();
  }
}

final connectRemoteProvider = Provider<SpotifyRemoteService>((ref) {
  final repository = ref.watch(spotifyRemoteRepositoryProvider);
  return SpotifyRemoteService(remoteRepository: repository);
});

final remoteResultsProvider = StreamProvider.autoDispose<bool>((ref) {
  final service = ref.watch(connectRemoteProvider);
  return service.results;
});
