import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/agent_template_item.dart';
import '../models/code_project.dart';
import '../models/generated_file.dart';
import '../services/app_storage.dart';
import '../services/downloads_watcher_service.dart';
import '../services/file_writer.dart';
import '../services/git_service.dart';
import '../services/project_naming.dart';
import '../services/response_parser.dart';
import '../services/zip_deploy_service.dart';

class ProjectProvider extends ChangeNotifier {
  ProjectProvider(this.storage, {this.initialZipPath});

  final AppStorage storage;
  final String? initialZipPath;
  final DownloadsWatcherService _downloadsWatcher = DownloadsWatcherService();

  bool isLoading = true;
  bool isWorking = false;
  bool isDeploying = false;
  String? errorMessage;
  String? infoMessage;
  List<CodeProject> projects = <CodeProject>[];
  List<AgentTemplateItem> templates = <AgentTemplateItem>[];
  String selectedTemplateId = 'flutter-monorepo-agents';
  CodeProject? currentProject;
  String agentContent = '';
  List<GeneratedFile> previewFiles = <GeneratedFile>[];
  List<String> parserWarnings = <String>[];
  String detectedResponseFormat = '';
  List<FileSystemEntity> outputFiles = <FileSystemEntity>[];

  String downloadsWatchPath = DownloadsWatcherService.defaultDownloadsPath();
  bool downloadsWatcherEnabled = false;
  final List<String> deployLogs = <String>[];
  String? lastDeployStatus;
  GitStatusSummary? lastGitStatus;

  AgentTemplateItem? get selectedTemplate {
    for (final template in templates) {
      if (template.id == selectedTemplateId) return template;
    }
    return templates.isEmpty ? null : templates.first;
  }

  int get selectedPreviewCount => previewFiles.where((file) => file.selected).length;

