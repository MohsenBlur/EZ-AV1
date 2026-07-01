// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preset_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PresetModel _$PresetModelFromJson(Map<String, dynamic> json) => _PresetModel(
  id: json['id'] as String,
  name: json['name'] as String,
  denoiseStrength: (json['denoiseStrength'] as num?)?.toDouble() ?? 0,
  photonNoise: (json['photonNoise'] as num?)?.toInt() ?? 0,
  targetVmaf: (json['targetVmaf'] as num?)?.toDouble() ?? 95,
  audioBitrate: (json['audioBitrate'] as num?)?.toInt() ?? 128,
  downmixToStereo: json['downmixToStereo'] as bool? ?? false,
);

Map<String, dynamic> _$PresetModelToJson(_PresetModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'denoiseStrength': instance.denoiseStrength,
      'photonNoise': instance.photonNoise,
      'targetVmaf': instance.targetVmaf,
      'audioBitrate': instance.audioBitrate,
      'downmixToStereo': instance.downmixToStereo,
    };
