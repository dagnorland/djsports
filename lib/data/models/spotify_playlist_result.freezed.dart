// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'spotify_playlist_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SpotifyPlaylistResult {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpotifyPlaylistResult);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SpotifyPlaylistResult()';
}


}

/// @nodoc
class $SpotifyPlaylistResultCopyWith<$Res>  {
$SpotifyPlaylistResultCopyWith(SpotifyPlaylistResult _, $Res Function(SpotifyPlaylistResult) __);
}


/// Adds pattern-matching-related methods to [SpotifyPlaylistResult].
extension SpotifyPlaylistResultPatterns on SpotifyPlaylistResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( Data value)?  $default,{TResult Function( Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Data() when $default != null:
return $default(_that);case Error() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( Data value)  $default,{required TResult Function( Error value)  error,}){
final _that = this;
switch (_that) {
case Data():
return $default(_that);case Error():
return error(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( Data value)?  $default,{TResult? Function( Error value)?  error,}){
final _that = this;
switch (_that) {
case Data() when $default != null:
return $default(_that);case Error() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Iterable<Track> tracks)?  $default,{TResult Function( SpotifyAPIError error)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Data() when $default != null:
return $default(_that.tracks);case Error() when error != null:
return error(_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Iterable<Track> tracks)  $default,{required TResult Function( SpotifyAPIError error)  error,}) {final _that = this;
switch (_that) {
case Data():
return $default(_that.tracks);case Error():
return error(_that.error);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Iterable<Track> tracks)?  $default,{TResult? Function( SpotifyAPIError error)?  error,}) {final _that = this;
switch (_that) {
case Data() when $default != null:
return $default(_that.tracks);case Error() when error != null:
return error(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class Data implements SpotifyPlaylistResult {
  const Data(this.tracks);
  

 final  Iterable<Track> tracks;

/// Create a copy of SpotifyPlaylistResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DataCopyWith<Data> get copyWith => _$DataCopyWithImpl<Data>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Data&&const DeepCollectionEquality().equals(other.tracks, tracks));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(tracks));

@override
String toString() {
  return 'SpotifyPlaylistResult(tracks: $tracks)';
}


}

/// @nodoc
abstract mixin class $DataCopyWith<$Res> implements $SpotifyPlaylistResultCopyWith<$Res> {
  factory $DataCopyWith(Data value, $Res Function(Data) _then) = _$DataCopyWithImpl;
@useResult
$Res call({
 Iterable<Track> tracks
});




}
/// @nodoc
class _$DataCopyWithImpl<$Res>
    implements $DataCopyWith<$Res> {
  _$DataCopyWithImpl(this._self, this._then);

  final Data _self;
  final $Res Function(Data) _then;

/// Create a copy of SpotifyPlaylistResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? tracks = null,}) {
  return _then(Data(
null == tracks ? _self.tracks : tracks // ignore: cast_nullable_to_non_nullable
as Iterable<Track>,
  ));
}


}

/// @nodoc


class Error implements SpotifyPlaylistResult {
  const Error(this.error);
  

 final  SpotifyAPIError error;

/// Create a copy of SpotifyPlaylistResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ErrorCopyWith<Error> get copyWith => _$ErrorCopyWithImpl<Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Error&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'SpotifyPlaylistResult.error(error: $error)';
}


}

/// @nodoc
abstract mixin class $ErrorCopyWith<$Res> implements $SpotifyPlaylistResultCopyWith<$Res> {
  factory $ErrorCopyWith(Error value, $Res Function(Error) _then) = _$ErrorCopyWithImpl;
@useResult
$Res call({
 SpotifyAPIError error
});




}
/// @nodoc
class _$ErrorCopyWithImpl<$Res>
    implements $ErrorCopyWith<$Res> {
  _$ErrorCopyWithImpl(this._self, this._then);

  final Error _self;
  final $Res Function(Error) _then;

/// Create a copy of SpotifyPlaylistResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(Error(
null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as SpotifyAPIError,
  ));
}


}

// dart format on
