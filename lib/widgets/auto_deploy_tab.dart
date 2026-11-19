import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/code_project.dart';
import '../providers/project_provider.dart';
import 'section_header.dart';

class AutoDeployTab extends StatefulWidget {
  const AutoDeployTab({super.key});

  @override
  State<AutoDeployTab> createState() => _AutoDeployTabState();
}

class _AutoDeployTabState extends State<AutoDeployTab> {
  final TextEditingController _watchPathController = TextEditingController();
  final TextEditingController _repoUrlController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();

  String? _loadedProjectId;
  bool _autoDeployEnabled = false;
  bool _deleteZipAfterDeploy = false;
  bool _cleanBeforeExtract = false;

  @override
  void dispose() {
    _watchPathController.dispose();
    _repoUrlController.dispose();
    _branchController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _syncFromProvider(ProjectProvider provider, CodeProject project) {
    if (_watchPathController.text.isEmpty) {
      _watchPathController.text = provider.downloadsWatchPath;
    }
    if (_loadedProjectId != project.id) {
      _loadedProjectId = project.id;
      _repoUrlController.text = project.gitRepoUrl;
      _branchController.text = project.gitBranch;
      _filterController.text = project.zipNameFilter;
      _autoDeployEnabled = project.autoDeployEnabled;
      _deleteZipAfterDeploy = project.deleteZipAfterDeploy;
      _cleanBeforeExtract = project.cleanBeforeExtract;
    }
  }

  Future<void> _pickWatchDirectory(ProjectProvider provider) async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку «Загрузки» для перехвата ZIP',
      initialDirectory: provider.downloadsWatchPath,
    );
    if (selected == null || selected.trim().isEmpty) return;
    _watchPathController.text = selected;
    await provider.setDownloadsWatcher(path: selected);
  }

  Future<void> _pickAndDeployZip(ProjectProvider provider) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Выберите ZIP-архив проекта для распаковки и push',
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null || path.isEmpty) return;
    await provider.deployZipArchive(path, fromWatcher: false);
  }

  Future<void> _saveProjectSettings(ProjectProvider provider) async {
    await provider.updateCurrentProjectDeploySettings(
      gitRepoUrl: _repoUrlController.text,
      gitBranch: _branchController.text,
      autoDeployEnabled: _autoDeployEnabled,
      zipNameFilter: _filterController.text,
      deleteZipAfterDeploy: _deleteZipAfterDeploy,
      cleanBeforeExtract: _cleanBeforeExtract,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки авто-деплоя сохранены.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = provider.currentProject;
    if (project == null) {
      return const Center(child: Text('Выберите проект'));
    }
    _syncFromProvider(provider, project);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Авто-деплой ZIP -> GitHub',
            subtitle:
                'Перехват скачанного .zip из папки «Загрузки» или через «Открыть с помощью -> code_bridge_mini.exe», распаковка в папку проекта и автоматический git push.',
            trailing: FilledButton.icon(
              onPressed: provider.isDeploying ? null : () => _pickAndDeployZip(provider),
              icon: provider.isDeploying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.archive_outlined, size: 18),
              label: Text(provider.isDeploying ? 'Деплой...' : 'Выбрать ZIP и залить'),
            ),
          ),
          const SizedBox(height: 18),
          _CardSection(
            title: '1. Фоновый перехват папки «Загрузки»',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Следить за новыми ZIP-архивами в фоне'),
                  subtitle: const Text(
                    'Нажимаете «Скачать» в браузере -> программа ждёт завершения загрузки, проверяет pubspec.yaml / AGENTS.md, распаковывает и пушит в GitHub.',
                  ),
                  value: provider.downloadsWatcherEnabled,
                  onChanged: (bool value) async {
                    await provider.setDownloadsWatcher(
                      path: _watchPathController.text,
                      enabled: value,
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _watchPathController,
                        decoration: const InputDecoration(
                          labelText: 'Папка загрузок',
                          hintText: r'C:\Users\User\Downloads',
                        ),
                        onSubmitted: (String value) =>
                            provider.setDownloadsWatcher(path: value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _pickWatchDirectory(provider),
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: const Text('Выбрать'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CardSection(
            title: '2. Настройки GitHub для проекта «${project.name}»',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Разрешить авто-деплой для этого проекта'),
                  subtitle: const Text(
                    'Принимать новые ZIP-архивы из «Загрузок» именно в этот проект.',
                  ),
                  value: _autoDeployEnabled,
                  onChanged: (bool value) => setState(() => _autoDeployEnabled = value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _repoUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Git Remote URL (origin)',
                          hintText: 'https://github.com/username/repo.git (необязательно, если origin уже настроен)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _branchController,
                        decoration: const InputDecoration(
                          labelText: 'Ветка',
                          hintText: 'main',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _filterController,
                  decoration: const InputDecoration(
                    labelText: 'Фильтр имени ZIP (необязательно)',
                    hintText: 'Например: CodeBridge — пустое поле принимает любой ZIP с pubspec.yaml или AGENTS.md',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Очищать старые файлы перед распаковкой (папка .git сохраняется)'),
                  value: _cleanBeforeExtract,
                  onChanged: (bool? value) =>
                      setState(() => _cleanBeforeExtract = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Удалять исходный ZIP из «Загрузок» после успешного push'),
                  value: _deleteZipAfterDeploy,
                  onChanged: (bool? value) =>
                      setState(() => _deleteZipAfterDeploy = value ?? false),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _saveProjectSettings(provider),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Сохранить настройки'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => provider.checkCurrentProjectGit(),
                      icon: const Icon(Icons.verified_outlined, size: 18),
                      label: const Text('Проверить Git'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CardSection(
            title: '3. Журнал авто-деплоя',
            trailing: TextButton(
              onPressed: provider.deployLogs.isEmpty ? null : provider.clearDeployLogs,
              child: const Text('Очистить'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (provider.lastDeployStatus != null) ...[
                  Text(
                    provider.lastDeployStatus!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF202A40),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: provider.deployLogs.isEmpty
                      ? const Center(
                          child: Text(
                            'Событий пока нет. Включите мониторинг «Загрузок», выберите ZIP вручную или откройте .zip через code_bridge_mini.exe.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : SingleChildScrollView(
                          reverse: true,
                          child: SelectableText(
                            provider.deployLogs.join('\n'),
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 12.5,
                              height: 1.45,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
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

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202A40),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
