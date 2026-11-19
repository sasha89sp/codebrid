import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/agent_template_item.dart';
import '../models/code_project.dart';
import '../models/generated_file.dart';
import '../providers/project_provider.dart';
import '../services/app_version.dart';
import '../services/backup_service.dart';
import '../services/build_bundle_service.dart';
import '../services/files_to_prompt.dart';
import '../widgets/auto_deploy_tab.dart';
import '../widgets/build_capture_tab.dart';
import '../widgets/section_header.dart';

Future<void> _openFolder(BuildContext context, String folderPath) async {
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
    if (!context.mounted) return;
    _showSnack(context, 'Не удалось открыть папку: $error');
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.code_rounded, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 11),
                const Text('CodeBridge Mini', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                const Text(AppVersion.currentVersion, style: TextStyle(color: Color(0xFF8B93A4), fontSize: 12)),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () => _showFilesToPromptDialog(context),
                icon: const Icon(Icons.code_rounded, size: 18),
                label: const Text('Файлы → текст для ИИ'),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => _showAboutDialog(context, context.read<ProjectProvider>()),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: const Text('О программе'),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Папка программы',
                onPressed: () => _openFolder(context, provider.storage.applicationDirectory),
                icon: const Icon(Icons.folder_open_outlined),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    _ProjectSidebar(provider: provider),
                    const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE7EAF1)),
                    Expanded(
                      child: provider.currentProject == null
                          ? const _WelcomePanel()
                          : _ProjectWorkspace(key: ValueKey(provider.currentProject!.id)),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ProjectSidebar extends StatelessWidget {
  const _ProjectSidebar({required this.provider});

  final ProjectProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 276,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: provider.isWorking ? null : () => _showCreateProjectDialog(context, provider),
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Новый проект'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 25),
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 10),
            child: Text('МОИ ПРОЕКТЫ', style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: Color(0xFF939BAD))),
          ),
          Expanded(
            child: provider.projects.isEmpty
                ? const Center(child: Text('Пока нет проектов', style: TextStyle(color: Color(0xFF929AAC))))
                : ListView.separated(
                    itemCount: provider.projects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final project = provider.projects[index];
                      final selected = provider.currentProject?.id == project.id;
                      return _ProjectTile(
                        project: project,
                        selected: selected,
                        onTap: () => provider.selectProject(project),
                      );
                    },
                  ),
          ),
          const Divider(color: Color(0xFFE7EAF1)),
          const Row(
            children: [
              Icon(Icons.usb_rounded, size: 17, color: Color(0xFF78849A)),
              SizedBox(width: 8),
              Expanded(child: Text('Портативный режим', style: TextStyle(fontSize: 12, color: Color(0xFF78849A)))),
              Icon(Icons.check_circle, size: 16, color: Color(0xFF31A477)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project, required this.selected, required this.onTap});

  final CodeProject project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEEF1FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.folder_rounded, size: 19, color: selected ? Theme.of(context).colorScheme.primary : const Color(0xFF929BAD)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: const Color(0xFF273149))),
                    const SizedBox(height: 3),
                    Text(_formatDate(project.createdAt), style: const TextStyle(fontSize: 11, color: Color(0xFF8C95A7))),
                  ],
                ),
              ),
              if (selected) Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(color: const Color(0xFFEEF1FF), borderRadius: BorderRadius.circular(24)),
              child: Icon(Icons.integration_instructions_rounded, size: 42, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 22),
            const Text('Создайте первый проект', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: Color(0xFF202A40))),
            const SizedBox(height: 10),
            const Text('CodeBridge подготовит AGENT.md, примет ответ любой нейросети и разложит код по файлам Flutter-проекта.', textAlign: TextAlign.center, style: TextStyle(height: 1.55, color: Color(0xFF737E92))),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: () => _showCreateProjectDialog(context, context.read<ProjectProvider>()), icon: const Icon(Icons.add), label: const Text('Создать проект')),
          ],
        ),
      ),
    );
  }
}

class _ProjectWorkspace extends StatefulWidget {
  const _ProjectWorkspace({super.key});

