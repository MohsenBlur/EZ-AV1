import 'preset_model.dart';

abstract class BatchNode {
  final String id;
  final String name;
  final String absolutePath;
  
  /// The preset explicitly assigned to this node, if any.
  PresetModel? assignedPreset;

  BatchNode({
    required this.id,
    required this.name,
    required this.absolutePath,
    this.assignedPreset,
  });

  /// The effective preset, which might be inherited or overridden.
  /// (This will be computed by the provider logic, but we can store it here)
  PresetModel? effectivePreset;
}

class FileNode extends BatchNode {
  final String extension;
  final int sizeBytes;

  FileNode({
    required super.id,
    required super.name,
    required super.absolutePath,
    super.assignedPreset,
    required this.extension,
    required this.sizeBytes,
  });
}

class DirectoryNode extends BatchNode {
  final List<BatchNode> children;
  
  /// Computed property: if true, children have divergent effective presets.
  bool hasMixedState = false;

  DirectoryNode({
    required super.id,
    required super.name,
    required super.absolutePath,
    super.assignedPreset,
    this.children = const [],
  });
}
