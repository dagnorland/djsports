import 'package:flutter/material.dart';

class LetsPlayHelpScreen extends StatelessWidget {
  const LetsPlayHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Let's Play Help",
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
                icon: Icons.sports_handball,
                iconColor: Colors.green.shade700,
                title: "Let's Play",
                subtitle:
                    'Your live DJ control center during the event.',
              ),
              const SizedBox(height: 24),
              const _HelpSection(
                stepNumber: '1',
                icon: Icons.touch_app,
                iconColor: Colors.green,
                title: 'Start Playing a Playlist',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap any playlist card to start playing the current '
                      'track immediately on Spotify.',
                    ),
                    SizedBox(height: 8),
                    _VisualRow(
                      icon: Icons.touch_app,
                      color: Colors.green,
                      label: 'Tap card → plays current track',
                    ),
                    SizedBox(height: 6),
                    Text(
                      'The card flashes briefly to confirm playback has '
                      'started.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _HelpSection(
                stepNumber: '2',
                icon: Icons.skip_next,
                iconColor: Colors.blue,
                title: 'Auto Next Track',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'If the playlist has "Auto Next" enabled, the app '
                      'will automatically advance to the next track after '
                      'the configured number of seconds.',
                    ),
                    SizedBox(height: 8),
                    _VisualRow(
                      icon: Icons.timer,
                      color: Colors.blue,
                      label: 'Auto Next: set in playlist options',
                    ),
                    SizedBox(height: 6),
                    Text(
                      'To enable Auto Next, edit the playlist and turn on '
                      'the Auto Next toggle before starting the event.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _HelpSection(
                stepNumber: '3',
                icon: Icons.swap_horiz,
                iconColor: Colors.purple,
                title: 'Browse Tracks with < and >',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Each playlist card shows the current track. '
                      'Use the arrow buttons to navigate through the '
                      'tracks without playing them.',
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        _ArrowChip(icon: Icons.chevron_left, label: '<'),
                        SizedBox(width: 10),
                        Text('Previous track', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        _ArrowChip(icon: Icons.chevron_right, label: '>'),
                        SizedBox(width: 10),
                        Text('Next track', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap the card after browsing to play the selected '
                      'track.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _HelpSection(
                stepNumber: '4',
                icon: Icons.volume_up,
                iconColor: Colors.orange,
                title: 'Set Volume',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Use the volume buttons in the control bar to adjust '
                      'the Spotify playback volume.',
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        _ControlChip(
                          icon: Icons.volume_up,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Volume up (+5%)',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        _ControlChip(
                          icon: Icons.volume_down,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Volume down (−5%)',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The current volume level is shown in the app bar '
                      'on the home screen.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _HelpSection(
                stepNumber: '5',
                icon: Icons.backspace,
                iconColor: Colors.red,
                title: 'Back to Home',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap the back button (⌫) in the control bar to exit '
                      "Let's Play and return to the home screen.",
                    ),
                    SizedBox(height: 8),
                    _ControlChip(
                      icon: Icons.backspace,
                      color: Colors.red,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Music will keep playing in Spotify — use the pause '
                      'button before going back if you want to stop.',
                    ),
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

class _VisualRow extends StatelessWidget {
  const _VisualRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowChip extends StatelessWidget {
  const _ArrowChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(icon, size: 20, color: Colors.grey.shade700),
    );
  }
}

class _ControlChip extends StatelessWidget {
  const _ControlChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