  @override
  State<_ProjectWorkspace> createState() => _ProjectWorkspaceState();
}

class _ProjectWorkspaceState extends State<_ProjectWorkspace> with TickerProviderStateMixin {
  TabController? _tabController;
  String _signature = '';
  int _activeIndex = 0;

  void _ensureController(List<String> order) {
    final sig = order.join(',');
    if (_tabController != null && _signature == sig) return;
    final prevIndex = (_tabController?.index ?? _activeIndex).clamp(0, order.length - 1);
    _tabController?.dispose();
    _signature = sig;
    _activeIndex = prevIndex;
    _tabController = TabController(
      length: order.length,
      vsync: this,
      initialIndex: prevIndex,
    )..addListener(() {
        if (_tabController != null && _activeIndex != _tabController!.index) {
          setState(() => _activeIndex = _tabController!.index);
        }
      });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  IconData _iconForTab(String id) {
    switch (id) {
      case 'agent':
        return Icons.description_outlined;
      case 'import':
        return Icons.content_paste_go_rounded;
      case 'files':
        return Icons.folder_copy_outlined;
      case 'build_capture':
        return Icons.layers_outlined;
      case 'auto_deploy':
      default:
        return Icons.rocket_launch_outlined;
    }
  }

  String _labelForTab(String id) {
    switch (id) {
      case 'agent':
        return 'Инструкция';
      case 'import':
        return 'Ответ ИИ';
      case 'files':
        return 'Файлы проекта';
      case 'build_capture':
        return 'Распаковка сборок';
      case 'auto_deploy':
      default:
        return 'Авто-деплой';
    }
  }

  Widget _bodyForTab(String id) {
    switch (id) {
      case 'agent':
        return const _AgentTab();
      case 'import':
        return const _ImportTab();
      case 'files':
        return const _FilesTab();
      case 'build_capture':
        return const BuildCaptureTab();
      case 'auto_deploy':
      default:
        return const AutoDeployTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = provider.currentProject!;
    final order = provider.tabOrder;
    _ensureController(order);
    final controller = _tabController!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            children: [
                              Flexible(
                                child: Text(
                                  project.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: Color(0xFF202A40)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Переименовать проект',
                                onPressed: () => _showRenameProjectDialog(context, context.read<ProjectProvider>(), project),
                                icon: const Icon(Icons.edit_outlined, size: 19),
                              ),
                            ],
                          ),
                        const SizedBox(height: 5),
                        Text(project.description.isEmpty ? 'Описание задачи не задано' : project.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF7C879A))),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openFolder(context, project.outputPath),
                        icon: const Icon(Icons.folder_open_outlined, size: 17),
                        label: const Text('Открыть папку'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          final buildDir = BuildBundleService.currentBuildDirectory(
                            dataDirectory: provider.storage.dataDirectory,
                            buildTargetDirectory: project.buildTargetDirectory,
                            packageName: project.packageName,
                            lastArchiveName: provider.lastBuildArchiveName,
                          );
                          _openFolder(context, buildDir);
                        },
                        icon: const Icon(Icons.inventory_2_outlined, size: 17),
                        label: const Text('Открыть сборку'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 62,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: order.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 28),
                        itemBuilder: (context, index) {
                          final tabId = order[index];
                          final selected = controller.index == index;
                          return DragTarget<int>(
                            onWillAcceptWithDetails: (details) => details.data != index,
                            onAcceptWithDetails: (details) {
                              final fromIdx = details.data;
                              final toIdx = index > fromIdx ? index + 1 : index;
                              provider.reorderTabs(fromIdx, toIdx);
                            },
                            builder: (context, candidateData, rejectedData) {
                              final isHoverTarget = candidateData.isNotEmpty;
                              return LongPressDraggable<int>(
                                data: index,
                                feedback: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_iconForTab(tabId), size: 18, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 8),
                                        Text(
                                          _labelForTab(tabId),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.4,
                                  child: _WorkspaceTabItem(
                                    icon: _iconForTab(tabId),
                                    label: _labelForTab(tabId),
                                    selected: selected,
                                    isHoverTarget: false,
                                    onTap: () => controller.animateTo(index),
                                  ),
                                ),
                                child: _WorkspaceTabItem(
                                  icon: _iconForTab(tabId),
                                  label: _labelForTab(tabId),
                                  selected: selected,
                                  isHoverTarget: isHoverTarget,
                                  onTap: () => controller.animateTo(index),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Переместить активную вкладку влево',
                    onPressed: controller.index > 0
                        ? () => provider.reorderTabs(controller.index, controller.index - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Переместить активную вкладку вправо',
                    onPressed: controller.index < order.length - 1
                        ? () => provider.reorderTabs(controller.index, controller.index + 2)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: order.map(_bodyForTab).toList(),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceTabItem extends StatelessWidget {
  const _WorkspaceTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isHoverTarget,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool isHoverTarget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final fgColor = selected ? activeColor : const Color(0xFF5A657A);

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isHoverTarget ? activeColor.withOpacity(0.06) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: selected ? activeColor : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fgColor),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentTab extends StatefulWidget {
  const _AgentTab();

  @override
  State<_AgentTab> createState() => _AgentTabState();
}

class _AgentTabState extends State<_AgentTab> {
  final TextEditingController _agentController = TextEditingController();
  String? _loadedProjectId;
  String _lastSyncedContent = '';
  bool _hasDirtyChanges = false;

  @override
  void dispose() {
    _agentController.dispose();
    super.dispose();
  }

  void _syncAgentEditor(ProjectProvider provider) {
    final projectId = provider.currentProject?.id;
    final incoming = provider.agentContent;
    final projectChanged = projectId != _loadedProjectId;
    final externalChanged = incoming != _lastSyncedContent;

    if (projectChanged || (externalChanged && !_hasDirtyChanges)) {
      _loadedProjectId = projectId;
      _lastSyncedContent = incoming;
      _hasDirtyChanges = false;
      _agentController.value = TextEditingValue(
        text: incoming,
        selection: TextSelection.collapsed(
          offset: incoming.length.clamp(0, incoming.length),
        ),
      );
    } else if (externalChanged && _hasDirtyChanges) {
      _lastSyncedContent = incoming;
    }
  }

  Future<void> _saveManualAgent(BuildContext context, ProjectProvider provider) async {
    try {
      await provider.saveAgentContent(_agentController.text);
      if (!mounted) return;
      _lastSyncedContent = provider.agentContent;
      setState(() => _hasDirtyChanges = false);
      if (!context.mounted) return;
      _showSnack(context, 'Изменения в agent.md сохранены.');
    } catch (error) {
      if (!mounted || !context.mounted) return;
      _showSnack(context, 'Не удалось сохранить agent.md: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    _syncAgentEditor(provider);
    final availableTemplates = provider.templates;
    final selectedId = availableTemplates.any((item) => item.id == provider.selectedTemplateId)
        ? provider.selectedTemplateId
        : (availableTemplates.isEmpty ? null : availableTemplates.first.id);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Инструкция AGENT.md',
            subtitle: 'Редактируйте инструкцию вручную, выбирайте шаблон и отправляйте AGENT.md в любую нейросеть.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<String>(
                  value: selectedId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Шаблон по умолчанию'),
                  items: availableTemplates.map((item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: provider.isWorking || selectedId == null
                      ? null
                      : (value) { if (value != null) provider.selectTemplate(value); },
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showTemplateManager(context, provider),
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Управление шаблонами'),
              ),
              OutlinedButton.icon(
                onPressed: provider.isWorking ? null : () async {
                  try {
                    await provider.regenerateAgent();
                    if (context.mounted) _showSnack(context, 'AGENT.md обновлён из выбранного шаблона.');
                  } catch (error) {
                    if (context.mounted) _showSnack(context, 'Не удалось обновить AGENT.md: $error');
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Обновить из шаблона'),
              ),
              OutlinedButton.icon(
                onPressed: provider.isWorking || !_hasDirtyChanges
                    ? null
                    : () => _saveManualAgent(context, provider),
                icon: const Icon(Icons.save_outlined, size: 17),
                label: Text(_hasDirtyChanges ? 'Сохранить правки*' : 'Сохранить правки'),
              ),
              FilledButton.icon(
                onPressed: _agentController.text.isEmpty ? null : () async {
                  await Clipboard.setData(ClipboardData(text: _agentController.text));
                  if (!context.mounted) return;
                  _showSnack(context, 'AGENT.md скопирован в буфер обмена.');
                },
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: const Text('Копировать AGENT.md'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TextField(
              controller: _agentController,
              expands: true,
              minLines: null,
              maxLines: null,
              readOnly: false,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 12.5,
                height: 1.55,
                color: Color(0xFF364158),
              ),
              onChanged: (_) {
                if (!_hasDirtyChanges) {
                  setState(() => _hasDirtyChanges = true);
                }
              },
              decoration: const InputDecoration(
                hintText: 'Введите или отредактируйте инструкцию agent.md...',
                hintStyle: TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Color(0xFF9AA3B3)),
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Каждый проект хранит собственную копию agent.md. Ручные правки сохраняются кнопкой «Сохранить правки»; изменение шаблона не меняет уже созданные инструкции автоматически.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF8A94A6)),
          ),
        ],
      ),
    );
  }
}
class _ImportTab extends StatefulWidget {
  const _ImportTab();

  @override
  State<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<_ImportTab> {
  final TextEditingController _responseController = TextEditingController();

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Импорт ответа ИИ',
            subtitle: 'Вставьте полный ответ Qwen, ChatGPT, DeepSeek, Claude или другой нейросети — формат определяется автоматически.',
            trailing: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (!mounted) return;
                    if (data?.text != null) {
                      provider.clearPreview();
                      _responseController.text = data!.text!;
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.content_paste_rounded, size: 17),
                  label: const Text('Вставить'),
                ),
                FilledButton.icon(
                  onPressed: provider.isWorking || _responseController.text.trim().isEmpty
                      ? null
                      : () => provider.prepareResponse(_responseController.text),
                  icon: const Icon(Icons.document_scanner_outlined, size: 17),
                  label: const Text('Распознать файлы'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _responseController,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5, height: 1.5),
              onChanged: (_) {
                setState(() {});
                if (provider.previewFiles.isNotEmpty) provider.clearPreview();
              },
              decoration: const InputDecoration(
                hintText: 'Вставьте сюда полный ответ нейросети.\n\nПоддерживаются: заголовки ## lib/main.dart, строки «Файл: lib/main.dart», блоки ```dart и маркеры <<<FILE: ...>>>.',
                hintStyle: TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Color(0xFF9AA3B3)),
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 12),
            _MessageBanner(message: provider.errorMessage!, isError: true),
          ],
          if (provider.parserWarnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final warning in provider.parserWarnings.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: _MessageBanner(message: warning, isError: false),
              ),
          ],
          if (provider.previewFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE5E9F1)), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF24966B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Распознано: ${provider.previewFiles.length} · к записи: ${provider.selectedPreviewCount}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      TextButton(onPressed: provider.clearPreview, child: const Text('Сбросить')),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        onPressed: provider.isWorking || provider.selectedPreviewCount == 0
                            ? null
                            : () => _writeFiles(context, provider),
                        icon: const Icon(Icons.save_alt_rounded, size: 17),
                        label: const Text('Создать файлы'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 132,
                    child: ListView.builder(
                      itemCount: provider.previewFiles.length,
                      itemBuilder: (context, index) {
                        final file = provider.previewFiles[index];
                        return InkWell(
                          onTap: () => _showGeneratedFile(context, file),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: file.selected,
                                  onChanged: (value) => provider.togglePreviewFile(index, value ?? false),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const Icon(Icons.insert_drive_file_outlined, size: 16, color: Color(0xFF7F8AA0)),
                                const SizedBox(width: 7),
                                Expanded(child: Text(file.path, style: const TextStyle(fontFamily: 'Consolas', fontSize: 12), overflow: TextOverflow.ellipsis)),
                                if (file.isFragment)
                                  const Chip(label: Text('Фрагмент'), visualDensity: VisualDensity.compact, labelStyle: TextStyle(fontSize: 10)),
                                if (file.note != null)
                                  const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.info_outline, size: 16, color: Color(0xFFB7791F))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Нажмите на имя файла для просмотра содержимого. Неотмеченные фрагменты не будут записаны.', style: TextStyle(fontSize: 11, color: Color(0xFF8791A3))),
                ],
              ),
            ),
          ],
          if (provider.infoMessage != null && provider.previewFiles.isEmpty) ...[
            const SizedBox(height: 10),
            _MessageBanner(message: provider.infoMessage!, isError: false),
          ],
          const SizedBox(height: 9),
          Text('Файлы будут записаны в: ${provider.currentProject?.outputPath ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF8791A3))),
        ],
      ),
    );
  }
}

Future<void> _showGeneratedFile(BuildContext context, GeneratedFile file) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(children: [const Icon(Icons.code_rounded), const SizedBox(width: 9), Expanded(child: Text(file.path, overflow: TextOverflow.ellipsis))]),
      content: SizedBox(
        width: 760,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (file.note != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(file.note!, style: const TextStyle(color: Color(0xFF9A681B), fontSize: 12))),
            Expanded(child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF6F7FA), borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(child: SelectableText(file.content, style: const TextStyle(fontFamily: 'Consolas', fontSize: 12))),
            )),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Закрыть'))],
    ),
  );
}

