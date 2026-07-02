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

  Map<String, dynamic> toJson();

  static BatchNode fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'directory') {
      return DirectoryNode.fromJson(json);
    } else {
      return FileNode.fromJson(json);
    }
  }
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

  @override
  Map<String, dynamic> toJson() => {
    'type': 'file',
    'id': id,
    'name': name,
    'absolutePath': absolutePath,
    'extension': extension,
    'sizeBytes': sizeBytes,
    'assignedPreset': assignedPreset?.toJson(),
  };

  factory FileNode.fromJson(Map<String, dynamic> json) {
    return FileNode(
      id: json['id'] as String,
      name: json['name'] as String,
      absolutePath: json['absolutePath'] as String,
      extension: json['extension'] as String,
      sizeBytes: json['sizeBytes'] as int,
      assignedPreset: json['assignedPreset'] != null 
          ? PresetModel.fromJson(json['assignedPreset'] as Map<String, dynamic>) 
          : null,
    );
  }
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
    List<BatchNode>? children,
  }) : children = children != null ? List<BatchNode>.from(children) : <BatchNode>[];

  @override
  Map<String, dynamic> toJson() => {
    'type': 'directory',
    'id': id,
    'name': name,
    'absolutePath': absolutePath,
    'assignedPreset': assignedPreset?.toJson(),
    'children': children.map((e) => e.toJson()).toList(),
  };

  factory DirectoryNode.fromJson(Map<String, dynamic> json) {
    return DirectoryNode(
      id: json['id'] as String,
      name: json['name'] as String,
      absolutePath: json['absolutePath'] as String,
      assignedPreset: json['assignedPreset'] != null 
          ? PresetModel.fromJson(json['assignedPreset'] as Map<String, dynamic>) 
          : null,
      children: (json['children'] as List<dynamic>)
          .map((e) => BatchNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
