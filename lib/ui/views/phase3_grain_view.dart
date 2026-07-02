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
import '../../providers/preset_provider.dart';
import '../../models/preset_model.dart';
import '../../services/preview_service.dart';
import '../../services/vapoursynth_service.dart';
import '../../services/av1an_service.dart';
import '../../services/environment_service.dart';
import '../widgets/ez_panel.dart';

class Phase3GrainView extends ConsumerStatefulWidget {
  const Phase3GrainView({super.key});

  @override
  ConsumerState<Phase3GrainView> createState() => _Phase3GrainViewState();
}

class _Phase3GrainViewState extends ConsumerState<Phase3GrainView> {
  late final Player _cleanPlayer;
  late final VideoController _cleanController;
  late final Player _grainPlayer;
  late final VideoController _grainController;
  
  final List<StreamSubscription> _subscriptions = [];
  Timer? _debounceTimer;

  bool _isPlaying = true;
  bool _isProcessingPipeline = false;
  String? _currentVideoPath;
  String? _denoisedSnippetPath;
  MediaColorProfile? _colorProfile;

  double _sliderPos = 0.5;
  int _grainStrength = 15;

  @override
  void initState() {
    super.initState();
    _cleanPlayer = Player();
    _cleanController = VideoController(_cleanPlayer);
    _grainPlayer = Player();
    _grainController = VideoController(_grainPlayer);

    _cleanPlayer.setPlaylistMode(PlaylistMode.loop);
    _cleanPlayer.setVolume(0.0);
    _grainPlayer.setPlaylistMode(PlaylistMode.loop);
    _grainPlayer.setVolume(0.0);

    final denoiseStrength = ref.read(workflowProvider).denoiseStrength;
    if (denoiseStrength > 0) {
      _grainStrength = Av1anService.calculatePhotonNoise(denoiseStrength);
      if (_grainStrength <= 0) _grainStrength = 15;
    }

    _subscriptions.add(_cleanPlayer.stream.position.listen((pos) {
      if (!mounted || !_isPlaying) return;
      final diff = (pos - _grainPlayer.state.position).inMilliseconds.abs();
      if (diff > 50) {
        _grainPlayer.seek(pos);
      }
    }));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMedia();
    });
  }

  int _vmafToSvtCrf(double vmaf) {
    if (vmaf >= 98.0) return 18;
    if (vmaf >= 97.0) return 20;
    if (vmaf >= 95.0) return 24;
    if (vmaf >= 93.0) return 27;
    if (vmaf >= 91.0) return 30;
    if (vmaf >= 88.0) return 34;
    if (vmaf >= 85.0) return 38;
    if (vmaf >= 80.0) return 44;
    return 50;
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
      _colorProfile = await PreviewService.detectColorProfile(_currentVideoPath!);
      final snippetPath = await PreviewService.extractKeyframeSnippet(_currentVideoPath!);
      if (!File(snippetPath).existsSync()) return;

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

      final denoisedPath = p.join(tempDir.path, 'ez_av1_phase3_denoised.mp4');
      _denoisedSnippetPath = await VapourSynthService.renderDenoisedPreview(
        scriptPath,
        denoisedPath,
        colorProfile: _colorProfile,
      );

      final baseSnippet = File(_denoisedSnippetPath!).existsSync() ? _denoisedSnippetPath! : snippetPath;
      final targetVmaf = ref.read(workflowProvider).targetVmaf;
      final crf = _vmafToSvtCrf(targetVmaf);

      final cleanPath = p.join(tempDir.path, 'ez_av1_phase3_clean_${targetVmaf.toInt()}.mp4');
      await _renderSvtAv1Pane(baseSnippet, cleanPath, crf, photonNoise: 0);

      final grainPath = p.join(tempDir.path, 'ez_av1_phase3_grain_$_grainStrength.mp4');
      await _renderSvtAv1Pane(baseSnippet, grainPath, crf, photonNoise: _grainStrength);

      if (File(cleanPath).existsSync() && File(cleanPath).lengthSync() > 0) {
        await _cleanPlayer.open(Media(cleanPath), play: false);
      } else {
        await _cleanPlayer.open(Media(baseSnippet), play: false);
      }

      if (File(grainPath).existsSync() && File(grainPath).lengthSync() > 0) {
        await _grainPlayer.open(Media(grainPath), play: false);
      } else {
        await _grainPlayer.open(Media(baseSnippet), play: false);
      }

      await _synchronousPlayAll();
    } catch (e) {
      debugPrint('[Phase3] Pipeline processing error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingPipeline = false);
    }
  }

  Future<void> _synchronousPlayAll() async {
    await _cleanPlayer.seek(Duration.zero);
    await _grainPlayer.seek(Duration.zero);
    if (_isPlaying) {
      _cleanPlayer.play();
      _grainPlayer.play();
    }
  }

  Future<void> _renderSvtAv1Pane(String inputPath, String outputPath, int crf, {required int photonNoise}) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }

    final ivfPath = p.join(tempDir.path, 'ez_av1_phase3_p${photonNoise}_c$crf.ivf');
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

      p1.stdout.listen(
        (data) {
          try {
            p2.stdin.add(data);
          } catch (_) {}
        },
        onDone: () async {
          try {
            await p2.stdin.close();
          } catch (_) {}
        },
        onError: (_) {},
        cancelOnError: true,
      );

      final exitCode = await p2.exitCode;

      if (exitCode == 0 && File(ivfPath).existsSync() && File(ivfPath).lengthSync() > 0) {
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
      }
    } catch (e) {
      debugPrint('[Phase3] SVT-AV1 encode exception: $e');
    }
  }

  void _onGrainStrengthChanged(double value) {
    final newStrength = value.round();
    setState(() {
      _grainStrength = newStrength;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isProcessingPipeline = true);

      try {
        final baseSnippet = (_denoisedSnippetPath != null && File(_denoisedSnippetPath!).existsSync())
            ? _denoisedSnippetPath!
            : _currentVideoPath!;

        Directory tempDir;
        try {
          tempDir = await getTemporaryDirectory();
        } catch (_) {
          tempDir = Directory.systemTemp;
        }

        final targetVmaf = ref.read(workflowProvider).targetVmaf;
        final crf = _vmafToSvtCrf(targetVmaf);
        final grainPath = p.join(tempDir.path, 'ez_av1_phase3_grain_$_grainStrength.mp4');

        await _renderSvtAv1Pane(baseSnippet, grainPath, crf, photonNoise: _grainStrength);

        if (mounted && File(grainPath).existsSync() && File(grainPath).lengthSync() > 0) {
          final pos = _cleanPlayer.state.position;
          await _grainPlayer.open(Media(grainPath), play: _isPlaying);
          await _grainPlayer.seek(pos);
        }
      } catch (e) {
        debugPrint('[Phase3] Grain strength update error: $e');
      } finally {
        if (mounted) setState(() => _isProcessingPipeline = false);
      }
    });
  }

  void _showSavePresetDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final denoiseStrength = ref.read(workflowProvider).denoiseStrength;
    final targetVmaf = ref.read(workflowProvider).targetVmaf;
    final nameController = TextEditingController(
      text: 'My Preset (VMAF ${targetVmaf.toInt()} Grain $_grainStrength)',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Save Custom Preset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Give your tuned preset a descriptive name for future use:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Preset Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop();
                await ref.read(presetProvider.notifier).createAndSavePreset(
                  name: name,
                  denoiseStrength: denoiseStrength,
                  targetVmaf: targetVmaf,
                  photonNoise: _grainStrength,
                );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Preset "$name" saved successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save Preset'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _cleanPlayer.dispose();
    _grainPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _cleanPlayer.play();
      _grainPlayer.play();
    } else {
      _cleanPlayer.pause();
      _grainPlayer.pause();
    }
  }

  void _syncSeek(Duration position) {
    _cleanPlayer.seek(position);
    _grainPlayer.seek(position);
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
                'Add video files in the Batch Queue to start film grain synthesis lock.',
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
                  'PHASE 3: GRAIN LOCK',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _showSavePresetDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                  label: const Text('SAVE AS PRESET'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final denoiseStrength = ref.read(workflowProvider).denoiseStrength;
                    final targetVmaf = ref.read(workflowProvider).targetVmaf;
                    final preset = PresetModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: 'EZ-AV1 VMAF ${targetVmaf.toInt()} Grain $_grainStrength',
                      denoiseStrength: denoiseStrength,
                      targetVmaf: targetVmaf,
                      photonNoise: _grainStrength,
                    );

                    final batchNodes = ref.read(batchQueueProvider);
                    final batchNotifier = ref.read(batchQueueProvider.notifier);
                    for (var node in batchNodes) {
                      batchNotifier.assignPreset(node.id, preset);
                    }

                    ref.read(workflowProvider.notifier).completePhase3(_grainStrength);
                    ref.read(selectedTabProvider.notifier).setTab(5); // Phase 4 Execution
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 32),
                  ),
                  icon: const Icon(Icons.queue_play_next_rounded, size: 16),
                  label: const Text('ADD TO QUEUE & RENDER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Main Workspace
          Expanded(
            child: Row(
              children: [
                // Split Wipe View Area
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.black,
                    child: Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return GestureDetector(
                                onHorizontalDragUpdate: (details) {
                                  setState(() {
                                    _sliderPos += details.delta.dx / constraints.maxWidth;
                                    _sliderPos = _sliderPos.clamp(0.0, 1.0);
                                  });
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Video(controller: _cleanController, controls: NoVideoControls),
                                    ClipRect(
                                      clipper: _SideBySideClipper(_sliderPos),
                                      child: Video(controller: _grainController, controls: NoVideoControls),
                                    ),
                                    Positioned(
                                      left: constraints.maxWidth * _sliderPos - 1,
                                      top: 0,
                                      bottom: 0,
                                      width: 2,
                                      child: Container(color: Theme.of(context).colorScheme.primary),
                                    ),
                                    Positioned(
                                      left: constraints.maxWidth * _sliderPos - 12,
                                      top: constraints.maxHeight / 2 - 12,
                                      width: 24,
                                      height: 24,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.drag_handle_rounded, size: 16, color: Colors.black),
                                      ),
                                    ),
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: _buildLabel('CLEAN AV1 (NO NOISE)', isPrimary: false),
                                    ),
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: _buildLabel('GRAIN SYNTHESIS ($_grainStrength)', isPrimary: true),
                                    ),
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
                                                'Rendering SVT-AV1 Synthetic Grain Preview (~0.4s)...',
                                                style: TextStyle(color: Colors.white70, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
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
                                  final pos = _cleanPlayer.state.position;
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
                                  final pos = _cleanPlayer.state.position;
                                  _syncSeek(pos + const Duration(seconds: 10));
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Inspector Panel
                Container(
                  width: 320,
                  color: const Color(0xFF181818),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      EzPanel(
                        title: 'GRAIN LOCK SETTINGS',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Film Grain Strength', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                Text('Level $_grainStrength', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: _grainStrength.toDouble(),
                              min: 0.0,
                              max: 50.0,
                              divisions: 50,
                              label: '$_grainStrength',
                              onChanged: _onGrainStrengthChanged,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'SVT-AV1 synthesizes organic film grain on video frames during playback. This restores realistic texture without forcing the video encoder to waste bitrate on noise.',
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

  Widget _buildLabel(String labelText, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary ? Theme.of(context).colorScheme.primary : Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isPrimary ? Colors.transparent : Colors.white38),
      ),
      child: Text(
        labelText,
        style: TextStyle(
          color: isPrimary ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SideBySideClipper extends CustomClipper<Rect> {
  final double fraction;

  _SideBySideClipper(this.fraction);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(size.width * fraction, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_SideBySideClipper oldClipper) {
    return fraction != oldClipper.fraction;
  }
}
