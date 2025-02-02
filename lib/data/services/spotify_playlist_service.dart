import 'dart:async';

import 'package:djsports/data/models/spotify_playlist_result.dart';
import 'package:djsports/data/repo/spotify_search_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

enum APIError { rateLimitExceeded }

class SpotifyPlaylistService {
  SpotifyPlaylistService({required this.searchRepository}) {
    // Implementation based on: https://youtu.be/7O1UO5rEpRc
    // ReactiveConf 2018 - Brian Egan & Filip Hracek: Practical Rx with Flutter
    _results = _getTerms
        .debounce((_) => TimerStream(null, const Duration(milliseconds: 500)))
        .switchMap((query) => Stream.fromFuture(
              searchRepository.getTracksByUri(query),
            ));
  }
  final SpotifySearchRepository searchRepository;

  // Input stream (search terms)
  final _getTerms = BehaviorSubject<String>();
  void getPlaylistByUri(String query) {
    debugPrint('query getPlaylistByUri: $query ${DateTime.now()}');
    _getTerms.add(query);
  }

  // Output stream (search results)
  late Stream<SpotifyPlaylistResult> _results;
  Stream<SpotifyPlaylistResult> get results => _results;

  void dispose() {
    _getTerms.close();
  }
}

final playlistServiceProvider = Provider<SpotifyPlaylistService>((ref) {
  final repository = ref.watch(searchRepositoryProvider);
  return SpotifyPlaylistService(searchRepository: repository);
});

final playlistResultsProvider =
    StreamProvider.autoDispose<SpotifyPlaylistResult>((ref) {
  final service = ref.watch(playlistServiceProvider);
  return service.results;
});
