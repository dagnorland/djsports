import 'package:flutter/material.dart';
import 'package:spotify/spotify.dart';

void main() async {
  var credentials = SpotifyApiCredentials(
    '7205348d8ded4b66ae65aca652168b0c',
    'f691c1f8731b4932b6003e5be60cce6b',
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
