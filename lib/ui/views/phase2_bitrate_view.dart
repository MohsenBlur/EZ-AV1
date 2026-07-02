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
  
  // Wipe crosshair coordinates (0.0 to 1.0)
  double _splitX = 0.5;
  double _splitY = 0.5;

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
      player.setVolume(0.0);
    }
      
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMedia();
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
                  final denoiseStrength = ref.read(workflowProvider).denoiseStrength;
                  final preset = PresetModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: 'Auto-VMAF ${_vmafTargets[_selectedTargetIndex].toInt()}',
                    denoiseStrength: denoiseStrength,
                    targetVmaf: _vmafTargets[_selectedTargetIndex],
                    photonNoise: _smartReveal ? 0 : (denoiseStrength > 0 ? 0 : 20),
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
                      // Quad-Split Wipe View
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  _splitX += details.delta.dx / constraints.maxWidth;
                                  _splitY += details.delta.dy / constraints.maxHeight;
                                  _splitX = _splitX.clamp(0.0, 1.0);
                                  _splitY = _splitY.clamp(0.0, 1.0);
                                });
                              },
                              onTapDown: (details) {
                                final x = details.localPosition.dx / constraints.maxWidth;
                                final y = details.localPosition.dy / constraints.maxHeight;
                                
                                int selected = 0;
                                if (x < _splitX && y < _splitY) selected = 0;
                                else if (x >= _splitX && y < _splitY) selected = 1;
                                else if (x < _splitX && y >= _splitY) selected = 2;
                                else if (x >= _splitX && y >= _splitY) selected = 3;
                                
                                setState(() => _selectedTargetIndex = selected);
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Video 0 (Top-Left) is the base layer
                                  Video(controller: _controllers[0]!, controls: NoVideoControls),
                                  if (_selectedTargetIndex == 0) _buildSelectionHighlight(0.0, 0.0, _splitX, _splitY, constraints),
                                  
                                  // Video 1 (Top-Right)
                                  ClipRect(
                                    clipper: _QuadClipper(_splitX, 0.0, 1.0, _splitY),
                                    child: Video(controller: _controllers[1]!, controls: NoVideoControls),
                                  ),
                                  if (_selectedTargetIndex == 1) _buildSelectionHighlight(_splitX, 0.0, 1.0, _splitY, constraints),
                                  
                                  // Video 2 (Bottom-Left)
                                  ClipRect(
                                    clipper: _QuadClipper(0.0, _splitY, _splitX, 1.0),
                                    child: Video(controller: _controllers[2]!, controls: NoVideoControls),
                                  ),
                                  if (_selectedTargetIndex == 2) _buildSelectionHighlight(0.0, _splitY, _splitX, 1.0, constraints),
                                  
                                  // Video 3 (Bottom-Right)
                                  ClipRect(
                                    clipper: _QuadClipper(_splitX, _splitY, 1.0, 1.0),
                                    child: Video(controller: _controllers[3]!, controls: NoVideoControls),
                                  ),
                                  if (_selectedTargetIndex == 3) _buildSelectionHighlight(_splitX, _splitY, 1.0, 1.0, constraints),
                                  
                                  // Crosshair Vertical Line
                                  Positioned(
                                    left: constraints.maxWidth * _splitX - 1,
                                    top: 0,
                                    bottom: 0,
                                    width: 2,
                                    child: Container(color: Theme.of(context).colorScheme.primary),
                                  ),
                                  
                                  // Crosshair Horizontal Line
                                  Positioned(
                                    top: constraints.maxHeight * _splitY - 1,
                                    left: 0,
                                    right: 0,
                                    height: 2,
                                    child: Container(color: Theme.of(context).colorScheme.primary),
                                  ),
                                  
                                  // Crosshair Center Node
                                  Positioned(
                                    left: constraints.maxWidth * _splitX - 6,
                                    top: constraints.maxHeight * _splitY - 6,
                                    width: 12,
                                    height: 12,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  
                                  // Corner Labels
                                  Positioned(top: 16, left: 16, child: _buildLabel(0)),
                                  Positioned(top: 16, right: 16, child: _buildLabel(1)),
                                  Positioned(bottom: 16, left: 16, child: _buildLabel(2)),
                                  Positioned(bottom: 16, right: 16, child: _buildLabel(3)),
                                ],
                              ),
                            );
                          }
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

  Widget _buildLabel(int index) {
    final isSelected = index == _selectedTargetIndex;
    final vmafTarget = _vmafTargets[index];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isSelected ? Colors.transparent : Colors.white38),
      ),
      child: Text(
        'VMAF ${vmafTarget.toInt()}',
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSelectionHighlight(double left, double top, double right, double bottom, BoxConstraints constraints) {
    return Positioned(
      left: constraints.maxWidth * left,
      top: constraints.maxHeight * top,
      width: constraints.maxWidth * (right - left),
      height: constraints.maxHeight * (bottom - top),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

class _QuadClipper extends CustomClipper<Rect> {
  final double left;
  final double top;
  final double right;
  final double bottom;

  _QuadClipper(this.left, this.top, this.right, this.bottom);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      size.width * left,
      size.height * top,
      size.width * right,
      size.height * bottom,
    );
  }

  @override
  bool shouldReclip(_QuadClipper oldClipper) {
    return left != oldClipper.left ||
           top != oldClipper.top ||
           right != oldClipper.right ||
           bottom != oldClipper.bottom;
  }
}
