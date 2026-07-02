import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../providers/execution_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/vapoursynth_service.dart';
import '../../services/preview_service.dart';
import '../widgets/ez_panel.dart';
import '../widgets/ez_slider.dart';
import '../../providers/workflow_provider.dart';

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
  
  final Set<Process> _activeProcesses = {};
  double _denoiseStrength = 0.0;
  double _splitPosition = 0.5; // 0.0 to 1.0 (50% default)
  Timer? _debounce;
  bool _isCompilingScript = false;
  bool _isLoadingSnippet = false;
  String? _currentVideoPath;
  String? _snippetPath;
  String? _denoisedPreviewPath;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _originalPlayer = Player();
    _originalController = VideoController(_originalPlayer);
    
    _filteredPlayer = Player();
    _filteredController = VideoController(_filteredPlayer);

    _originalPlayer.setPlaylistMode(PlaylistMode.loop);
    _filteredPlayer.setPlaylistMode(PlaylistMode.loop);
    
    _originalPlayer.setVolume(0.0);
    _filteredPlayer.setVolume(0.0);

    // Frame synchronization guardrail: keeps filtered layer locked to original player
    _subscriptions.add(_originalPlayer.stream.position.listen((pos) {
      if (!mounted || !_originalPlayer.state.playing) return;
      final filteredPos = _filteredPlayer.state.position;
      final diff = (pos - filteredPos).inMilliseconds.abs();
      if (diff > 250) {
        _filteredPlayer.seek(pos);
      }
    }));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final savedDenoise = ref.read(workflowProvider).denoiseStrength;
      if (savedDenoise > 0) {
        setState(() {
          _denoiseStrength = savedDenoise;
        });
      }
      _initMedia();
    });
  }

  void _killActiveProcesses() {
    for (final proc in _activeProcesses) {
      try {
        if (Platform.isWindows) {
          Process.run('taskkill', ['/F', '/T', '/PID', proc.pid.toString()]);
        } else {
          proc.kill();
        }
      } catch (_) {}
    }
    _activeProcesses.clear();
  }

  Future<void> _initMedia() async {
    _killActiveProcesses();
    final batchFiles = ref.read(workflowProvider).batchFiles;
    if (batchFiles.isNotEmpty) {
      final validFiles = batchFiles.where((f) => File(f).existsSync()).toList();
      if (validFiles.isEmpty) {
        if (mounted) setState(() => _currentVideoPath = null);
        return;
      }

      _currentVideoPath = validFiles.first;
      if (mounted) setState(() => _isLoadingSnippet = true);
      
      try {
        _snippetPath = await PreviewService.extractKeyframeSnippet(_currentVideoPath!);
      } catch (e) {
        debugPrint('[Phase1] Snippet extraction error: $e');
        _snippetPath = _currentVideoPath;
      } finally {
        if (mounted) setState(() => _isLoadingSnippet = false);
      }
      
      final mediaPath = (_snippetPath != null && _snippetPath!.isNotEmpty && File(_snippetPath!).existsSync())
          ? _snippetPath!
          : _currentVideoPath!;

      if (File(mediaPath).existsSync()) {
        await _updateDenoisedPreview(mediaPath);
      }
    }
  }

  Future<void> _updateDenoisedPreview(String snippetPath) async {
    if (!File(snippetPath).existsSync()) return;
    if (mounted) setState(() => _isCompilingScript = true);

    try {
      Directory tempDir;
      try {
        tempDir = await getTemporaryDirectory();
      } catch (_) {
        tempDir = Directory.systemTemp;
      }

      _denoisedPreviewPath = p.join(tempDir.path, 'ez_av1_denoised_preview.mp4');

      final scriptPath = await VapourSynthService.generateDenoiseScript(
        _denoiseStrength,
        sourceFilePath: snippetPath,
      );

      final colorProfile = _currentVideoPath != null
          ? await PreviewService.detectColorProfile(_currentVideoPath!)
          : null;

      final renderedPath = await VapourSynthService.renderDenoisedPreview(
        scriptPath,
        _denoisedPreviewPath!,
        colorProfile: colorProfile,
      );

      if (!mounted) return;

      if (File(snippetPath).existsSync()) {
        await _originalPlayer.open(Media(snippetPath), play: true);
      }
      
      if (File(renderedPath).existsSync() && File(renderedPath).lengthSync() > 0) {
        await _filteredPlayer.open(Media(renderedPath), play: true);
      } else if (File(snippetPath).existsSync()) {
        await _filteredPlayer.open(Media(snippetPath), play: true);
      }
    } catch (e) {
      debugPrint('[Phase1] Denoise preview render exception: $e');
    } finally {
      if (mounted) setState(() => _isCompilingScript = false);
    }
  }

  @override
  void dispose() {
    _killActiveProcesses();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _debounce?.cancel();
    _originalPlayer.dispose();
    _filteredPlayer.dispose();
    super.dispose();
  }

  void _onDenoiseChanged(double value) {
    setState(() {
      _denoiseStrength = value;
    });
    
    // Debounce preview rendering
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _killActiveProcesses();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (_snippetPath != null || _currentVideoPath != null) {
        final targetPath = _snippetPath ?? _currentVideoPath!;
        if (File(targetPath).existsSync()) {
          await _updateDenoisedPreview(targetPath);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listenManual(workflowProvider.select((w) => w.batchFiles), (previous, next) {
      if (next.isNotEmpty && next.first != _currentVideoPath) {
        _initMedia();
      }
    });

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
                onPressed: () => ref.read(selectedTabProvider.notifier).setTab(5),
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

    if (_currentVideoPath == null || !File(_currentVideoPath!).existsSync()) {
      return Container(
        color: const Color(0xFF0F0F0F),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_library_outlined, size: 64, color: Colors.white38),
              const SizedBox(height: 24),
              const Text(
                'No Active Video Selected',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add video files in the Batch Queue to start texture previewing.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(selectedTabProvider.notifier).setTab(0),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Go to Batch Queue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
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
                onPressed: () {
                  _killActiveProcesses();
                  ref.read(workflowProvider.notifier).completePhase1(_denoiseStrength);
                  ref.read(selectedTabProvider.notifier).setTab(3); // Bitrate
                },
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
                            if (_isCompilingScript || _isLoadingSnippet)
                              Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 12),
                                      Text(
                                        _isLoadingSnippet
                                            ? 'Extracting Lossless Keyframe Snippet...'
                                            : 'Rendering VapourSynth Denoise Preview (~0.1s)...',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  ),
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
                            divisions: 100,
                            onChanged: _onDenoiseChanged,
                            labelBuilder: (v) => v == 0 ? 'OFF' : v.toStringAsFixed(1),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Drag the slider to adjust KNLMeansCL GPU denoise strength gradually. Drag the center divider to compare Original vs Denoised.',
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
    return Rect.fromLTWH(size.width * splitPosition, 0, size.width * (1 - splitPosition), size.height);
  }

  @override
  bool shouldReclip(_WipeClipper oldClipper) => splitPosition != oldClipper.splitPosition;
}
