class Track {
  Album album = Album.empty();
  List<Artists> artists = [];
  int discNumber = 0;
  int durationMs = 0;
  bool explicit = false;
  String href = '';
  String id = '';
  bool isLocal = false;
  String name = '';
  int popularity = 0;
  String previewUrl = '';
  int trackNumber = 0;
  String type = '';
  String uri = '';

  Track(
      {required this.album,
      required this.artists,
      required this.discNumber,
      required this.durationMs,
      required this.explicit,
      required this.href,
      required this.id,
      required this.isLocal,
      required this.name,
      required this.popularity,
      required this.previewUrl,
      required this.trackNumber,
      required this.type,
      required this.uri});

  factory Track.empty() {
    return Track(
        album: Album.empty(),
        artists: [],
        discNumber: 0,
        durationMs: 0,
        explicit: false,
        href: '',
        id: '',
        isLocal: false,
        name: '',
        popularity: 0,
        previewUrl: '',
        trackNumber: 0,
        type: '',
        uri: '');
  }

  Track.fromJson(Map<String, dynamic> json) {
    if (json['album'] != null) {
      album = Album.fromJson(json['album']);
    }
    //album = json['album'];

    if (json['artists'] != null) {
      artists = [];
      json['artists'].forEach((v) {
        artists.add(Artists.fromJson(v));
      });
    }
    discNumber = json['disc_number'] ?? 0;
    durationMs = json['duration_ms'] ?? 100;
    explicit = json['explicit'] ?? false;
    href = json['href'] ?? '';
    id = json['id'] ?? '';
    isLocal = json['is_local'] ?? false;
    name = json['name'] ?? '';
    popularity = json['popularity'] ?? 0;
    previewUrl = json['preview_url'] ?? '';
    trackNumber = json['track_number'] ?? 0;
    type = json['type'] ?? '';
    uri = json['uri'] ?? '';
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['album'] = album.toJson();
    data['artists'] = artists.map((v) => v.toJson()).toList();
    data['disc_number'] = discNumber;
    data['duration_ms'] = durationMs;
    data['explicit'] = explicit;
    data['href'] = href;
    data['id'] = id;
    data['is_local'] = isLocal;
    data['name'] = name;
    data['popularity'] = popularity;
    data['preview_url'] = previewUrl;
    data['track_number'] = trackNumber;
    data['type'] = type;
    data['uri'] = uri;
    return data;
  }
}

class Album {
  String albumType = '';
  List<Artists> artists = [];
  String href = '';
  String id = '';
  List<Images> images = [];
  String name = '';
  String releaseDate = '';
  String releaseDatePrecision = '';
  int totalTracks = 0;
  String type = '';
  String uri = '';

  Album(
      {required this.albumType,
      required this.artists,
      required this.href,
      required this.id,
      required this.images,
      required this.name,
      required this.releaseDate,
      required this.releaseDatePrecision,
      required this.totalTracks,
      required this.type,
      required this.uri});

  factory Album.empty() {
    return Album(
        albumType: '',
        artists: [],
        href: '',
        id: '',
        images: [],
        name: '',
        releaseDate: '',
        releaseDatePrecision: '',
        totalTracks: 0,
        type: '',
        uri: '');
  }

  Album.fromJson(Map<String, dynamic> json) {
    albumType = json['album_type'];
    if (json['artists'] != null) {
      List<Artists> artists = [];
      json['artists'].forEach((v) {
        artists.add(Artists.fromJson(v));
      });
    }
    href = json['href'];
    id = json['id'];
    if (json['images'] != null) {
      images = [];
      json['images'].forEach((v) {
        images.add(Images.fromJson(v));
      });
    }
    name = json['name'];
    releaseDate = json['release_date'];
    releaseDatePrecision = json['release_date_precision'];
    totalTracks = json['total_tracks'];
    type = json['type'];
    uri = json['uri'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['album_type'] = albumType;
    data['artists'] = artists.map((v) => v.toJson()).toList();
    data['href'] = href;
    data['id'] = id;
    data['images'] = images.map((v) => v.toJson()).toList();
    data['name'] = name;
    data['release_date'] = releaseDate;
    data['release_date_precision'] = releaseDatePrecision;
    data['total_tracks'] = totalTracks;
    data['type'] = type;
    data['uri'] = uri;
    return data;
  }
}

class Artists {
  String href = '';
  String id = '';
  String name = '';
  String type = '';
  String uri = '';

  Artists(
      {required this.href,
      required this.id,
      required this.name,
      required this.type,
      required this.uri});

  Artists.fromJson(Map<String, dynamic> json) {
    href = json['href'];
    id = json['id'];
    name = json['name'];
    type = json['type'];
    uri = json['uri'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['href'] = href;
    data['id'] = id;
    data['name'] = name;
    data['type'] = type;
    data['uri'] = uri;
    return data;
  }
}

class Images {
  int height = 0;
  String url = '';
  int width = 0;

  Images({required this.height, required this.url, required this.width});

  Images.fromJson(Map<String, dynamic> json) {
    height = json['height'];
    url = json['url'];
    width = json['width'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['height'] = height;
    data['url'] = url;
    data['width'] = width;
    return data;
  }
}

class ExternalIds {
  String isrc = '';

  ExternalIds({required this.isrc});

  ExternalIds.fromJson(Map<String, dynamic> json) {
    isrc = json['isrc'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['isrc'] = isrc;
    return data;
  }
}
