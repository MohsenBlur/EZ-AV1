import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
      
      // In reality, this would load the encoded test chunks:
      // player.open(Media('path/to/test_chunk_$i.mkv'), play: false);
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

  void _syncSeek(Duration position) {
    for (var player in _players.values) {
      player.seek(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Save preset and Queue for Batch
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
