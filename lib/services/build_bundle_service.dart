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
    this.launchedExePath,
  });

  final bool success;
  final String message;
  final List<String> logs;
  final String? targetDirectory;
  final String? backupDirectory;
  final String? launchedExePath;
}

class BuildBundleService {
  static String defaultBuildsRootDirectory(String dataDirectory) {
    return p.join(dataDirectory, 'builds');
  }

  static String currentBuildDirectory({
    required String dataDirectory,
    required String buildTargetDirectory,
    required String packageName,
    String? lastArchiveName,
  }) {
    final trimmedTarget = buildTargetDirectory.trim();
    if (trimmedTarget.isNotEmpty) {
      final normTarget = p.normalize(trimmedTarget);
      if (p.basename(normTarget).toLowerCase() == 'current') {
        return normTarget;
      }
      if (lastArchiveName != null && lastArchiveName.trim().isNotEmpty) {
        final baseName = _sanitizeFolderName(
          lastArchiveName.toLowerCase().endsWith('.zip')
              ? lastArchiveName.substring(0, lastArchiveName.length - 4)
              : lastArchiveName,
        );
        final candidate = p.normalize(p.join(normTarget, baseName, 'current'));
        if (Directory(candidate).existsSync()) {
          return candidate;
        }
      }
      return p.normalize(p.join(normTarget, 'current'));
    }

    final buildsRoot = defaultBuildsRootDirectory(dataDirectory);
    if (lastArchiveName != null && lastArchiveName.trim().isNotEmpty) {
      final baseName = _sanitizeFolderName(
        lastArchiveName.toLowerCase().endsWith('.zip')
            ? lastArchiveName.substring(0, lastArchiveName.length - 4)
            : lastArchiveName,
      );
      final candidate = p.normalize(p.join(buildsRoot, baseName, 'current'));
      if (Directory(candidate).existsSync()) {
        return candidate;
      }
    }

    return p.normalize(p.join(buildsRoot, _sanitizeFolderName(packageName), 'current'));
  }

  static Future<BuildBundleResult> applyDownloadedBuild({
    required String zipPath,
    required String buildsRootDirectory,
    String? customTargetDirectory,
    List<String> preservedPatterns = const <String>[],
    bool overlayPreviousVersion = true,
    bool clearTargetBeforeApply = false,
    int historyKeepCount = 10,
    bool autoLaunchExe = false,
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

      if (clearTargetBeforeApply) {
        logs.add('Включена очистка перед сборкой — база старой версии не подмешивается в staging.');
      } else if (overlayPreviousVersion) {
        await _copyDirectoryContents(backupDir, stagingDir);
        logs.add('Старая версия подмешана в staging как основа для переноса настроек (оверлей включён).');
      } else {
        logs.add('Оверлей старой версии отключён — собирается только содержимое нового архива.');
      }
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
        if (hasExistingCurrent && overlayPreviousVersion && !clearTargetBeforeApply && _matchesPreserved(relPath, preservedPatterns)) {
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

      // Заменяем содержимое current готовой обновлённой версией с учётом возможных блокировок файлов.
      await _clearDirectorySafe(currentDir, logs);
      await _copyDirectoryContentsSafe(stagingDir, currentDir, logs);
      logs.add('Обновлённая сборка готова в: ${currentDir.path}');

      await _pruneHistory(historyRoot, historyKeepCount.clamp(1, 200), logs);

      String? launchedExe;
      if (autoLaunchExe) {
        launchedExe = await _launchNewestExeIfAny(currentDir, logs);
      }

      return BuildBundleResult(
        success: true,
        message: 'Новая версия собрана и сохранена в ${currentDir.path}',
        logs: logs,
        targetDirectory: currentDir.path,
        backupDirectory: backupPath,
        launchedExePath: launchedExe,
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
        final escapedPat = RegExp.escape(pat).replaceAll(r'\*', '.*');
        final patternStr = '^$escapedPat\$';
        if (RegExp(patternStr).hasMatch(lowerName) ||
            RegExp(patternStr).hasMatch(lowerPath)) {
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
  static Future<void> _clearDirectorySafe(Directory dir, List<String> logs) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } catch (e) {
        logs.add('Предупреждение: не удалось удалить "${p.basename(entity.path)}" (возможно, файл занят): $e');
      }
    }
  }

  static Future<void> _copyDirectoryContentsSafe(
    Directory source,
    Directory destination,
    List<String> logs,
  ) async {
    if (!await source.exists()) return;
    await destination.create(recursive: true);
    final srcRoot = p.normalize(source.absolute.path);
    final dstRoot = p.normalize(destination.absolute.path);

    await for (final entity in source.list(recursive: true, followLinks: false)) {
      final rel = p.relative(entity.path, from: srcRoot);
      final targetPath = p.join(dstRoot, rel);
      try {
        if (entity is Directory) {
          await Directory(targetPath).create(recursive: true);
        } else if (entity is File) {
          await File(targetPath).parent.create(recursive: true);
          await entity.copy(targetPath);
        }
      } catch (e) {
        logs.add('Предупреждение: не удалось скопировать "$rel" (возможно, файл открыт): $e');
      }
    }
  }

  static Future<void> _pruneHistory(
    Directory historyRoot,
    int keepCount,
    List<String> logs,
  ) async {
    if (!await historyRoot.exists()) return;
    final entries = <FileSystemEntity>[];
    await for (final item in historyRoot.list(followLinks: false)) {
      entries.add(item);
    }
    if (entries.length <= keepCount) return;
    entries.sort((a, b) {
      final sa = a.statSync().modified;
      final sb = b.statSync().modified;
      return sb.compareTo(sa);
    });
    for (final stale in entries.skip(keepCount)) {
      try {
        await stale.delete(recursive: true);
        logs.add('Удалена старая версия из _history: ${p.basename(stale.path)}');
      } catch (e) {
        logs.add('Не удалось удалить старую версию ${p.basename(stale.path)}: $e');
      }
    }
  }

  static Future<String?> _launchNewestExeIfAny(Directory currentDir, List<String> logs) async {
    if (!await currentDir.exists()) return null;
    final exeFiles = <File>[];
    await for (final entity in currentDir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.exe')) {
        final base = p.basename(entity.path).toLowerCase();
        if (base == 'createdump.exe') continue;
        exeFiles.add(entity);
      }
    }
    if (exeFiles.isEmpty) {
      logs.add('Автозапуск включён, но в ${currentDir.path} не найден .exe файл.');
      return null;
    }
    exeFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final exe = exeFiles.first;
    try {
      await Process.start(
        exe.absolute.path,
        const <String>[],
        workingDirectory: p.dirname(exe.absolute.path),
        mode: ProcessStartMode.detached,
      );
      logs.add('Запущена новая сборка: ${exe.path}');
      return exe.path;
    } catch (e) {
      logs.add('Не удалось запустить ${exe.path}: $e');
      return null;
    }
  }

}
