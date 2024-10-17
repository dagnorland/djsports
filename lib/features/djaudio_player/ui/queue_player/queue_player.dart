import 'package:djsports/features/djaudio_player/ui/queue_player/widgets/carousel.dart';
import 'package:djsports/features/djaudio_player/ui/queue_player/widgets/control_buttons.dart';
import 'package:djsports/features/djaudio_player/ui/queue_player/widgets/progress_bar.dart';
import 'package:djsports/features/djaudio_player/ui/queue_player/widgets/queue_icon.dart';
import 'package:djsports/features/djaudio_player/ui/queue_player/widgets/song_info.dart';
import 'package:flutter/material.dart';

class QueuePlayerScreen extends StatelessWidget {
  const QueuePlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          0,
          MediaQuery.of(context).padding.top + 20,
          0,
          10,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_downward),
                  ),
                  Text(
                    'Now playing',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const QueueIcon(),
                ],
              ),
            ),
            const SizedBox(height: 50),
            const SongInfo(),
            const SizedBox(height: 30),
            const SizedBox(height: 300, child: Carousel()),
            const SizedBox(height: 50),
            const ControlButtons(),
            const SizedBox(height: 20),
            const AudioProgressBar(),
          ],
        ),
      ),
    );
  }
}
