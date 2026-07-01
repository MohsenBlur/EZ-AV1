// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'preset_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PresetModel {

 String get id; String get name;// Phase 1: Texture
 double get denoiseStrength;// Phase 2: Bitrate
 int get photonNoise; double get targetVmaf;// Audio
 int get audioBitrate;// in kbps
 bool get downmixToStereo;
/// Create a copy of PresetModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PresetModelCopyWith<PresetModel> get copyWith => _$PresetModelCopyWithImpl<PresetModel>(this as PresetModel, _$identity);

  /// Serializes this PresetModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PresetModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.denoiseStrength, denoiseStrength) || other.denoiseStrength == denoiseStrength)&&(identical(other.photonNoise, photonNoise) || other.photonNoise == photonNoise)&&(identical(other.targetVmaf, targetVmaf) || other.targetVmaf == targetVmaf)&&(identical(other.audioBitrate, audioBitrate) || other.audioBitrate == audioBitrate)&&(identical(other.downmixToStereo, downmixToStereo) || other.downmixToStereo == downmixToStereo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,denoiseStrength,photonNoise,targetVmaf,audioBitrate,downmixToStereo);

@override
String toString() {
  return 'PresetModel(id: $id, name: $name, denoiseStrength: $denoiseStrength, photonNoise: $photonNoise, targetVmaf: $targetVmaf, audioBitrate: $audioBitrate, downmixToStereo: $downmixToStereo)';
}


}

/// @nodoc
abstract mixin class $PresetModelCopyWith<$Res>  {
  factory $PresetModelCopyWith(PresetModel value, $Res Function(PresetModel) _then) = _$PresetModelCopyWithImpl;
@useResult
$Res call({
 String id, String name, double denoiseStrength, int photonNoise, double targetVmaf, int audioBitrate, bool downmixToStereo
});




}
/// @nodoc
class _$PresetModelCopyWithImpl<$Res>
    implements $PresetModelCopyWith<$Res> {
  _$PresetModelCopyWithImpl(this._self, this._then);

  final PresetModel _self;
  final $Res Function(PresetModel) _then;

/// Create a copy of PresetModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? denoiseStrength = null,Object? photonNoise = null,Object? targetVmaf = null,Object? audioBitrate = null,Object? downmixToStereo = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,denoiseStrength: null == denoiseStrength ? _self.denoiseStrength : denoiseStrength // ignore: cast_nullable_to_non_nullable
as double,photonNoise: null == photonNoise ? _self.photonNoise : photonNoise // ignore: cast_nullable_to_non_nullable
as int,targetVmaf: null == targetVmaf ? _self.targetVmaf : targetVmaf // ignore: cast_nullable_to_non_nullable
as double,audioBitrate: null == audioBitrate ? _self.audioBitrate : audioBitrate // ignore: cast_nullable_to_non_nullable
as int,downmixToStereo: null == downmixToStereo ? _self.downmixToStereo : downmixToStereo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PresetModel].
extension PresetModelPatterns on PresetModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PresetModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PresetModel() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PresetModel value)  $default,){
final _that = this;
switch (_that) {
case _PresetModel():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PresetModel value)?  $default,){
final _that = this;
switch (_that) {
case _PresetModel() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  double denoiseStrength,  int photonNoise,  double targetVmaf,  int audioBitrate,  bool downmixToStereo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PresetModel() when $default != null:
return $default(_that.id,_that.name,_that.denoiseStrength,_that.photonNoise,_that.targetVmaf,_that.audioBitrate,_that.downmixToStereo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  double denoiseStrength,  int photonNoise,  double targetVmaf,  int audioBitrate,  bool downmixToStereo)  $default,) {final _that = this;
switch (_that) {
case _PresetModel():
return $default(_that.id,_that.name,_that.denoiseStrength,_that.photonNoise,_that.targetVmaf,_that.audioBitrate,_that.downmixToStereo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  double denoiseStrength,  int photonNoise,  double targetVmaf,  int audioBitrate,  bool downmixToStereo)?  $default,) {final _that = this;
switch (_that) {
case _PresetModel() when $default != null:
return $default(_that.id,_that.name,_that.denoiseStrength,_that.photonNoise,_that.targetVmaf,_that.audioBitrate,_that.downmixToStereo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PresetModel implements PresetModel {
  const _PresetModel({required this.id, required this.name, this.denoiseStrength = 0, this.photonNoise = 0, this.targetVmaf = 95, this.audioBitrate = 128, this.downmixToStereo = false});
  factory _PresetModel.fromJson(Map<String, dynamic> json) => _$PresetModelFromJson(json);

@override final  String id;
@override final  String name;
// Phase 1: Texture
@override@JsonKey() final  double denoiseStrength;
// Phase 2: Bitrate
@override@JsonKey() final  int photonNoise;
@override@JsonKey() final  double targetVmaf;
// Audio
@override@JsonKey() final  int audioBitrate;
// in kbps
@override@JsonKey() final  bool downmixToStereo;

/// Create a copy of PresetModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PresetModelCopyWith<_PresetModel> get copyWith => __$PresetModelCopyWithImpl<_PresetModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PresetModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PresetModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.denoiseStrength, denoiseStrength) || other.denoiseStrength == denoiseStrength)&&(identical(other.photonNoise, photonNoise) || other.photonNoise == photonNoise)&&(identical(other.targetVmaf, targetVmaf) || other.targetVmaf == targetVmaf)&&(identical(other.audioBitrate, audioBitrate) || other.audioBitrate == audioBitrate)&&(identical(other.downmixToStereo, downmixToStereo) || other.downmixToStereo == downmixToStereo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,denoiseStrength,photonNoise,targetVmaf,audioBitrate,downmixToStereo);

@override
String toString() {
  return 'PresetModel(id: $id, name: $name, denoiseStrength: $denoiseStrength, photonNoise: $photonNoise, targetVmaf: $targetVmaf, audioBitrate: $audioBitrate, downmixToStereo: $downmixToStereo)';
}


}

/// @nodoc
abstract mixin class _$PresetModelCopyWith<$Res> implements $PresetModelCopyWith<$Res> {
  factory _$PresetModelCopyWith(_PresetModel value, $Res Function(_PresetModel) _then) = __$PresetModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, double denoiseStrength, int photonNoise, double targetVmaf, int audioBitrate, bool downmixToStereo
});




}
/// @nodoc
class __$PresetModelCopyWithImpl<$Res>
    implements _$PresetModelCopyWith<$Res> {
  __$PresetModelCopyWithImpl(this._self, this._then);

  final _PresetModel _self;
  final $Res Function(_PresetModel) _then;

/// Create a copy of PresetModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? denoiseStrength = null,Object? photonNoise = null,Object? targetVmaf = null,Object? audioBitrate = null,Object? downmixToStereo = null,}) {
  return _then(_PresetModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,denoiseStrength: null == denoiseStrength ? _self.denoiseStrength : denoiseStrength // ignore: cast_nullable_to_non_nullable
as double,photonNoise: null == photonNoise ? _self.photonNoise : photonNoise // ignore: cast_nullable_to_non_nullable
as int,targetVmaf: null == targetVmaf ? _self.targetVmaf : targetVmaf // ignore: cast_nullable_to_non_nullable
as double,audioBitrate: null == audioBitrate ? _self.audioBitrate : audioBitrate // ignore: cast_nullable_to_non_nullable
as int,downmixToStereo: null == downmixToStereo ? _self.downmixToStereo : downmixToStereo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
