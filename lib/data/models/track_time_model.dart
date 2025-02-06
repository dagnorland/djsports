import 'package:djsports/data/models/djtrack_model.dart';
import 'package:hive/hive.dart';

part 'track_time_model.g.dart';

const String trackTimeBoxName = 'trackTime';

@HiveType(typeId: 2) // Velg en unik typeId
class TrackTime extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int startTime;

  @HiveField(2)
  final int? startTimeMS;

  TrackTime({
    required this.id,
    required this.startTime,
    this.startTimeMS,
  });

  factory TrackTime.fromJson(Map<String, dynamic> json) => TrackTime(
        id: json['id'] as String,
        startTime: json['startTime'] as int,
        startTimeMS: json['startTimeMS'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime,
        if (startTimeMS != null) 'startTimeMS': startTimeMS,
      };

  factory TrackTime.fromDJTrack(DJTrack track) {
    return TrackTime(
      id: track.id,
      startTime: track.startTime,
      startTimeMS: track.startTimeMS,
    );
  }
}
