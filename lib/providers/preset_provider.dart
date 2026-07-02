import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/preset_model.dart';

final presetProvider = NotifierProvider<PresetNotifier, List<PresetModel>>(() {
  return PresetNotifier();
});

class PresetNotifier extends Notifier<List<PresetModel>> {
  final _uuid = const Uuid();
  Future<void>? _loadFuture;

  static const List<PresetModel> defaultPresets = [
    PresetModel(
      id: 'default_vmaf_93',
      name: 'EZ-AV1 Standard (VMAF 93)',
      denoiseStrength: 0.0,
      targetVmaf: 93.0,
      photonNoise: 0,
    ),
    PresetModel(
      id: 'default_anime_denoise',
      name: 'Anime Denoised (VMAF 91)',
      denoiseStrength: 2.0,
      targetVmaf: 91.0,
      photonNoise: 10,
    ),
    PresetModel(
      id: 'default_film_archival',
      name: 'Film Archival & Grain (VMAF 95)',
      denoiseStrength: 0.0,
      targetVmaf: 95.0,
      photonNoise: 20,
    ),
  ];

  @override
  List<PresetModel> build() {
    _loadFuture = _loadState();
    return defaultPresets;
  }

  Future<void> ensureInitialized() async {
    if (_loadFuture != null) {
      await _loadFuture;
    }
  }

  Future<void> _loadState() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File(p.join(directory.path, 'custom_presets.json'));
      if (file.existsSync()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        final customNodes = jsonList.map((e) => PresetModel.fromJson(e as Map<String, dynamic>)).toList();

        final existingIds = {for (var p in defaultPresets) p.id};
        final uniqueCustom = customNodes.where((p) => !existingIds.contains(p.id)).toList();

        state = [...defaultPresets, ...uniqueCustom];
      }
    } catch (e) {
      debugPrint('[PresetProvider] Error loading custom presets: $e');
    }
  }

  Future<void> _saveState() async {
    try {
      final directory = await getApplicationSupportDirectory();
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      final file = File(p.join(directory.path, 'custom_presets.json'));
      final customOnly = state.where((p) => !p.id.startsWith('default_')).toList();
      await file.writeAsString(jsonEncode(customOnly.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[PresetProvider] Error saving custom presets: $e');
    }
  }

  Future<PresetModel> createAndSavePreset({
    required String name,
    required double denoiseStrength,
    required double targetVmaf,
    required int photonNoise,
  }) async {
    await ensureInitialized();
    final newPreset = PresetModel(
      id: _uuid.v4(),
      name: name,
      denoiseStrength: denoiseStrength,
      targetVmaf: targetVmaf,
      photonNoise: photonNoise,
    );

    state = [...state, newPreset];
    await _saveState();
    return newPreset;
  }

  Future<void> deletePreset(String id) async {
    if (id.startsWith('default_')) return; // Protect built-in defaults
    await ensureInitialized();
    state = state.where((p) => p.id != id).toList();
    await _saveState();
  }
}
