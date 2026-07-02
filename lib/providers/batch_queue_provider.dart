import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/batch_node_model.dart';
import '../models/preset_model.dart';
import 'package:path/path.dart' as p;

final batchQueueProvider = NotifierProvider<BatchQueueNotifier, List<BatchNode>>(() {
  return BatchQueueNotifier();
});

class BatchQueueNotifier extends Notifier<List<BatchNode>> {
  final _uuid = const Uuid();
  Future<void>? _initialLoadFuture;

  @override
  List<BatchNode> build() {
    _initialLoadFuture = _loadState();
    return [];
  }

  Future<void> ensureInitialized() async {
    if (_initialLoadFuture != null) {
      await _initialLoadFuture;
    }
  }

  Future<void> _loadState() async {
    try {
      final directory = await getApplicationSupportDirectory();
      if (!ref.mounted) return;
      final file = File(p.join(directory.path, 'state.json'));
      if (file.existsSync()) {
        final content = await file.readAsString();
        if (!ref.mounted) return;
        final List<dynamic> jsonList = jsonDecode(content);
        final diskNodes = jsonList.map((e) => BatchNode.fromJson(e as Map<String, dynamic>)).toList();

        // Merge disk nodes with any nodes that were added before _loadState finished
        final existingIds = {for (var n in state) n.id};
        final newDiskNodes = diskNodes.where((n) => !existingIds.contains(n.id)).toList();
        state = [...newDiskNodes, ...state];
        _recalculateState();
      }
    } catch (e) {
      // Ignore load errors, start fresh
    }
  }

  Future<void> _saveState() async {
    if (!ref.mounted) return;
    try {
      final directory = await getApplicationSupportDirectory();
      if (!ref.mounted) return;
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      final file = File(p.join(directory.path, 'state.json'));
      await file.writeAsString(jsonEncode(state.map((e) => e.toJson()).toList()));
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Recursively parses a directory from disk and loads it into the queue.
  Future<void> importDirectory(String path) async {
    await ensureInitialized();
    final dir = Directory(path);
    if (!await dir.exists()) return;

    final rootNodes = await _parseDirectory(dir);
    state = [...state, ...rootNodes];
    _recalculateState();
    _saveState();
  }

  /// Adds a list of flat file paths to the queue
  Future<void> addFiles(List<String> filePaths) async {
    await ensureInitialized();
    final newNodes = <BatchNode>[];
    for (final path in filePaths) {
      final file = File(path);
      if (await file.exists()) {
        final stat = await file.stat();
        newNodes.add(FileNode(
          id: _uuid.v4(),
          name: p.basename(path),
          absolutePath: file.absolute.path,
          extension: p.extension(path).toLowerCase(),
          sizeBytes: stat.size,
        ));
      }
    }
    if (newNodes.isNotEmpty) {
      state = [...state, ...newNodes];
      _recalculateState();
      _saveState();
    }
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
  Future<void> assignPreset(String nodeId, PresetModel preset) async {
    await ensureInitialized();
    final node = _findNode(state, nodeId);
    if (node != null) {
      node.assignedPreset = preset;
      _recalculateState();
      _saveState();
    }
  }

  /// Removes a node by ID
  Future<void> removeNode(String nodeId) async {
    await ensureInitialized();
    bool removed = _removeNodeRecursive(state, nodeId);
    if (removed) {
      _recalculateState();
      _saveState();
    }
  }

  bool _removeNodeRecursive(List<BatchNode> nodes, String id) {
    for (int i = 0; i < nodes.length; i++) {
      if (nodes[i].id == id) {
        nodes.removeAt(i);
        return true;
      }
      final node = nodes[i];
      if (node is DirectoryNode) {
        if (_removeNodeRecursive(node.children, id)) return true;
      }
    }
    return false;
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
