import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../services/vapoursynth_service.dart';
import '../widgets/ez_panel.dart';
import '../widgets/ez_slider.dart';

class Phase1TextureView extends ConsumerStatefulWidget {
  const Phase1TextureView({super.key});

  @override
  ConsumerState<Phase1TextureView> createState() => _Phase1TextureViewState();
}

class _Phase1TextureViewState extends ConsumerState<Phase1TextureView> {
  late final Player _originalPlayer;
  late final VideoController _originalController;

  late final Player _filteredPlayer;
  late final VideoController _filteredController;
  
  double _denoiseStrength = 0.0;
  double _splitPosition = 0.5; // 0.0 to 1.0 (50% default)
  Timer? _debounce;
  bool _isCompilingScript = false;

  @override
  void initState() {
    super.initState();
    // Initialize standard players
    _originalPlayer = Player();
    _originalController = VideoController(_originalPlayer);
    
    _filteredPlayer = Player();
    _filteredController = VideoController(_filteredPlayer);
    
    _originalPlayer.setPlaylistMode(PlaylistMode.loop);
    _filteredPlayer.setPlaylistMode(PlaylistMode.loop);
    
    // In a real flow, load actual media
    // _originalPlayer.open(Media('path/to/original.mkv'));
    // _filteredPlayer.open(Media('path/to/script.vpy'));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originalPlayer.dispose();
    _filteredPlayer.dispose();
    super.dispose();
  }

  void _onDenoiseChanged(double value) {
    setState(() {
      _denoiseStrength = value;
    });
    
    // Debounce the script generation and player reload
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isCompilingScript = true);
      
      // In a real app, videoPath comes from the selected BatchNode
      const dummyVideoPath = 'C:\\dummy\\video.mkv'; 
      try {
        final scriptPath = await VapourSynthService.generateDenoiseScript(dummyVideoPath, _denoiseStrength);
        
        // Save current position to seamless seek after reload
        final currentPosition = _originalPlayer.state.position;
        
        await _filteredPlayer.open(Media(scriptPath), play: true);
        await _filteredPlayer.seek(currentPosition);
      } catch (e) {
        // Handle script generation errors
      } finally {
        if (mounted) setState(() => _isCompilingScript = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.space && event is KeyDownEvent) {
          if (_originalPlayer.state.playing) {
            _originalPlayer.pause();
            _filteredPlayer.pause();
          } else {
            _originalPlayer.play();
            _filteredPlayer.play();
          }
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
                'PHASE 1: TEXTURE LOCK',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(120, 32),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        
        // Main Workspace Area
        Expanded(
          child: Row(
            children: [
              // Side-By-Side Wipe Section
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.black,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _splitPosition += details.delta.dx / constraints.maxWidth;
                            _splitPosition = _splitPosition.clamp(0.0, 1.0);
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Bottom Layer: Original Video
                            Video(
                              controller: _originalController,
                              controls: NoVideoControls,
                            ),
                            
                            // Top Layer: Filtered Video (Clipped)
                            ClipRect(
                              clipper: _WipeClipper(_splitPosition),
                              child: Video(
                                controller: _filteredController,
                                controls: NoVideoControls,
                              ),
                            ),
                            
                            // Wipe Divider Line
                            Positioned(
                              left: constraints.maxWidth * _splitPosition - 2,
                              top: 0,
                              bottom: 0,
                              width: 4,
                              child: Container(
                                color: Theme.of(context).colorScheme.primary,
                                child: const Center(
                                  child: Icon(Icons.compare_arrows, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                            
                            // Labels
                            Positioned(
                              top: 16,
                              left: 16,
                              child: _buildLabel('ORIGINAL', Colors.white38),
                            ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: _buildLabel('DENOISED (KNLMeansCL)', Theme.of(context).colorScheme.primary),
                            ),
                            
                            // Loading Overlay
                            if (_isCompilingScript)
                              Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ),
                      );
                    }
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
                      title: 'INSPECTOR',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EzSlider(
                            label: 'Denoise Strength',
                            value: _denoiseStrength,
                            min: 0,
                            max: 10,
                            divisions: 20,
                            onChanged: _onDenoiseChanged,
                            labelBuilder: (v) => v == 0 ? 'OFF' : v.toStringAsFixed(1),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Drag the slider to preview KNLMeansCL denoise. Drag the center divider to compare Original vs Denoised. The exact noise removed will be predicted and added synthetically by AV1.',
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
  
  Widget _buildLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  final double splitPosition;
  _WipeClipper(this.splitPosition);

  @override
  Rect getClip(Size size) {
    // Reveal from the right side
    return Rect.fromLTWH(size.width * splitPosition, 0, size.width * (1 - splitPosition), size.height);
  }

  @override
  bool shouldReclip(_WipeClipper oldClipper) => splitPosition != oldClipper.splitPosition;
}
