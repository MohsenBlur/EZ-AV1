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
import '../../providers/workflow_provider.dart';
import '../../providers/batch_queue_provider.dart';
import '../../models/preset_model.dart';
import '../../services/preview_service.dart';
import '../../services/vapoursynth_service.dart';
import '../../services/av1an_service.dart';
import '../../services/environment_service.dart';
import '../widgets/ez_panel.dart';

class Phase2BitrateView extends ConsumerStatefulWidget {
  const Phase2BitrateView({super.key});

  @override
  ConsumerState<Phase2BitrateView> createState() => _Phase2BitrateViewState();
}

class _Phase2BitrateViewState extends ConsumerState<Phase2BitrateView> {
  final Map<int, Player> _players = {};
  final Map<int, VideoController> _controllers = {};
  final List<StreamSubscription> _subscriptions = [];
  final Map<String, String> _paneCache = {};
  
  // Available VMAF target options (including targets lower than 91)
  final List<double> _availableVmafTargets = [75.0, 80.0, 85.0, 88.0, 91.0, 93.0, 95.0, 97.0, 98.0];
  late List<double> _paneVmafTargets;
  int _selectedTargetIndex = 2; // Default to Pane 2
  
  bool _isPlaying = true;
  bool _smartReveal = false; // False = Grain Synthesis Active, True = Grain Bypassed
  bool _isProcessingPipeline = false;
  String? _currentVideoPath;
  String? _denoisedSnippetPath;
  MediaColorProfile? _colorProfile;
  
  double _splitX = 0.5;
  double _splitY = 0.5;

