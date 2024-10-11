import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';

class DJVolumeController {
  // Mock implementation of VolumeController
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.5);

  void setVolume(double volume) {
    volumeNotifier.value = volume;
  }

  ValueNotifier<double> get listener => volumeNotifier;
}

class CurrentVolumeWidget extends StatefulWidget {
  const CurrentVolumeWidget({super.key});

  @override
  CurrentVolumeWidgetState createState() => CurrentVolumeWidgetState();
}

class CurrentVolumeWidgetState extends State<CurrentVolumeWidget> {
  final DJVolumeController _currentVolumeController = DJVolumeController();

  @override
  void initState() {
    VolumeController().listener((volume) {
      _currentVolumeController.setVolume(volume);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _currentVolumeController.listener,
      builder: (context, volume, child) {
        return Chip(
          label: Text('${(volume * 100).toStringAsFixed(0)}%'),
        );
      },
    );
  }
}
