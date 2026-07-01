import 'package:freezed_annotation/freezed_annotation.dart';
import 'batch_node_model.dart';

part 'execution_model.freezed.dart';

enum JobStatus {
  pending,
  encoding,
  paused,
  done,
  error,
}

@freezed
abstract class ExecutionJob with _$ExecutionJob {
  const factory ExecutionJob({
    required String id,
    required BatchNode node, // Only FileNodes should be processed
    @Default(JobStatus.pending) JobStatus status,
    @Default(0.0) double progress, // 0.0 to 1.0
    @Default(0.0) double fps,
    @Default('--:--:--') String eta,
    @Default('') String logOutput,
    String? errorMessage,
  }) = _ExecutionJob;
}
