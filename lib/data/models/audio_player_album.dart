class AudioPlayerAlbum {
  final int id;
  final String title;
  final String artist;
  final int songCount;
  final String? path;

  const AudioPlayerAlbum({
    required this.id,
    required this.title,
    required this.artist,
    required this.songCount,
    required this.path,
  });
}
