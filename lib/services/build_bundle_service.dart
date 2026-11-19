import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class BuildBundleResult {
  const BuildBundleResult({
    required this.success,
    required this.message,
    required this.logs,
    this.targetDirectory,
    this.backupDirectory,
  });

  final bool success;
  final String message;
  final List<String> logs;
  final String? targetDirectory;
  final String? backupDirectory;
}

class BuildBundleService {
  static String defaultBuildsRootDirectory(String dataDirectory) {
    return p.join(dataDirectory, 'builds');
  }

  static Future<BuildBundleResult> applyDownloadedBuild({
    required String zipPath,
    required String buildsRootDirectory,
    String? customTargetDirectory,
    List<String> preservedPatterns = const <String>[],
  }) async {
    final logs = <String>[];
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      return BuildBundleResult(
        success: false,
        message: 'Архив сборки не найден: $zipPath',
        logs: <String>['Архив сборки не найден: $zipPath'],
      );
    }

    final zipName = p.basename(zipPath);
    final baseDirName = _sanitizeFolderName(
      zipName.toLowerCase().endsWith('.zip')
          ? zipName.substring(0, zipName.length - 4)
          : zipName,
    );

    final targetRoot = (customTargetDirectory != null && customTargetDirectory.trim().isNotEmpty)
        ? p.normalize(customTargetDirectory.trim())
        : p.normalize(p.join(buildsRootDirectory, baseDirName));

    final currentDir = Directory(p.join(targetRoot, 'current'));
    final historyRoot = Directory(p.join(targetRoot, '_history'));
    final stagingDir = Directory(p.join(targetRoot, '_staging_${DateTime.now().millisecondsSinceEpoch}'));

    await currentDir.create(recursive: true);
    await historyRoot.create(recursive: true);
    if (await stagingDir.exists()) {
      await stagingDir.delete(recursive: true);
    }
    await stagingDir.create(recursive: true);

    logs.add('Подготовка сборки из архива: $zipName');
    logs.add('Целевая папка проекта сборок: $targetRoot');

    String? backupPath;
    final hasExistingCurrent = await _directoryHasFiles(currentDir);

    if (hasExistingCurrent) {
      final stamp = _timestampSlug(DateTime.now());
      final backupDir = Directory(p.join(historyRoot.path, '${stamp}_$baseDirName'));
      await backupDir.create(recursive: true);
      await _copyDirectoryContents(currentDir, backupDir);
      backupPath = backupDir.path;
      logs.add('Старая версия сохранена в исходном виде: $backupPath');

      // Копируем старую версию в staging, чтобы перенести настройки и файлы,
      // а поверх неё накатываем новый архив.
      await _copyDirectoryContents(backupDir, stagingDir);
    } else {
      logs.add('Предыдущая версия в папке current отсутствует — создаётся первая сборка.');
    }

    int extractedCount = 0;
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final fileEntries = <({String path, List<int> data})>[];

      for (final entry in archive) {
        if (!entry.isFile) continue;
        final normalized = _normalizeEntryPath(entry.name);
        if (normalized == null) {
          throw FormatException('Небезопасный путь внутри архива: "${entry.name}".');
        }
        if (_isIgnoredMeta(normalized)) continue;
        fileEntries.add((path: normalized, data: entry.content as List<int>));
      }

      if (fileEntries.isEmpty) {
        throw const FormatException('Архив скомпилированного проекта пуст.');
      }

      final rootPrefix = _detectSingleRootPrefix(
        fileEntries.map((e) => e.path).toList(),
      );

      for (final item in fileEntries) {
        final relPath = _stripPrefix(item.path, rootPrefix);
        if (relPath.isEmpty) continue;
        if (hasExistingCurrent && _matchesPreserved(relPath, preservedPatterns)) {
          logs.add('Сохранён защищённый файл старой версии: $relPath');
          continue;
        }
        final parts = relPath.split('/');
        final destPath = p.normalize(p.joinAll(<String>[stagingDir.path, ...parts]));
        if (!p.isWithin(p.normalize(stagingDir.path), destPath)) {
          throw FormatException('Путь выходит за пределы каталога сборки: "$relPath".');
        }
        final outFile = File(destPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(item.data, flush: true);
        extractedCount++;
      }

      logs.add('Накачано новых файлов поверх старой версии: $extractedCount');

      // Заменяем содержимое current готовой обновлённой версией.
      await _clearDirectory(currentDir);
      await _copyDirectoryContents(stagingDir, currentDir);
      logs.add('Обновлённая сборка готова в: ${currentDir.path}');

      return BuildBundleResult(
        success: true,
        message: 'Новая версия собрана и сохранена в ${currentDir.path}',
        logs: logs,
        targetDirectory: currentDir.path,
        backupDirectory: backupPath,
      );
    } finally {
      if (await stagingDir.exists()) {
        try {
          await stagingDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  static Future<bool> _directoryHasFiles(Directory dir) async {
    if (!await dir.exists()) return false;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) return true;
    }
    return false;
  }

  static Future<void> _clearDirectory(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      await entity.delete(recursive: true);
    }
  }

  static Future<void> _copyDirectoryContents(Directory source, Directory destination) async {
    if (!await source.exists()) return;
    await destination.create(recursive: true);
    final srcRoot = p.normalize(source.absolute.path);
    final dstRoot = p.normalize(destination.absolute.path);

    await for (final entity in source.list(recursive: true, followLinks: false)) {
      final rel = p.relative(entity.path, from: srcRoot);
      final targetPath = p.join(dstRoot, rel);
      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
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

  static bool _isIgnoredMeta(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('__macosx/') ||
        lower.endsWith('/.ds_store') ||
        lower == '.ds_store';
  }

  static String _detectSingleRootPrefix(List<String> paths) {
    if (paths.isEmpty) return '';
    final roots = <String>{};
    for (final path in paths) {
      final idx = path.indexOf('/');
      if (idx <= 0) return '';
      roots.add(path.substring(0, idx));
      if (roots.length > 1) return '';
    }
    return '${roots.first}/';
  }

  static String _stripPrefix(String path, String prefix) {
    if (prefix.isEmpty) return path;
    return path.startsWith(prefix) ? path.substring(prefix.length) : path;
  }

  static bool _matchesPreserved(String relPath, List<String> patterns) {
    if (patterns.isEmpty) return false;
    final lowerPath = relPath.toLowerCase();
    final lowerName = p.basename(relPath).toLowerCase();
    for (final raw in patterns) {
      final pat = raw.trim().toLowerCase();
      if (pat.isEmpty) continue;
      if (pat == lowerName || pat == lowerPath) return true;
      if (pat.startsWith('*.')) {
        final ext = pat.substring(1);
        if (lowerName.endsWith(ext)) return true;
      } else if (pat.contains('*')) {
        final escaped = RegExp.escape(pat).replaceAll(r'\*', '.*');
        if (RegExp('^$escaped$').hasMatch(lowerName) ||
            RegExp('^$escaped$').hasMatch(lowerPath)) {
          return true;
        }
      }
    }
    return false;
  }

  static String _sanitizeFolderName(String input) {
    final cleaned = input.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return cleaned.isEmpty ? 'build' : cleaned;
  }

  static String _timestampSlug(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}${two(dt.second)}_$ms';
  }
}
