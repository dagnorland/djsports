import 'package:flutter/material.dart';

class PlaylistHelpScreen extends StatelessWidget {
  const PlaylistHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Playlist Help',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpHeader(
                icon: Icons.queue_music,
                iconColor: Colors.green.shade700,
                title: 'Managing Playlists',
                subtitle:
                    'Set up your playlists with Spotify tracks for the event.',
              ),
              const SizedBox(height: 24),
              const _HelpSection(
                stepNumber: '1',
                icon: Icons.add,
                iconColor: Colors.black,
                title: 'Add a New Playlist',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap the + button in the top-right of the home screen to '
                      'create a new playlist.',
                    ),
                    SizedBox(height: 8),
                    _InlineChip(icon: Icons.add, label: '+ New Playlist'),
                    SizedBox(height: 8),
                    Text('Give the playlist a name that makes it easy to '
                        'identify during the event.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _HelpSection(
                stepNumber: '2',
                icon: Icons.label,
                iconColor: Colors.purple,
                title: 'Set the Playlist Type',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose the type that fits when this playlist will be '
                      'played:',
                    ),
                    const SizedBox(height: 10),
                    _TypeRow(
                      color: Colors.red,
                      label: 'Hotspot',
                      description: 'High-energy moments',
                    ),
                    _TypeRow(
                      color: Colors.green.shade700,
                      label: 'Match',
                      description: 'During gameplay',
                    ),
                    _TypeRow(
                      color: Colors.blue,
                      label: 'Fun Stuff',
                      description: 'Entertainment breaks',
                    ),
                    _TypeRow(
                      color: Colors.black,
                      label: 'Pre-Match',
                      description: 'Pre-game atmosphere',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _HelpSection(
                stepNumber: '3',
                icon: Icons.link,
                iconColor: Colors.teal,
                title: 'Paste the Spotify URI',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Spotify and find the playlist you want to use. '
                      'Copy its URI:',
                    ),
                    SizedBox(height: 8),
                    _StepItem(
                      text:
                          'In Spotify: tap ··· on a playlist → Share → Copy '
                          'Spotify URI',
                    ),
                    _StepItem(
                      text:
                          'The URI looks like: spotify:playlist:37i9dQZF…',
                    ),
                    _StepItem(
                      text: 'Paste it into the Spotify URI field in the '
                          'playlist editor.',
                    ),
                    SizedBox(height: 8),
                    _InlineChip(
                      icon: Icons.content_paste,
                      label: 'Spotify URI field',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _HelpSection(
                stepNumber: '4',
                icon: Icons.sync,
                iconColor: Colors.green,
                title: 'Sync Tracks from Spotify',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'After pasting the URI, tap the Sync button to import '
                      'all tracks from that Spotify playlist.',
                    ),
                    SizedBox(height: 8),
                    _InlineChip(icon: Icons.sync, label: 'Sync'),
                    SizedBox(height: 8),
                    Text(
                      'The app will fetch the tracks and add them to your '
                      'playlist. This requires a Spotify connection.',
                    ),
                    SizedBox(height: 8),
                    _StepItem(
                      text: 'You can re-sync later to pick up new tracks '
                          'added to the Spotify playlist.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _HelpSection(
                stepNumber: '5',
                icon: Icons.timer,
                iconColor: Colors.orange,
                title: 'Edit Track Start Times',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Each track can have a custom start time so playback '
                      'begins at the best moment of the song.',
                    ),
                    SizedBox(height: 8),
                    _StepItem(
                      text: 'Tap a track in the playlist to open the track '
                          'editor.',
                    ),
                    _StepItem(
                      text: 'Use the start time slider to set minutes and '
                          'seconds.',
                    ),
                    _StepItem(
                      text: 'Save the track — the start time will be used '
                          'every time that track plays.',
                    ),
                    SizedBox(height: 8),
                    _InlineChip(icon: Icons.access_time, label: 'Start time'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpHeader extends StatelessWidget {
  const _HelpHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(26),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: iconColor.withAlpha(77)),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.stepNumber,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final String stepNumber;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
            child: body,
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.color,
    required this.label,
    required this.description,
  });

  final Color color;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '— $description',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade500,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  const _InlineChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
