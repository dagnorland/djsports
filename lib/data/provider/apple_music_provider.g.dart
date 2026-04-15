// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apple_music_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appleMusicRepository)
final appleMusicRepositoryProvider = AppleMusicRepositoryProvider._();

final class AppleMusicRepositoryProvider
    extends
        $FunctionalProvider<
          AppleMusicRepository,
          AppleMusicRepository,
          AppleMusicRepository
        >
    with $Provider<AppleMusicRepository> {
  AppleMusicRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appleMusicRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appleMusicRepositoryHash();

  @$internal
  @override
  $ProviderElement<AppleMusicRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppleMusicRepository create(Ref ref) {
    return appleMusicRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppleMusicRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppleMusicRepository>(value),
    );
  }
}

String _$appleMusicRepositoryHash() =>
    r'87fa1eb5b84c0a7653f9c1ed13beb09920bff311';

@ProviderFor(AppleMusicSearch)
final appleMusicSearchProvider = AppleMusicSearchProvider._();

final class AppleMusicSearchProvider
    extends $AsyncNotifierProvider<AppleMusicSearch, List<AppleMusicTrack>> {
  AppleMusicSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appleMusicSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appleMusicSearchHash();

  @$internal
  @override
  AppleMusicSearch create() => AppleMusicSearch();
}

String _$appleMusicSearchHash() => r'2dcb41778350748204aa9ed76b5f0e64499b163e';

abstract class _$AppleMusicSearch
    extends $AsyncNotifier<List<AppleMusicTrack>> {
  FutureOr<List<AppleMusicTrack>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<AppleMusicTrack>>, List<AppleMusicTrack>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<AppleMusicTrack>>,
                List<AppleMusicTrack>
              >,
              AsyncValue<List<AppleMusicTrack>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
