import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/workflow_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/batch_queue_provider.dart';
import '../../providers/preset_provider.dart';
import '../../models/preset_model.dart';

class Phase0BypassView extends ConsumerStatefulWidget {
  const Phase0BypassView({super.key});

  @override
  ConsumerState<Phase0BypassView> createState() => _Phase0BypassViewState();
}

class _Phase0BypassViewState extends ConsumerState<Phase0BypassView> {
  int _selectedMode = 0; // 0 = Visual Calibration & Preset Creation, 1 = Apply Saved Preset Direct to Queue
  PresetModel? _selectedPreset;

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(presetProvider);
    if (_selectedPreset == null && presets.isNotEmpty) {
      _selectedPreset = presets.first;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Workflow Mode Selection',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose whether to visually tune video settings using live previews or quickly apply a saved preset.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Segmented Mode Switch
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMode = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedMode == 0 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: _selectedMode == 0 ? Colors.black : Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Visual Preset Tuning',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _selectedMode == 0 ? Colors.black : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMode = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedMode == 1 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bookmark_added_rounded,
                                size: 18,
                                color: _selectedMode == 1 ? Colors.black : Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Use Saved Preset Direct',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _selectedMode == 1 ? Colors.black : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Mode 0: Visual Tuning Options
              if (_selectedMode == 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: _SelectionCard(
                        title: 'Film / Live Action',
                        description: 'Contains natural film grain or sensor noise.\nRequires Texture Lock (Phase 1).',
                        icon: Icons.camera_roll_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () {
                          ref.read(workflowProvider.notifier).setSourceType(SourceType.film);
                          ref.read(selectedTabProvider.notifier).setTab(2); // Jump to Texture
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _SelectionCard(
                        title: 'Clean Digital / Animation',
                        description: 'No natural grain. Clean sharp lines.\nBypasses Texture Lock directly to Phase 2.',
                        icon: Icons.animation_rounded,
                        color: Colors.blueAccent,
                        onTap: () {
                          ref.read(workflowProvider.notifier).setSourceType(SourceType.clean);
                          ref.read(selectedTabProvider.notifier).setTab(3); // Jump to Bitrate
                        },
                      ),
                    ),
                  ],
                ),
              ],

              // Mode 1: Saved Preset Selection
              if (_selectedMode == 1) ...[
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Select Saved Preset',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<PresetModel>(
                        initialValue: _selectedPreset,
                        dropdownColor: const Color(0xFF222222),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: presets.map((preset) {
                          return DropdownMenuItem<PresetModel>(
                            value: preset,
                            child: Row(
                              children: [
                                Icon(
                                  preset.id.startsWith('default_') ? Icons.verified_rounded : Icons.bookmark_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(preset.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPreset = val);
                          }
                        },
                      ),
                      if (_selectedPreset != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF181818),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetric('Denoise', '${_selectedPreset!.denoiseStrength}x'),
                              Container(width: 1, height: 28, color: Colors.white12),
                              _buildMetric('Target Quality', 'VMAF ${_selectedPreset!.targetVmaf.toInt()}'),
                              Container(width: 1, height: 28, color: Colors.white12),
                              _buildMetric('Film Grain', 'Level ${_selectedPreset!.photonNoise}'),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _selectedPreset == null ? null : () {
                          final batchNodes = ref.read(batchQueueProvider);
                          final batchNotifier = ref.read(batchQueueProvider.notifier);
                          for (var node in batchNodes) {
                            batchNotifier.assignPreset(node.id, _selectedPreset!);
                          }
                          
                          ref.read(workflowProvider.notifier).completePhase1(_selectedPreset!.denoiseStrength);
                          ref.read(workflowProvider.notifier).completePhase2(_selectedPreset!.targetVmaf);
                          ref.read(workflowProvider.notifier).completePhase3(_selectedPreset!.photonNoise);
                          ref.read(selectedTabProvider.notifier).setTab(5); // Advance direct to Execution
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 22),
                        label: const Text('APPLY PRESET TO BATCH & RENDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _SelectionCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SelectionCard> createState() => _SelectionCardState();
}

class _SelectionCardState extends State<_SelectionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          padding: const EdgeInsets.all(28),
          transform: Matrix4.diagonal3Values(
            _isHovered ? 1.02 : 1.0, 
            _isHovered ? 1.02 : 1.0, 
            1.0
          ),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFF2A2A2A) : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.color.withValues(alpha: 0.5) : const Color(0xFF333333),
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? widget.color.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.2),
                blurRadius: _isHovered ? 20 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(widget.icon, size: 56, color: widget.color),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                widget.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
