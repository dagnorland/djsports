import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../controller/djtrack_controller.dart';
import '../models/djtrack_model.dart';
import '../repo/djtrack_repository.dart';

///filtered data based on user todo status

final dataTrackProvider = Provider<List<DJTrack>>(
  (ref) {
    final hiveDatas = ref.watch(hiveTrackData);
    return hiveDatas!.toList();
  },
);

final dataTrackWithStartTimeProvider = Provider<List<DJTrack>>(
  (ref) {
    final hiveDatas = ref.watch(hiveTrackData);
    return hiveDatas!.toList().where((track) => track.startTime > 0).toList();
  },
);

///Todo RepoProvider
final providerTrackHive = Provider<DJTrackRepo>((ref) => DJTrackRepo());

///Hive data

final hiveTrackData = StateNotifierProvider<DJTrackHive, List<DJTrack>?>(
    (ref) => DJTrackHive(ref));
