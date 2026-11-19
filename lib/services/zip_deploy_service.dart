import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class ZipInspectionResult {
  const ZipInspectionResult({
    required this.isValidProject,
    required this.fileCount,
    required this.hasPubspec,
    required this.hasAgentsMd,
    this.strippedRootPrefix = '',
    this.reason,
  });

  final bool isValidProject;
  final int fileCount;
  final bool hasPubspec;
  final bool hasAgentsMd;
  final String strippedRootPrefix;
  final String? reason;
}

class ZipExtractResult {
  const ZipExtractResult({
    required this.extractedCount,
    required this.skippedEntries,
    required this.strippedRootPrefix,
  });

  final int extractedCount;
  final List<String> skippedEntries;
  final String strippedRootPrefix;
}

class ZipDeployService {
  static const int maxArchiveBytes = 200 * 1024 * 1024;
  static const int maxExtractedFiles = 5000;

  static Future<ZipInspectionResult> inspectZip(String zipPath) async {
    final file = File(zipPath);
    if (!await file.exists()) {
      return const ZipInspectionResult(
        isValidProject: false,
        fileCount: 0,
        hasPubspec: false,
        hasAgentsMd: false,
        reason: 'Архив не найден на диске.',
      );
    }

    final length = await file.length();
    if (length == 0) {
      return const ZipInspectionResult(
        isValidProject: false,
        fileCount: 0,
        hasPubspec: false,
        hasAgentsMd: false,
        reason: 'Архив пустой.',
      );
    }
    if (length > maxArchiveBytes) {
      return const ZipInspectionResult(
        isValidProject: false,
        fileCount: 0,
        hasPubspec: false,
        hasAgentsMd: false,
        reason: 'Архив превышает лимит 200 МБ.',
      );
    }

    final Archive archive;
    try {
      final bytes = await file.readAsBytes();
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (error) {
      return ZipInspectionResult(
        isValidProject: false,
        fileCount: 0,
        hasPubspec: false,
        hasAgentsMd: false,
        reason: 'Не удалось прочитать ZIP-архив: $error',
      );
    }

    final filePaths = <String>[];
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final normalized = _normalizeEntryPath(entry.name);
      if (normalized == null) {
        return ZipInspectionResult(
          isValidProject: false,
          fileCount: 0,
          hasPubspec: false,
          hasAgentsMd: false,
          reason: 'Обнаружен небезопасный путь внутри архива: "${entry.name}".',
        );
      }
      if (_isIgnoredMetaPath(normalized)) continue;
      filePaths.add(normalized);
    }

    if (filePaths.isEmpty) {
      return const ZipInspectionResult(
        isValidProject: false,
        fileCount: 0,
        hasPubspec: false,
        hasAgentsMd: false,
        reason: 'В архиве нет файлов для распаковки.',
      );
    }
    if (filePaths.length > maxExtractedFiles) {
      return const ZipInspectionResult(
        isValidProject: false,
        fileCount: 0,
        hasPubspec: false,
        hasAgentsMd: false,
        reason: 'Слишком много файлов в архиве (лимит $maxExtractedFiles).',
      );
    }

    final prefix = _detectSingleRootPrefix(filePaths);
    final relativePaths = filePaths.map((path) => _stripPrefix(path, prefix)).toList();

    final hasPubspec = relativePaths.any((path) => path.toLowerCase() == 'pubspec.yaml');
    final hasAgentsMd = relativePaths.any((path) => path.toLowerCase() == 'agents.md');
    final isValidProject = hasPubspec || hasAgentsMd;

    return ZipInspectionResult(
      isValidProject: isValidProject,
      fileCount: relativePaths.length,
      hasPubspec: hasPubspec,
      hasAgentsMd: hasAgentsMd,
      strippedRootPrefix: prefix,
      reason: isValidProject
          ? null
          : 'В корне архива не найдены pubspec.yaml или AGENTS.md.',
    );
  }

  static Future<ZipExtractResult> extractToDirectory({
    required String zipPath,
    required String targetDirectory,
    bool cleanTarget = false,
    bool requireProjectMarkers = true,
  }) async {
    final inspection = await inspectZip(zipPath);
    if (requireProjectMarkers && !inspection.isValidProject) {
      throw FormatException(inspection.reason ?? 'Архив не похож на проект.');
    }
    if (inspection.fileCount == 0) {
      throw FormatException(inspection.reason ?? 'Архив не содержит файлов.');
    }

    final targetDir = Directory(targetDirectory);
    await targetDir.create(recursive: true);
    final normalizedRoot = p.normalize(targetDir.absolute.path);

    if (cleanTarget) {
      await _cleanDirectoryPreservingGit(targetDir);
    }

    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);

    var extractedCount = 0;
    final skippedEntries = <String>[];

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final normalized = _normalizeEntryPath(entry.name);
      if (normalized == null) {
        throw FormatException('Небезопасный путь внутри архива: "${entry.name}".');
      }
      if (_isIgnoredMetaPath(normalized)) {
        skippedEntries.add(normalized);
        continue;
      }

      final stripped = _stripPrefix(normalized, inspection.strippedRootPrefix);
      if (stripped.isEmpty) continue;

      final segments = stripped.split('/');
      if (segments.first.toLowerCase() == '.git') {
        skippedEntries.add(stripped);
        continue;
      }

      final destinationPath = p.normalize(p.joinAll(<String>[normalizedRoot, ...segments]));
      if (!p.isWithin(normalizedRoot, destinationPath)) {
        throw FormatException('Путь выходит за пределы папки проекта: "$stripped".');
      }

      final outFile = File(destinationPath);
      await outFile.parent.create(recursive: true);
      final data = entry.content as List<int>;
      await outFile.writeAsBytes(data, flush: true);
      extractedCount++;
    }

    return ZipExtractResult(
      extractedCount: extractedCount,
      skippedEntries: skippedEntries,
      strippedRootPrefix: inspection.strippedRootPrefix,
    );
  }

  static Future<void> _cleanDirectoryPreservingGit(Directory directory) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name.toLowerCase() == '.git') continue;
      await entity.delete(recursive: true);
    }
  }

  static String? _normalizeEntryPath(String raw) {
    final cleaned = raw.replaceAll('\\', '/').trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('/') || RegExp(r'^[a-zA-Z]:/').hasMatch(cleaned)) {
      return null;
    }
    final parts = cleaned.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    for (final part in parts) {
      if (part == '.' || part == '..') return null;
    }
    return parts.join('/');
  }

  static bool _isIgnoredMetaPath(String normalizedPath) {
    final lower = normalizedPath.toLowerCase();
    return lower.startsWith('__macosx/') ||
        lower.endsWith('/.ds_store') ||
        lower == '.ds_store';
  }

  static String _detectSingleRootPrefix(List<String> paths) {
    if (paths.isEmpty) return '';
    final firstSegments = <String>{};
    for (final path in paths) {
      final idx = path.indexOf('/');
      if (idx <= 0) {
        return '';
      }
      firstSegments.add(path.substring(0, idx));
      if (firstSegments.length > 1) return '';
    }
    return '${firstSegments.first}/';
  }

  static String _stripPrefix(String path, String prefix) {
    if (prefix.isEmpty) return path;
    if (path.startsWith(prefix)) {
      return path.substring(prefix.length);
    }
    return path;
  }
}
