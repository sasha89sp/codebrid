import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../providers/project_provider.dart';
import '../services/app_version.dart';
import '../services/backup_service.dart';
import 'project_dialogs.dart';

Future<void> showAboutBackupDialog(BuildContext context, ProjectProvider provider) async {
  final backupDirCtrl = TextEditingController(text: provider.backupDirectory ?? '');
  var autoEnabled = provider.autoBackupEnabled;
  var intervalMinutes = provider.autoBackupIntervalMinutes;
  var statusText = provider.lastBackupZipPath != null
      ? 'Последний архив: ${provider.lastBackupZipPath}'
      : 'Бэкапы сохраняются в ${provider.backupDirectory ?? BackupService.defaultBackupDirectory(provider.storage.dataDirectory)}';
  var busy = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final effectiveBackupDir = backupDirCtrl.text.trim().isEmpty
              ? BackupService.defaultBackupDirectory(provider.storage.dataDirectory)
              : backupDirCtrl.text.trim();

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 22),
                SizedBox(width: 8),
                Text('CodeBridge Mini — v${AppVersion.fullVersion}'),
              ],
            ),
            content: SizedBox(
              width: 680,
              height: 540,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Актуальная версия: ${AppVersion.currentVersion} (сборка ${AppVersion.currentBuildNumber}). '
                    'Сохранение настроек, шаблонов, проектов и наработок.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF5C687D)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE1E7F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Резервное копирование и автобэкап',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF202A40)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      setDialogState(() => busy = true);
                                      final res = await provider.createBackupNow(isAuto: false);
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        busy = false;
                                        statusText = res.message;
                                      });
                                    },
                              icon: const Icon(Icons.backup_outlined, size: 16),
                              label: const Text('Сделать бэкап'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final picked = await FilePicker.platform.pickFiles(
                                        dialogTitle: 'Выберите архив бэкапа (.zip)',
                                        type: FileType.custom,
                                        allowedExtensions: const <String>['zip'],
                                        initialDirectory: effectiveBackupDir,
                                      );
                                      final path = picked?.files.single.path;
                                      if (path == null || path.isEmpty || !dialogContext.mounted) return;
                                      setDialogState(() => busy = true);
                                      final res = await provider.restoreBackup(path);
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        busy = false;
                                        statusText = res.message;
                                      });
                                    },
                              icon: const Icon(Icons.restore_rounded, size: 16),
                              label: const Text('Восстановить'),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Автобэкап настроек и проектов'),
                          value: autoEnabled,
                          onChanged: busy ? null : (v) => setDialogState(() => autoEnabled = v),
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 210,
                              child: DropdownButtonFormField<int>(
                                value: intervalMinutes,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Интервал автобэкапа'),
                                items: const <DropdownMenuItem<int>>[
                                  DropdownMenuItem<int>(value: 15, child: Text('Каждые 15 минут')),
                                  DropdownMenuItem<int>(value: 30, child: Text('Каждые 30 минут')),
                                  DropdownMenuItem<int>(value: 60, child: Text('Каждый час')),
                                  DropdownMenuItem<int>(value: 180, child: Text('Каждые 3 часа')),
                                ],
                                onChanged: busy
                                    ? null
                                    : (v) {
                                        if (v != null) setDialogState(() => intervalMinutes = v);
                                      },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: backupDirCtrl,
                                enabled: !busy,
                                decoration: const InputDecoration(
                                  labelText: 'Папка бэкапов (по умолчанию рядом с data)',
                                  hintText: r'Например: D:\Backups\CodeBridgeMini',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final selected = await FilePicker.platform.getDirectoryPath(
                                        dialogTitle: 'Выберите папку для бэкапов',
                                      );
                                      if (selected != null && selected.trim().isNotEmpty) {
                                        setDialogState(() => backupDirCtrl.text = selected.trim());
                                      }
                                    },
                              child: const Text('Папка'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      setDialogState(() => busy = true);
                                      await provider.updateBackupSettings(
                                        enabled: autoEnabled,
                                        intervalMinutes: intervalMinutes,
                                        customBackupDir: backupDirCtrl.text,
                                      );
                                      if (!dialogContext.mounted) return;
                                      setDialogState(() {
                                        busy = false;
                                        statusText = 'Настройки автобэкапа сохранены (${autoEnabled ? 'вкл' : 'выкл'}, каждые $intervalMinutes мин).';
                                      });
                                    },
                              child: const Text('Сохранить'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusText,
                          style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, color: Color(0xFF4A5568)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'История изменений версий',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF202A40)),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.separated(
                      itemCount: AppVersion.history.length,
                      separatorBuilder: (_, __) => const Divider(height: 14),
                      itemBuilder: (context, index) {
                        final entry = AppVersion.history[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'v${entry.fullVersion} — ${entry.title}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF202A40)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.summary,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568)),
                            ),
                            const SizedBox(height: 4),
                            ...entry.changes.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontWeight: FontWeight.w700)),
                                    Expanded(
                                      child: Text(item, style: const TextStyle(fontSize: 11.5, color: Color(0xFF364158))),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () => openFolderInExplorer(context, effectiveBackupDir),
                icon: const Icon(Icons.folder_open_outlined, size: 17),
                label: const Text('Папка бэкапов'),
              ),
              OutlinedButton.icon(
                onPressed: () => openFolderInExplorer(context, provider.storage.dataDirectory),
                icon: const Icon(Icons.folder_open_outlined, size: 17),
                label: const Text('Папка данных'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          );
        },
      );
    },
  );

  backupDirCtrl.dispose();
}

void _showAboutSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

String _formatAboutDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}

String _formatAboutFileSize(File file) {
  try {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  } catch (_) {
    return 'Размер неизвестен';
  }
}
