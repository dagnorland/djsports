import 'package:djsports/data/repo/apple_music_repository.dart';
import 'package:djsports/data/services/apple_music_platform_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apple_music_provider.g.dart';

@Riverpod(keepAlive: true)
AppleMusicRepository appleMusicRepository(Ref ref) {
  return AppleMusicRepository();
}

// ── Search notifier ──────────────────────────────────────────────────────────

@riverpod
class AppleMusicSearch extends _$AppleMusicSearch {
  @override
  Future<List<AppleMusicTrack>> build() async {
    return [];
  }

  Future<void> search(String query) async {
    if (query.length < 3) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(appleMusicRepositoryProvider).search(query),
    );
  }

  void clear() {
    state = const AsyncData([]);
  }
}
