import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/code_project.dart';
import '../providers/project_provider.dart';
import '../services/agent_template.dart';

Future<void> showRenameProjectDialog(
  BuildContext context,
  ProjectProvider provider,
  CodeProject project,
) async {
  final controller = TextEditingController(text: project.name);
  var saving = false;
  var errorText = '';

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Переименовать проект'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Новое название проекта', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    readOnly: false,
                    enabled: !saving,
                    onChanged: (_) {
                      if (errorText.isNotEmpty) setDialogState(() => errorText = '');
                      setDialogState(() {});
                    },
                    decoration: const InputDecoration(hintText: 'Введите название проекта'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Имя Flutter-пакета: ${provider.packageNameFor(controller.text)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF69758B)),
                  ),
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(errorText, style: const TextStyle(color: Color(0xFFB74444), fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final clean = controller.text.trim();
                        if (clean.isEmpty) {
                          setDialogState(() => errorText = 'Введите название проекта.');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          errorText = '';
                        });
                        try {
                          await provider.renameCurrentProject(clean);
                          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        } catch (error) {
                          setDialogState(() {
                            errorText = error.toString().replaceFirst('Bad state: ', '');
                          });
                        } finally {
                          if (dialogContext.mounted) setDialogState(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Сохранить'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
}

Future<void> showCreateProjectDialog(BuildContext context, ProjectProvider provider) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final outputController = TextEditingController();
  final repoNameController = TextEditingController();
  final existingRepoUrlController = TextEditingController();
  final ownerController = TextEditingController(text: provider.githubOwner);
  final tokenController = TextEditingController(text: provider.githubToken);
  final branchController = TextEditingController(text: 'main');

  var outputWasEdited = false;
  var repoNameWasEdited = false;
  var attachExistingRepo = false;
  var cloneIfEmpty = true;
  var overwriteExistingStarterFiles = false;
  var createRemoteRepo = false;
  var isPrivateRepo = true;
  var createStarterFiles = true;
  var includeReadme = true;
  var includeGitignore = true;
  var includeAgentFile = true;
  var pushInitialCommit = true;
  var autoEnableDeploy = true;
  var autoSyncOnReject = true;
  final zipFilterController = TextEditingController();
  var zipFilterWasEdited = false;
  var dialogError = '';
  var creating = false;
  var templateId = provider.selectedTemplateId;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void onNameChanged(String name) {
            if (!outputWasEdited) {
              final nextPath = name.trim().isEmpty ? '' : provider.defaultOutputPathFor(name);
              if (outputController.text != nextPath) outputController.text = nextPath;
            }
            if (!repoNameWasEdited) {
              final suggested = name.trim().isEmpty
                  ? ''
                  : name
                      .trim()
                      .toLowerCase()
                      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
                      .replaceAll(RegExp(r'-{2,}'), '-')
                      .replaceAll(RegExp(r'^[.-]+|[.-]+$'), '');
              if (repoNameController.text != suggested) repoNameController.text = suggested;
            }
            if (!zipFilterWasEdited) {
              final compact = name.trim().replaceAll(RegExp(r'\s+'), '');
              if (zipFilterController.text != compact) zipFilterController.text = compact;
            }
            setDialogState(() {});
          }

          final packageName = provider.packageNameFor(nameController.text);
          return AlertDialog(
            title: const Text('Новый проект'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.create_new_folder_outlined, size: 16),
                          label: Text('Новый проект с нуля'),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.link_rounded, size: 16),
                          label: Text('Подключить готовый репозиторий'),
                        ),
                      ],
                      selected: <bool>{attachExistingRepo},
                      onSelectionChanged: creating
                          ? null
                          : (Set<bool> next) {
                              if (next.isNotEmpty) {
                                final toExisting = next.first;
                                setDialogState(() {
                                  attachExistingRepo = toExisting;
                                  if (toExisting) {
                                    createRemoteRepo = false;
                                    overwriteExistingStarterFiles = false;
                                  }
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    const Text('Название проекта', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 7),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      onChanged: onNameChanged,
                      decoration: const InputDecoration(hintText: 'Например: Калькулятор или My Calculator'),
                    ),
                    const SizedBox(height: 6),
                    Text('Имя Flutter-пакета: $packageName', style: const TextStyle(fontSize: 11, color: Color(0xFF69758B))),
                    const SizedBox(height: 14),
                    const Text('Описание функциональности', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 7),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(hintText: 'Опишите назначение приложения, экраны, логику и ключевые требования...'),
                    ),
                    const SizedBox(height: 14),
                    const Text('Шаблон инструкции AGENT.md', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 7),
                    DropdownButtonFormField<String>(
                      value: templateId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Выберите шаблон'),
                      items: provider.templates.map((item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: creating ? null : (value) { if (value != null) setDialogState(() => templateId = value); },
                    ),
                    const SizedBox(height: 14),
                    const Text('Папка для исходников и файлов проекта', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: outputController,
                            onChanged: (_) { outputWasEdited = true; setDialogState(() {}); },
                            decoration: const InputDecoration(hintText: 'Например: C:\\Users\\Alexey\\Documents\\my_app'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: creating ? null : () async {
                            final selected = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Выберите папку для файлов проекта');
                            if (selected != null && selected.trim().isNotEmpty) {
                              outputWasEdited = true;
                              outputController.text = selected.trim();
                              setDialogState(() {});
                            }
                          },
                          icon: const Icon(Icons.folder_open_outlined, size: 18),
                          label: const Text('Выбрать'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (attachExistingRepo) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: existingRepoUrlController,
                              enabled: !creating,
                              decoration: const InputDecoration(
                                labelText: 'URL готового репозитория',
                                hintText: 'https://github.com/user/repo.git',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: branchController,
                              enabled: !creating,
                              decoration: const InputDecoration(
                                labelText: 'Ветка',
                                hintText: 'main',
                              ),
                            ),
                          ),
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Клонировать репозиторий (git clone), если локальная папка пуста или не создана'),
                        value: cloneIfEmpty,
                        onChanged: creating
                            ? null
                            : (bool? v) => setDialogState(() => cloneIfEmpty = v ?? true),
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        attachExistingRepo
                            ? 'Добавить недостающие служебные файлы (README.md, .gitignore, AGENTS.md)'
                            : 'Создать базовые файлы проекта (README.md, .gitignore, AGENTS.md)',
                      ),
                      value: createStarterFiles,
                      onChanged: creating ? null : (v) => setDialogState(() => createStarterFiles = v),
                    ),
                    if (createStarterFiles) ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('README.md'),
                            selected: includeReadme,
                            onSelected: creating ? null : (v) => setDialogState(() => includeReadme = v),
                          ),
                          FilterChip(
                            label: const Text('.gitignore'),
                            selected: includeGitignore,
                            onSelected: creating ? null : (v) => setDialogState(() => includeGitignore = v),
                          ),
                          FilterChip(
                            label: const Text('AGENTS.md'),
                            selected: includeAgentFile,
                            onSelected: creating ? null : (v) => setDialogState(() => includeAgentFile = v),
                          ),
                        ],
                      ),
                      if (attachExistingRepo)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Разрешить перезапись уже существующих README.md / .gitignore / AGENTS.md'),
                          value: overwriteExistingStarterFiles,
                          onChanged: creating
                              ? null
                              : (bool? v) => setDialogState(() => overwriteExistingStarterFiles = v ?? false),
                        ),
                    ],
                    if (!attachExistingRepo) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Автоматически создать репозиторий на GitHub'),
                        subtitle: const Text('Создаёт удалённый репозиторий, привязывает origin и сохраняет URL в проекте.'),
                        value: createRemoteRepo,
                        onChanged: creating ? null : (v) => setDialogState(() => createRemoteRepo = v),
                      ),
                      if (createRemoteRepo) ...[
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: const <ButtonSegment<bool>>[
                            ButtonSegment<bool>(
                              value: true,
                              icon: Icon(Icons.lock_outline, size: 16),
                              label: Text('Приватный'),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              icon: Icon(Icons.public, size: 16),
                              label: Text('Публичный'),
                            ),
                          ],
                          selected: <bool>{isPrivateRepo},
                          onSelectionChanged: creating
                              ? null
                              : (Set<bool> next) {
                                  if (next.isNotEmpty) {
                                    setDialogState(() => isPrivateRepo = next.first);
                                  }
                                },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: repoNameController,
                                onChanged: (_) => repoNameWasEdited = true,
                                decoration: const InputDecoration(
                                  labelText: 'Имя репозитория на GitHub',
                                  hintText: 'my-project',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 140,
                              child: TextField(
                                controller: branchController,
                                decoration: const InputDecoration(
                                  labelText: 'Ветка',
                                  hintText: 'main',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: ownerController,
                                decoration: const InputDecoration(
                                  labelText: 'Владелец / организация (необязательно)',
                                  hintText: 'Например: sasha89sp',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: tokenController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'GitHub Token (или через gh CLI)',
                                  hintText: 'ghp_... / github_pat_...',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('Сделать первый коммит и отправить файлы в репозиторий'),
                          value: pushInitialCommit,
                          onChanged: creating
                              ? null
                              : (bool? v) => setDialogState(() => pushInitialCommit = v ?? true),
                        ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Автозаполнить и включить настройки авто-деплоя'),
                      subtitle: const Text('Включает мониторинг «Загрузок», фильтр по названию и авто-синхронизацию при расхождении веток.'),
                      value: autoEnableDeploy,
                      onChanged: creating
                          ? null
                          : (bool v) => setDialogState(() => autoEnableDeploy = v),
                    ),
                    if (autoEnableDeploy) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: zipFilterController,
                        onChanged: (_) => zipFilterWasEdited = true,
                        decoration: const InputDecoration(
                          labelText: 'Фильтр имени ZIP для авто-деплоя',
                          hintText: 'Подставляется автоматически из названия проекта',
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Автоматически синхронизировать ветку при отклонении push'),
                        value: autoSyncOnReject,
                        onChanged: creating
                            ? null
                            : (bool? v) => setDialogState(() => autoSyncOnReject = v ?? true),
                      ),
                    ],
                    if (dialogError.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(dialogError, style: const TextStyle(color: Color(0xFFB74444), fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: creating ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: creating ? null : () async {
                  final cleanName = nameController.text.trim();
                  if (cleanName.isEmpty) {
                    setDialogState(() => dialogError = 'Введите название проекта.');
                    return;
                  }
                  if (attachExistingRepo && existingRepoUrlController.text.trim().isEmpty) {
                    setDialogState(() => dialogError = 'Укажите URL готового репозитория.');
                    return;
                  }
                  setDialogState(() { creating = true; dialogError = ''; });
                  try {
                    await provider.createProject(
                      name: cleanName,
                      description: descriptionController.text.trim(),
                      outputPath: outputController.text.trim(),
                      templateId: templateId,
                      attachExistingRepo: attachExistingRepo,
                      existingRepoUrl: existingRepoUrlController.text.trim(),
                      cloneIfEmpty: cloneIfEmpty,
                      overwriteExistingStarterFiles: overwriteExistingStarterFiles,
                      createRemoteRepo: createRemoteRepo,
                      privateRepo: isPrivateRepo,
                      repoName: repoNameController.text.trim(),
                      githubOwnerOverride: ownerController.text.trim(),
                      githubTokenOverride: tokenController.text.trim(),
                      gitBranch: branchController.text.trim(),
                      createStarterFiles: createStarterFiles,
                      includeReadme: includeReadme,
                      includeGitignore: includeGitignore,
                      includeAgentFile: includeAgentFile,
                      pushInitialCommit: pushInitialCommit,
                      autoEnableDeploy: autoEnableDeploy,
                      autoSyncOnReject: autoSyncOnReject,
                      zipNameFilterOverride: zipFilterController.text.trim(),
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  } catch (error) {
                    setDialogState(() {
                      dialogError = error.toString().replaceFirst('Bad state: ', '');
                      creating = false;
                    });
                  }
                },
                child: creating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(attachExistingRepo ? 'Подключить проект' : 'Создать проект'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  descriptionController.dispose();
  outputController.dispose();
  repoNameController.dispose();
  existingRepoUrlController.dispose();
  ownerController.dispose();
  tokenController.dispose();
  branchController.dispose();
  zipFilterController.dispose();
}

Future<void> openFolderInExplorer(BuildContext context, String folderPath) async {
  try {
    final dir = Directory(folderPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    if (Platform.isWindows) {
      await Process.run('explorer.exe', <String>[p.normalize(dir.absolute.path)]);
    } else if (Platform.isMacOS) {
      await Process.run('open', <String>[dir.absolute.path]);
    } else {
      await Process.run('xdg-open', <String>[dir.absolute.path]);
    }
  } catch (error) {
    if (context.mounted) {
      _showProjDialogSnack(context, 'Не удалось открыть папку: $error');
    }
  }
}

void _showProjDialogSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
