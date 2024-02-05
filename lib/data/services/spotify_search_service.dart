import 'dart:async';

import 'package:djsports/data/models/spotify_search_result.dart';
import 'package:djsports/data/repo/spotify_search_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

enum APIError { rateLimitExceeded }

class SpotifySearchService {
  SpotifySearchService({required this.searchRepository}) {
    // Implementation based on: https://youtu.be/7O1UO5rEpRc
    // ReactiveConf 2018 - Brian Egan & Filip Hracek: Practical Rx with Flutter
    _results = _searchTerms
        .debounce((_) => TimerStream(true, const Duration(milliseconds: 10)))
        .switchMap((query) async* {
      debugPrint('query _searchTerms: $query');
      yield await searchRepository.searchTracks(query);
    }); // discard previous events
  }
  final SpotifySearchRepository searchRepository;

  // Input stream (search terms)
  final _searchTerms = BehaviorSubject<String>();
  void searchTrack(String query) {
    debugPrint('query searchTrack: $query');
    _searchTerms.add(query);
  }

  // Output stream (search results)
  late Stream<SpotifySearchResult> _results;
  Stream<SpotifySearchResult> get results => _results;

  void dispose() {
    _searchTerms.close();
  }
}

final searchServiceProvider = Provider<SpotifySearchService>((ref) {
  final repository = ref.watch(searchRepositoryProvider);
  return SpotifySearchService(searchRepository: repository);
});

final searchResultsProvider =
    StreamProvider.autoDispose<SpotifySearchResult>((ref) {
  final service = ref.watch(searchServiceProvider);
  return service.results;
});
