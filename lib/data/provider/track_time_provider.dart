import 'package:djsports/data/controller/track_time_controller.dart';
import 'package:djsports/data/models/track_time_model.dart';
import 'package:djsports/data/repo/track_time_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dataTrackTimeProvider = Provider<List<TrackTime>>(
  (ref) {
    final hiveDatas = ref.watch(hiveTrackTimeData);
    return hiveDatas!.toList();
  },
);

///Todo RepoProvider
final providerTrackTimeHive = Provider<TrackTimeRepo>((ref) => TrackTimeRepo());

///Hive data

final hiveTrackTimeData =
    StateNotifierProvider<TrackTimeHive, List<TrackTime>?>(
        (ref) => TrackTimeHive(ref));
