import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:djsports/data/models/djplaylist_model.dart';
import 'package:djsports/data/models/djtrack_model.dart';
import 'package:djsports/data/models/track_time_model.dart';
import 'package:djsports/data/repo/djplaylist_repository.dart';
import 'package:djsports/data/repo/djtrack_repository.dart';
import 'package:djsports/data/repo/track_time_repository.dart';

class CloudBackupSummary {
  const CloudBackupSummary({
    required this.id,
    required this.profileName,
    required this.spotifyUserId,
    required this.spotifyDisplayName,
    required this.deviceName,
    required this.createdAt,
    required this.playlistCount,
    required this.trackCount,
    required this.tracksWithStartTime,
    required this.version,
  });

  final String id;
  final String profileName;
  final String spotifyUserId;
  final String spotifyDisplayName;
  final String deviceName;
  final DateTime createdAt;
  final int playlistCount;
  final int trackCount;
  final int tracksWithStartTime;
  final String version;
}

class CloudBackupService {
  static const _collection = 'backups';
  static const _version = '1.0';
  static const _maxBackupsPerDevice = 5;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<void> createBackup({
    required String profileName,
    required String spotifyUserId,
    required String spotifyDisplayName,
    required String deviceName,
    required DJPlaylistRepo playlistRepo,
    required DJTrackRepo trackRepo,
    required TrackTimeRepo trackTimeRepo,
  }) async {
    final playlists = playlistRepo.getDJPlaylists();
    final tracks = trackRepo.getDJTracks();
    final trackTimes = trackTimeRepo.getTrackTimes();
    final tracksWithStartTime = tracks
        .where((t) => t.startTime > 0 || t.startTimeMS > 0)
        .length;

    // Enforce 5-backup limit per device (delete oldest when at limit).
    final existing = await listBackupsForProfile(profileName);
    final deviceBackups = existing
        .where((b) => b.deviceName == deviceName)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // oldest first
    if (deviceBackups.length >= _maxBackupsPerDevice) {
      final toDelete = deviceBackups.take(
        deviceBackups.length - (_maxBackupsPerDevice - 1),
      );
      for (final old in toDelete) {
        await deleteBackup(old.id);
      }
    }

    await _db.collection(_collection).add({
      'profileName': profileName,
      'spotifyUserId': spotifyUserId,
      'spotifyDisplayName': spotifyDisplayName,
      'deviceName': deviceName,
      'createdAt': FieldValue.serverTimestamp(),
      'version': _version,
      'playlistCount': playlists.length,
      'trackCount': tracks.length,
      'tracksWithStartTime': tracksWithStartTime,
      'playlists': playlists.map((p) => p.toJson()).toList(),
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'trackTimes': trackTimes.map((t) => t.toJson()).toList(),
    });
  }

  Future<List<CloudBackupSummary>> listBackupsForProfile(
    String profileName,
  ) async {
    // No orderBy in Firestore to avoid requiring a composite index.
    // Sort by createdAt descending in Dart after fetching.
    final snapshot = await _db
        .collection(_collection)
        .where('profileName', isEqualTo: profileName)
        .get()
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Firestore timed out — check that Firestore Database is enabled '
            'in your Firebase project and security rules allow read/write.',
          ),
        );

    final results = snapshot.docs.map((doc) {
      final data = doc.data();
      final ts = data['createdAt'] as Timestamp?;
      return CloudBackupSummary(
        id: doc.id,
        profileName: data['profileName'] as String? ?? '',
        spotifyUserId: data['spotifyUserId'] as String? ?? '',
        spotifyDisplayName: data['spotifyDisplayName'] as String? ?? '',
        deviceName: data['deviceName'] as String? ?? '',
        createdAt: ts?.toDate() ?? DateTime.now(),
        playlistCount: data['playlistCount'] as int? ?? 0,
        trackCount: data['trackCount'] as int? ?? 0,
        tracksWithStartTime: data['tracksWithStartTime'] as int? ?? 0,
        version: data['version'] as String? ?? '',
      );
    }).toList();

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  Future<void> restoreBackup({
    required String backupId,
    required DJPlaylistRepo playlistRepo,
    required DJTrackRepo trackRepo,
    required TrackTimeRepo trackTimeRepo,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Fetching backup from cloud…');
    final doc = await _db.collection(_collection).doc(backupId).get();
    if (!doc.exists) throw Exception('Backup not found: $backupId');

    final data = doc.data()!;

    final playlistsJson = data['playlists'] as List<dynamic>? ?? [];
    final tracksJson = data['tracks'] as List<dynamic>? ?? [];
    final trackTimesJson = data['trackTimes'] as List<dynamic>? ?? [];

    onProgress?.call('Clearing local data…');
    // Initialize Hive boxes by reading first (needed before deleteAll).
    playlistRepo.getDJPlaylists();
    trackRepo.getDJTracks();
    trackTimeRepo.getTrackTimes();

    playlistRepo.deleteAll();
    trackRepo.deleteAll();
    trackTimeRepo.deleteAll();

    onProgress?.call('Restoring ${playlistsJson.length} playlists…');
    for (final p in playlistsJson) {
      final playlist = DJPlaylist.fromJson(
        Map<String, dynamic>.from(p as Map),
      );
      playlistRepo.addDJPlaylist(playlist);
    }

    onProgress?.call('Restoring ${tracksJson.length} tracks…');
    for (final t in tracksJson) {
      final track = DJTrack.fromJson(Map<String, dynamic>.from(t as Map));
      trackRepo.addDJTrack(track);
    }

    onProgress?.call('Restoring ${trackTimesJson.length} track timings…');
    for (final tt in trackTimesJson) {
      final time = TrackTime.fromJson(
        Map<String, dynamic>.from(tt as Map),
      );
      trackTimeRepo.addTrackTime(time);
    }

    onProgress?.call('Done!');
  }

  Future<void> deleteBackup(String backupId) =>
      _db.collection(_collection).doc(backupId).delete();
}
