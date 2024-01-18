import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:spotify/spotify.dart';

void main() async {
  var credentials = SpotifyApiCredentials(
    dotenv.env['SPOTIFY_CLIENTID'],
    dotenv.env['SPOTIFY_SECRET'],
  );

  try {
    var spotify = await SpotifyApi.asyncFromCredentials(credentials);
    var search = await spotify.search.get(
      'Against The Current - weapon',
      types: [SearchType.track],
    ).first(1);

    debugPrint(search.toString());
  } on AuthorizationException {
    debugPrint('Invalid credentials!');
  }
}
