import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/batch_node_model.dart';
import '../models/preset_model.dart';

final batchQueueProvider = StateNotifierProvider<BatchQueueNotifier, List<BatchNode>>((ref) {
  return BatchQueueNotifier();
});

class BatchQueueNotifier extends StateNotifier<List<BatchNode>> {
  BatchQueueNotifier() : super([]);

  /// Loads a root directory and parses it.
  void loadRootNodes(List<BatchNode> nodes) {
    state = nodes;
    _recalculateState();
  }

  /// Assigns a preset to a specific node (directory or file)
  void assignPreset(String nodeId, PresetModel preset) {
    // Deep clone the state to ensure Riverpod notices the change
    // For simplicity, we just mutate and re-assign the list in this skeleton.
    // In a production app, we'd use immutable updates, but Dart object trees 
    // are easiest handled by mutating and triggering state = [...state];
    
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
    // Trigger UI rebuild
    state = [...state];
  }

  /// Computes effective presets based on inheritance (cascade vs override)
  PresetModel? _computeEffectiveState(BatchNode node, PresetModel? parentPreset) {
    // 1. Determine this node's effective preset
    // If it has its own assigned preset, that overrides the parent.
    // Otherwise, it inherits the parent's preset.
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
          // If any child has a different effective preset than the first child, it's mixed.
          hasMixed = true;
        }

        // If a child directory itself is mixed, this directory is implicitly mixed.
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
