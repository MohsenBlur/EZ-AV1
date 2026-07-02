import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/navigation_provider.dart';
import '../views/phase0_bypass_view.dart';
import '../views/phase1_texture_view.dart';
import '../views/phase2_bitrate_view.dart';
import '../views/phase3_grain_view.dart';
import '../views/phase3_execution_view.dart';
import '../views/file_import_view.dart';
import '../../providers/workflow_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);
    ref.watch(workflowProvider); // trigger rebuilds on state change
    final workflowNotifier = ref.read(workflowProvider.notifier);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 64,
            color: const Color(0xFF141414), // Darker than background
            child: Column(
              children: [
                const SizedBox(height: 20),
                _SidebarIcon(
                  icon: Icons.drive_folder_upload_rounded,
                  label: 'Import',
                  isSelected: selectedIndex == 0,
                  isLocked: !workflowNotifier.isTabUnlocked(0),
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(0),
                ),
                _SidebarIcon(
                  icon: Icons.list_alt_rounded,
                  label: 'Source',
                  isSelected: selectedIndex == 1,
                  isLocked: !workflowNotifier.isTabUnlocked(1),
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(1),
                ),
                _SidebarIcon(
                  icon: Icons.compare_arrows_rounded,
                  label: 'Texture',
                  isSelected: selectedIndex == 2,
                  isLocked: !workflowNotifier.isTabUnlocked(2),
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(2),
                ),
                _SidebarIcon(
                  icon: Icons.speed_rounded,
                  label: 'Bitrate',
                  isSelected: selectedIndex == 3,
                  isLocked: !workflowNotifier.isTabUnlocked(3),
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(3),
                ),
                _SidebarIcon(
                  icon: Icons.grain_rounded,
                  label: 'Grain',
                  isSelected: selectedIndex == 4,
                  isLocked: !workflowNotifier.isTabUnlocked(4),
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(4),
                ),
                _SidebarIcon(
                  icon: Icons.rocket_launch_rounded,
                  label: 'Render',
                  isSelected: selectedIndex == 5,
                  isLocked: !workflowNotifier.isTabUnlocked(5),
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(5),
                ),
                const Spacer(),
                _SidebarIcon(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: selectedIndex == 6,
                  isLocked: false,
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(6),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Workspace Area
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: IndexedStack(
                      index: selectedIndex,
                      children: [
                        _LazyView(index: 0, selectedIndex: selectedIndex, child: const FileImportView()),
                        _LazyView(index: 1, selectedIndex: selectedIndex, child: const Phase0BypassView()),
                        _LazyView(index: 2, selectedIndex: selectedIndex, child: const Phase1TextureView()),
                        _LazyView(index: 3, selectedIndex: selectedIndex, child: const Phase2BitrateView()),
                        _LazyView(index: 4, selectedIndex: selectedIndex, child: const Phase3GrainView()),
                        _LazyView(index: 5, selectedIndex: selectedIndex, child: const Phase3ExecutionView()),
                        _LazyView(index: 6, selectedIndex: selectedIndex, child: const Center(child: Text('Settings View'))),
                      ],
                    ),
                  ),
                ),
                
                // Status Bar
                Container(
                  height: 28,
                  color: const Color(0xFF1F1F1F),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Ready',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      const Spacer(),
                      Text(
                        'EZ-AV1 v1.0',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LazyView extends StatefulWidget {
  final int index;
  final int selectedIndex;
  final Widget child;

  const _LazyView({
    required this.index,
    required this.selectedIndex,
    required this.child,
  });

  @override
  State<_LazyView> createState() => _LazyViewState();
}

class _LazyViewState extends State<_LazyView> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    if (widget.index == widget.selectedIndex) {
      _initialized = true;
    }

    if (!_initialized) {
      return const SizedBox.shrink();
    }

    return widget.child;
  }
}

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const _SidebarIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isLocked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final color = isSelected ? activeColor : Colors.grey[600];
    
    return IgnorePointer(
      ignoring: isLocked,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isLocked ? 0.3 : 1.0,
        child: InkWell(
          onTap: isLocked ? null : onTap,
          child: Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isSelected ? activeColor : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Icon(icon, color: color, size: 24),
                    if (isLocked)
                      Transform.translate(
                        offset: const Offset(4, -4),
                        child: const Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
