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

extension PresetModelConfigComparison on PresetModel {
  /// Returns true if two PresetModels share the exact same encoding configuration,
  /// ignoring unique identifier IDs.
  bool isSameConfiguration(PresetModel? other) {
    if (other == null) return false;
    return name == other.name &&
        denoiseStrength == other.denoiseStrength &&
        photonNoise == other.photonNoise &&
        targetVmaf == other.targetVmaf &&
        audioBitrate == other.audioBitrate &&
        downmixToStereo == other.downmixToStereo;
  }
}
