import 'dart:async';
import 'dart:io';

import '../models/code_project.dart';
import 'app_storage.dart';
import 'backup_service.dart';

class BackupCoordinator {
  BackupCoordinator({
    required this.storage,
    required this.getProjects,
    required this.onLog,
    required this.onInfo,
    required this.onError,
    required this.onReloadAfterRestore,
    required this.onNotify,
  });

  final AppStorage storage;
  final List<CodeProject> Function() getProjects;
  final void Function(String message) onLog;
  final void Function(String message) onInfo;
  final void Function(String message) onError;
  final Future<void> Function(
    bool enabled,
    int intervalMinutes,
    String? customDir,
    String? lastAutoAt,
  ) onReloadAfterRestore;
  final void Function() onNotify;

  Timer? _timer;
  bool autoBackupEnabled = true;
  int autoBackupIntervalMinutes = 30;
  String? backupDirectory;
  String? lastBackupZipPath;
  String? lastAutoBackupAt;

  void applyInitialState({
    required bool enabled,
    required int intervalMinutes,
    required String? customDir,
    required String? lastAutoAt,
  }) {
    autoBackupEnabled = enabled;
    autoBackupIntervalMinutes = intervalMinutes.clamp(5, 1440);
    backupDirectory = customDir;
    lastAutoBackupAt = lastAutoAt;
    configureTimer();
  }

  void configureTimer() {
    _timer?.cancel();
    _timer = null;
    if (!autoBackupEnabled) return;
    final minutes = autoBackupIntervalMinutes.clamp(5, 1440);
    _timer = Timer.periodic(Duration(minutes: minutes), (_) {
      unawaited(runIfDue(force: false));
    });
  }

  Future<void> runIfDue({bool force = false}) async {
    if (!autoBackupEnabled && !force) return;
    final now = DateTime.now();
    if (!force && lastAutoBackupAt != null && lastAutoBackupAt!.isNotEmpty) {
      final parsed = DateTime.tryParse(lastAutoBackupAt!);
      if (parsed != null) {
        final elapsed = now.difference(parsed);
        if (elapsed.inMinutes < autoBackupIntervalMinutes.clamp(5, 1440)) {
          return;
        }
      }
    }
    await createBackupNow(isAuto: true, silent: true);
  }

  Future<void> updateSettings({
    required bool enabled,
    required int intervalMinutes,
    String? customBackupDir,
  }) async {
    autoBackupEnabled = enabled;
    autoBackupIntervalMinutes = intervalMinutes.clamp(5, 1440);
    final trimmed = customBackupDir?.trim() ?? '';
    backupDirectory = trimmed.isEmpty ? null : trimmed;
    await storage.saveBackupSettings(
      autoBackupEnabled: autoBackupEnabled,
      autoBackupIntervalMinutes: autoBackupIntervalMinutes,
      backupDirectory: backupDirectory,
    );
    configureTimer();
    if (autoBackupEnabled) {
      await runIfDue(force: true);
    }
    onNotify();
  }

  Future<BackupResult> createBackupNow({
    bool isAuto = false,
    bool silent = false,
  }) async {
    final extraDirs = <String>[
      for (final proj in getProjects())
        if (Directory(proj.outputPath).existsSync()) proj.outputPath,
    ];
    final res = await BackupService.createFullBackup(
      dataDirectory: storage.dataDirectory,
      customBackupDirectory: backupDirectory,
      isAuto: isAuto,
      extraDirectories: extraDirs,
    );
    if (res.success && res.backupZipPath != null) {
      lastBackupZipPath = res.backupZipPath;
      final stampIso = DateTime.now().toIso8601String();
      lastAutoBackupAt = stampIso;
      await storage.recordLastAutoBackup(stampIso);
      onLog(res.message);
      if (!silent) {
        onInfo(res.message);
      }
      onNotify();
    } else if (!silent) {
      onError(res.message);
      onNotify();
    }
    return res;
  }

  Future<BackupResult> restoreBackup(String zipPath) async {
    final res = await BackupService.restoreFromBackupZip(
      zipPath: zipPath,
      dataDirectory: storage.dataDirectory,
    );
    if (!res.success) {
      onError(res.message);
      return res;
    }
    final settings = await storage.loadSettings();
    applyInitialState(
      enabled: settings.autoBackupEnabled,
      intervalMinutes: settings.autoBackupIntervalMinutes,
      customDir: settings.backupDirectory,
      lastAutoAt: settings.lastAutoBackupAt,
    );
    await onReloadAfterRestore(
      settings.autoBackupEnabled,
      settings.autoBackupIntervalMinutes,
      settings.backupDirectory,
      settings.lastAutoBackupAt,
    );
    onInfo(res.message);
    onLog(res.message);
    return res;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
