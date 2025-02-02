import 'package:hive/hive.dart';

part 'track_time_model.g.dart';

const String trackTimeBoxName = 'trackTime';

@HiveType(typeId: 2) // Velg en unik typeId
class TrackTime extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String startTime;

  TrackTime({
    required this.id,
    required this.startTime,
  });

  factory TrackTime.fromJson(Map<String, dynamic> json) => TrackTime(
        id: json['id'] as String,
        startTime: json['startTime'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime,
      };
}
