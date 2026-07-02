import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/execution_provider.dart';
import '../../models/execution_model.dart';

class Phase3ExecutionView extends ConsumerWidget {
  const Phase3ExecutionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final executionState = ref.watch(executionProvider);
    final notifier = ref.read(executionProvider.notifier);

    final validJobs = executionState.jobs.where((j) => j.status != JobStatus.error).toList();
    final totalJobs = validJobs.length;
    final completedJobs = validJobs.where((j) => j.status == JobStatus.done).length;
    final totalProgress = totalJobs > 0 
        ? validJobs.fold<double>(0, (sum, j) => sum + j.progress) / totalJobs 
        : 0.0;

    return Column(
      children: [
        // Top Toolbar
        Container(
          height: 48,
          color: const Color(0xFF141414),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Phase 3: Execution Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const Spacer(),
              Row(
                children: [
                  const Text('Low Spec Mode', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 8),
                  Switch(
                    value: executionState.lowSpecMode,
                    onChanged: executionState.isRunning ? null : (val) => notifier.setLowSpecMode(val),
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(width: 1, height: 24, color: Colors.white24),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: executionState.isRunning 
                    ? null 
                    : () {
                        final existing = notifier.getExistingOutputFiles();
                        if (existing.isEmpty) {
                          notifier.startBatch();
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF181818),
                              title: const Text('Overwrite Files?', style: TextStyle(color: Colors.white)),
                              content: Text(
                                '${existing.length} output file(s) already exist. Do you want to safely overwrite them before encoding?',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    notifier.startBatch(overwriteFiles: true);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  child: const Text('Overwrite & Render', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Render'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: executionState.isRunning ? () => notifier.stopBatch() : null,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),

        // Master Progress Ribbon
        Container(
          height: 40,
          color: const Color(0xFF1F1F1F),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalProgress,
                    backgroundColor: Colors.black,
                    color: Theme.of(context).colorScheme.primary,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${(totalProgress * 100).toStringAsFixed(1)}% ($completedJobs / $totalJobs completed)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),

        // Workspace
        Expanded(
          child: Container(
            color: const Color(0xFF0F0F0F), // Deep dark for workspace
            padding: const EdgeInsets.all(16),
            child: executionState.jobs.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    itemCount: executionState.jobs.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final job = executionState.jobs[index];
                      return _JobCard(job: job);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          const Text(
            'Queue is Empty',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatefulWidget {
  final ExecutionJob job;
  const _JobCard({required this.job});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final isActive = j.status == JobStatus.encoding;
    final isDone = j.status == JobStatus.done;
    final isError = j.status == JobStatus.error;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
              : isError ? Colors.red.withValues(alpha: 0.5) : const Color(0xFF333333),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildStatusIcon(j.status),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          j.node.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: j.progress,
                            backgroundColor: Colors.black,
                            color: isDone ? Colors.green : Theme.of(context).colorScheme.primary,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  if (isActive) ...[
                    _buildBadge('${j.fps.toStringAsFixed(1)} FPS', Colors.blueAccent),
                    const SizedBox(width: 8),
                    _buildBadge('ETA: ${j.eta}', Colors.orangeAccent),
                  ],
                  if (isDone)
                    _buildBadge('COMPLETE', Colors.green),
                  if (isError)
                    _buildBadge('ERROR', Colors.red),
                  const SizedBox(width: 16),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (j.errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error: ${j.errorMessage}',
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        j.logLines.isEmpty ? 'No logs available.' : j.logLines.join('\n'),
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(JobStatus status) {
    switch (status) {
      case JobStatus.pending:
        return const Icon(Icons.schedule_rounded, color: Colors.grey);
      case JobStatus.encoding:
        return const SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case JobStatus.paused:
        return const Icon(Icons.pause_circle_rounded, color: Colors.amber);
      case JobStatus.done:
        return const Icon(Icons.check_circle_rounded, color: Colors.green);
      case JobStatus.error:
        return const Icon(Icons.error_rounded, color: Colors.red);
    }
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
