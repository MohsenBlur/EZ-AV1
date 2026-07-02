import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

        // Prune any nodes whose underlying files/directories no longer exist on disk
        final validNodes = _filterExistingNodes(diskNodes);

        // Deduplicate by absolutePath
        final existingPaths = BatchNode.extractFileNodes(state).map((n) => n.absolutePath).toSet();
        final uniqueDiskNodes = validNodes.where((n) {
          if (n is FileNode) return !existingPaths.contains(n.absolutePath);
          return true;
        }).toList();

        state = [...uniqueDiskNodes, ...state];
        _recalculateState();
        _saveState();
      }
    } catch (e) {
      // Ignore load errors, start fresh
    }
  }

  List<BatchNode> _filterExistingNodes(List<BatchNode> nodes) {
    final result = <BatchNode>[];
    for (final node in nodes) {
      if (node is FileNode) {
        if (File(node.absolutePath).existsSync()) {
          result.add(node);
        } else {
          debugPrint('Pruned non-existent batch file from session: ${node.absolutePath}');
        }
      } else if (node is DirectoryNode) {
        final validChildren = _filterExistingNodes(node.children);
        if (validChildren.isNotEmpty) {
          result.add(DirectoryNode(
            id: node.id,
            name: node.name,
            absolutePath: node.absolutePath,
            assignedPreset: node.assignedPreset,
            children: validChildren,
          ));
        } else {
          debugPrint('Pruned non-existent directory from session: ${node.absolutePath}');
        }
      }
    }
    return result;
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
    
    // Filter duplicates
    final existingPaths = BatchNode.extractFileNodes(state).map((n) => n.absolutePath).toSet();
    final uniqueNodes = rootNodes.where((n) {
      if (n is FileNode) return !existingPaths.contains(n.absolutePath);
      return true;
    }).toList();

    state = [...state, ...uniqueNodes];
    _recalculateState();
    _saveState();
  }

  /// Adds a list of flat file paths to the queue without duplicates
  Future<void> addFiles(List<String> filePaths) async {
    await ensureInitialized();
    final existingPaths = BatchNode.extractFileNodes(state).map((n) => n.absolutePath).toSet();
    final newNodes = <BatchNode>[];
    
    for (final path in filePaths) {
      if (existingPaths.contains(path)) continue; // Skip duplicate!
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
        existingPaths.add(file.absolute.path);
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
          if (supportedVideoExtensions.contains(ext)) {
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
    state = [...state];
  }

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
        } else if (_presetsDiffer(childEffective, firstChildPreset)) {
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

  bool _presetsDiffer(PresetModel? p1, PresetModel? p2) {
    if (p1 == null && p2 == null) return false;
    if (p1 == null || p2 == null) return true;
    return !p1.isSameConfiguration(p2);
  }
}