class _FilesTab extends StatelessWidget {
  const _FilesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = provider.currentProject!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Файлы проекта',
            subtitle: project.outputPath,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(tooltip: 'Обновить', onPressed: provider.refreshOutputFiles, icon: const Icon(Icons.refresh_rounded)),
                OutlinedButton.icon(onPressed: () => _openFolder(context, project.outputPath), icon: const Icon(Icons.folder_open_outlined, size: 17), label: const Text('Открыть в проводнике')),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE5E9F1)), borderRadius: BorderRadius.circular(14)),
              child: provider.outputFiles.isEmpty
                  ? const Center(child: Text('Файлы ещё не созданы. Вставьте ответ нейросети на вкладке «Ответ ИИ».', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF808B9F))))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: provider.outputFiles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F2F6)),
                      itemBuilder: (context, index) {
                        final file = provider.outputFiles[index] as File;
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.description_outlined, color: Color(0xFF7283B1)),
                          title: Text(p.relative(file.path, from: project.outputPath), style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5)),
                          subtitle: Text(_fileSize(file), style: const TextStyle(fontSize: 11, color: Color(0xFF8B95A7))),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFB74444) : const Color(0xFF267B5D);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: isError ? const Color(0xFFFFF1F0) : const Color(0xFFECF8F2), borderRadius: BorderRadius.circular(9)),
      child: Row(children: [Icon(isError ? Icons.error_outline : Icons.info_outline, size: 17, color: color), const SizedBox(width: 8), Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: color))) ]),
    );
  }
}

