import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/batch_node_model.dart';
import '../models/preset_model.dart';
import 'package:path/path.dart' as p;

final batchQueueProvider = NotifierProvider<BatchQueueNotifier, List<BatchNode>>(() {
  return BatchQueueNotifier();
});

class BatchQueueNotifier extends Notifier<List<BatchNode>> {
  @override
  List<BatchNode> build() => [];
  final _uuid = const Uuid();

  /// Recursively parses a directory from disk and loads it into the queue.
  Future<void> importDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return;

    final rootNodes = await _parseDirectory(dir);
    state = [...state, ...rootNodes];
    _recalculateState();
  }

  Future<List<BatchNode>> _parseDirectory(Directory dir) async {
    final nodes = <BatchNode>[];
    try {
      final entities = await dir.list().toList();
      // Sort: directories first, then files alphabetically
      entities.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });

      for (var entity in entities) {
        final name = p.basename(entity.path);
        final absolutePath = entity.absolute.path;

        if (entity is Directory) {
          final children = await _parseDirectory(entity);
          // Only add directories that contain video files eventually
          if (children.isNotEmpty) {
            nodes.add(DirectoryNode(
              id: _uuid.v4(),
              name: name,
              absolutePath: absolutePath,
              children: children,
            ));
          }
        } else if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          // Filter for common video formats
          if (const ['.mp4', '.mkv', '.avi', '.mov', '.webm'].contains(ext)) {
            final stat = await entity.stat();
            nodes.add(FileNode(
              id: _uuid.v4(),
              name: name,
              absolutePath: absolutePath,
              extension: ext,
              sizeBytes: stat.size,
            ));
          }
        }
      }
    } catch (e) {
      // Handle permission errors silently for now
    }
    return nodes;
  }

  /// Assigns a preset to a specific node (directory or file)
  void assignPreset(String nodeId, PresetModel preset) {
    final node = _findNode(state, nodeId);
    if (node != null) {
      node.assignedPreset = preset;
      _recalculateState();
    }
  }

  /// Finds a node by ID recursively
  BatchNode? _findNode(List<BatchNode> nodes, String id) {
    for (var node in nodes) {
      if (node.id == id) return node;
      if (node is DirectoryNode) {
        final child = _findNode(node.children, id);
        if (child != null) return child;
      }
    }
    return null;
  }

  /// Recursively recalculates the effective presets and the mixed state flags
  void _recalculateState() {
    for (var node in state) {
      _computeEffectiveState(node, null);
    }
    // Trigger UI rebuild by creating a shallow copy of the top level list
    state = [...state];
  }

  /// Computes effective presets based on inheritance (cascade vs override)
  PresetModel? _computeEffectiveState(BatchNode node, PresetModel? parentPreset) {
    node.effectivePreset = node.assignedPreset ?? parentPreset;

    if (node is DirectoryNode) {
      bool hasMixed = false;
      PresetModel? firstChildPreset;
      bool isFirst = true;

      for (var child in node.children) {
        final childEffective = _computeEffectiveState(child, node.effectivePreset);
        
        if (isFirst) {
          firstChildPreset = childEffective;
          isFirst = false;
        } else if (childEffective != firstChildPreset) {
          hasMixed = true;
        }

        if (child is DirectoryNode && child.hasMixedState) {
          hasMixed = true;
        }
      }
      
      node.hasMixedState = hasMixed;
      return node.effectivePreset;
    }

    return node.effectivePreset;
  }
}
