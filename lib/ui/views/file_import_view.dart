import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../providers/workflow_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/batch_queue_provider.dart';
import '../../models/batch_node_model.dart';

const validExtensions = ['.mkv', '.mp4', '.mov', '.avi', '.m2ts', '.webm', '.flv'];

class FileImportView extends ConsumerStatefulWidget {
  const FileImportView({super.key});

  @override
  ConsumerState<FileImportView> createState() => _FileImportViewState();
}

class _FileImportViewState extends ConsumerState<FileImportView> {
  bool _isDragging = false;
  bool _isProcessing = false;

  Future<void> _processPaths(List<String> paths) async {
    setState(() => _isProcessing = true);
    
    final batchQueueNotifier = ref.read(batchQueueProvider.notifier);
    final filePathsToAdd = <String>[];

    try {
      for (final path in paths) {
        if (await FileSystemEntity.isDirectory(path)) {
          await batchQueueNotifier.importDirectory(path);
        } else if (await FileSystemEntity.isFile(path)) {
          final ext = p.extension(path).toLowerCase();
          if (validExtensions.contains(ext)) {
            filePathsToAdd.add(path);
          }
        }
      }

      if (filePathsToAdd.isNotEmpty) {
        await batchQueueNotifier.addFiles(filePathsToAdd);
      }

      // Sync all valid file paths into workflowProvider
      final allQueueNodes = ref.read(batchQueueProvider);
      final allFiles = BatchNode.extractFileNodes(allQueueNodes);

      if (allFiles.isNotEmpty) {
        ref.read(workflowProvider.notifier).setBatchFiles(allFiles.map((f) => f.absolutePath).toList());
        
        // Auto-advance to Source Type phase
        if (mounted) {
          ref.read(selectedTabProvider.notifier).setTab(1);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No supported video files found.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing files: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _browseFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: validExtensions.map((e) => e.replaceAll('.', '')).toList(),
    );

    if (result != null && result.paths.isNotEmpty) {
      final validPaths = result.paths.where((p) => p != null).cast<String>().toList();
      _processPaths(validPaths);
    }
  }

  Future<void> _browseFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      _processPaths([result]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) => setState(() => _isDragging = true),
      onDragExited: (details) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        final paths = details.files.map((e) => e.path).toList();
        _processPaths(paths);
      },
      child: Container(
        color: _isDragging ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isDragging ? Theme.of(context).colorScheme.primary : const Color(0xFF333333),
                  width: _isDragging ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _isProcessing
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 24),
                        Text(
                          'Scanning directories...',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.drive_folder_upload_rounded,
                          size: 80,
                          color: _isDragging ? Theme.of(context).colorScheme.primary : Colors.white54,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Drag and Drop Media',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _isDragging ? Theme.of(context).colorScheme.primary : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Drop MKV, MP4, MOV files or entire season folders here.\nIrrelevant files will be automatically ignored.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white54,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _browseFiles,
                              icon: const Icon(Icons.file_open_rounded),
                              label: const Text('Browse Files'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                backgroundColor: const Color(0xFF333333),
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _browseFolder,
                              icon: const Icon(Icons.folder_open_rounded),
                              label: const Text('Browse Folder'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                backgroundColor: const Color(0xFF333333),
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
