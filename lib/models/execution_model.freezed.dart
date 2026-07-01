// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'execution_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ExecutionJob {

 String get id; BatchNode get node;// Only FileNodes should be processed
 JobStatus get status; double get progress;// 0.0 to 1.0
 double get fps; String get eta; List<String> get logLines; String? get errorMessage;
/// Create a copy of ExecutionJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExecutionJobCopyWith<ExecutionJob> get copyWith => _$ExecutionJobCopyWithImpl<ExecutionJob>(this as ExecutionJob, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExecutionJob&&(identical(other.id, id) || other.id == id)&&(identical(other.node, node) || other.node == node)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.eta, eta) || other.eta == eta)&&const DeepCollectionEquality().equals(other.logLines, logLines)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,id,node,status,progress,fps,eta,const DeepCollectionEquality().hash(logLines),errorMessage);

@override
String toString() {
  return 'ExecutionJob(id: $id, node: $node, status: $status, progress: $progress, fps: $fps, eta: $eta, logLines: $logLines, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $ExecutionJobCopyWith<$Res>  {
  factory $ExecutionJobCopyWith(ExecutionJob value, $Res Function(ExecutionJob) _then) = _$ExecutionJobCopyWithImpl;
@useResult
$Res call({
 String id, BatchNode node, JobStatus status, double progress, double fps, String eta, List<String> logLines, String? errorMessage
});




}
/// @nodoc
class _$ExecutionJobCopyWithImpl<$Res>
    implements $ExecutionJobCopyWith<$Res> {
  _$ExecutionJobCopyWithImpl(this._self, this._then);

  final ExecutionJob _self;
  final $Res Function(ExecutionJob) _then;

/// Create a copy of ExecutionJob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? node = null,Object? status = null,Object? progress = null,Object? fps = null,Object? eta = null,Object? logLines = null,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,node: null == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as BatchNode,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JobStatus,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,eta: null == eta ? _self.eta : eta // ignore: cast_nullable_to_non_nullable
as String,logLines: null == logLines ? _self.logLines : logLines // ignore: cast_nullable_to_non_nullable
as List<String>,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExecutionJob].
extension ExecutionJobPatterns on ExecutionJob {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExecutionJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExecutionJob() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExecutionJob value)  $default,){
final _that = this;
switch (_that) {
case _ExecutionJob():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExecutionJob value)?  $default,){
final _that = this;
switch (_that) {
case _ExecutionJob() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  BatchNode node,  JobStatus status,  double progress,  double fps,  String eta,  List<String> logLines,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExecutionJob() when $default != null:
return $default(_that.id,_that.node,_that.status,_that.progress,_that.fps,_that.eta,_that.logLines,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  BatchNode node,  JobStatus status,  double progress,  double fps,  String eta,  List<String> logLines,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _ExecutionJob():
return $default(_that.id,_that.node,_that.status,_that.progress,_that.fps,_that.eta,_that.logLines,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  BatchNode node,  JobStatus status,  double progress,  double fps,  String eta,  List<String> logLines,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _ExecutionJob() when $default != null:
return $default(_that.id,_that.node,_that.status,_that.progress,_that.fps,_that.eta,_that.logLines,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _ExecutionJob implements ExecutionJob {
  const _ExecutionJob({required this.id, required this.node, this.status = JobStatus.pending, this.progress = 0.0, this.fps = 0.0, this.eta = '--:--:--', final  List<String> logLines = const [], this.errorMessage}): _logLines = logLines;
  

@override final  String id;
@override final  BatchNode node;
// Only FileNodes should be processed
@override@JsonKey() final  JobStatus status;
@override@JsonKey() final  double progress;
// 0.0 to 1.0
@override@JsonKey() final  double fps;
@override@JsonKey() final  String eta;
 final  List<String> _logLines;
@override@JsonKey() List<String> get logLines {
  if (_logLines is EqualUnmodifiableListView) return _logLines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_logLines);
}

@override final  String? errorMessage;

/// Create a copy of ExecutionJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExecutionJobCopyWith<_ExecutionJob> get copyWith => __$ExecutionJobCopyWithImpl<_ExecutionJob>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExecutionJob&&(identical(other.id, id) || other.id == id)&&(identical(other.node, node) || other.node == node)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.eta, eta) || other.eta == eta)&&const DeepCollectionEquality().equals(other._logLines, _logLines)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,id,node,status,progress,fps,eta,const DeepCollectionEquality().hash(_logLines),errorMessage);

@override
String toString() {
  return 'ExecutionJob(id: $id, node: $node, status: $status, progress: $progress, fps: $fps, eta: $eta, logLines: $logLines, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$ExecutionJobCopyWith<$Res> implements $ExecutionJobCopyWith<$Res> {
  factory _$ExecutionJobCopyWith(_ExecutionJob value, $Res Function(_ExecutionJob) _then) = __$ExecutionJobCopyWithImpl;
@override @useResult
$Res call({
 String id, BatchNode node, JobStatus status, double progress, double fps, String eta, List<String> logLines, String? errorMessage
});




}
/// @nodoc
class __$ExecutionJobCopyWithImpl<$Res>
    implements _$ExecutionJobCopyWith<$Res> {
  __$ExecutionJobCopyWithImpl(this._self, this._then);

  final _ExecutionJob _self;
  final $Res Function(_ExecutionJob) _then;

/// Create a copy of ExecutionJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? node = null,Object? status = null,Object? progress = null,Object? fps = null,Object? eta = null,Object? logLines = null,Object? errorMessage = freezed,}) {
  return _then(_ExecutionJob(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,node: null == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as BatchNode,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JobStatus,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,eta: null == eta ? _self.eta : eta // ignore: cast_nullable_to_non_nullable
as String,logLines: null == logLines ? _self._logLines : logLines // ignore: cast_nullable_to_non_nullable
as List<String>,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
