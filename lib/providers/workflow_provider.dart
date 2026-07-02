import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return const WorkflowState();
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