Future<void> _showFilesToPromptDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _FilesToPromptDialog(),
  );
}

class _FilesToPromptDialog extends StatefulWidget {
  const _FilesToPromptDialog();

  @override
  State<_FilesToPromptDialog> createState() => _FilesToPromptDialogState();
}

class _FilesToPromptDialogState extends State<_FilesToPromptDialog> {
  final TextEditingController _textController = TextEditingController();
  bool _working = false;
  String _status = 'Выберите отдельные файлы или папку проекта.';
  int _included = 0;
  List<String> _skipped = <String>[];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles({required bool directory}) async {
    try {
      List<String>? selectedFiles;
      String? selectedDirectory;
      if (directory) {
        selectedDirectory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Выберите папку проекта',
        );
        if (selectedDirectory == null) return;
      } else {
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: 'Выберите файлы для отправки нейросети',
          allowMultiple: true,
          withData: false,
          type: FileType.any,
        );
        if (result == null || result.files.isEmpty) return;
        selectedFiles = result.files.map((item) => item.path).whereType<String>().toList();
      }

      if (!mounted) return;
      setState(() {
        _working = true;
        _status = 'Читаю файлы и формирую текст…';
        _textController.clear();
        _included = 0;
        _skipped = <String>[];
      });

      final result = directory
          ? await FilesToPrompt.fromDirectory(selectedDirectory!)
          : await FilesToPrompt.fromFiles(selectedFiles!);
      if (!mounted) return;
      setState(() {
        _textController.text = result.text;
        _included = result.included;
        _skipped = result.skipped;
        _status = 'Готово: добавлено файлов — ${result.included}. Можно копировать текст или сохранить его в TXT.';
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Ошибка: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _saveText() async {
    if (_textController.text.isEmpty) return;
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить текст для ИИ',
        fileName: 'project_files_for_ai.txt',
        type: FileType.custom,
        allowedExtensions: const ['txt'],
      );
      if (path == null) return;
      await File(path).writeAsString(_textController.text, encoding: utf8, flush: true);
      if (mounted) setState(() => _status = 'Текст сохранён: $path');
    } catch (error) {
      if (mounted) setState(() => _status = 'Не удалось сохранить файл: $error');
    }
  }

