import 'dart:core';

import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';

void testDJPlaylistController() {
  // We create 4 playlists,
  // we add 2-3 tracks to each playlist,

  // We then save them to the box
  // Then changes some tracks and saves them again

  DJPlaylist firstPlaylist = DJPlaylist(
      name: 'Score Home team',
      type: DJPlaylistType.score.name,
      spotifyUri: '',
      autoNext: true,
      shuffleAtEnd: false,
      currentTrack: 0,
      playCount: 0,
      trackIds: []);

  DJPlaylist secondPlaylist = DJPlaylist(
      name: 'Score Away team',
      spotifyUri: '',
      autoNext: true,
      shuffleAtEnd: false,
      type: DJPlaylistType.score.name,
      playCount: 0,
      trackIds: []);

  DJPlaylist thirdPlaylist = DJPlaylist(
      name: 'Penalty',
      spotifyUri: '',
      autoNext: true,
      shuffleAtEnd: false,
      type: DJPlaylistType.event.name,
      playCount: 0,
      trackIds: []);

  DJPlaylist fourthPlaylist = DJPlaylist(
      name: 'Get well',
      spotifyUri: '',
      autoNext: true,
      shuffleAtEnd: false,
      type: DJPlaylistType.event.name,
      playCount: 0,
      trackIds: []);

  DJPlaylist fifthPlaylist = DJPlaylist(
      name: 'Cheer',
      spotifyUri: '',
      autoNext: true,
      shuffleAtEnd: false,
      type: DJPlaylistType.event.name,
      playCount: 0,
      trackIds: []);

  DJPlaylist sixthPlaylist = DJPlaylist(
      name: 'Interups',
      spotifyUri: '',
      autoNext: true,
      shuffleAtEnd: false,
      type: DJPlaylistType.event.name,
      playCount: 0,
      trackIds: []);

  DJTrack firstTrack = DJTrack.simple(
    name: 'First track',
    album: 'First album',
    artist: 'First artist',
    spotifyUri: 'spotify:track:2USlegnFJLrVLpoVfPimKB',
  );

  DJTrack secondTrack = DJTrack.simple(
      name: 'Second track',
      album: 'Second album',
      artist: 'Second artist',
      spotifyUri: 'spotify:track:3H02NoVI6OnKSg5u8CLzZd');

  DJTrack thirdTrack = DJTrack.simple(
      album: 'Third album',
      name: 'Third track',
      artist: 'Third artist',
      spotifyUri: 'spotify:track:6QgjcU0zLnzq5OrUoSZ3OK');

  DJTrack? fourthTrack = DJTrack.simple(
      name: 'Fourth track',
      album: 'Fourth album',
      artist: 'Fourth artist',
      spotifyUri: 'spotify:track:76hfruVvmfQbw0eYn1nmeC');

  List<String> trackIds = [
    firstTrack.id,
    secondTrack.id,
    thirdTrack.id,
    fourthTrack.id
  ];

  firstPlaylist.trackIds = trackIds;
  secondPlaylist.trackIds = trackIds;
  thirdPlaylist.trackIds = trackIds;
  fourthPlaylist.trackIds = trackIds;
  fifthPlaylist.trackIds = trackIds;
  sixthPlaylist.trackIds = trackIds;
}
