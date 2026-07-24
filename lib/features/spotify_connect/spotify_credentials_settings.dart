import 'package:djsports/data/provider/spotify_credentials_provider.dart';
import 'package:djsports/data/repo/app_settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Settings section for Bring Your Own Spotify Client ID.
///
/// Since February 2026 Spotify Development Mode apps are limited to
/// 5 authorized users per Client ID. Each user therefore creates their
/// own (free) app in the Spotify Developer Dashboard and enters the
/// credentials here. Values are stored locally in Hive; empty values
/// fall back to the bundled .env (developer builds).
class SpotifyCredentialsSettings extends StatefulHookConsumerWidget {
  const SpotifyCredentialsSettings({super.key});

  @override
  ConsumerState<SpotifyCredentialsSettings> createState() =>
      _SpotifyCredentialsSettingsState();
}

class _SpotifyCredentialsSettingsState
    extends ConsumerState<SpotifyCredentialsSettings> {
  late final TextEditingController _clientIdController;
  late final TextEditingController _clientSecretController;
  late final TextEditingController _redirectUrlController;
  bool _obscureSecret = true;
  String _statusMessage = '';
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    // Show the user's own stored values (not the .env fallback) so it is
    // obvious whether they have configured anything themselves.
    _clientIdController =
        TextEditingController(text: AppSettings.spotifyClientId);
    _clientSecretController =
        TextEditingController(text: AppSettings.spotifyClientSecret);
    _redirectUrlController = TextEditingController(
      text: AppSettings.spotifyRedirectUrl.isEmpty
          ? AppSettings.defaultSpotifyRedirectUrl
          : AppSettings.spotifyRedirectUrl,
    );
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _redirectUrlController.dispose();
    super.dispose();
  }

  String? _validate() {
    final clientId = _clientIdController.text.trim();
    final redirectUrl = _redirectUrlController.text.trim();
    if (clientId.isEmpty) {
      return null; // Empty is allowed: clears back to .env fallback.
    }
    if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(clientId)) {
      return 'Client ID should be a 32-character hex string';
    }
    final uri = Uri.tryParse(redirectUrl);
    if (redirectUrl.isEmpty || uri == null || !uri.isAbsolute) {
      return 'Redirect URI must be a valid URI, '
          'e.g. ${AppSettings.defaultSpotifyRedirectUrl}';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      setState(() {
        _statusMessage = error;
        _statusIsError = true;
      });
      return;
    }
    await ref.read(spotifyCredentialsProvider.notifier).save(
          clientId: _clientIdController.text,
          clientSecret: _clientSecretController.text,
          redirectUrl: _redirectUrlController.text,
        );
    setState(() {
      _statusMessage = _clientIdController.text.trim().isEmpty
          ? 'Cleared — using built-in developer credentials'
          : 'Saved — djSports now uses your Spotify app';
      _statusIsError = false;
    });
  }

  Future<void> _clear() async {
    await ref.read(spotifyCredentialsProvider.notifier).clear();
    setState(() {
      _clientIdController.text = '';
      _clientSecretController.text = '';
      _redirectUrlController.text = AppSettings.defaultSpotifyRedirectUrl;
      _statusMessage = 'Cleared — using built-in developer credentials';
      _statusIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final creds = ref.watch(spotifyCredentialsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActiveCredentialsBanner(isUserProvided: creds.isUserProvided),
          const Gap(12),
          const _SetupInstructions(),
          const Gap(16),
          TextField(
            controller: _clientIdController,
            decoration: const InputDecoration(
              labelText: 'Spotify Client ID',
              hintText: 'From your app in the Spotify Developer Dashboard',
              border: OutlineInputBorder(),
            ),
          ),
          const Gap(12),
          TextField(
            controller: _clientSecretController,
            obscureText: _obscureSecret,
            decoration: InputDecoration(
              labelText: 'Spotify Client Secret',
              hintText: 'Used for track search (stored only on this device)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSecret ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() {
                  _obscureSecret = !_obscureSecret;
                }),
              ),
            ),
          ),
          const Gap(12),
          TextField(
            controller: _redirectUrlController,
            decoration: const InputDecoration(
              labelText: 'Redirect URI',
              hintText: AppSettings.defaultSpotifyRedirectUrl,
              border: OutlineInputBorder(),
            ),
          ),
          const Gap(12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
              const Gap(12),
              OutlinedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
            ],
          ),
          if (_statusMessage.isNotEmpty) ...[
            const Gap(8),
            SelectableText.rich(
              TextSpan(
                text: _statusMessage,
                style: TextStyle(
                  color: _statusIsError
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveCredentialsBanner extends StatelessWidget {
  const _ActiveCredentialsBanner({required this.isUserProvided});

  final bool isUserProvided;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isUserProvided ? Icons.person : Icons.build_circle_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const Gap(8),
        Expanded(
          child: Text(
            isUserProvided
                ? 'Using your own Spotify app credentials'
                : 'Using built-in developer credentials (limited to 5 '
                    'authorized users by Spotify)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _SetupInstructions extends StatelessWidget {
  const _SetupInstructions();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        'How to get your own Client ID (one-time, ~5 min)',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '1. Go to developer.spotify.com/dashboard and log in with '
            'your Spotify Premium account.\n'
            '2. Create an app (any name, e.g. "djSports"). Check '
            '"Android" and "iOS" as app types if asked.\n'
            '3. In the app settings, add this exact Redirect URI: '
            '${AppSettings.defaultSpotifyRedirectUrl}\n'
            '4. Copy the Client ID and Client Secret into the fields '
            'below and press Save.\n\n'
            'Note: Spotify requires a Premium account for Development '
            'Mode apps, and you can create one app per account. Your '
            'credentials never leave this device.',
            style: style,
          ),
        ),
      ],
    );
  }
}