  Future<void> _copyText() async {
    if (_textController.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _textController.text));
    if (mounted) setState(() => _status = 'Текст скопирован. Вставьте его в запрос к нейросети.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.code_rounded),
        SizedBox(width: 10),
        Expanded(child: Text('Файлы → текст для ИИ')),
      ]),
      content: SizedBox(
        width: 820,
        height: 610,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Выберите папку целиком или несколько файлов. Текстовые файлы объединяются с путями и маркерами <<<FILE>>>. Скрытые служебные каталоги и бинарные файлы пропускаются; лимит — 2 МБ на файл и 12 МБ на весь результат.',
              style: TextStyle(color: Color(0xFF68758B), height: 1.4),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: _working ? null : () => _loadFiles(directory: true),
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Выбрать папку'),
              ),
              OutlinedButton.icon(
                onPressed: _working ? null : () => _loadFiles(directory: false),
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('Выбрать файлы'),
              ),
              if (_textController.text.isNotEmpty)
                TextButton.icon(
                  onPressed: _working ? null : () => setState(() { _textController.clear(); _included = 0; _skipped = <String>[]; _status = 'Выберите файлы или папку проекта.'; }),
                  icon: const Icon(Icons.clear_rounded, size: 17),
                  label: const Text('Очистить'),
                ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              if (_working) ...[
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 9),
              ],
              Expanded(child: Text(_status, style: const TextStyle(fontSize: 12, color: Color(0xFF68758B)))),
              if (_included > 0) Text('Файлов: $_included', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            if (_skipped.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text('Пропущено: ${_skipped.take(5).join('; ')}${_skipped.length > 5 ? ' и ещё ${_skipped.length - 5}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9A7132))),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _textController,
                expands: true,
                minLines: null,
                maxLines: null,
                readOnly: false,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 11.5, height: 1.45),
                decoration: const InputDecoration(
                  hintText: 'Здесь появится объединённое содержимое выбранных файлов…',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _working ? null : () => Navigator.of(context).pop(), child: const Text('Закрыть')),
        OutlinedButton.icon(onPressed: _working || _textController.text.isEmpty ? null : _saveText, icon: const Icon(Icons.save_alt_rounded, size: 17), label: const Text('Сохранить TXT')),
        FilledButton.icon(onPressed: _working || _textController.text.isEmpty ? null : _copyText, icon: const Icon(Icons.copy_rounded, size: 17), label: const Text('Копировать для ИИ')),
      ],
    );
  }
}

