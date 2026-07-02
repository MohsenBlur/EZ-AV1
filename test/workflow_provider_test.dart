import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ez_av1/models/batch_node_model.dart';
import 'package:ez_av1/providers/batch_queue_provider.dart';
import 'package:ez_av1/providers/workflow_provider.dart';

void main() {
  group('WorkflowNotifier', () {
    test('completePhase1 persists denoiseStrength in WorkflowState', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(workflowProvider.notifier);
      expect(container.read(workflowProvider).denoiseStrength, 0.0);
      expect(container.read(workflowProvider).isPhase1Complete, isFalse);

      notifier.completePhase1(3.5);

      final state = container.read(workflowProvider);
      expect(state.denoiseStrength, 3.5);
      expect(state.isPhase1Complete, isTrue);
    });

    test('WorkflowNotifier auto-syncs batchFiles when batchQueueProvider state changes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final queueNotifier = container.read(batchQueueProvider.notifier);
      expect(container.read(workflowProvider).batchFiles, isEmpty);
      expect(container.read(workflowProvider.notifier).isTabUnlocked(1), isFalse);

      final file1 = FileNode(id: 'f1', name: 'v1.mp4', absolutePath: '/v1.mp4', extension: '.mp4', sizeBytes: 100);
      queueNotifier.state = [file1];

      expect(container.read(workflowProvider).batchFiles, equals(['/v1.mp4']));
      expect(container.read(workflowProvider.notifier).isTabUnlocked(1), isTrue);

      await queueNotifier.removeNode('f1');
      expect(container.read(workflowProvider).batchFiles, isEmpty);
      expect(container.read(workflowProvider.notifier).isTabUnlocked(1), isFalse);
    });
  });
}
