// Copyright (c) 2017, 2020 rinukkusu, hayribakici. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:spotify/spotify.dart';

void main() async {
  var credentials = SpotifyApiCredentials(
    dotenv.env['SPOTIFY_CLIENTID'],
    dotenv.env['SPOTIFY_SECRET'],
  );
  var spotify = SpotifyApi(credentials);

  debugPrint('\nPodcast:');
  await spotify.shows
      .get('4rOoJ6Egrf8K2IrywzwOMk')
      .then((podcast) => debugPrint(podcast.name))
      .onError((error, stackTrace) =>
          debugPrint((error as SpotifyException).message));

  debugPrint('\nPodcast episode:');
  var episodes = spotify.shows.episodes('4AlxqGkkrqe0mfIx3Mi7Xt');
  await episodes
      .first()
      .then((first) => debugPrint(first.items!.first.toString()))
      .onError((error, stackTrace) =>
          debugPrint((error as SpotifyException).message));

  debugPrint('\nArtists:');
  var artists = await spotify.artists.list(['0OdUWJ0sBjDrqHygGUXeCF']);
  for (var x in artists) {
    debugPrint(x.name);
  }

  debugPrint('\nAlbum:');
  var album = await spotify.albums.get('2Hog1V8mdTWKhCYqI5paph');
  debugPrint(album.name);

  debugPrint('\nAlbum Tracks:');
  var tracks = await spotify.albums.tracks(album.id!).all();
  for (var track in tracks) {
    debugPrint(track.name);
  }

  debugPrint('\nNew Releases');
  // ignore: deprecated_member_use
  var newReleases = await spotify.browse.getNewReleases().first();
  for (var album in newReleases.items!) {
    debugPrint(album.name);
  }

  debugPrint('\nFeatured Playlist:');
  var featuredPlaylists = await spotify.playlists.featured.all();
  for (var playlist in featuredPlaylists) {
    debugPrint(playlist.name);
  }

  debugPrint('\nUser\'s playlists:');
  var usersPlaylists =
      await spotify.playlists.getUsersPlaylists('superinteressante').all();
  for (var playlist in usersPlaylists) {
    debugPrint(playlist.name);
  }

  debugPrint("\nSearching for 'Metallica':");
  var search = await spotify.search.get('metallica').first(2);

  for (var pages in search) {
    if (pages.items == null) {
      debugPrint('Empty items');
    }
    for (var item in pages.items!) {
      if (item is PlaylistSimple) {
        debugPrint('Playlist: \n'
            'id: ${item.id}\n'
            'name: ${item.name}:\n'
            'collaborative: ${item.collaborative}\n'
            'href: ${item.href}\n'
            'trackslink: ${item.tracksLink!.href}\n'
            'owner: ${item.owner}\n'
            'public: ${item.owner}\n'
            'snapshotId: ${item.snapshotId}\n'
            'type: ${item.type}\n'
            'uri: ${item.uri}\n'
            'images: ${item.images!.length}\n'
            '-------------------------------');
      }
      if (item is Artist) {
        debugPrint('Artist: \n'
            'id: ${item.id}\n'
            'name: ${item.name}\n'
            'href: ${item.href}\n'
            'type: ${item.type}\n'
            'uri: ${item.uri}\n'
            'popularity: ${item.popularity}\n'
            '-------------------------------');
      }
      if (item is Track) {
        debugPrint('Track:\n'
            'id: ${item.id}\n'
            'name: ${item.name}\n'
            'href: ${item.href}\n'
            'type: ${item.type}\n'
            'uri: ${item.uri}\n'
            'isPlayable: ${item.isPlayable}\n'
            'artists: ${item.artists!.length}\n'
            'availableMarkets: ${item.availableMarkets!.length}\n'
            'discNumber: ${item.discNumber}\n'
            'trackNumber: ${item.trackNumber}\n'
            'explicit: ${item.explicit}\n'
            'popularity: ${item.popularity}\n'
            '-------------------------------');
      }
      if (item is AlbumSimple) {
        debugPrint('Album:\n'
            'id: ${item.id}\n'
            'name: ${item.name}\n'
            'href: ${item.href}\n'
            'type: ${item.type}\n'
            'uri: ${item.uri}\n'
            'albumType: ${item.albumType}\n'
            'artists: ${item.artists!.length}\n'
            'availableMarkets: ${item.availableMarkets!.length}\n'
            'images: ${item.images!.length}\n'
            'releaseDate: ${item.releaseDate}\n'
            'releaseDatePrecision: ${item.releaseDatePrecision}\n'
            '-------------------------------');
      }
    }
  }

  var relatedArtists =
      await spotify.artists.relatedArtists('0OdUWJ0sBjDrqHygGUXeCF');
  debugPrint('\nRelated Artists: ${relatedArtists.length}');

  credentials = await spotify.getCredentials();
  debugPrint('\nCredentials:');
  debugPrint('Client Id: ${credentials.clientId}');
  debugPrint('Access Token: ${credentials.accessToken}');
  debugPrint('Credentials Expired: ${credentials.isExpired}');
}