Future<void> _showRenameProjectDialog(
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

Future<void> _showCreateProjectDialog(BuildContext context, ProjectProvider provider) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final outputController = TextEditingController();
  final repoNameController = TextEditingController();
  final ownerController = TextEditingController(text: provider.githubOwner);
  final tokenController = TextEditingController(text: provider.githubToken);
  final branchController = TextEditingController(text: 'main');

  var outputWasEdited = false;
  var repoNameWasEdited = false;
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
            if (!zipFilterWasEdited) {
              final compact = name.trim().replaceAll(RegExp(r'\s+'), '');
              if (zipFilterController.text != compact) zipFilterController.text = compact;
            }
            }
            setDialogState(() {});
          }

          final packageName = provider.packageNameFor(nameController.text);
          return AlertDialog(
            title: const Text('Новый проект'),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      minLines: 3,
                      maxLines: 5,
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
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Создать базовые файлы проекта (README.md, .gitignore, AGENTS.md)'),
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
                    ],
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
                  setDialogState(() { creating = true; dialogError = ''; });
                  try {
                    await provider.createProject(
                      name: cleanName,
                      description: descriptionController.text.trim(),
                      outputPath: outputController.text.trim(),
                      templateId: templateId,
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
                    : const Text('Создать проект'),
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
  ownerController.dispose();
  tokenController.dispose();
  branchController.dispose();
  zipFilterController.dispose();
}
Future<void> _showTemplateManager(BuildContext context, ProjectProvider provider) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TemplateManagerDialog(provider: provider),
  );
}