  Future<void> initialize() async {
    try {
      templates = await storage.loadTemplates();
      projects = await storage.loadProjects();
      final settings = await storage.loadSettings();
      if (settings.selectedTemplateId != null &&
          templates.any((item) => item.id == settings.selectedTemplateId)) {
        selectedTemplateId = settings.selectedTemplateId!;
      }
      if (settings.downloadsWatchPath != null &&
          settings.downloadsWatchPath!.trim().isNotEmpty) {
        downloadsWatchPath = settings.downloadsWatchPath!.trim();
      }
      downloadsWatcherEnabled = settings.downloadsWatcherEnabled;

      if (settings.lastProjectId != null) {
        currentProject = _findProject(settings.lastProjectId!);
      }
      currentProject ??= projects.isNotEmpty ? projects.first : null;
      if (currentProject != null) {
        await _loadCurrentProjectDetails();
        await storage.saveLastProject(currentProject!.id);
      }

      if (downloadsWatcherEnabled) {
        await _syncDownloadsWatcher();
      }
    } catch (error) {
      errorMessage = 'Не удалось загрузить данные: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }

    if (initialZipPath != null && initialZipPath!.trim().isNotEmpty) {
      unawaited(handleIncomingZipArgument(initialZipPath!));
    }
  }

  @override
  void dispose() {
    unawaited(_downloadsWatcher.stop());
    super.dispose();
  }

  CodeProject? _findProject(String id) {
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  String packageNameFor(String projectName) => ProjectNaming.packageName(projectName);

  String defaultOutputPathFor(String projectName) {
    return storage.defaultOutputPath(ProjectNaming.packageName(projectName));
  }

  Future<void> selectTemplate(String id) async {
    if (!templates.any((template) => template.id == id)) return;
    selectedTemplateId = id;
    await storage.saveSelectedTemplate(id);
    notifyListeners();
  }

  Future<void> saveTemplate(AgentTemplateItem template) async {
    await storage.saveTemplate(template);
    templates = await storage.loadTemplates();
    selectedTemplateId = template.id;
    await storage.saveSelectedTemplate(template.id);
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    await storage.deleteTemplate(id);
    templates = await storage.loadTemplates();
    if (!templates.any((item) => item.id == selectedTemplateId)) {
      selectedTemplateId = templates.isEmpty ? 'flutter-monorepo-agents' : templates.first.id;
      if (templates.isNotEmpty) await storage.saveSelectedTemplate(selectedTemplateId);
    }
    notifyListeners();
  }

  Future<void> regenerateAgent({String? templateId}) async {
    final project = currentProject;
    if (project == null) return;
    final id = templateId ?? selectedTemplateId;
    AgentTemplateItem? template;
    for (final item in templates) {
      if (item.id == id) template = item;
    }
    if (template == null) throw StateError('Шаблон инструкции не найден.');
    isWorking = true;
    notifyListeners();
    try {
      final rendered = _renderTemplate(template.content, project);
      await storage.writeAgent(project, rendered);
      agentContent = await storage.readAgent(project);
      infoMessage = 'AGENT.md обновлён из шаблона «${template.name}».';
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  String _renderTemplate(String content, CodeProject project) {
    return content
        .replaceAll('{{project_name}}', project.name)
        .replaceAll('{{project_slug}}', project.packageName)
        .replaceAll('{{project_description}}', project.description.trim().isEmpty
            ? '[Опишите функциональность проекта]'
            : project.description.trim())
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }

  Future<void> createProject({
    required String name,
    required String description,
    required String outputPath,
    String? templateId,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw const FormatException('Введите название проекта.');
    final chosenTemplateId = templateId ?? selectedTemplateId;
    AgentTemplateItem? template;
    for (final candidate in templates) {
      if (candidate.id == chosenTemplateId) template = candidate;
    }
    template ??= selectedTemplate;
    if (template == null) throw StateError('Нет доступных шаблонов AGENT.md.');

    isWorking = true;
    errorMessage = null;
    notifyListeners();
    try {
      final project = await storage.createProject(
        name: cleanName,
        packageName: ProjectNaming.packageName(cleanName),
        description: description,
        templateId: template.id,
        templateContent: template.content,
        requestedOutputPath: outputPath,
      );
      projects = await storage.loadProjects();
      currentProject = _findProject(project.id) ?? project;
      previewFiles = <GeneratedFile>[];
      parserWarnings = <String>[];
      await _loadCurrentProjectDetails();
      await storage.saveLastProject(project.id);
      selectedTemplateId = template.id;
      await storage.saveSelectedTemplate(template.id);
      infoMessage = 'Проект «${project.name}» создан.';
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  Future<void> selectProject(CodeProject project) async {
    currentProject = project;
    previewFiles = <GeneratedFile>[];
    parserWarnings = <String>[];
    lastGitStatus = null;
    errorMessage = null;
    infoMessage = null;
    isWorking = true;
    notifyListeners();
    try {
      await _loadCurrentProjectDetails();
      await storage.saveLastProject(project.id);
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentProjectDetails() async {
    final project = currentProject;
    if (project == null) return;
    agentContent = await storage.readAgent(project);
    outputFiles = await storage.listOutputFiles(project);
  }

  Future<void> refreshOutputFiles() async {
    if (currentProject == null) return;
    outputFiles = await storage.listOutputFiles(currentProject!);
    notifyListeners();
  }

  Future<void> updateCurrentProjectDeploySettings({
    required String gitRepoUrl,
    required String gitBranch,
    required bool autoDeployEnabled,
    required String zipNameFilter,
    required bool deleteZipAfterDeploy,
    required bool cleanBeforeExtract,
  }) async {
    final project = currentProject;
    if (project == null) return;
    final cleanBranch = gitBranch.trim().isEmpty ? 'main' : gitBranch.trim();
    final updated = project.copyWith(
      gitRepoUrl: gitRepoUrl.trim(),
      gitBranch: cleanBranch,
      autoDeployEnabled: autoDeployEnabled,
      zipNameFilter: zipNameFilter.trim(),
      deleteZipAfterDeploy: deleteZipAfterDeploy,
      cleanBeforeExtract: cleanBeforeExtract,
    );
    await storage.updateProject(updated);
    currentProject = updated;
    projects = projects.map((item) => item.id == updated.id ? updated : item).toList();
    _appendDeployLog('Сохранены настройки авто-деплоя для «${updated.name}».');
    notifyListeners();
  }

  Future<void> setDownloadsWatcher({
    String? path,
    bool? enabled,
  }) async {
    if (path != null && path.trim().isNotEmpty) {
      downloadsWatchPath = path.trim();
    }
    if (enabled != null) {
      downloadsWatcherEnabled = enabled;
    }
    await storage.saveDownloadsWatcherSettings(
      downloadsWatchPath: downloadsWatchPath,
      downloadsWatcherEnabled: downloadsWatcherEnabled,
    );
    await _syncDownloadsWatcher();
    notifyListeners();
  }

  Future<void> _syncDownloadsWatcher() async {
    if (!downloadsWatcherEnabled) {
      await _downloadsWatcher.stop();
      _appendDeployLog('Мониторинг папки «Загрузки» остановлен.');
      return;
    }
    try {
      await _downloadsWatcher.start(
        directoryPath: downloadsWatchPath,
        onZipReady: (String zipPath) => deployZipArchive(zipPath, fromWatcher: true),
      );
      _appendDeployLog('Мониторинг активен: $downloadsWatchPath');
    } catch (error) {
      downloadsWatcherEnabled = false;
      await storage.saveDownloadsWatcherSettings(downloadsWatcherEnabled: false);
      _appendDeployLog('Ошибка запуска мониторинга: $error');
    }
  }

  Future<GitStatusSummary?> checkCurrentProjectGit() async {
    final project = currentProject;
    if (project == null) return null;
    lastGitStatus = await GitService.inspectDirectory(project.outputPath);
    if (lastGitStatus!.gitInstalled) {
      if (lastGitStatus!.isRepository) {
        _appendDeployLog(
          'Git OK (${lastGitStatus!.gitVersion}): ветка ${lastGitStatus!.branch ?? '?'}, '
          'origin: ${lastGitStatus!.remoteUrl ?? 'не задан'}',
        );
      } else {
        _appendDeployLog(
          'Git установлен (${lastGitStatus!.gitVersion}), но в папке проекта пока нет .git (будет создан автоматически при деплое).',
        );
      }
    } else {
      _appendDeployLog('Git не найден: ${lastGitStatus!.error ?? 'установите Git for Windows'}');
    }
    notifyListeners();
    return lastGitStatus;
  }

  Future<void> handleIncomingZipArgument(String zipPath) async {
    _appendDeployLog('Получен ZIP через «Открыть с помощью»: ${p.basename(zipPath)}');
    await deployZipArchive(zipPath, fromWatcher: false);
  }

  Future<void> deployZipArchive(String zipPath, {bool fromWatcher = false}) async {
    final project = currentProject;
    if (project == null) {
      _appendDeployLog('Пропущено (${p.basename(zipPath)}): не выбран активный проект.');
      notifyListeners();
      return;
    }

    if (fromWatcher && !project.autoDeployEnabled) {
      return;
    }

    final fileName = p.basename(zipPath);
    if (fromWatcher && project.zipNameFilter.isNotEmpty) {
      if (!fileName.toLowerCase().contains(project.zipNameFilter.toLowerCase())) {
        return;
      }
    }

    if (isDeploying) {
      _appendDeployLog('Пропущено ($fileName): уже выполняется другой деплой.');
      notifyListeners();
      return;
    }

    isDeploying = true;
    errorMessage = null;
    lastDeployStatus = 'Обработка $fileName...';
    _appendDeployLog('--- Старт авто-деплоя: $fileName ---');
    notifyListeners();

    try {
      final inspection = await ZipDeployService.inspectZip(zipPath);
      if (!inspection.isValidProject) {
        final reason = inspection.reason ?? 'Архив не содержит pubspec.yaml или AGENTS.md.';
        if (fromWatcher) {
          _appendDeployLog('Игнорирован ($fileName): $reason');
          lastDeployStatus = null;
        } else {
          _appendDeployLog('Отклонён ($fileName): $reason');
          lastDeployStatus = reason;
          errorMessage = reason;
        }
        return;
      }

      _appendDeployLog(
        'Архив проверен: файлов ${inspection.fileCount}'
        '${inspection.strippedRootPrefix.isNotEmpty ? ', снята корневая папка "${inspection.strippedRootPrefix}"' : ''}.',
      );

      final extractResult = await ZipDeployService.extractToDirectory(
        zipPath: zipPath,
        targetDirectory: project.outputPath,
        cleanTarget: project.cleanBeforeExtract,
        requireProjectMarkers: true,
      );
      _appendDeployLog(
        'Распаковано файлов: ${extractResult.extractedCount} -> ${project.outputPath}',
      );

      outputFiles = await storage.listOutputFiles(project);

      final gitResult = await GitService.deployDirectory(
        directory: project.outputPath,
        repoUrl: project.gitRepoUrl,
        branch: project.gitBranch,
        commitMessage: 'Auto-deploy $fileName via CodeBridge Mini',
        push: true,
      );

      for (final line in gitResult.logs) {
        _appendDeployLog(line);
      }

      lastDeployStatus = gitResult.message;
      if (gitResult.success) {
        infoMessage = gitResult.message;
        if (project.deleteZipAfterDeploy) {
          try {
            final zipFile = File(zipPath);
            if (await zipFile.exists()) {
              await zipFile.delete();
              _appendDeployLog('Исходный ZIP удалён: $fileName');
            }
          } catch (error) {
            _appendDeployLog('Не удалось удалить ZIP: $error');
          }
        }
      } else {
        errorMessage = gitResult.message;
      }
    } catch (error) {
      final msg = error is FormatException ? error.message : error.toString();
      _appendDeployLog('Ошибка авто-деплоя: $msg');
      lastDeployStatus = 'Ошибка: $msg';
      errorMessage = msg;
    } finally {
      isDeploying = false;
      notifyListeners();
    }
  }

  void clearDeployLogs() {
    deployLogs.clear();
    lastDeployStatus = null;
    notifyListeners();
  }

  void _appendDeployLog(String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    deployLogs.add('[$hh:$mm:$ss] $message');
    if (deployLogs.length > 200) {
      deployLogs.removeRange(0, deployLogs.length - 200);
    }
  }

  Future<void> prepareResponse(String response) async {
    errorMessage = null;
    infoMessage = null;
    parserWarnings = <String>[];
    previewFiles = <GeneratedFile>[];
    notifyListeners();
    try {
      final project = currentProject;
      if (project == null) throw const FormatException('Сначала создайте или выберите проект.');
      final parsed = ResponseParser.parseDetailed(response);
      detectedResponseFormat = parsed.format;
      parserWarnings = List<String>.from(parsed.warnings);
      final readyFiles = <GeneratedFile>[];

      for (final file in parsed.files) {
        if (!file.isFragment) {
          readyFiles.add(file);
          continue;
        }
        if (await FileWriter.canMergePubspecFragment(project.outputPath, file)) {
          try {
            final merged = await FileWriter.mergePubspecFragment(project.outputPath, file);
            readyFiles.add(merged);
          } catch (error) {
            readyFiles.add(file.copyWith(selected: false, note: 'Не удалось объединить автоматически: $error'));
          }
        } else {
          readyFiles.add(file.copyWith(
            selected: false,
            note: 'Это фрагмент, а полного файла в папке проекта пока нет. Запроси у ИИ весь файл или добавь полный файл в проект.',
          ));
        }
      }
      previewFiles = readyFiles;
      final included = selectedPreviewCount;
      final fragments = previewFiles.length - previewFiles.where((file) => !file.isFragment).length;
      final summary = <String>[
        'Распознано файлов: ${previewFiles.length}.',
        'Готово к записи: $included.',
        if (fragments > 0) 'Фрагменты требуют проверки: $fragments.',
      ];
      if (parserWarnings.isNotEmpty) summary.add('Есть замечания — см. ниже.');
      infoMessage = summary.join(' ');
    } catch (error) {
      previewFiles = <GeneratedFile>[];
      errorMessage = error is FormatException ? error.message : error.toString();
    }
    notifyListeners();
  }

  void togglePreviewFile(int index, bool selected) {
    if (index < 0 || index >= previewFiles.length) return;
    previewFiles[index] = previewFiles[index].copyWith(selected: selected);
    notifyListeners();
  }

  Future<List<String>> findOverwriteConflicts() async {
    final project = currentProject;
    if (project == null) return <String>[];
    return FileWriter.findConflicts(project.outputPath, previewFiles);
  }

  Future<int> writePreview({required bool overwrite}) async {
    final project = currentProject;
    final selected = previewFiles.where((file) => file.selected).toList();
    if (project == null || selected.isEmpty) {
      throw StateError('Нет выбранных файлов для записи. Отметь нужные файлы в предпросмотре.');
    }

    isWorking = true;
    errorMessage = null;
    notifyListeners();
    try {
      await FileWriter.writeFiles(
        outputDirectory: project.outputPath,
        files: selected,
        overwrite: overwrite,
      );
      final written = selected.length;
      previewFiles = <GeneratedFile>[];
      parserWarnings = <String>[];
      outputFiles = await storage.listOutputFiles(project);
      infoMessage = 'Создано файлов: $written.';
      return written;
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  void clearPreview() {
    previewFiles = <GeneratedFile>[];
    parserWarnings = <String>[];
    errorMessage = null;
    infoMessage = null;
    notifyListeners();
  }

  Future<void> renameCurrentProject(String newName) async {
    final project = currentProject;
    if (project == null) return;
    final cleanName = newName.trim();
    if (cleanName.isEmpty) {
      throw const FormatException('Введите название проекта.');
    }
    isWorking = true;
    errorMessage = null;
    notifyListeners();
    try {
      final updated = await storage.renameProject(project, cleanName);
      currentProject = updated;
      projects = projects
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
      infoMessage = 'Название проекта обновлено: «${updated.name}».';
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }
}
