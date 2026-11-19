import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:code_bridge_mini/services/zip_deploy_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<String> _createZip(
  Directory dir,
  String name,
  Map<String, String> entries,
) async {
  final archive = Archive();
  for (final entry in entries.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  final encoded = ZipEncoder().encode(archive)!;
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(encoded, flush: true);
  return file.path;
}

void main() {
  group('ZipDeployService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('codebridge_zip_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('detects valid Flutter project and strips single top-level folder', () async {
      final zipPath = await _createZip(tempDir, 'project.zip', <String, String>{
        'my_app/pubspec.yaml': 'name: my_app\n',
        'my_app/lib/main.dart': 'void main() {}\n',
      });

      final inspection = await ZipDeployService.inspectZip(zipPath);
      expect(inspection.isValidProject, isTrue);
      expect(inspection.hasPubspec, isTrue);
      expect(inspection.strippedRootPrefix, 'my_app/');
      expect(inspection.fileCount, 2);

      final targetDir = p.join(tempDir.path, 'out');
      final result = await ZipDeployService.extractToDirectory(
        zipPath: zipPath,
        targetDirectory: targetDir,
      );

      expect(result.extractedCount, 2);
      expect(File(p.join(targetDir, 'pubspec.yaml')).existsSync(), isTrue);
      expect(File(p.join(targetDir, 'lib', 'main.dart')).existsSync(), isTrue);
    });

    test('rejects random ZIP without pubspec.yaml or AGENTS.md', () async {
      final zipPath = await _createZip(tempDir, 'random.zip', <String, String>{
        'notes.txt': 'hello',
      });

      final inspection = await ZipDeployService.inspectZip(zipPath);
      expect(inspection.isValidProject, isFalse);
      expect(inspection.hasPubspec, isFalse);
      expect(inspection.hasAgentsMd, isFalse);
    });

    test('preserves .git directory when cleanTarget is true and ignores .git in archive', () async {
      final targetDir = Directory(p.join(tempDir.path, 'repo'));
      final gitHead = File(p.join(targetDir.path, '.git', 'HEAD'));
      final staleFile = File(p.join(targetDir.path, 'old.txt'));
      await gitHead.parent.create(recursive: true);
      await gitHead.writeAsString('ref: refs/heads/main\n');
      await staleFile.writeAsString('remove me');

      final zipPath = await _createZip(tempDir, 'update.zip', <String, String>{
        'AGENTS.md': '# AGENTS\n',
        '.git/HEAD': 'malicious override',
        'lib/new.dart': '// new\n',
      });

      final result = await ZipDeployService.extractToDirectory(
        zipPath: zipPath,
        targetDirectory: targetDir.path,
        cleanTarget: true,
      );

      expect(result.extractedCount, 2);
      expect(staleFile.existsSync(), isFalse);
      expect(await gitHead.readAsString(), 'ref: refs/heads/main\n');
      expect(File(p.join(targetDir.path, 'lib', 'new.dart')).existsSync(), isTrue);
    });

    test('rejects archives containing path traversal entries', () async {
      final zipPath = await _createZip(tempDir, 'evil.zip', <String, String>{
        'pubspec.yaml': 'name: evil\n',
        '../outside.txt': 'boom',
      });

      final inspection = await ZipDeployService.inspectZip(zipPath);
      expect(inspection.isValidProject, isFalse);
      expect(inspection.reason, contains('небезопасный путь'));
    });
  });
}
