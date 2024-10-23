// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'spotify_sync_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SyncProgress {
  int get addedCount => throw _privateConstructorUsedError;
  int get skippedCount => throw _privateConstructorUsedError;
  int get totalTracks => throw _privateConstructorUsedError;

  /// Create a copy of SyncProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SyncProgressCopyWith<SyncProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncProgressCopyWith<$Res> {
  factory $SyncProgressCopyWith(
          SyncProgress value, $Res Function(SyncProgress) then) =
      _$SyncProgressCopyWithImpl<$Res, SyncProgress>;
  @useResult
  $Res call({int addedCount, int skippedCount, int totalTracks});
}

/// @nodoc
class _$SyncProgressCopyWithImpl<$Res, $Val extends SyncProgress>
    implements $SyncProgressCopyWith<$Res> {
  _$SyncProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SyncProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? addedCount = null,
    Object? skippedCount = null,
    Object? totalTracks = null,
  }) {
    return _then(_value.copyWith(
      addedCount: null == addedCount
          ? _value.addedCount
          : addedCount // ignore: cast_nullable_to_non_nullable
              as int,
      skippedCount: null == skippedCount
          ? _value.skippedCount
          : skippedCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalTracks: null == totalTracks
          ? _value.totalTracks
          : totalTracks // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SyncProgressImplCopyWith<$Res>
    implements $SyncProgressCopyWith<$Res> {
  factory _$$SyncProgressImplCopyWith(
          _$SyncProgressImpl value, $Res Function(_$SyncProgressImpl) then) =
      __$$SyncProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int addedCount, int skippedCount, int totalTracks});
}

/// @nodoc
class __$$SyncProgressImplCopyWithImpl<$Res>
    extends _$SyncProgressCopyWithImpl<$Res, _$SyncProgressImpl>
    implements _$$SyncProgressImplCopyWith<$Res> {
  __$$SyncProgressImplCopyWithImpl(
      _$SyncProgressImpl _value, $Res Function(_$SyncProgressImpl) _then)
      : super(_value, _then);

  /// Create a copy of SyncProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? addedCount = null,
    Object? skippedCount = null,
    Object? totalTracks = null,
  }) {
    return _then(_$SyncProgressImpl(
      addedCount: null == addedCount
          ? _value.addedCount
          : addedCount // ignore: cast_nullable_to_non_nullable
              as int,
      skippedCount: null == skippedCount
          ? _value.skippedCount
          : skippedCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalTracks: null == totalTracks
          ? _value.totalTracks
          : totalTracks // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$SyncProgressImpl implements _SyncProgress {
  const _$SyncProgressImpl(
      {this.addedCount = 0, this.skippedCount = 0, this.totalTracks = 0});

  @override
  @JsonKey()
  final int addedCount;
  @override
  @JsonKey()
  final int skippedCount;
  @override
  @JsonKey()
  final int totalTracks;

  @override
  String toString() {
    return 'SyncProgress(addedCount: $addedCount, skippedCount: $skippedCount, totalTracks: $totalTracks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncProgressImpl &&
            (identical(other.addedCount, addedCount) ||
                other.addedCount == addedCount) &&
            (identical(other.skippedCount, skippedCount) ||
                other.skippedCount == skippedCount) &&
            (identical(other.totalTracks, totalTracks) ||
                other.totalTracks == totalTracks));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, addedCount, skippedCount, totalTracks);

  /// Create a copy of SyncProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncProgressImplCopyWith<_$SyncProgressImpl> get copyWith =>
      __$$SyncProgressImplCopyWithImpl<_$SyncProgressImpl>(this, _$identity);
}

abstract class _SyncProgress implements SyncProgress {
  const factory _SyncProgress(
      {final int addedCount,
      final int skippedCount,
      final int totalTracks}) = _$SyncProgressImpl;

  @override
  int get addedCount;
  @override
  int get skippedCount;
  @override
  int get totalTracks;

  /// Create a copy of SyncProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncProgressImplCopyWith<_$SyncProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
