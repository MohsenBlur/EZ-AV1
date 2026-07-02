import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ez_av1/models/batch_node_model.dart';
import 'package:ez_av1/providers/batch_queue_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BatchQueueNotifier', () {
    test('removeNode safely removes child node from DirectoryNode without UnsupportedError', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchQueueProvider.notifier);

      // Create a directory node with an unmodifiable list or default constructor
      final fileChild = FileNode(
        id: 'child_1',
        name: 'test.mp4',
        absolutePath: '/videos/test.mp4',
        extension: '.mp4',
        sizeBytes: 1000,
      );

      final parentDir = DirectoryNode(
        id: 'dir_1',
        name: 'Season 1',
        absolutePath: '/videos/Season 1',
        children: [fileChild], // Passed list
      );

      notifier.state = [parentDir];

      // Attempt to remove child node
      await notifier.removeNode('child_1');

      final updatedState = container.read(batchQueueProvider);
      final updatedParent = updatedState.first as DirectoryNode;
      expect(updatedParent.children, isEmpty);
    });

    test('DirectoryNode default constructor creates growable mutable children list', () {
      final emptyDir = DirectoryNode(
        id: 'dir_empty',
        name: 'Empty',
        absolutePath: '/empty',
      );

      expect(() => emptyDir.children.add(FileNode(
        id: 'f1',
        name: 'a.mp4',
        absolutePath: '/a.mp4',
        extension: '.mp4',
        sizeBytes: 100,
      )), returnsNormally);

      expect(emptyDir.children.length, equals(1));
    });

    test('ensureInitialized awaits initial load before modifying state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchQueueProvider.notifier);
      await notifier.ensureInitialized();

      expect(notifier.state, isA<List<BatchNode>>());
    });

    test('BatchNode.extractFileNodes flattens nested DirectoryNode trees correctly', () {
      final file1 = FileNode(id: '1', name: 'a.mp4', absolutePath: '/a.mp4', extension: '.mp4', sizeBytes: 10);
      final file2 = FileNode(id: '2', name: 'b.mkv', absolutePath: '/sub/b.mkv', extension: '.mkv', sizeBytes: 20);
      final subDir = DirectoryNode(id: 'd2', name: 'sub', absolutePath: '/sub', children: [file2]);
      final rootDir = DirectoryNode(id: 'd1', name: 'root', absolutePath: '/', children: [file1, subDir]);

      final files = BatchNode.extractFileNodes([rootDir]);
      expect(files.length, equals(2));
      expect(files.map((f) => f.absolutePath), containsAll(['/a.mp4', '/sub/b.mkv']));
    });

    test('DirectoryNode.fromJson handles null or missing children safely', () {
      final jsonMap = {
        'type': 'directory',
        'id': 'd_null',
        'name': 'NullDir',
        'absolutePath': '/NullDir',
        'children': null,
      };

      final node = DirectoryNode.fromJson(jsonMap);
      expect(node.children, isEmpty);
    });
  });
}
