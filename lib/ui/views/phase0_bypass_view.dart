import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/workflow_provider.dart';
import '../../providers/navigation_provider.dart';

class Phase0BypassView extends ConsumerWidget {
  const Phase0BypassView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Source Material Type',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Select the type of content you are encoding. This helps optimize the pipeline.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
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
                  const SizedBox(width: 32),
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
          ),
        ),
      ),
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
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(32),
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
              Icon(widget.icon, size: 64, color: widget.color),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                widget.description,
                style: const TextStyle(
                  fontSize: 14,
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
