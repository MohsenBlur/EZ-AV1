import 'package:freezed_annotation/freezed_annotation.dart';

part 'preset_model.freezed.dart';
part 'preset_model.g.dart';

@freezed
abstract class PresetModel with _$PresetModel {
  const factory PresetModel({
    required String id,
    required String name,
    
    // Phase 1: Texture
    @Default(0) double denoiseStrength,
    
    // Phase 2: Bitrate
    @Default(0) int photonNoise,
    @Default(95) double targetVmaf,
    
    // Audio
    @Default(128) int audioBitrate, // in kbps
    @Default(false) bool downmixToStereo,
  }) = _PresetModel;

  factory PresetModel.fromJson(Map<String, dynamic> json) => 
      _$PresetModelFromJson(json);
}
