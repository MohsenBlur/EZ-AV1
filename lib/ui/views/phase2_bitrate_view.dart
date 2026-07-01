import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../providers/execution_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/workflow_provider.dart';
import '../../providers/batch_queue_provider.dart';
import '../../models/preset_model.dart';
import '../widgets/ez_panel.dart';

class Phase2BitrateView extends ConsumerStatefulWidget {
  const Phase2BitrateView({super.key});

  @override
  ConsumerState<Phase2BitrateView> createState() => _Phase2BitrateViewState();
}

class _Phase2BitrateViewState extends ConsumerState<Phase2BitrateView> {
  // 4 players for the Quad-Split comparison
  final Map<int, Player> _players = {};
  final Map<int, VideoController> _controllers = {};
  
  final List<double> _vmafTargets = [91.0, 93.0, 95.0, 97.0];
  int _selectedTargetIndex = 2; // Default to 95.0
  bool _isPlaying = true;
  bool _smartReveal = false;

  @override
  void initState() {
    super.initState();
    // Initialize 4 players
    for (int i = 0; i < 4; i++) {
      final player = Player(); // media_kit defaults to optimal settings
      _players[i] = player;
      _controllers[i] = VideoController(player);
      
      // Configure looping for seamless visual comparison of small chunks
      player.setPlaylistMode(PlaylistMode.loop);
    }
      
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMedia();
    });

    // Master Clock Drift Enforcer
    _players[0]?.stream.position.listen((masterPos) {
      if (!_isPlaying) return;
      for (int i = 1; i < 4; i++) {
        final slavePos = _players[i]?.state.position ?? Duration.zero;
        if ((masterPos - slavePos).inMilliseconds.abs() > 150) {
          _players[i]?.seek(masterPos);
        }
      }
    });

    // Snippet loop enforcer
    _players[0]?.stream.position.listen((pos) {
      if (_snippetStart != null && pos >= _snippetEnd!) {
        _syncSeek(_snippetStart!);
      }
    });
    
    // Setup snippet once duration is known
    _players[0]?.stream.duration.listen((duration) {
      if (_snippetStart == null && duration.inSeconds > 10) {
        // Start 20% into the video
        _snippetStart = Duration(milliseconds: (duration.inMilliseconds * 0.2).round());
        _snippetEnd = _snippetStart! + const Duration(seconds: 5);
        _syncSeek(_snippetStart!);
      }
    });
  }
  
  Duration? _snippetStart;
  Duration? _snippetEnd;

  void _initMedia() {
    final batchFiles = ref.read(workflowProvider).batchFiles;
    if (batchFiles.isEmpty) return;
    
    final currentVideoPath = batchFiles.first;
    for (int i = 0; i < 4; i++) {
      // For now, load the original video in all 4 panes.
      // In a real flow, this would load the encoded test chunks.
      _players[i]?.open(Media(currentVideoPath), play: _isPlaying);
    }
  }

  @override
  void dispose() {
    for (var player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    for (var player in _players.values) {
      if (_isPlaying) {
        player.play();
      } else {
        player.pause();
      }
    }
  }

  void _toggleSmartReveal(bool value) {
    setState(() => _smartReveal = value);
    for (var player in _players.values) {
      if (player.platform is NativePlayer) {
        (player.platform as NativePlayer).setProperty('vd-lavc-film-grain', value ? 'no' : 'auto');
      }
    }
  }

  void _syncSeek(Duration position) {
    for (var player in _players.values) {
      player.seek(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch execution state for resource suspension
    final isRendering = ref.watch(executionProvider.select((s) => s.isRunning));

    if (isRendering) {
      return Container(
        color: const Color(0xFF0F0F0F),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rocket_launch_rounded, size: 64, color: Colors.orangeAccent),
              const SizedBox(height: 24),
              const Text(
                'Playback Suspended',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'System resources are fully dedicated to the Av1an batch render.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => ref.read(selectedTabProvider.notifier).setTab(3),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('View Render Progress'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.space && event is KeyDownEvent) {
          _togglePlayPause();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          // Top Toolbar
        Container(
          height: 48,
          color: const Color(0xFF141414),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'PHASE 2: BITRATE EFFICIENCY',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Text('Smart Reveal (Bypass Grain)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 8),
                  Switch(
                    value: _smartReveal,
                    onChanged: _toggleSmartReveal,
                    activeThumbColor: Colors.blueAccent,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(width: 1, height: 24, color: Colors.white24),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  final preset = PresetModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: 'Auto-VMAF ${_vmafTargets[_selectedTargetIndex].toInt()}',
                    targetVmaf: _vmafTargets[_selectedTargetIndex],
                    photonNoise: _smartReveal ? 0 : 20,
                  );
                  
                  // Apply to all files for the quick flow
                  final batchNodes = ref.read(batchQueueProvider);
                  final batchNotifier = ref.read(batchQueueProvider.notifier);
                  for (var node in batchNodes) {
                    batchNotifier.assignPreset(node.id, preset);
                  }
                  
                  ref.read(workflowProvider.notifier).completePhase2();
                  ref.read(selectedTabProvider.notifier).setTab(4); // Execution
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Queue button color
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 32),
                ),
                icon: const Icon(Icons.queue_play_next_rounded, size: 16),
                label: const Text('ADD TO QUEUE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        
        // Main Workspace
        Expanded(
          child: Row(
            children: [
              // Quad-Split Video Area
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.black,
                  child: Column(
                    children: [
                      // Grid
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          childAspectRatio: 16/9,
                          physics: const NeverScrollableScrollPhysics(),
                          children: List.generate(4, (index) {
                            return _buildQuadQuadrant(index);
                          }),
                        ),
                      ),
                      
                      // Unified Master Playback Bar
                      Container(
                        height: 48,
                        color: const Color(0xFF181818),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10_rounded),
                              color: Colors.white,
                              onPressed: () {
                                final pos = _players[0]?.state.position ?? Duration.zero;
                                _syncSeek(pos - const Duration(seconds: 10));
                              },
                            ),
                            IconButton(
                              icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              color: Colors.white,
                              iconSize: 32,
                              onPressed: _togglePlayPause,
                            ),
                            IconButton(
                              icon: const Icon(Icons.forward_10_rounded),
                              color: Colors.white,
                              onPressed: () {
                                final pos = _players[0]?.state.position ?? Duration.zero;
                                _syncSeek(pos + const Duration(seconds: 10));
                              },
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'MASTER SYNC CONTROL',
                              style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Inspector Panel
              Container(
                width: 320,
                color: const Color(0xFF181818),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    EzPanel(
                      title: 'PRESET SETTINGS',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Target VMAF (Quality)',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedTargetIndex,
                            dropdownColor: const Color(0xFF222222),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            items: List.generate(4, (index) {
                              return DropdownMenuItem(
                                value: index,
                                child: Text('VMAF ${_vmafTargets[index].toInt()}'),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedTargetIndex = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Select the lowest VMAF target that looks visually identical to the original video. This maximizes space savings while preserving subjective quality.',
                            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                          ),
                        ],
                      ),
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

  Widget _buildQuadQuadrant(int index) {
    final isSelected = index == _selectedTargetIndex;
    final vmafTarget = _vmafTargets[index];
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTargetIndex = index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          Video(
            controller: _controllers[index]!,
            controls: NoVideoControls, // Clean quad split, no individual controls
          ),
          
          // Selection Border
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
            
          // Label
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'VMAF ${vmafTarget.toInt()}',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