  @override
  void initState() {
    super.initState();
    _paneVmafTargets = [95.0, 80.0, 88.0, 93.0]; // Pane 0 = Reference Denoised, Pane 1 = 80, Pane 2 = 88, Pane 3 = 93

    for (int i = 0; i < 4; i++) {
      final player = Player();
      _players[i] = player;
      _controllers[i] = VideoController(player);
      
      player.setPlaylistMode(PlaylistMode.loop);
      player.setVolume(0.0);
    }

    if (_players[0] != null) {
      _subscriptions.add(_players[0]!.stream.position.listen((pos) {
        if (!mounted || !_isPlaying) return;
        for (int i = 1; i < 4; i++) {
          final player = _players[i];
          if (player != null) {
            final diff = (pos - player.state.position).inMilliseconds.abs();
            if (diff > 250) {
              player.seek(pos);
            }
          }
        }
      }));
    }
      
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMedia();
    });
  }

  /// Maps target VMAF to real SVT-AV1 CRF scale (AV1 encoder engine).
  int _vmafToSvtCrf(double vmaf) {
    if (vmaf >= 98.0) return 18;
    if (vmaf >= 97.0) return 20;
    if (vmaf >= 95.0) return 24;
    if (vmaf >= 93.0) return 27;
    if (vmaf >= 91.0) return 30;
    if (vmaf >= 88.0) return 34;
    if (vmaf >= 85.0) return 38;
    if (vmaf >= 80.0) return 44;
    return 50; // VMAF 75 or lower
  }

  void _initMedia() async {
    final batchFiles = ref.read(workflowProvider).batchFiles;
    final validFiles = batchFiles.where((f) => File(f).existsSync()).toList();
    if (validFiles.isEmpty) {
      if (mounted) setState(() => _currentVideoPath = null);
      return;
    }
    
    _currentVideoPath = validFiles.first;
    if (mounted) setState(() => _isProcessingPipeline = true);
    
    try {
      // 0. Detect exact source color profile
      _colorProfile = await PreviewService.detectColorProfile(_currentVideoPath!);

      // 1. Extract keyframe snippet with native color calibration
      final snippetPath = await PreviewService.extractKeyframeSnippet(_currentVideoPath!);
      if (!File(snippetPath).existsSync()) return;

      // 2. Process snippet through Phase 1 denoiser
      final denoiseStrength = ref.read(workflowProvider).denoiseStrength;
      Directory tempDir;
      try {
        tempDir = await getTemporaryDirectory();
      } catch (_) {
        tempDir = Directory.systemTemp;
      }

      final scriptPath = await VapourSynthService.generateDenoiseScript(
        denoiseStrength,
        sourceFilePath: snippetPath,
      );

      final denoisedPath = p.join(tempDir.path, 'ez_av1_phase2_denoised.mp4');
      _denoisedSnippetPath = await VapourSynthService.renderDenoisedPreview(
        scriptPath,
        denoisedPath,
        colorProfile: _colorProfile,
      );

      final baseSnippet = File(_denoisedSnippetPath!).existsSync() ? _denoisedSnippetPath! : snippetPath;

      // 3. Open Pane 0 as Reference Denoised Clip
      await _players[0]?.open(Media(baseSnippet), play: _isPlaying);

      // 4. Encode real SVT-AV1 comparison clips for Panes 1, 2, and 3
      for (int i = 1; i < 4; i++) {
        final panePath = await _getOrRenderPane(i, _paneVmafTargets[i], _smartReveal, baseSnippet);
        if (File(panePath).existsSync() && File(panePath).lengthSync() > 0) {
          await _players[i]?.open(Media(panePath), play: _isPlaying);
        } else {
          await _players[i]?.open(Media(baseSnippet), play: _isPlaying);
        }
        
        // Background pre-render opposite grain state for INSTANT toggle (<10ms)
        _getOrRenderPane(i, _paneVmafTargets[i], !_smartReveal, baseSnippet);
      }
    } catch (e) {
      debugPrint('[Phase2] Pipeline processing error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingPipeline = false);
    }
  }

  Future<String> _getOrRenderPane(int paneIndex, double vmaf, bool bypassGrain, String baseSnippet) async {
    final cacheKey = '${paneIndex}_${vmaf.toInt()}_grain_${bypassGrain ? 'off' : 'on'}';
    if (_paneCache.containsKey(cacheKey)) {
      final cached = _paneCache[cacheKey]!;
      if (File(cached).existsSync() && File(cached).lengthSync() > 0) {
        return cached;
      }
    }

    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }

    final crf = _vmafToSvtCrf(vmaf);
    final outputPath = p.join(tempDir.path, 'ez_av1_pane_${paneIndex}_${vmaf.toInt()}_${bypassGrain ? "nograin" : "grain"}.mp4');
    
    await _renderSvtAv1Pane(baseSnippet, outputPath, crf, bypassGrain: bypassGrain);
    if (File(outputPath).existsSync() && File(outputPath).lengthSync() > 0) {
      _paneCache[cacheKey] = outputPath;
    }
    return outputPath;
  }

  /// Encodes the denoised snippet clip through native SVT-AV1 with explicit color metadata & photon noise (~0.4s).
  Future<void> _renderSvtAv1Pane(String inputPath, String outputPath, int crf, {required bool bypassGrain}) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }

    final ivfPath = p.join(tempDir.path, 'ez_av1_pane_${crf}_${bypassGrain ? "nograin" : "grain"}.ivf');
    final denoiseStrength = ref.read(workflowProvider).denoiseStrength;
    
    // Predictive Inversion: calculate active photon noise for SVT-AV1 grain synthesis
    int photonNoise = 0;
    if (!bypassGrain) {
      photonNoise = Av1anService.calculatePhotonNoise(denoiseStrength > 0 ? denoiseStrength : 4.0);
      if (photonNoise <= 0) photonNoise = 16; // Ensure visible organic grain synthesis when active
    }

    final svtArgs = <String>[
      '-i', 'stdin',
      '--preset', '8',
      '--rc', '0',
      '--crf', '$crf',
      if (_colorProfile != null) ..._colorProfile!.toSvtAv1Args(),
      if (photonNoise > 0) ...['--film-grain', '$photonNoise', '--film-grain-denoise', '0'],
      '-b', ivfPath,
    ];

    try {
      final p1 = await Process.start(
        EnvironmentService.ffmpegPath,
        [
          '-y',
          '-i', inputPath,
          '-f', 'yuv4mpegpipe',
          '-strict', '-1',
          '-',
        ],
        environment: EnvironmentService.processEnvironment,
      );

      final p2 = await Process.start(
        EnvironmentService.svtAv1Path,
        svtArgs,
        environment: EnvironmentService.processEnvironment,
      );

      p1.stderr.listen((_) {});
      p2.stderr.listen((_) {});

      await p1.stdout.pipe(p2.stdin);
      final exitCode = await p2.exitCode;

      if (exitCode == 0 && File(ivfPath).existsSync() && File(ivfPath).lengthSync() > 0) {
        // Mux IVF to MP4 using av1_metadata bitstream filter to force exact 1:1 color parity
        final muxArgs = <String>[
          '-y',
          '-i', ivfPath,
          if (_colorProfile != null) ..._colorProfile!.toAv1MetadataBsf(),
          '-c:v', 'copy',
          if (_colorProfile != null) ..._colorProfile!.toFfmpegArgs(),
          '-an',
          outputPath,
        ];
        await Process.run(
          EnvironmentService.ffmpegPath,
          muxArgs,
          environment: EnvironmentService.processEnvironment,
        );
      } else {
        debugPrint('[Phase2] SVT-AV1 encode exited with code $exitCode');
      }
    } catch (e) {
      debugPrint('[Phase2] SVT-AV1 encode exception: $e');
    }
  }

  void _onVmafTargetChanged(double newVmaf) async {
    final index = _selectedTargetIndex;
    if (index == 0) return; // Pane 0 is Reference Denoised Clip

    setState(() {
      _paneVmafTargets[index] = newVmaf;
      _isProcessingPipeline = true;
    });

    try {
      final baseSnippet = (_denoisedSnippetPath != null && File(_denoisedSnippetPath!).existsSync())
          ? _denoisedSnippetPath!
          : _currentVideoPath!;

      final panePath = await _getOrRenderPane(index, newVmaf, _smartReveal, baseSnippet);

      if (mounted && File(panePath).existsSync() && File(panePath).lengthSync() > 0) {
        await _players[index]?.open(Media(panePath), play: _isPlaying);
      }

      // Background pre-render opposite grain state for INSTANT toggle
      _getOrRenderPane(index, newVmaf, !_smartReveal, baseSnippet);
    } catch (e) {
      debugPrint('[Phase2] Update pane $index error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingPipeline = false);
    }
  }

  void _toggleSmartReveal(bool value) async {
    setState(() {
      _smartReveal = value;
    });

    final baseSnippet = (_denoisedSnippetPath != null && File(_denoisedSnippetPath!).existsSync())
        ? _denoisedSnippetPath!
        : _currentVideoPath!;

    bool allCached = true;
    for (int i = 1; i < 4; i++) {
      final cacheKey = '${i}_${_paneVmafTargets[i].toInt()}_grain_${value ? 'off' : 'on'}';
      if (!_paneCache.containsKey(cacheKey) || !File(_paneCache[cacheKey]!).existsSync()) {
        allCached = false;
        break;
      }
    }

    if (!allCached) {
      setState(() => _isProcessingPipeline = true);
    }

    try {
      for (int i = 1; i < 4; i++) {
        final panePath = await _getOrRenderPane(i, _paneVmafTargets[i], value, baseSnippet);
        if (File(panePath).existsSync() && File(panePath).lengthSync() > 0) {
          await _players[i]?.open(Media(panePath), play: _isPlaying);
        }
      }
    } catch (e) {
      debugPrint('[Phase2] Smart reveal toggle error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingPipeline = false);
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
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
                'Add video files in the Batch Queue to start bitrate efficiency testing.',
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
                  final selectedTarget = _paneVmafTargets[_selectedTargetIndex];
                  final preset = PresetModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: 'Auto-VMAF ${selectedTarget.toInt()}',
                    denoiseStrength: denoiseStrength,
                    targetVmaf: selectedTarget,
                    photonNoise: _smartReveal ? 0 : (denoiseStrength > 0 ? 0 : 20),
                  );
                  
                  final batchNodes = ref.read(batchQueueProvider);
                  final batchNotifier = ref.read(batchQueueProvider.notifier);
                  for (var node in batchNodes) {
                    batchNotifier.assignPreset(node.id, preset);
                  }
                  
                  ref.read(workflowProvider.notifier).completePhase2();
                  ref.read(selectedTabProvider.notifier).setTab(4); // Execution
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
                                if (x < _splitX && y < _splitY) {
                                  selected = 0;
                                } else if (x >= _splitX && y < _splitY) {
                                  selected = 1;
                                } else if (x < _splitX && y >= _splitY) {
                                  selected = 2;
                                } else if (x >= _splitX && y >= _splitY) {
                                  selected = 3;
                                }
                                
                                setState(() {
                                  _selectedTargetIndex = selected;
                                });
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Video(controller: _controllers[0]!, controls: NoVideoControls),
                                  if (_selectedTargetIndex == 0) _buildSelectionBorder(0.0, 0.0, _splitX, _splitY, constraints),
                                  
                                  ClipRect(
                                    clipper: _QuadClipper(_splitX, 0.0, 1.0, _splitY),
                                    child: Video(controller: _controllers[1]!, controls: NoVideoControls),
                                  ),
                                  if (_selectedTargetIndex == 1) _buildSelectionBorder(_splitX, 0.0, 1.0, _splitY, constraints),
                                  
                                  ClipRect(
                                    clipper: _QuadClipper(0.0, _splitY, _splitX, 1.0),
                                    child: Video(controller: _controllers[2]!, controls: NoVideoControls),
                                  ),
                                  if (_selectedTargetIndex == 2) _buildSelectionBorder(0.0, _splitY, _splitX, 1.0, constraints),
                                  
                                  ClipRect(
                                    clipper: _QuadClipper(_splitX, _splitY, 1.0, 1.0),
                                    child: Video(controller: _controllers[3]!, controls: NoVideoControls),
                                  ),
                                  if (_selectedTargetIndex == 3) _buildSelectionBorder(_splitX, _splitY, 1.0, 1.0, constraints),
                                  
                                  Positioned(
                                    left: constraints.maxWidth * _splitX - 1,
                                    top: 0,
                                    bottom: 0,
                                    width: 2,
                                    child: Container(color: Theme.of(context).colorScheme.primary),
                                  ),
                                  
                                  Positioned(
                                    top: constraints.maxHeight * _splitY - 1,
                                    left: 0,
                                    right: 0,
                                    height: 2,
                                    child: Container(color: Theme.of(context).colorScheme.primary),
                                  ),
                                  
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
                                  
                                  Positioned(top: 16, left: 16, child: _buildLabel(0, 'DENOISED REF')),
                                  Positioned(top: 16, right: 16, child: _buildLabel(1, 'VMAF ${_paneVmafTargets[1].toInt()}')),
                                  Positioned(bottom: 16, left: 16, child: _buildLabel(2, 'VMAF ${_paneVmafTargets[2].toInt()}')),
                                  Positioned(bottom: 16, right: 16, child: _buildLabel(3, 'VMAF ${_paneVmafTargets[3].toInt()}')),
                                  
                                  if (_isProcessingPipeline)
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 12),
                                            Text(
                                              'Rendering Real SVT-AV1 Bitrate Samples (~0.4s)...',
                                              style: TextStyle(color: Colors.white70, fontSize: 13),
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
                          DropdownButtonFormField<double>(
                            initialValue: _paneVmafTargets[_selectedTargetIndex],
                            dropdownColor: const Color(0xFF222222),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            items: _availableVmafTargets.map((vmaf) {
                              return DropdownMenuItem(
                                value: vmaf,
                                child: Text('VMAF ${vmaf.toInt()}'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                _onVmafTargetChanged(val);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Select the lowest VMAF target that looks visually identical to the denoised reference video. This maximizes space savings while preserving subjective quality.',
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

  Widget _buildLabel(int index, String labelText) {
    final isSelected = index == _selectedTargetIndex;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isSelected ? Colors.transparent : Colors.white38),
      ),
      child: Text(
        labelText,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSelectionBorder(double left, double top, double right, double bottom, BoxConstraints constraints) {
    return Positioned(
      left: constraints.maxWidth * left,
      top: constraints.maxHeight * top,
      width: constraints.maxWidth * (right - left),
      height: constraints.maxHeight * (bottom - top),
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2.0,
            ),
          ),
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
