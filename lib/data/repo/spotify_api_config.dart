class SpotifyConfig {
  final String clientId = '7205348d8ded4b66ae65aca652168b0c';
  final String secret = 'f691c1f8731b4932b6003e5be60cce6b';
  final String redirectUrl = "djsports://callback";
  //final String redirectUrl = "djsportshall://spotify/callback";

  final String oldSpotifySearch = 'https://api.spotify.com/v1/search';
  final String oldSpotifyTracks = 'https://api.spotify.com/v1/tracks';

  //"spotify-flutter://callback"; //  "//spotify-flutter://callback";
  //"https://djsportshall/callback/";
  final String scope = 'app-remote-control, '
      'user-modify-playback-state, '
      'playlist-read-private, '
      'playlist-modify-public, '
      'user-read-currently-playing';

  //'user-read-private, user-read-email, app-remote-control, user-read-playback-state, streaming, user-modify-playback-state';
  //'user-read-private user-read-email, app-remote-control, user-read-playback-state, streaming, user-modify-playback-state';
}
