import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/agent_template_item.dart';
import '../models/code_project.dart';
import '../models/project_note.dart';
import '../models/generated_file.dart';
import '../services/agent_template.dart';
import '../services/app_storage.dart';
import '../services/backup_coordinator_service.dart';
import '../services/backup_service.dart';
import '../services/downloads_watcher_service.dart';
import '../services/file_writer.dart';
import '../services/git_service.dart';
import '../services/github_build_fetcher_service.dart';
import '../services/github_build_polling_service.dart';
import '../services/github_repo_service.dart';
import '../services/project_naming.dart';
import '../services/response_parser.dart';
import '../services/build_bundle_service.dart';
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
  ProjectNotesStore currentProjectNotes = const ProjectNotesStore();
  List<GeneratedFile> previewFiles = <GeneratedFile>[];
  List<String> parserWarnings = <String>[];
  String detectedResponseFormat = '';
  List<FileSystemEntity> outputFiles = <FileSystemEntity>[];

  String downloadsWatchPath = DownloadsWatcherService.defaultDownloadsPath();
  bool downloadsWatcherEnabled = false;
  List<String> tabOrder = const <String>['agent', 'import', 'files', 'notes', 'auto_deploy', 'build_capture'];
  final List<String> activityLogs = <String>[];
  List<String> get deployLogs => activityLogs;
  String? lastDeployStatus;
  GitStatusSummary? lastGitStatus;
  String? pendingBuildZipPath;
  String? pendingBuildSuggestedDir;
  String? lastBuildArchiveName;
  String? lastBuildAutoCheckAt;
  String? lastBuildAutoCheckSummary;
  bool lastBuildCheckHadFailure = false;
  GitHubBuildFailureInfo? latestFailedGitHubBuild;
  List<String> get unpackLogs => activityLogs;
  String githubToken = '';
  String githubOwner = '';
  int logRetentionDays = 30;
  late final BackupCoordinator _backupCoordinator = BackupCoordinator(
    storage: storage,
    getProjects: () => projects,
    onLog: _appendDeployLog,
    onInfo: (msg) => infoMessage = msg,
    onError: (msg) => errorMessage = msg,
    onReloadAfterRestore: (_, __, ___, ____) async {
      projects = await storage.loadProjects();
      if (projects.isNotEmpty) {
        currentProject = (currentProject?.id != null ? _findProject(currentProject!.id) : null) ?? projects.first;
        await _loadCurrentProjectDetails();
      }
    },
    onNotify: notifyListeners,
  );

  bool get autoBackupEnabled => _backupCoordinator.autoBackupEnabled;
  int get autoBackupIntervalMinutes => _backupCoordinator.autoBackupIntervalMinutes;
  String? get backupDirectory => _backupCoordinator.backupDirectory;
  String? get lastBackupZipPath => _backupCoordinator.lastBackupZipPath;
  String? get lastAutoBackupAt => _backupCoordinator.lastAutoBackupAt;
  late final GitHubBuildPollingCoordinator _buildPollingCoordinator = GitHubBuildPollingCoordinator(
    storage: storage,
    getProjects: () => projects,
    getCurrentProject: () => currentProject,
    getGitHubToken: () => githubToken,
    getLastSourceId: (id) => _lastFetchedBuildSourceByProject[id],
    onRecordSourceId: (id, srcId) async {
      _lastFetchedBuildSourceByProject[id] = srcId;
      await storage.saveLastFetchedBuildSource(id, srcId);
    },
    onLog: _appendDeployLog,
    onApplyToActiveProject: (_, __) => checkAndApplyGitHubBuilds(silent: true),
    onNotify: notifyListeners,
  );
  final Map<String, String> _lastFetchedBuildSourceByProject = <String, String>{};
  bool isCheckingGitHubBuilds = false;
  int selectedTabIndex = 0;

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
      final loadedProjects = await storage.loadProjects();
      final settings = await storage.loadSettings();
      if (settings.projectOrder.isNotEmpty) {
        final orderMap = <String, int>{
          for (var i = 0; i < settings.projectOrder.length; i++)
            settings.projectOrder[i]: i,
        };
        loadedProjects.sort((a, b) {
          final ia = orderMap[a.id] ?? 1 << 20;
          final ib = orderMap[b.id] ?? 1 << 20;
          if (ia != ib) return ia.compareTo(ib);
          return b.createdAt.compareTo(a.createdAt);
        });
      }
      projects = loadedProjects;
      if (settings.selectedTemplateId != null &&
          templates.any((item) => item.id == settings.selectedTemplateId)) {
        selectedTemplateId = settings.selectedTemplateId!;
      }
      if (settings.downloadsWatchPath != null &&
          settings.downloadsWatchPath!.trim().isNotEmpty) {
        downloadsWatchPath = settings.downloadsWatchPath!.trim();
      }
      downloadsWatcherEnabled = settings.downloadsWatcherEnabled;
      githubToken = settings.githubToken;
      githubOwner = settings.githubOwner;
      logRetentionDays = settings.logRetentionDays;
      final savedUnified = await storage.loadUnifiedLogHistory(
        retentionDays: logRetentionDays,
      );
      activityLogs
        ..clear()
        ..addAll(savedUnified);
      _lastFetchedBuildSourceByProject
        ..clear()
        ..addAll(settings.lastFetchedBuildSources);
      _backupCoordinator.applyInitialState(
        enabled: settings.autoBackupEnabled,
        intervalMinutes: settings.autoBackupIntervalMinutes,
        customDir: settings.backupDirectory,
        lastAutoAt: settings.lastAutoBackupAt,
      );
      if (autoBackupEnabled) {
        unawaited(_backupCoordinator.runIfDue());
      }
      if (settings.tabOrder.isNotEmpty) {
        const allowed = <String>['agent', 'import', 'files', 'notes', 'auto_deploy', 'build_capture'];
        final normalized = <String>[];
        for (final id in settings.tabOrder) {
          if (allowed.contains(id) && !normalized.contains(id)) {
            normalized.add(id);
          }
        }
        for (final id in allowed) {
          if (!normalized.contains(id)) normalized.add(id);
        }
        tabOrder = normalized;
      }

      final activeList = activeProjects;
      if (settings.lastProjectId != null) {
        final candidate = _findProject(settings.lastProjectId!);
        if (candidate != null && !candidate.isTrashed) {
          currentProject = candidate;
        }
      }
      currentProject ??= activeList.isNotEmpty ? activeList.first : null;
      if (currentProject != null) {
        await _loadCurrentProjectDetails();
        await storage.saveLastProject(currentProject!.id);
      }

      if (downloadsWatcherEnabled) {
        await _syncDownloadsWatcher();
      }
      _configureGitHubBuildPolling();
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
    _buildPollingCoordinator.dispose();
    unawaited(_downloadsWatcher.stop());
    super.dispose();
  }

  CodeProject? _findProject(String id) {
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  List<CodeProject> get activeProjects =>
      projects.where((p) => !p.isTrashed).toList(growable: false);

  List<CodeProject> get trashedProjects {
    final list = projects.where((p) => p.isTrashed).toList();
    list.sort((a, b) {
      final da = a.trashedAt ?? a.createdAt;
      final db = b.trashedAt ?? b.createdAt;
      return db.compareTo(da);
    });
    return list;
  }

  Future<void> _persistOrder() async {
    await storage.saveProjectOrder(projects.map((p) => p.id).toList());
  }

  Future<void> moveActiveProject(int oldIndex, int newIndex) async {
    final active = List<CodeProject>.from(activeProjects);
    if (oldIndex < 0 || oldIndex >= active.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= active.length || target == oldIndex) return;

    final moved = active.removeAt(oldIndex);
    active.insert(target, moved);

    final trashed = projects.where((p) => p.isTrashed).toList();
    projects = <CodeProject>[...active, ...trashed];
    await _persistOrder();
    notifyListeners();
  }

  Future<void> moveActiveProjectStep(String projectId, int delta) async {
    final active = activeProjects;
    final idx = active.indexWhere((p) => p.id == projectId);
    if (idx < 0) return;
    final dest = idx + delta;
    if (dest < 0 || dest >= active.length) return;
    final insertAt = delta > 0 ? dest + 1 : dest;
    await moveActiveProject(idx, insertAt);
  }

  Future<void> moveProjectToTrash(CodeProject project) async {
    if (project.isTrashed) return;
    final updated = project.copyWith(
      isTrashed: true,
      trashedAt: DateTime.now(),
    );
    await storage.updateProject(updated);
    projects = projects.map((item) => item.id == updated.id ? updated : item).toList();
    await _persistOrder();

    if (currentProject?.id == project.id) {
      final remainingActive = activeProjects;
      currentProject = remainingActive.isNotEmpty ? remainingActive.first : null;
      await storage.saveLastProject(currentProject?.id);
      if (currentProject != null) {
        await _loadCurrentProjectDetails();
      } else {
        agentContent = '';
        outputFiles = <FileSystemEntity>[];
        currentProjectNotes = const ProjectNotesStore();
      }
    }
    infoMessage = 'Проект «${project.name}» перемещён в корзину.';
    notifyListeners();
  }

  Future<void> restoreProjectFromTrash(CodeProject project) async {
    if (!project.isTrashed) return;
    final updated = project.copyWith(
      isTrashed: false,
      clearTrashedAt: true,
    );
    await storage.updateProject(updated);
    projects = projects.map((item) => item.id == updated.id ? updated : item).toList();
    await _persistOrder();

    currentProject ??= updated;
    if (currentProject?.id == updated.id) {
      await storage.saveLastProject(updated.id);
      await _loadCurrentProjectDetails();
    }
    infoMessage = 'Проект «${project.name}» восстановлен из корзины.';
    notifyListeners();
  }

  Future<void> deleteProjectForever(
    CodeProject project, {
    bool deleteExternalSourceFolder = false,
  }) async {
    await storage.deleteProjectPermanently(
      project,
      deleteExternalSourceFolder: deleteExternalSourceFolder,
    );
    projects = projects.where((item) => item.id != project.id).toList();
    await _persistOrder();

    if (currentProject?.id == project.id) {
      final remainingActive = activeProjects;
      currentProject = remainingActive.isNotEmpty ? remainingActive.first : null;
      await storage.saveLastProject(currentProject?.id);
      if (currentProject != null) {
        await _loadCurrentProjectDetails();
      } else {
        agentContent = '';
        outputFiles = <FileSystemEntity>[];
        currentProjectNotes = const ProjectNotesStore();
      }
    }
    infoMessage = 'Проект «${project.name}» удалён навсегда.';
    notifyListeners();
  }

  Future<void> emptyProjectsTrash({bool deleteExternalSourceFolder = false}) async {
    final items = List<CodeProject>.from(trashedProjects);
    for (final item in items) {
      await storage.deleteProjectPermanently(
        item,
        deleteExternalSourceFolder: deleteExternalSourceFolder,
      );
    }
    final trashedIds = items.map((e) => e.id).toSet();
    projects = projects.where((p) => !trashedIds.contains(p.id)).toList();
    await _persistOrder();
    infoMessage = 'Корзина проектов очищена.';
    notifyListeners();
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

  Future<void> saveAgentContent(String content) async {
    final project = currentProject;
    if (project == null) return;
    isWorking = true;
    notifyListeners();
    try {
      await storage.writeAgent(project, content);
      agentContent = await storage.readAgent(project);
      infoMessage = 'Изменения в agent.md сохранены.';
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

  Future<void> saveGitHubCredentials({
    required String token,
    required String owner,
  }) async {
    githubToken = token.trim();
    githubOwner = owner.trim();
    await storage.saveGitHubCredentials(
      githubToken: githubToken,
      githubOwner: githubOwner,
    );
    notifyListeners();
  }

  Future<void> createProject({
    required String name,
    required String description,
    required String outputPath,
    String? templateId,
    bool attachExistingRepo = false,
    String existingRepoUrl = '',
    bool cloneIfEmpty = true,
    bool overwriteExistingStarterFiles = false,
    bool createRemoteRepo = false,
    bool privateRepo = true,
    String? repoName,
    String? githubOwnerOverride,
    String? githubTokenOverride,
    String gitBranch = 'main',
    bool createStarterFiles = true,
    bool includeReadme = true,
    bool includeGitignore = true,
    bool includeAgentFile = true,
    bool pushInitialCommit = true,
    bool autoEnableDeploy = true,
    bool autoSyncOnReject = true,
    String? zipNameFilterOverride,
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
      var project = await storage.createProject(
        name: cleanName,
        packageName: ProjectNaming.packageName(cleanName),
        description: description,
        templateId: template.id,
        templateContent: template.content,
        requestedOutputPath: outputPath,
      );

      final renderedAgent = AgentTemplate.render(
        template: template.content,
        projectName: project.name,
        projectSlug: project.packageName,
        description: project.description,
      );

      final cleanBranch = gitBranch.trim().isEmpty ? 'main' : gitBranch.trim();
      final defaultFilter = (zipNameFilterOverride != null && zipNameFilterOverride.trim().isNotEmpty)
          ? zipNameFilterOverride.trim()
          : cleanName.replaceAll(RegExp(r'\s+'), '');

      String summarySuffix = '';
      if (attachExistingRepo) {
        final attached = await GitHubRepoService.attachExistingRepository(
          repoUrl: existingRepoUrl,
          branch: cleanBranch,
          localDirectory: project.outputPath,
          cloneIfEmpty: cloneIfEmpty,
        );
        for (final line in attached.logs) {
          _appendDeployLog(line);
        }
        if (!attached.success) {
          throw StateError(
            attached.errorMessage ?? 'Не удалось подключить готовый репозиторий.',
          );
        }
        if (createStarterFiles) {
          await GitHubRepoService.scaffoldStarterFiles(
            directory: project.outputPath,
            projectName: project.name,
            packageName: project.packageName,
            description: project.description,
            agentContent: renderedAgent,
            includeReadme: includeReadme,
            includeGitignore: includeGitignore,
            includeAgentFile: includeAgentFile,
            overwriteExisting: overwriteExistingStarterFiles,
          );
        }
        final updatedProj = project.copyWith(
          gitRepoUrl: attached.remoteUrl ?? existingRepoUrl.trim(),
          gitBranch: cleanBranch,
          autoDeployEnabled: autoEnableDeploy,
          zipNameFilter: defaultFilter,
          autoSyncOnReject: autoSyncOnReject,
        );
        await storage.updateProject(updatedProj);
        project = updatedProj;
        summarySuffix = ' Подключён готовый репозиторий: ${project.gitRepoUrl} (ветка: $cleanBranch).';
      } else {
        if (createStarterFiles) {
          await GitHubRepoService.scaffoldStarterFiles(
            directory: project.outputPath,
            projectName: project.name,
            packageName: project.packageName,
            description: project.description,
            agentContent: renderedAgent,
            includeReadme: includeReadme,
            includeGitignore: includeGitignore,
            includeAgentFile: includeAgentFile,
            overwriteExisting: overwriteExistingStarterFiles,
          );
        }
      }

      if (!attachExistingRepo && createRemoteRepo) {
        final effectiveToken = (githubTokenOverride ?? '').trim().isNotEmpty
            ? githubTokenOverride!.trim()
            : githubToken;
        final effectiveOwner = (githubOwnerOverride ?? '').trim().isNotEmpty
            ? githubOwnerOverride!.trim()
            : githubOwner;
        if (effectiveToken.isNotEmpty || effectiveOwner.isNotEmpty) {
          await saveGitHubCredentials(
            token: effectiveToken,
            owner: effectiveOwner,
          );
        }

        final targetRepo = (repoName != null && repoName.trim().isNotEmpty)
            ? repoName.trim()
            : cleanName;

        final provision = await GitHubRepoService.createRemoteRepository(
          repoName: targetRepo,
          isPrivate: privateRepo,
          description: description,
          token: effectiveToken,
          ownerOrOrg: effectiveOwner,
          branch: cleanBranch,
          localDirectory: project.outputPath,
          pushInitialCommit: pushInitialCommit,
          commitMessage: 'Initial commit for ${project.name}',
        );
        for (final line in provision.logs) {
          _appendDeployLog(line);
        }
        if (!provision.success) {
          throw StateError(
            provision.errorMessage ?? 'Не удалось создать репозиторий на GitHub.',
          );
        }

        final updatedProj = project.copyWith(
          gitRepoUrl: provision.remoteUrl ?? '',
          gitBranch: cleanBranch,
          autoDeployEnabled: autoEnableDeploy,
          zipNameFilter: defaultFilter,
          autoSyncOnReject: autoSyncOnReject,
        );
        await storage.updateProject(updatedProj);
        project = updatedProj;
        summarySuffix = ' Репозиторий создан (${privateRepo ? 'приватный' : 'публичный'})'
            '${provision.htmlUrl != null ? ': ${provision.htmlUrl}' : ''}.';
      } else {
        final updatedProj = project.copyWith(
          gitBranch: cleanBranch,
          autoDeployEnabled: autoEnableDeploy,
          zipNameFilter: defaultFilter,
          autoSyncOnReject: autoSyncOnReject,
        );
        await storage.updateProject(updatedProj);
        project = updatedProj;
      }

      if (autoEnableDeploy && !downloadsWatcherEnabled) {
        await setDownloadsWatcher(enabled: true);
      }
      _appendDeployLog(
        'Автозаполнены настройки авто-деплоя для «${project.name}»: '
        'autoDeploy=${project.autoDeployEnabled}, ветка=${project.gitBranch}, фильтр="${project.zipNameFilter}".',
      );

      projects = await storage.loadProjects();
      currentProject = _findProject(project.id) ?? project;
      previewFiles = <GeneratedFile>[];
      parserWarnings = <String>[];
      await _loadCurrentProjectDetails();
      await storage.saveLastProject(project.id);
      selectedTemplateId = template.id;
      await storage.saveSelectedTemplate(template.id);
      infoMessage = 'Проект «${project.name}» создан.$summarySuffix';
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
    currentProjectNotes = await storage.loadProjectNotes(project);
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
    bool autoSyncOnReject = true,
    bool moveZipAfterPush = true,
    bool moveZipToVersionsAndDeleteSource = false,
    String zipArchiveFolder = '',
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
      autoSyncOnReject: autoSyncOnReject,
      moveZipAfterPush: moveZipAfterPush,
      moveZipToVersionsAndDeleteSource: moveZipToVersionsAndDeleteSource,
      zipArchiveFolder: zipArchiveFolder.trim(),
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
        onZipReady: (String zipPath) => _handleWatchedZip(zipPath),
      );
      _appendDeployLog('Мониторинг активен: $downloadsWatchPath');
    } catch (error) {
      downloadsWatcherEnabled = false;
      await storage.saveDownloadsWatcherSettings(downloadsWatcherEnabled: false);
      _appendDeployLog('Ошибка запуска мониторинга: $error');
    }
  }

  Future<void> _handleWatchedZip(String zipPath) async {
    final project = currentProject;
    final fileName = p.basename(zipPath);
    if (project != null && project.buildCaptureEnabled) {
      final filter = project.buildZipFilter.trim();
      final matchesFilter = project.buildTakeAllPublicBuilds ||
          filter.isEmpty ||
          fileName.toLowerCase().contains(filter.toLowerCase());
      if (matchesFilter) {
        final baseBuildsDir = project.buildTargetDirectory.trim().isNotEmpty
            ? project.buildTargetDirectory.trim()
            : BuildBundleService.defaultBuildsRootDirectory(storage.dataDirectory);
        if (project.buildAskTargetBeforeExtract) {
          pendingBuildZipPath = zipPath;
          pendingBuildSuggestedDir = baseBuildsDir;
          _appendDeployLog('Перехвачен архив сборки: $fileName — ожидает выбора/подтверждения папки.');
          notifyListeners();
          return;
        }
        await applyBuildArchive(zipPath, customTargetDirectory: baseBuildsDir);
        return;
      }
    }
    await deployZipArchive(zipPath, fromWatcher: true);
  }

  Future<void> updateCurrentProjectBuildSettings({
    required bool buildCaptureEnabled,
    required bool buildAskTargetBeforeExtract,
    required String buildTargetDirectory,
    required String buildZipFilter,
    required String buildPreservedFiles,
    bool buildTakeAllPublicBuilds = true,
    bool buildOverlayPrevious = true,
    bool buildClearBeforeApply = false,
    bool buildAutoFetchEnabled = false,
    int buildAutoFetchIntervalMinutes = 5,
    bool buildAutoLaunchExe = false,
    int buildHistoryKeepCount = 10,
  }) async {
    final project = currentProject;
    if (project == null) return;
    final updated = project.copyWith(
      buildCaptureEnabled: buildCaptureEnabled,
      buildAskTargetBeforeExtract: buildAskTargetBeforeExtract,
      buildTargetDirectory: buildTargetDirectory.trim(),
      buildZipFilter: buildZipFilter.trim(),
      buildPreservedFiles: buildPreservedFiles.trim(),
      buildTakeAllPublicBuilds: buildTakeAllPublicBuilds,
      buildOverlayPrevious: buildOverlayPrevious,
      buildClearBeforeApply: buildClearBeforeApply,
      buildAutoFetchEnabled: buildAutoFetchEnabled,
      buildAutoFetchIntervalMinutes: buildAutoFetchIntervalMinutes.clamp(1, 120),
      buildAutoLaunchExe: buildAutoLaunchExe,
      buildHistoryKeepCount: buildHistoryKeepCount.clamp(1, 200),
    );
    await storage.updateProject(updated);
    currentProject = updated;
    projects = projects.map((item) => item.id == updated.id ? updated : item).toList();
    _configureGitHubBuildPolling();
    _appendDeployLog('Сохранены настройки перехвата сборок для «${updated.name}».');
    notifyListeners();
  }

  void _configureGitHubBuildPolling() {
    _buildPollingCoordinator.configure();
  }

  Future<GitHubBuildFetchResult> checkAndApplyGitHubBuilds({bool silent = false}) async {
    final proj = currentProject;
    if (proj == null) {
      if (!silent) errorMessage = 'Нет выбранного проекта.';
      notifyListeners();
      return const GitHubBuildFetchResult(
        success: false,
        logs: <String>['Нет выбранного проекта.'],
        fetchedZips: <FetchedBuildItem>[],
        errorMessage: 'Нет выбранного проекта.',
      );
    }
    if (isCheckingGitHubBuilds) {
      return const GitHubBuildFetchResult(
        success: true,
        logs: <String>['Проверка сборок на GitHub уже выполняется...'],
        fetchedZips: <FetchedBuildItem>[],
      );
    }
    isCheckingGitHubBuilds = true;
    if (!silent) errorMessage = null;
    notifyListeners();
    try {
      final fetchDir = p.join(storage.dataDirectory, 'builds', '_fetched', proj.packageName);
      final res = await GitHubBuildFetcherService.fetchLatestBuilds(
        repoUrl: proj.gitRepoUrl,
        token: githubToken,
        downloadDirectory: fetchDir,
        lastProcessedId: _lastFetchedBuildSourceByProject[proj.id],
        zipFilter: proj.buildZipFilter,
        takeAllBuilds: proj.buildTakeAllPublicBuilds,
        forceRecheck: !silent,
      );
      for (final line in res.logs) {
        _appendUnpackLog(line);
        _appendDeployLog(line);
      }
      latestFailedGitHubBuild = res.latestFailedBuild;
      if (!res.success && !silent && res.errorMessage != null) {
        errorMessage = res.errorMessage;
      }
      for (final item in res.fetchedZips) {
        _lastFetchedBuildSourceByProject[proj.id] = item.sourceId;
        await storage.saveLastFetchedBuildSource(proj.id, item.sourceId);
        if (proj.buildCaptureEnabled) {
          final baseBuildsDir = proj.buildTargetDirectory.trim().isNotEmpty
              ? proj.buildTargetDirectory.trim()
              : BuildBundleService.defaultBuildsRootDirectory(storage.dataDirectory);
          await applyBuildArchive(item.zipPath, customTargetDirectory: baseBuildsDir);
        } else {
          pendingBuildZipPath = item.zipPath;
          infoMessage = 'Скачана новая сборка с GitHub: ${item.fileName}';
        }
      }
      final nowStamp = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      lastBuildAutoCheckAt = '${two(nowStamp.hour)}:${two(nowStamp.minute)}:${two(nowStamp.second)}';
      final versions = res.fetchedZips
          .map((e) => e.detectedVersion)
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .toSet()
          .toList();
      final verLabel = versions.isNotEmpty ? ' — версия ${versions.join(', ')}' : '';
      if (res.latestFailedBuild != null) {
        lastBuildCheckHadFailure = true;
        final failSummary = res.latestFailedBuild!.shortSummary;
        lastBuildAutoCheckSummary = res.fetchedZips.isNotEmpty
            ? '$failSummary; скачана предыдущая успешная сборка: ${res.fetchedZips.length}$verLabel'
            : failSummary;
      } else if (!res.success) {
        lastBuildCheckHadFailure = true;
        lastBuildAutoCheckSummary = res.errorMessage ?? 'Ошибка проверки GitHub';
      } else {
        lastBuildCheckHadFailure = false;
        lastBuildAutoCheckSummary = res.fetchedZips.isNotEmpty
            ? 'Скачано и распаковано сборок: ${res.fetchedZips.length}$verLabel'
            : (res.hasInProgressBuild
                ? 'Сборка на GitHub ещё выполняется...'
                : 'Новых сборок нет');
      }
      for (final line in res.logs) {
        _appendUnpackLog(line);
      }
      if (!silent && res.success && res.fetchedZips.isEmpty) {
        infoMessage = 'Новых готовых сборок на GitHub не найдено.';
      }
      return res;
    } finally {
      isCheckingGitHubBuilds = false;
      notifyListeners();
    }
  }

  Future<void> confirmPendingBuild({String? chosenTargetDirectory}) async {
    final zipPath = pendingBuildZipPath;
    if (zipPath == null) return;
    pendingBuildZipPath = null;
    pendingBuildSuggestedDir = null;
    notifyListeners();
    await applyBuildArchive(zipPath, customTargetDirectory: chosenTargetDirectory);
  }

  void dismissPendingBuild() {
    pendingBuildZipPath = null;
    pendingBuildSuggestedDir = null;
    notifyListeners();
  }

  Future<void> applyBuildArchive(
    String zipPath, {
    String? customTargetDirectory,
  }) async {
    final project = currentProject;
    if (project == null) {
      _appendDeployLog('Пропущено (${p.basename(zipPath)}): не выбран активный проект.');
      notifyListeners();
      return;
    }
    if (isDeploying) {
      _appendDeployLog('Пропущено (${p.basename(zipPath)}): уже выполняется обработка.');
      notifyListeners();
      return;
    }

    isDeploying = true;
    errorMessage = null;
    lastDeployStatus = 'Сборка новой версии из ${p.basename(zipPath)}...';
    _appendDeployLog('--- Перехват скомпилированного архива: ${p.basename(zipPath)} ---');
    _appendUnpackLog('--- Распаковка архива сборки: ${p.basename(zipPath)} ---');
    notifyListeners();

    try {
      final preserved = project.buildPreservedFiles
          .split(RegExp(r'[,\n;]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final buildsRoot = project.buildTargetDirectory.trim().isNotEmpty
          ? project.buildTargetDirectory.trim()
          : BuildBundleService.defaultBuildsRootDirectory(storage.dataDirectory);

      lastBuildArchiveName = p.basename(zipPath);
      final result = await BuildBundleService.applyDownloadedBuild(
        zipPath: zipPath,
        buildsRootDirectory: buildsRoot,
        customTargetDirectory: customTargetDirectory,
        preservedPatterns: preserved,
        overlayPreviousVersion: project.buildOverlayPrevious,
        clearTargetBeforeApply: project.buildClearBeforeApply,
        historyKeepCount: project.buildHistoryKeepCount,
        autoLaunchExe: project.buildAutoLaunchExe,
      );

      for (final line in result.logs) {
        _appendDeployLog(line);
        _appendUnpackLog(line);
      }
      lastDeployStatus = result.message;
      if (result.success) {
        infoMessage = result.message;
      } else {
        errorMessage = result.message;
      }
    } catch (error) {
      final msg = error is FormatException ? error.message : error.toString();
      _appendDeployLog('Ошибка сборки версии: $msg');
      _appendUnpackLog('Ошибка сборки версии: $msg');
      lastDeployStatus = 'Ошибка: $msg';
      errorMessage = msg;
    } finally {
      isDeploying = false;
      notifyListeners();
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
        autoSyncOnReject: project.autoSyncOnReject,
      );

      for (final line in gitResult.logs) {
        _appendDeployLog(line);
      }

      lastDeployStatus = gitResult.message;
      if (gitResult.success) {
        infoMessage = gitResult.message;
        final zipFile = File(zipPath);
        final shouldSaveToVersions =
            project.moveZipAfterPush || project.moveZipToVersionsAndDeleteSource;
        if (shouldSaveToVersions) {
          try {
            if (await zipFile.exists()) {
              final archiveDirPath = project.zipArchiveFolder.trim().isNotEmpty
                  ? p.normalize(project.zipArchiveFolder.trim())
                  : p.normalize(p.join(project.outputPath, '_zip_versions'));
              final archiveDir = Directory(archiveDirPath);
              await archiveDir.create(recursive: true);

              var destPath = p.join(archiveDir.path, fileName);
              if (await File(destPath).exists()) {
                final dotIdx = fileName.lastIndexOf('.');
                final stem = dotIdx > 0 ? fileName.substring(0, dotIdx) : fileName;
                final ext = dotIdx > 0 ? fileName.substring(dotIdx) : '';
                final now = DateTime.now();
                String two(int n) => n.toString().padLeft(2, '0');
                final stamp = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
                destPath = p.join(archiveDir.path, '${stem}_$stamp$ext');
                var counter = 2;
                while (await File(destPath).exists()) {
                  destPath = p.join(archiveDir.path, '${stem}_${stamp}_$counter$ext');
                  counter++;
                }
              }

              final shouldRemoveSource =
                  project.moveZipToVersionsAndDeleteSource || project.deleteZipAfterDeploy;
              if (shouldRemoveSource) {
                try {
                  await zipFile.rename(destPath);
                } on FileSystemException {
                  await zipFile.copy(destPath);
                  await zipFile.delete();
                }
                _appendDeployLog(
                  'ZIP перемещён в папку версий и удалён из исходной папки: $destPath',
                );
              } else {
                await zipFile.copy(destPath);
                _appendDeployLog(
                  'ZIP скопирован в папку версий (исходный файл оставлен): $destPath',
                );
              }
            }
          } catch (error) {
            _appendDeployLog('Не удалось сохранить ZIP в папку версий: $error');
          }
        } else if (project.deleteZipAfterDeploy) {
          try {
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

  void setSelectedTabIndex(int index) {
    if (index < 0 || index >= tabOrder.length) return;
    selectedTabIndex = index;
    notifyListeners();
  }

  Future<void> setLogRetentionDays(int days) async {
    final normalized = days.clamp(0, 3650);
    logRetentionDays = normalized;
    final current = await storage.loadSettings();
    await storage.saveSettings(current.copyWith(logRetentionDays: normalized));
    final prunedUnified = await storage.loadUnifiedLogHistory(
      retentionDays: normalized,
    );
    activityLogs
      ..clear()
      ..addAll(prunedUnified);
    notifyListeners();
  }

  Future<void> clearActivityLogs() async {
    activityLogs.clear();
    lastDeployStatus = null;
    await storage.clearAllLogHistories();
    notifyListeners();
  }

  Future<void> clearDeployLogs() => clearActivityLogs();

  String zipVersionsDirectoryFor(CodeProject project) {
    if (project.zipArchiveFolder.trim().isNotEmpty) {
      return p.normalize(project.zipArchiveFolder.trim());
    }
    return p.normalize(p.join(project.outputPath, '_zip_versions'));
  }

  Future<void> prepareForGracefulExit() async {
    _backupCoordinator.dispose();
    _buildPollingCoordinator.dispose();
    try {
      await _downloadsWatcher.stop();
    } catch (_) {}
  }

  Future<ProjectNoteFolder?> createProjectNoteFolder(String name) async {
    final project = currentProject;
    if (project == null) return null;
    final clean = name.trim();
    if (clean.isEmpty) return null;
    final folder = ProjectNoteFolder(
      id: 'folder_${DateTime.now().microsecondsSinceEpoch}',
      name: clean,
      createdAt: DateTime.now(),
    );
    final updated = currentProjectNotes.copyWith(
      folders: <ProjectNoteFolder>[...currentProjectNotes.folders, folder],
    );
    currentProjectNotes = updated;
    await storage.saveProjectNotes(project, updated);
    notifyListeners();
    return folder;
  }

  Future<void> renameProjectNoteFolder(String folderId, String newName) async {
    final project = currentProject;
    if (project == null) return;
    final clean = newName.trim();
    if (clean.isEmpty) return;
    final updatedFolders = currentProjectNotes.folders
        .map((f) => f.id == folderId ? f.copyWith(name: clean) : f)
        .toList();
    final updated = currentProjectNotes.copyWith(folders: updatedFolders);
    currentProjectNotes = updated;
    await storage.saveProjectNotes(project, updated);
    notifyListeners();
  }

  Future<void> deleteProjectNoteFolder(String folderId) async {
    final project = currentProject;
    if (project == null) return;
    final updatedFolders =
        currentProjectNotes.folders.where((f) => f.id != folderId).toList();
    final updatedNotes = currentProjectNotes.notes
        .map((n) => n.folderId == folderId ? n.copyWith(clearFolder: true) : n)
        .toList();
    final updated = currentProjectNotes.copyWith(
      folders: updatedFolders,
      notes: updatedNotes,
    );
    currentProjectNotes = updated;
    await storage.saveProjectNotes(project, updated);
    notifyListeners();
  }

  Future<ProjectNoteItem?> createProjectNote({
    String? folderId,
    String title = 'Новая заметка',
    String content = '',
  }) async {
    final project = currentProject;
    if (project == null) return null;
    final now = DateTime.now();
    final validFolderId = (folderId != null &&
            currentProjectNotes.folders.any((f) => f.id == folderId))
        ? folderId
        : null;
    final note = ProjectNoteItem(
      id: 'note_${now.microsecondsSinceEpoch}',
      folderId: validFolderId,
      title: title.trim().isEmpty ? 'Новая заметка' : title.trim(),
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    final updated = currentProjectNotes.copyWith(
      notes: <ProjectNoteItem>[note, ...currentProjectNotes.notes],
    );
    currentProjectNotes = updated;
    await storage.saveProjectNotes(project, updated);
    notifyListeners();
    return note;
  }

  Future<void> saveProjectNote({
    required String noteId,
    required String title,
    required String content,
    String? folderId,
    bool updateFolder = false,
  }) async {
    final project = currentProject;
    if (project == null) return;
    final cleanTitle = title.trim().isEmpty ? 'Без названия' : title.trim();
    final now = DateTime.now();
    final updatedNotes = currentProjectNotes.notes.map((n) {
      if (n.id != noteId) return n;
      return n.copyWith(
        title: cleanTitle,
        content: content,
        folderId: updateFolder ? folderId : n.folderId,
        clearFolder: updateFolder && (folderId == null || folderId.isEmpty),
        updatedAt: now,
      );
    }).toList();
    final updated = currentProjectNotes.copyWith(notes: updatedNotes);
    currentProjectNotes = updated;
    await storage.saveProjectNotes(project, updated);
    notifyListeners();
  }

  Future<void> deleteProjectNote(String noteId) async {
    final project = currentProject;
    if (project == null) return;
    final updatedNotes =
        currentProjectNotes.notes.where((n) => n.id != noteId).toList();
    final updated = currentProjectNotes.copyWith(notes: updatedNotes);
    currentProjectNotes = updated;
    await storage.saveProjectNotes(project, updated);
    notifyListeners();
  }

  Future<void> reorderTabs(int oldIndex, int newIndex) async {
    final list = List<String>.from(tabOrder);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0 || newIndex >= list.length) return;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    tabOrder = list;
    await storage.saveTabOrder(tabOrder);
    notifyListeners();
  }

  Future<void> resetTabOrder() async {
    tabOrder = const <String>['agent', 'import', 'files', 'notes', 'auto_deploy', 'build_capture'];
    await storage.saveTabOrder(tabOrder);
    notifyListeners();
  }

  Future<void> updateBackupSettings({
    required bool enabled,
    required int intervalMinutes,
    String? customBackupDir,
  }) =>
      _backupCoordinator.updateSettings(
        enabled: enabled,
        intervalMinutes: intervalMinutes,
        customBackupDir: customBackupDir,
      );

  Future<BackupResult> createBackupNow({
    bool isAuto = false,
    bool silent = false,
  }) =>
      _backupCoordinator.createBackupNow(isAuto: isAuto, silent: silent);

  Future<BackupResult> restoreBackup(String zipPath) async {
    isWorking = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _backupCoordinator.restoreBackup(zipPath);
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  void dismissGitHubBuildFailureBanner() {
    latestFailedGitHubBuild = null;
    notifyListeners();
  }

  Future<void> clearUnpackLogs() => clearActivityLogs();

  void _appendActivityLog(String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final line = '[$hh:$mm:$ss] $message';
    if (activityLogs.isNotEmpty && activityLogs.first == line) {
      return;
    }
    activityLogs.insert(0, line);
    if (activityLogs.length > 500) {
      activityLogs.removeRange(500, activityLogs.length);
    }
    unawaited(storage.appendLogEntry(
      channel: 'unified',
      line: line,
      retentionDays: logRetentionDays,
    ));
  }

  void _appendUnpackLog(String message) => _appendActivityLog(message);

  void _appendDeployLog(String message) => _appendActivityLog(message);

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

  void clearPreview() {
    previewFiles = <GeneratedFile>[];
    parserWarnings = <String>[];
    errorMessage = null;
    infoMessage = null;
    notifyListeners();
  }
}
