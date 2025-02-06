import 'package:djsports/data/models/djtrack_model.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Provider for accessing the last played DJTrack
final lastDjTrackPlayedProvider =
    NotifierProvider<LastDjTrackPlayedNotifier, AsyncValue<DJTrack?>>(
  LastDjTrackPlayedNotifier.new,
);

/// Notifier class to handle the last played DJTrack state and operations
class LastDjTrackPlayedNotifier extends Notifier<AsyncValue<DJTrack?>> {
  @override
  AsyncValue<DJTrack?> build() {
    // Initialize with loading state
    return const AsyncValue.data(null);
  }

  /// Updates the last played track and notifies listeners
  Future<void> updateLastPlayedTrack(DJTrack track) async {
    try {
      state = const AsyncValue.loading();

      // Her kan du legge til Supabase-logikk for å lagre til database
      // await supabase.from('last_played_tracks').upsert({...});

      state = AsyncValue.data(track);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Clears the last played track
  void clearLastPlayedTrack() {
    state = const AsyncValue.data(null);
  }
}
