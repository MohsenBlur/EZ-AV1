import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/navigation_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);

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
                  icon: Icons.list_alt_rounded,
                  label: 'Batch',
                  isSelected: selectedIndex == 0,
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(0),
                ),
                _SidebarIcon(
                  icon: Icons.compare_arrows_rounded,
                  label: 'Texture',
                  isSelected: selectedIndex == 1,
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(1),
                ),
                _SidebarIcon(
                  icon: Icons.speed_rounded,
                  label: 'Bitrate',
                  isSelected: selectedIndex == 2,
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(2),
                ),
                const Spacer(),
                _SidebarIcon(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: selectedIndex == 3,
                  onTap: () => ref.read(selectedTabProvider.notifier).setTab(3),
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
                    child: _buildContent(selectedIndex),
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

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return const Center(child: Text('Batch Queue View'));
      case 1:
        return const Center(child: Text('Phase 1: Texture Lock'));
      case 2:
        return const Center(child: Text('Phase 2: Bitrate Efficiency'));
      case 3:
        return const Center(child: Text('Settings View'));
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final color = isSelected ? activeColor : Colors.grey[600];
    
    return InkWell(
      onTap: onTap,
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
            Icon(icon, color: color, size: 24),
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
    );
  }
}