class _TemplateManagerDialog extends StatefulWidget {
  const _TemplateManagerDialog({required this.provider});

  final ProjectProvider provider;

  @override
  State<_TemplateManagerDialog> createState() => _TemplateManagerDialogState();
}

class _TemplateManagerDialogState extends State<_TemplateManagerDialog> {
  late List<AgentTemplateItem> _templates;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _selectedId;
  String _error = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _templates = List<AgentTemplateItem>.from(widget.provider.templates);
    if (_templates.isNotEmpty) _select(_templates.first.id);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  AgentTemplateItem? get _selected {
    for (final item in _templates) {
      if (item.id == _selectedId) return item;
    }
    return null;
  }

  void _select(String id) {
    final item = _templates.where((template) => template.id == id).toList();
    if (item.isEmpty) return;
    setState(() {
      _selectedId = id;
      _nameController.text = item.first.name;
      _contentController.text = item.first.content;
      _error = '';
    });
  }

  void _newTemplate() {
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    final template = AgentTemplateItem(
      id: id,
      name: 'Новый шаблон',
      content: '# Инструкция для {{project_name}}\n\nОписание задачи:\n{{project_description}}\n\n## Формат файлов\nДля каждого файла используй:\n\n<<<FILE: relative/path>>>\nполное содержимое\n<<<END>>>\n\n<<<END_PROJECT>>>\n',
      isBuiltIn: false,
    );
    setState(() => _templates.add(template));
    _select(id);
  }

  Future<void> _duplicateTemplate() async {
    final current = _selected;
    if (current == null) return;
    final duplicate = AgentTemplateItem(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: '${current.name} — копия',
      content: _contentController.text,
      isBuiltIn: false,
    );
    setState(() => _templates.add(duplicate));
    _select(duplicate.id);
    await _saveTemplate();
  }

