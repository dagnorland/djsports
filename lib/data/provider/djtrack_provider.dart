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

final dataTrackWithShortcutProvider = Provider<List<DJTrack>>(
  (ref) {
    final hiveDatas = ref.watch(hiveTrackData) ?? [];
    final tracks =
        hiveDatas.where((t) => t.shortcut.trim().isNotEmpty).toList();

    int compareShortcut(DJTrack a, DJTrack b) {
      final as = a.shortcut.trim();
      final bs = b.shortcut.trim();
      final ai = int.tryParse(as);
      final bi = int.tryParse(bs);
      if (ai != null && bi != null) return ai.compareTo(bi);
      return as.toLowerCase().compareTo(bs.toLowerCase());
    }

    tracks.sort(compareShortcut);
    return tracks;
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
