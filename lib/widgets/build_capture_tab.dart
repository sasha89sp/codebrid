import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/code_project.dart';
import '../providers/project_provider.dart';
import 'section_header.dart';

class BuildCaptureTab extends StatefulWidget {
  const BuildCaptureTab({super.key});

  @override
  State<BuildCaptureTab> createState() => _BuildCaptureTabState();
}

class _BuildCaptureTabState extends State<BuildCaptureTab> {
  final TextEditingController _targetDirController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
  final TextEditingController _preservedController = TextEditingController();

  String? _loadedProjectId;
  bool _buildCaptureEnabled = false;
  bool _buildAskTargetBeforeExtract = false;
  bool _buildTakeAllPublicBuilds = true;
  bool _buildOverlayPrevious = true;
  bool _buildClearBeforeApply = false;
  String? _shownPendingZipPath;

  @override
  void dispose() {
    _targetDirController.dispose();
    _filterController.dispose();
    _preservedController.dispose();
    super.dispose();
  }

  void _syncFromProject(CodeProject project) {
    if (_loadedProjectId == project.id) return;
    _loadedProjectId = project.id;
    _buildCaptureEnabled = project.buildCaptureEnabled;
    _buildAskTargetBeforeExtract = project.buildAskTargetBeforeExtract;
    _buildTakeAllPublicBuilds = project.buildTakeAllPublicBuilds;
    _buildOverlayPrevious = project.buildOverlayPrevious;
    _buildClearBeforeApply = project.buildClearBeforeApply;
    _targetDirController.text = project.buildTargetDirectory;
    _filterController.text = project.buildZipFilter;
    _preservedController.text = project.buildPreservedFiles;
  }

  Future<void> _saveSettings(ProjectProvider provider) async {
    await provider.updateCurrentProjectBuildSettings(
      buildCaptureEnabled: _buildCaptureEnabled,
      buildAskTargetBeforeExtract: _buildAskTargetBeforeExtract,
      buildTargetDirectory: _targetDirController.text,
      buildZipFilter: _filterController.text,
      buildPreservedFiles: _preservedController.text,
      buildTakeAllPublicBuilds: _buildTakeAllPublicBuilds,
      buildOverlayPrevious: _buildOverlayPrevious,
      buildClearBeforeApply: _buildClearBeforeApply,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки распаковки сборок сохранены.')),
    );
  }

  Future<void> _pickTargetFolder() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку для сохранения и сборки версий проекта',
      initialDirectory: _targetDirController.text.trim().isEmpty
          ? null
          : _targetDirController.text.trim(),
    );
    if (selected == null || selected.trim().isEmpty || !mounted) return;
    setState(() => _targetDirController.text = selected);
  }

  Future<void> _pickAndApplyZip(ProjectProvider provider) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Выберите архив скомпилированного проекта',
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty) return;
    await provider.applyBuildArchive(
      path,
      customTargetDirectory: _targetDirController.text.trim().isEmpty
          ? null
          : _targetDirController.text.trim(),
    );
  }

  void _maybeShowPendingDialog(BuildContext context, ProjectProvider provider) {
    final pendingZip = provider.pendingBuildZipPath;
    if (pendingZip == null || _shownPendingZipPath == pendingZip) return;
    _shownPendingZipPath = pendingZip;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted || provider.pendingBuildZipPath != pendingZip) return;
      final dirCtrl = TextEditingController(
        text: provider.pendingBuildSuggestedDir ?? '',
      );
      final fileName = pendingZip.split(RegExp(r'[/\\]')).last;
      final confirmedPath = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setLocalState) {
              return AlertDialog(
                title: const Text('Перехвачен архив сборки'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Файл: $fileName',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Старая версия из current будет сохранена в _history, а поверх неё накопится новый архив.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF5C687D)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dirCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Папка назначения сборок',
                                hintText: 'По умолчанию data/builds/<имя_архива>',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Выбрать папку',
                            onPressed: () async {
                              final picked = await FilePicker.platform.getDirectoryPath(
                                dialogTitle: 'Выберите папку для распаковки сборки',
                                initialDirectory:
                                    dirCtrl.text.trim().isEmpty ? null : dirCtrl.text.trim(),
                              );
                              if (picked != null && picked.trim().isNotEmpty) {
                                setLocalState(() => dirCtrl.text = picked);
                              }
                            },
                            icon: const Icon(Icons.folder_open),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(null),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(dirCtrl.text.trim()),
                    child: const Text('Сохранить старую и собрать новую'),
                  ),
                ],
              );
            },
          );
        },
      );
      dirCtrl.dispose();
      _shownPendingZipPath = null;
      if (!context.mounted) return;
      if (confirmedPath == null) {
        provider.dismissPendingBuild();
      } else {
        await provider.confirmPendingBuild(
          chosenTargetDirectory: confirmedPath.isEmpty ? null : confirmedPath,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = provider.currentProject;
    if (project == null) {
      return const Center(child: Text('Выберите проект'));
    }
    _syncFromProject(project);
    _maybeShowPendingDialog(context, provider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Распаковка после компиляции',
            subtitle:
                'Отдельный раздел для готовых скомпилированных архивов: сохранение старой версии в _history, перенос настроек оверлеем и сборка новой версии в current.',
            trailing: FilledButton.icon(
              onPressed: provider.isDeploying ? null : () => _pickAndApplyZip(provider),
              icon: provider.isDeploying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.layers_outlined, size: 18),
              label: Text(provider.isDeploying ? 'Сборка...' : 'Выбрать ZIP сборки'),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE4E9F2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Перехватывать готовый архив сборки из «Загрузок»'),
                  subtitle: const Text(
                    'Сохраняет текущую версию в _history, а поверх неё накатывает новый архив, перенося настройки в current.',
                  ),
                  value: _buildCaptureEnabled,
                  onChanged: (bool value) => setState(() => _buildCaptureEnabled = value),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Спрашивать / давать выбрать папку при каждом перехвате архива'),
                  value: _buildAskTargetBeforeExtract,
                  onChanged: (bool? value) =>
                      setState(() => _buildAskTargetBeforeExtract = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Публичные сборки: брать все подходящие ZIP-архивы без отсева по фильтру'),
                  value: _buildTakeAllPublicBuilds,
                  onChanged: (bool? value) =>
                      setState(() => _buildTakeAllPublicBuilds = value ?? true),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Сохранять оверлей старой версии поверх (перенос настроек и файлов)'),
                  value: _buildOverlayPrevious,
                  onChanged: (bool? value) =>
                      setState(() => _buildOverlayPrevious = value ?? true),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Очищать перед сборкой (собирать current только из нового архива)'),
                  value: _buildClearBeforeApply,
                  onChanged: (bool? value) =>
                      setState(() => _buildClearBeforeApply = value ?? false),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _targetDirController,
                        decoration: const InputDecoration(
                          labelText: 'Папка для сборок по умолчанию (необязательно)',
                          hintText: r'По умолчанию data/builds/<имя_архива> (внутри: _history и current)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _pickTargetFolder,
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: const Text('Выбрать'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _filterController,
                        decoration: const InputDecoration(
                          labelText: 'Фильтр имени архива сборки',
                          hintText: 'Например: _rel или rocketdock_windows',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _preservedController,
                        decoration: const InputDecoration(
                          labelText: 'Не перезаписывать из нового ZIP (через запятую)',
                          hintText: 'Например: Settings.ini, config.json',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _saveSettings(provider),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Сохранить настройки сборки'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