  Future<void> _saveTemplate() async {
    final current = _selected;
    if (current == null) return;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Введите название шаблона.');
      return;
    }
    setState(() { _saving = true; _error = ''; });
    final updated = current.copyWith(
      name: _nameController.text.trim(),
      content: _contentController.text,
    );
    try {
      await widget.provider.saveTemplate(updated);
      if (!mounted) return;
      setState(() {
        _templates = List<AgentTemplateItem>.from(widget.provider.templates);
        _error = 'Шаблон сохранён.';
      });
      _select(updated.id);
    } catch (error) {
      if (mounted) setState(() => _error = 'Не удалось сохранить: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteTemplate() async {
    final current = _selected;
    if (current == null) return;
    if (current.isBuiltIn) {
      setState(() => _error = 'Встроенный шаблон нельзя удалить. Его можно редактировать или копировать.');
      return;
    }
    try {
      await widget.provider.deleteTemplate(current.id);
      if (!mounted) return;
      setState(() {
        _templates = List<AgentTemplateItem>.from(widget.provider.templates);
        _selectedId = _templates.isEmpty ? null : _templates.first.id;
      });
      if (_selectedId != null) {
        _select(_selectedId!);
      } else {
        _nameController.clear();
        _contentController.clear();
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Dialog(
      child: SizedBox(
        width: 980,
        height: 680,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.library_books_outlined, size: 23),
                const SizedBox(width: 10),
                const Expanded(child: Text('Библиотека шаблонов AGENT.md', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                IconButton(tooltip: 'Закрыть', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(onPressed: _newTemplate, icon: const Icon(Icons.add), label: const Text('Новый шаблон')),
                          const SizedBox(height: 7),
                          OutlinedButton.icon(onPressed: selected == null ? null : _duplicateTemplate, icon: const Icon(Icons.copy), label: const Text('Копировать')),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _templates.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final item = _templates[index];
                                return ListTile(
                                  dense: true,
                                  selected: item.id == _selectedId,
                                  selectedTileColor: const Color(0xFFEEF1FF),
                                  leading: Icon(item.isBuiltIn ? Icons.verified_outlined : Icons.description_outlined, size: 18),
                                  title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  onTap: () => _select(item.id),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    const VerticalDivider(width: 1),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Название шаблона', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextField(controller: _nameController, enabled: selected != null, decoration: const InputDecoration(hintText: 'Например, Flutter Desktop + Riverpod')),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Expanded(child: Text('Текст инструкции Markdown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                            if (selected?.isBuiltIn == true) const Chip(label: Text('Встроенный'), visualDensity: VisualDensity.compact),
                          ]),
                          const SizedBox(height: 6),
                          Expanded(
                            child: TextField(
                              controller: _contentController,
                              enabled: selected != null,
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, height: 1.4),
                              decoration: const InputDecoration(
                                hintText: 'Напишите инструкцию. Переменные: {{project_name}}, {{project_slug}}, {{project_description}}',
                                alignLabelWithHint: true,
                              ),
                            ),
                          ),
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(_error, style: TextStyle(fontSize: 12, color: _error == 'Шаблон сохранён.' ? const Color(0xFF267B5D) : const Color(0xFFB74444))),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: selected == null || selected.isBuiltIn || _saving ? null : _deleteTemplate,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Удалить'),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: selected == null || _saving ? null : _saveTemplate,
                                icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                                label: const Text('Сохранить шаблон'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Переменные подставляются автоматически при создании проекта. Изменения шаблона не переписывают AGENT.md старых проектов.', style: TextStyle(fontSize: 11, color: Color(0xFF7C879A))),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _writeFiles(BuildContext context, ProjectProvider provider) async {
  final conflicts = await provider.findOverwriteConflicts();
  var overwrite = false;
  if (conflicts.isNotEmpty) {
    if (!context.mounted) return;
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Файлы уже существуют'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Будет перезаписано файлов: ${conflicts.length}. Продолжить?'),
              const SizedBox(height: 9),
              Text(conflicts.take(8).join('\n'), style: const TextStyle(fontFamily: 'Consolas', fontSize: 11.5)),
              if (conflicts.length > 8) Text('...и ещё ${conflicts.length - 8}', style: const TextStyle(color: Color(0xFF818B9D))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Перезаписать')),
        ],
      ),
    );
    if (answer != true) return;
    overwrite = true;
  }

  try {
    final count = await provider.writePreview(overwrite: overwrite);
    if (context.mounted) _showSnack(context, 'Записано файлов: $count');
  } catch (error) {
    if (context.mounted) _showSnack(context, 'Ошибка записи: $error');
  }
}

Future<void> _showAboutDialog(BuildContext context, ProjectProvider provider) async {
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
            title: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 22),
                const SizedBox(width: 8),
                const Text('CodeBridge Mini — v${AppVersion.fullVersion}'),
              ],
            ),
            content: SizedBox(
              width: 680,
              height: 540,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Актуальная версия: ${AppVersion.currentVersion} (сборка ${AppVersion.currentBuildNumber}). '
                    'Сохранение настроек, шаблонов, проектов и наработок.',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF5C687D)),
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
                onPressed: () => _openFolder(context, effectiveBackupDir),
                icon: const Icon(Icons.folder_open_outlined, size: 17),
                label: const Text('Папка бэкапов'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openFolder(context, provider.storage.dataDirectory),
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
void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}

String _fileSize(File file) {
  try {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  } catch (_) {
    return 'Размер неизвестен';
  }
}
