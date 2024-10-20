import 'package:freezed_annotation/freezed_annotation.dart';

part 'spotify_track_start_times.freezed.dart';
part 'spotify_track_start_times.g.dart';

@freezed
class SpotifyTrackStartTime with _$SpotifyTrackStartTime {
  const factory SpotifyTrackStartTime({
    required String uri,
    required int startTime,
  }) = _SpotifyTrackStartTime;

  factory SpotifyTrackStartTime.fromJson(Map<String, dynamic> json) =>
      _$SpotifyTrackStartTimeFromJson(json);
}

const List<SpotifyTrackStartTime> spotifyTrackStartTimes = [
  SpotifyTrackStartTime(
      uri: "spotify:track:6NPVjNh8Jhru9xOmyQigds", startTime: 24),
  SpotifyTrackStartTime(
      uri: "spotify:track:6JV2JOEocMgcZxYSZelKcc", startTime: 24),
  SpotifyTrackStartTime(
      uri: "spotify:track:5HbCnVLXRyZVxnreOPgJCK", startTime: 0),
  SpotifyTrackStartTime(
      uri: "spotify:track:7KIbDUwumrpG5f30kEYW1v", startTime: 0),
  SpotifyTrackStartTime(
      uri: "spotify:track:0lxt6J01WBpovNFVF87Yqa", startTime: 0),
  SpotifyTrackStartTime(
      uri: "spotify:track:2RhBpEgfPbuxciijmxYNTp", startTime: 0),
  SpotifyTrackStartTime(
      uri: "spotify:track:0y3fi7fknIXOxnkbUgzT3n", startTime: 12),
  SpotifyTrackStartTime(
      uri: "spotify:track:2O2mr2gzBRtKGRiswqRyiN", startTime: 19),
  SpotifyTrackStartTime(
      uri: "spotify:track:5ZzocszrJZomS1IM5qtKOu", startTime: 0),
  SpotifyTrackStartTime(
      uri: "spotify:track:6tyzWC5Jaeu0BHkkMvWvp9", startTime: 65),
  SpotifyTrackStartTime(
      uri: "spotify:track:7L3b6iaVhDVjfo52Hbvh9Z", startTime: 8),
  SpotifyTrackStartTime(
      uri: "spotify:track:4VTRlB4KVaNfm7ZbMOKLNT", startTime: 54),
  SpotifyTrackStartTime(
      uri: "spotify:track:3bKFDxDxHokwoSMgv3SjXt", startTime: 10),
  SpotifyTrackStartTime(
      uri: "spotify:track:5HVWA8Jm07fwuU1b9B0W3T", startTime: 37),
  SpotifyTrackStartTime(
      uri: "spotify:track:5AEs83CYoPApEjYEJGbTuJ", startTime: 37),
  SpotifyTrackStartTime(
      uri: "spotify:track:0vZCG0H9KhtU7K8MEUVAoV", startTime: 77),
  SpotifyTrackStartTime(
      uri: "spotify:track:6u5M4jPpYkoRV4vVHDQvkd", startTime: 8),
  SpotifyTrackStartTime(
      uri: "spotify:track:7AAcQMV6Uw3YXt9TTx4b6r", startTime: 7),
  SpotifyTrackStartTime(
      uri: "spotify:track:25FitAyupH9zHMouaoMpYF", startTime: 82),
  SpotifyTrackStartTime(
      uri: "spotify:track:4IXxoFmHujKVqZL6BKMZh4", startTime: 56),
  SpotifyTrackStartTime(
      uri: "spotify:track:0U10zFw4GlBacOy9VDGfGL", startTime: 75),
  SpotifyTrackStartTime(
      uri: "spotify:track:5je0DzcnYUy6JCVly2Fi0I", startTime: 10),
  SpotifyTrackStartTime(
      uri: "spotify:track:5hVfRyANdHtNotvCfvMchn", startTime: 0),
  SpotifyTrackStartTime(
      uri: "spotify:track:0wP3e5PzSxafy2TRtlayq9", startTime: 80),
  SpotifyTrackStartTime(
      uri: "spotify:track:0T1OrvV6bOQVL2vSQiDn6W", startTime: 0),
  SpotifyTrackStartTime(
      uri: "spotify:track:4hgAcBgycjmEbvvwsaOcZr", startTime: 60),
  SpotifyTrackStartTime(
      uri: "spotify:track:1OE5bn5HUmCqTLNpo13ya3", startTime: 27),
  SpotifyTrackStartTime(
      uri: "spotify:track:2DX0WG5OGLQLaXb41Cq1IA", startTime: 22),
  SpotifyTrackStartTime(
      uri: "spotify:track:6yeI0vpccn4jvXobaEXIqu", startTime: 46),
  SpotifyTrackStartTime(
      uri: "spotify:track:0FkLMOUTkSTPSAYkIXQ579", startTime: 31),
  SpotifyTrackStartTime(
      uri: "spotify:track:0KT6DLAELYSbgfUemzwGPX", startTime: 15),
];
