import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'batch_queue_provider.dart';
import '../models/batch_node_model.dart';

enum SourceType {
  unselected,
  film,
  clean
}

class WorkflowState {
  final List<String> batchFiles;
  final SourceType sourceType;
  final double denoiseStrength;
  final bool isPhase1Complete;
  final bool isPhase2Complete;

  const WorkflowState({
    this.batchFiles = const [],
    this.sourceType = SourceType.unselected,
    this.denoiseStrength = 0.0,
    this.isPhase1Complete = false,
    this.isPhase2Complete = false,
  });

  WorkflowState copyWith({
    List<String>? batchFiles,
    SourceType? sourceType,
    double? denoiseStrength,
    bool? isPhase1Complete,
    bool? isPhase2Complete,
  }) {
    return WorkflowState(
      batchFiles: batchFiles ?? this.batchFiles,
      sourceType: sourceType ?? this.sourceType,
      denoiseStrength: denoiseStrength ?? this.denoiseStrength,
      isPhase1Complete: isPhase1Complete ?? this.isPhase1Complete,
      isPhase2Complete: isPhase2Complete ?? this.isPhase2Complete,
    );
  }
}

class WorkflowNotifier extends Notifier<WorkflowState> {
  @override
  WorkflowState build() {
    // Listen to changes in batchQueueProvider to automatically sync batchFiles
    ref.listen<List<BatchNode>>(batchQueueProvider, (previous, next) {
      _syncFilesFromQueue(next);
    });

    final currentQueue = ref.read(batchQueueProvider);
    final fileNodes = BatchNode.extractFileNodes(currentQueue);
    final filePaths = fileNodes.map((f) => f.absolutePath).toList();

    return WorkflowState(batchFiles: filePaths);
  }

  void _syncFilesFromQueue(List<BatchNode> nodes) {
    final fileNodes = BatchNode.extractFileNodes(nodes);
    final filePaths = fileNodes.map((f) => f.absolutePath).toList();
    state = state.copyWith(batchFiles: filePaths);
  }

  void setBatchFiles(List<String> files) {
    state = state.copyWith(batchFiles: files);
  }

  void addBatchFiles(List<String> files) {
    final current = Set<String>.from(state.batchFiles);
    current.addAll(files);
    state = state.copyWith(batchFiles: current.toList());
  }

  void setSourceType(SourceType type) {
    state = state.copyWith(sourceType: type);
  }

  void setDenoiseStrength(double strength) {
    state = state.copyWith(denoiseStrength: strength);
  }

  void completePhase1([double? denoiseStrength]) {
    state = state.copyWith(
      denoiseStrength: denoiseStrength ?? state.denoiseStrength,
      isPhase1Complete: true,
    );
  }

  void completePhase2() {
    state = state.copyWith(isPhase2Complete: true);
  }

  bool isTabUnlocked(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return true;
      case 1:
        return state.batchFiles.isNotEmpty;
      case 2:
        return state.sourceType == SourceType.film;
      case 3:
        if (state.sourceType == SourceType.clean) return true;
        if (state.sourceType == SourceType.film && state.isPhase1Complete) return true;
        return false;
      case 4:
        return state.isPhase2Complete;
      case 5:
        return true;
      default:
        return false;
    }
  }
}

final workflowProvider = NotifierProvider<WorkflowNotifier, WorkflowState>(WorkflowNotifier.new);
