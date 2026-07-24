import 'package:djsports/data/repo/app_settings_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Effective Spotify credentials used by the app.
///
/// Resolution order per field: user-supplied value from [AppSettings]
/// (Bring Your Own Client ID), falling back to the bundled `.env`
/// (developer builds). [isUserProvided] is true when the Client ID
/// comes from the user.
class SpotifyCredentialsState {
  const SpotifyCredentialsState({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUrl,
    required this.isUserProvided,
  });

  final String clientId;
  final String clientSecret;
  final String redirectUrl;
  final bool isUserProvided;

  /// True when we have at least a Client ID to try connecting with.
  bool get isConfigured => clientId.isNotEmpty;
}

class SpotifyCredentialsNotifier extends Notifier<SpotifyCredentialsState> {
  @override
  SpotifyCredentialsState build() => _resolve();

  /// Safe .env lookup: dotenv throws if no .env asset was ever loaded
  /// (the normal case for end-user builds).
  static String _env(String key) =>
      dotenv.isInitialized ? (dotenv.env[key] ?? '') : '';

  SpotifyCredentialsState _resolve() {
    final userClientId = AppSettings.spotifyClientId;
    final userSecret = AppSettings.spotifyClientSecret;
    final userRedirect = AppSettings.spotifyRedirectUrl;
    final isUserProvided = userClientId.isNotEmpty;

    final envRedirect = _env('SPOTIFY_REDIRECT_URL');
    return SpotifyCredentialsState(
      clientId: isUserProvided ? userClientId : _env('SPOTIFY_CLIENTID'),
      clientSecret: isUserProvided ? userSecret : _env('SPOTIFY_SECRET'),
      redirectUrl: userRedirect.isNotEmpty
          ? userRedirect
          : (envRedirect.isNotEmpty
              ? envRedirect
              : AppSettings.defaultSpotifyRedirectUrl),
      isUserProvided: isUserProvided,
    );
  }

  /// Persists the credentials and rebuilds every provider that watches
  /// this one (remote repository, search repository, ...).
  Future<void> save({
    required String clientId,
    required String clientSecret,
    required String redirectUrl,
  }) async {
    await AppSettings.setSpotifyClientId(clientId);
    await AppSettings.setSpotifyClientSecret(clientSecret);
    await AppSettings.setSpotifyRedirectUrl(redirectUrl);
    state = _resolve();
  }

  /// Clears user-supplied credentials, reverting to the `.env` fallback.
  Future<void> clear() => save(clientId: '', clientSecret: '', redirectUrl: '');
}

final spotifyCredentialsProvider =
    NotifierProvider<SpotifyCredentialsNotifier, SpotifyCredentialsState>(
  SpotifyCredentialsNotifier.new,
);
