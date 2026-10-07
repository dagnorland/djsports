/// A Spotify Connect device as returned by `GET /v1/me/player/devices`
/// (via the native `getDevices` channel method on iOS/macOS).
class SpotifyDevice {
  const SpotifyDevice({
    required this.id,
    required this.name,
    this.type = '',
    this.isActive = false,
    this.isRestricted = false,
    this.volumePercent = -1,
  });

  factory SpotifyDevice.fromMap(Map<dynamic, dynamic> map) => SpotifyDevice(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? 'Unknown',
    type: map['type'] as String? ?? '',
    isActive: map['isActive'] as bool? ?? false,
    isRestricted: map['isRestricted'] as bool? ?? false,
    volumePercent: (map['volumePercent'] as num?)?.toInt() ?? -1,
  );

  final String id;
  final String name;

  /// Spotify device type, e.g. `Computer`, `Smartphone`, `Speaker`.
  final String type;
  final bool isActive;
  final bool isRestricted;

  /// -1 when Spotify doesn't report a volume for the device.
  final int volumePercent;

  @override
  bool operator ==(Object other) => other is SpotifyDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name ($type)${isActive ? ' ●' : ''}';
}

/// The Spotify account djSports is authorized as (`GET /v1/me`).
class SpotifyAccount {
  const SpotifyAccount({
    required this.id,
    required this.displayName,
    this.email = '',
    this.product = '',
  });

  factory SpotifyAccount.fromMap(Map<String, String> map) => SpotifyAccount(
    id: map['id'] ?? '',
    displayName: map['displayName'] ?? '',
    email: map['email'] ?? '',
    product: map['product'] ?? '',
  );

  final String id;
  final String displayName;
  final String email;

  /// `premium`, `free`, `open` – empty when unknown.
  final String product;

  bool get isPremium => product == 'premium';

  /// False only when Spotify told us the account is not Premium.
  bool get premiumOrUnknown => product.isEmpty || isPremium;

  String get label => displayName.isNotEmpty ? displayName : id;
}

/// Why djSports will (or won't) play where it plays.
enum SpotifyTargetStatus {
  /// No access token – not logged in to Spotify.
  notConnected,

  /// Devices haven't been loaded yet.
  unknown,

  /// Plays on the device the user picked.
  preferred,

  /// Plays on the account's currently active device.
  active,

  /// Plays on Spotify running on this Mac / iPhone.
  thisDevice,

  /// Spotify is running here but this device isn't in the account's device
  /// list – it is most likely signed in with a different Spotify account.
  otherAccountSuspected,

  /// No usable device – djSports will ask on the next play.
  willAsk,
}

/// Snapshot of who (account) and where (device) djSports plays.
class SpotifySession {
  const SpotifySession({
    this.connected = false,
    this.account,
    this.devices = const [],
    this.devicesLoaded = false,
    this.localDeviceName = '',
    this.localSpotifyRunning,
    this.preferredDeviceId = '',
    this.preferredDeviceName = '',
    this.lastPlayedDevice,
  });

  final bool connected;
  final SpotifyAccount? account;
  final List<SpotifyDevice> devices;
  final bool devicesLoaded;

  /// Name Spotify uses for this machine (macOS computer name / iPhone name).
  final String localDeviceName;

  /// macOS only: whether the Spotify app is running. Null = unknown.
  final bool? localSpotifyRunning;
  final String preferredDeviceId;
  final String preferredDeviceName;
  final SpotifyDevice? lastPlayedDevice;

  SpotifyDevice? get preferredDevice =>
      _firstWhereOrNull((d) => d.id == preferredDeviceId);

  SpotifyDevice? get activeDevice => _firstWhereOrNull((d) => d.isActive);

  SpotifyDevice? get localDevice => localDeviceName.isEmpty
      ? null
      : _firstWhereOrNull((d) => d.name == localDeviceName);

  bool isLocal(SpotifyDevice device) =>
      localDeviceName.isNotEmpty && device.name == localDeviceName;

  /// Spotify runs on this Mac but isn't in the account's device list, so it
  /// is most likely signed in with a different Spotify account.
  bool get suspectsOtherAccount =>
      devicesLoaded && localSpotifyRunning == true && localDevice == null;

  /// The device the next play will go to, mirroring the native order:
  /// preferred → active → this device.
  SpotifyDevice? get targetDevice =>
      preferredDevice ?? activeDevice ?? localDevice;

  SpotifyTargetStatus get status {
    if (!connected) return SpotifyTargetStatus.notConnected;
    if (!devicesLoaded) return SpotifyTargetStatus.unknown;
    // A device the user picked deliberately wins over the mismatch warning.
    if (preferredDevice != null) return SpotifyTargetStatus.preferred;
    if (suspectsOtherAccount) return SpotifyTargetStatus.otherAccountSuspected;
    if (activeDevice != null) return SpotifyTargetStatus.active;
    if (localDevice != null) return SpotifyTargetStatus.thisDevice;
    return SpotifyTargetStatus.willAsk;
  }

  SpotifySession copyWith({
    bool? connected,
    SpotifyAccount? account,
    bool clearAccount = false,
    List<SpotifyDevice>? devices,
    bool? devicesLoaded,
    String? localDeviceName,
    bool? localSpotifyRunning,
    String? preferredDeviceId,
    String? preferredDeviceName,
    SpotifyDevice? lastPlayedDevice,
    bool clearLastPlayedDevice = false,
  }) => SpotifySession(
    connected: connected ?? this.connected,
    account: clearAccount ? null : account ?? this.account,
    devices: devices ?? this.devices,
    devicesLoaded: devicesLoaded ?? this.devicesLoaded,
    localDeviceName: localDeviceName ?? this.localDeviceName,
    localSpotifyRunning: localSpotifyRunning ?? this.localSpotifyRunning,
    preferredDeviceId: preferredDeviceId ?? this.preferredDeviceId,
    preferredDeviceName: preferredDeviceName ?? this.preferredDeviceName,
    lastPlayedDevice: clearLastPlayedDevice
        ? null
        : lastPlayedDevice ?? this.lastPlayedDevice,
  );

  SpotifyDevice? _firstWhereOrNull(bool Function(SpotifyDevice) test) {
    for (final d in devices) {
      if (test(d)) return d;
    }
    return null;
  }
}
