import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  });
}
