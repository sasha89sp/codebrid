import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class BackupResult {
  const BackupResult({
    required this.success,
    required this.message,
    this.backupZipPath,
    this.archivedFilesCount = 0,
  });

  final bool success;
  final String message;
  final String? backupZipPath;
  final int archivedFilesCount;
}

class BackupService {
  static String defaultBackupDirectory(String dataDirectory) {
    return p.normalize(p.join(p.dirname(dataDirectory), 'backups'));
  }

  static String _stamp(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}${two(l.month)}${two(l.day)}_${two(l.hour)}${two(l.minute)}${two(l.second)}';
  }

  static Future<BackupResult> createFullBackup({
    required String dataDirectory,
    String? customBackupDirectory,
    bool isAuto = false,
    int keepLast = 15,
    List<String> extraDirectories = const <String>[],
  }) async {
    final dataDir = Directory(dataDirectory);
    if (!await dataDir.exists()) {
      return BackupResult(
        success: false,
        message: 'Каталог данных не найден: $dataDirectory',
      );
    }

    final backupRoot = Directory(
      (customBackupDirectory != null && customBackupDirectory.trim().isNotEmpty)
          ? p.normalize(customBackupDirectory.trim())
          : defaultBackupDirectory(dataDirectory),
    );
    await backupRoot.create(recursive: true);

    final prefix = isAuto ? 'auto_backup' : 'backup';
    final zipName = 'CodeBridgeMini_${prefix}_${_stamp(DateTime.now())}.zip';
    final outZipPath = p.join(backupRoot.path, zipName);

    final archive = Archive();
    var added = 0;

    Future<void> addDirectoryTree(Directory sourceDir, String archiveRootPrefix) async {
      if (!await sourceDir.exists()) return;
      final normRoot = p.normalize(sourceDir.absolute.path);
      await for (final entity in sourceDir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final fullNorm = p.normalize(entity.absolute.path);
        if (!p.isWithin(normRoot, fullNorm)) continue;
        final rel = p.relative(fullNorm, from: normRoot).replaceAll('\\', '/');
        if (rel.isEmpty) continue;
        // Пропускаем временные каталоги сборок и старые архивы бэкапов внутри data
        if (rel.startsWith('builds/_staging_') || rel.startsWith('backups/')) continue;

        final bytes = await entity.readAsBytes();
        final entryPath = archiveRootPrefix.isEmpty ? rel : '$archiveRootPrefix/$rel';
        archive.addFile(ArchiveFile(entryPath, bytes.length, bytes));
        added++;
      }
    }

    await addDirectoryTree(dataDir, 'data');

    for (var i = 0; i < extraDirectories.length; i++) {
      final rawExtra = extraDirectories[i].trim();
      if (rawExtra.isEmpty) continue;
      final extraDir = Directory(rawExtra);
      if (await extraDir.exists()) {
        final safeLabel = p.basename(p.normalize(extraDir.absolute.path)).replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
        await addDirectoryTree(
          extraDir,
          'workspace_${i + 1}_${safeLabel.isEmpty ? 'dir' : safeLabel}',
        );
      }
    }

    if (added == 0) {
      return const BackupResult(
        success: false,
        message: 'Нет файлов для сохранения в бэкап.',
      );
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      return const BackupResult(
        success: false,
        message: 'Не удалось упаковать архив бэкапа.',
      );
    }

    await File(outZipPath).writeAsBytes(encoded, flush: true);

    if (keepLast > 0) {
      await _pruneOldBackups(backupRoot, keepLast: keepLast);
    }

    return BackupResult(
      success: true,
      message: '${isAuto ? 'Автобэкап' : 'Бэкап'} сохранён: $outZipPath ($added файлов)',
      backupZipPath: outZipPath,
      archivedFilesCount: added,
    );
  }

  static Future<void> _pruneOldBackups(Directory backupRoot, {required int keepLast}) async {
    final entries = <FileSystemEntity>[];
    await for (final entity in backupRoot.list(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.zip')) {
        entries.add(entity);
      }
    }
    if (entries.length <= keepLast) return;
    entries.sort((a, b) => a.path.compareTo(b.path));
    final toRemove = entries.length - keepLast;
    for (var i = 0; i < toRemove; i++) {
      try {
        await entries[i].delete(recursive: true);
      } catch (_) {}
    }
  }

  static Future<BackupResult> restoreFromBackupZip({
    required String zipPath,
    required String dataDirectory,
  }) async {
    final file = File(zipPath);
    if (!await file.exists()) {
      return BackupResult(
        success: false,
        message: 'Файл бэкапа не найден: $zipPath',
      );
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final dataRoot = p.normalize(Directory(dataDirectory).absolute.path);
    var restored = 0;

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final cleanEntry = entry.name.replaceAll('\\', '/');
      if (cleanEntry.contains('..') || cleanEntry.startsWith('/')) continue;
      if (!cleanEntry.startsWith('data/')) continue;
      final relInData = cleanEntry.substring('data/'.length);
      if (relInData.isEmpty) continue;
      final destPath = p.normalize(p.joinAll(<String>[dataRoot, ...relInData.split('/')]));
      if (!p.isWithin(dataRoot, destPath) && destPath != dataRoot) continue;
      final outFile = File(destPath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>, flush: true);
      restored++;
    }

    return BackupResult(
      success: true,
      message: 'Восстановлено файлов настроек и проектов: $restored из ${p.basename(zipPath)}',
      backupZipPath: zipPath,
      archivedFilesCount: restored,
    );
  }
}
