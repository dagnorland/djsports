import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:djsports/data/provider/audio_player_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Carousel extends ConsumerStatefulWidget {
  const Carousel({super.key});

  @override
  ConsumerState<Carousel> createState() => _CarouselState();
}

class _CarouselState extends ConsumerState<Carousel> {
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(audioPlayerProvider.select((value) => value.queue));
    final queueIndex =
        ref.watch(audioPlayerProvider.select((value) => value.queueIndex));
    final isrepeatModeOne = ref.watch(
      audioPlayerProvider
          .select((value) => value.repeatMode == AudioServiceRepeatMode.one),
    );

    ref.listen<int>(
      audioPlayerProvider.select((playerState) => playerState.queueIndex),
      (previous, next) {
        if (previous != next) {
          _carouselController.animateToPage(next);
        }
      },
    );

    return CarouselSlider.builder(
      carouselController: _carouselController,
      itemCount: queue.length,
      itemBuilder: (context, index, realIndex) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 15),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image(
              image: (queue[index].artUri == null)
                  ? const AssetImage('assets/images/default_music.png')
                  : FileImage(File(queue[index].artUri!.path)) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
      options: CarouselOptions(
        aspectRatio: 4 / 3,
        initialPage: queueIndex,
        scrollPhysics:
            isrepeatModeOne ? const NeverScrollableScrollPhysics() : null,
        viewportFraction: 0.65,
        enlargeCenterPage: true,
        enableInfiniteScroll: false,
        onPageChanged: (index, reason) => _onPageChanged(
          index: index,
          queueIndex: queueIndex,
          reason: reason,
          ref: ref,
        ),
      ),
    );
  }

  void _onPageChanged({
    required int index,
    required int queueIndex,
    required CarouselPageChangedReason reason,
    required WidgetRef ref,
  }) {
    if (reason == CarouselPageChangedReason.manual) {
      if (index > queueIndex) {
        ref.watch(audioPlayerProvider.notifier).skipToNext();
      } else {
        ref.watch(audioPlayerProvider.notifier).skipToPrevious();
      }
    }
  }
}
