import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/agent_template_item.dart';
import '../models/app_settings.dart';
import '../models/code_project.dart';
import 'agent_template.dart';
import 'project_naming.dart';

class AppStorage {
  late final String applicationDirectory;
  late final String dataDirectory;
  late final String projectsDirectory;
  late final String templatesDirectory;
  late final String settingsFile;
  late final String templatesIndexFile;
  AppSettings? _settingsCache;
  Future<void> _settingsWriteQueue = Future<void>.value();

  Future<void> initialize() async {
    applicationDirectory = p.dirname(Platform.resolvedExecutable);
    dataDirectory = p.join(applicationDirectory, 'data');
    projectsDirectory = p.join(dataDirectory, 'projects');
    templatesDirectory = p.join(dataDirectory, 'templates');
    settingsFile = p.join(dataDirectory, 'settings.json');
    templatesIndexFile = p.join(templatesDirectory, 'index.json');

    await Directory(projectsDirectory).create(recursive: true);
    await Directory(templatesDirectory).create(recursive: true);
    if (!await File(settingsFile).exists()) {
      await saveSettings(const AppSettings());
    }
    await _ensureBuiltInTemplates();
  }

  Future<AppSettings> loadSettings() async {
    if (_settingsCache != null) return _settingsCache!;
    final file = File(settingsFile);
    if (!await file.exists()) {
      _settingsCache = const AppSettings();
      return _settingsCache!;
    }
    try {
      final decoded = jsonDecode(await file.readAsString(encoding: utf8));
      if (decoded is Map<String, dynamic>) {
        _settingsCache = AppSettings.fromJson(decoded);
        return _settingsCache!;
      }
    } catch (_) {
      // Повреждённые настройки не должны мешать запуску приложения.
    }
    _settingsCache = const AppSettings();
    return _settingsCache!;
  }

  Future<void> saveSettings(AppSettings settings) async {
    _settingsCache = settings;
    final previous = _settingsWriteQueue.catchError((Object _) {});
    final next = previous.then((_) async {
      await Directory(dataDirectory).create(recursive: true);
      await File(settingsFile).writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(settings.toJson())}\n',
        encoding: utf8,
        flush: true,
      );
    });
    _settingsWriteQueue = next;
    await next;
  }

  String resolveStoredPath(String value) {
    if (p.isAbsolute(value) || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value)) {
      return p.normalize(value);
    }
    final resolved = p.normalize(p.join(applicationDirectory, value));
    final root = p.normalize(applicationDirectory);
    final comparableRoot = Platform.isWindows ? root.toLowerCase() : root;
    final comparableResolved = Platform.isWindows ? resolved.toLowerCase() : resolved;
    if (comparableResolved != comparableRoot && !p.isWithin(root, resolved)) {
      throw FormatException('Относительный путь не может выходить за папку программы: "$value".');
    }
    return resolved;
  }

  String storePath(String absolutePath) {
    final normalizedRoot = p.normalize(applicationDirectory);
    final normalizedValue = p.normalize(absolutePath);
    final rootPrefix = normalizedRoot.endsWith(p.separator)
        ? normalizedRoot
        : '$normalizedRoot${p.separator}';
    final comparableRoot = Platform.isWindows ? rootPrefix.toLowerCase() : rootPrefix;
    final comparableValue = Platform.isWindows ? normalizedValue.toLowerCase() : normalizedValue;
    if (comparableValue.startsWith(comparableRoot)) {
      return p.relative(normalizedValue, from: normalizedRoot);
    }
    return normalizedValue;
  }

  String defaultOutputPath(String projectId) =>
      p.join(projectsDirectory, projectId, 'output');


  bool _samePath(String first, String second) {
    final a = p.normalize(first);
    final b = p.normalize(second);
    return Platform.isWindows ? a.toLowerCase() == b.toLowerCase() : a == b;
  }

  String packageNameFor(String projectName) => ProjectNaming.packageName(projectName);

  Future<CodeProject> createProject({
    required String name,
    required String packageName,
    required String description,
    required String templateId,
    required String templateContent,
    required String requestedOutputPath,
  }) async {
    final displayName = name.trim();
    if (displayName.isEmpty) {
      throw const FormatException('Введите название проекта.');
    }
    final safePackageName = ProjectNaming.packageName(packageName);
    var projectId = safePackageName;
    var suffix = 2;
    while (await Directory(p.join(projectsDirectory, projectId)).exists()) {
      projectId = '${safePackageName}_$suffix';
      suffix++;
    }

    final projectDirectory = p.join(projectsDirectory, projectId);
    final requested = requestedOutputPath.trim();
    final requestedResolved = requested.isEmpty ? null : resolveStoredPath(requested);
    final defaultForBaseId = p.normalize(defaultOutputPath(safePackageName));
    final requestedMatchesDefault = requestedResolved != null &&
        _samePath(requestedResolved, defaultForBaseId);
    // Если проект с таким именем уже существует, не направляем новый проект
    // в ту же папку output: используем уникальный каталог с суффиксом ID.
    final resolvedOutputPath = requestedResolved == null || requestedMatchesDefault
        ? defaultOutputPath(projectId)
        : requestedResolved;
    await Directory(projectDirectory).create(recursive: true);
    await Directory(resolvedOutputPath).create(recursive: true);

    final project = CodeProject(
      id: projectId,
      name: displayName,
      packageName: safePackageName,
      description: description,
      createdAt: DateTime.now(),
      projectDirectory: projectDirectory,
      outputPathStored: storePath(resolvedOutputPath),
      outputPath: resolvedOutputPath,
      templateId: templateId,
    );

    final projectJson = project.toJson();
    projectJson['projectDirectory'] = p.relative(projectDirectory, from: dataDirectory);
    final json = const JsonEncoder.withIndent('  ').convert(projectJson);
    await File(p.join(projectDirectory, 'project.json')).writeAsString(
      '$json\n',
      encoding: utf8,
      flush: true,
    );
    await writeAgent(project, AgentTemplate.render(
      template: templateContent,
      projectName: project.name,
      projectSlug: project.packageName,
      description: project.description,
    ));
    return project;
  }

  Future<void> writeAgent(CodeProject project, String content) async {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    await File(p.join(project.projectDirectory, 'agent.md')).writeAsString(
      normalized.endsWith('\n') ? normalized : '$normalized\n',
      encoding: utf8,
      flush: true,
    );
  }

  Future<List<CodeProject>> loadProjects() async {
    final root = Directory(projectsDirectory);
    if (!await root.exists()) return <CodeProject>[];
    final projects = <CodeProject>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final metadataFile = File(p.join(entity.path, 'project.json'));
      if (!await metadataFile.exists()) continue;
      try {
        final decoded = jsonDecode(await metadataFile.readAsString(encoding: utf8));
        if (decoded is! Map<String, dynamic>) continue;
        final storedOutput = decoded['outputPath'] as String? ?? 'output';
        projects.add(
          CodeProject.fromJson(
            decoded,
            projectDirectory: entity.path,
            resolvedOutputPath: resolveStoredPath(storedOutput),
          ),
        );
      } catch (_) {
        // Один повреждённый проект не блокирует загрузку остальных.
      }
    }
    projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return projects;
  }

  Future<String> readAgent(CodeProject project) async {
    final file = File(p.join(project.projectDirectory, 'agent.md'));
    if (!await file.exists()) return '';
    return file.readAsString(encoding: utf8);
  }

  Future<List<FileSystemEntity>> listOutputFiles(CodeProject project) async {
    final directory = Directory(project.outputPath);
    if (!await directory.exists()) return <FileSystemEntity>[];
    final entries = <FileSystemEntity>[];
    await for (final entry in directory.list(recursive: true, followLinks: false)) {
      if (entry is File) entries.add(entry);
    }
    entries.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return entries;
  }

  Future<List<AgentTemplateItem>> loadTemplates() async {
    await _ensureBuiltInTemplates();
    final decoded = jsonDecode(await File(templatesIndexFile).readAsString(encoding: utf8));
    if (decoded is! List) return AgentTemplate.builtInTemplates();
    final templates = <AgentTemplateItem>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'] as String?;
      final name = item['name'] as String?;
      if (id == null || name == null || !_isSafeTemplateId(id)) continue;
      final file = File(p.join(templatesDirectory, '$id.md'));
      if (!await file.exists()) continue;
      templates.add(AgentTemplateItem(
        id: id,
        name: name,
        content: await file.readAsString(encoding: utf8),
        isBuiltIn: item['isBuiltIn'] == true,
      ));
    }
    return templates;
  }

  Future<void> saveTemplate(AgentTemplateItem template) async {
    if (!_isSafeTemplateId(template.id)) {
      throw const FormatException('Недопустимый идентификатор шаблона.');
    }
    if (template.name.trim().isEmpty) {
      throw const FormatException('Введите название шаблона.');
    }
    final file = File(p.join(templatesDirectory, '${template.id}.md'));
    final content = template.content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    await file.writeAsString(content, encoding: utf8, flush: true);

    final entries = await _readTemplateIndex();
    final next = <Map<String, Object?>>[];
    var replaced = false;
    for (final entry in entries) {
      if (entry['id'] == template.id) {
        next.add({'id': template.id, 'name': template.name.trim(), 'isBuiltIn': template.isBuiltIn});
        replaced = true;
      } else {
        next.add(entry);
      }
    }
    if (!replaced) {
      next.add({'id': template.id, 'name': template.name.trim(), 'isBuiltIn': template.isBuiltIn});
    }
    await _writeTemplateIndex(next);
  }

  Future<void> deleteTemplate(String id) async {
    final entries = await _readTemplateIndex();
    Map<String, dynamic>? target;
    for (final entry in entries) {
      if (entry['id'] == id) {
        target = entry;
        break;
      }
    }
    if (target == null) return;
    if (target['isBuiltIn'] == true) {
      throw StateError('Встроенный шаблон нельзя удалить. Его можно редактировать или копировать.');
    }
    final templateFile = File(p.join(templatesDirectory, '$id.md'));
    if (await templateFile.exists()) {
      await templateFile.delete();
    }
    entries.removeWhere((entry) => entry['id'] == id);
    await _writeTemplateIndex(entries);
  }

  Future<void> writeWindowSize(double width, double height) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(windowWidth: width, windowHeight: height));
  }

  Future<void> saveLastProject(String? projectId) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(
      lastProjectId: projectId,
      clearLastProject: projectId == null,
    ));
  }

  Future<void> saveSelectedTemplate(String templateId) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(selectedTemplateId: templateId));
  }

  Future<void> saveDownloadsWatcherSettings({
    String? downloadsWatchPath,
    bool? downloadsWatcherEnabled,
  }) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(
      downloadsWatchPath: downloadsWatchPath,
      downloadsWatcherEnabled: downloadsWatcherEnabled,
    ));
  }

  Future<void> saveTabOrder(List<String> tabOrder) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(
      tabOrder: List<String>.from(tabOrder),
    ));
  }

  Future<void> saveGitHubCredentials({
    required String githubToken,
    required String githubOwner,
  }) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(
      githubToken: githubToken.trim(),
      githubOwner: githubOwner.trim(),
    ));
  }

  Future<void> saveBackupSettings({
    required bool autoBackupEnabled,
    required int autoBackupIntervalMinutes,
    String? backupDirectory,
  }) async {
    final current = await loadSettings();
    final cleanDir = backupDirectory?.trim() ?? '';
    await saveSettings(current.copyWith(
      autoBackupEnabled: autoBackupEnabled,
      autoBackupIntervalMinutes: autoBackupIntervalMinutes.clamp(5, 1440),
      backupDirectory: cleanDir.isEmpty ? null : cleanDir,
      clearBackupDirectory: cleanDir.isEmpty,
    ));
  }

  Future<void> recordLastAutoBackup(String isoTimestamp) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(lastAutoBackupAt: isoTimestamp));
  }

  Future<void> updateProject(CodeProject project) async {
    final projectJson = project.toJson();
    projectJson['projectDirectory'] = p.relative(project.projectDirectory, from: dataDirectory);
    final json = const JsonEncoder.withIndent('  ').convert(projectJson);
    await File(p.join(project.projectDirectory, 'project.json')).writeAsString(
      '$json\n',
      encoding: utf8,
      flush: true,
    );
  }

  Future<CodeProject> renameProject(CodeProject project, String newName) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) {
      throw const FormatException('Введите название проекта.');
    }
    final nextPackageName = ProjectNaming.packageName(cleanName);
    final updated = project.copyWith(
      name: cleanName,
      packageName: nextPackageName,
    );
    await updateProject(updated);
    return updated;
  }

  Future<void> _ensureBuiltInTemplates() async {
    final builtIns = AgentTemplate.builtInTemplates();
    if (!await File(templatesIndexFile).exists()) {
      for (final template in builtIns) {
        await File(p.join(templatesDirectory, '${template.id}.md')).writeAsString(
          template.content,
          encoding: utf8,
          flush: true,
        );
      }
      await _writeTemplateIndex(builtIns.map((template) => <String, Object?>{
            'id': template.id,
            'name': template.name,
            'isBuiltIn': true,
          }).toList());
      return;
    }

    final existingEntries = await _readTemplateIndex();
    final existingIds = existingEntries
        .map((entry) => entry['id'])
        .whereType<String>()
        .toSet();
    final updated = List<Map<String, Object?>>.from(existingEntries);
    var changed = false;

    for (final template in builtIns) {
      final templateFile = File(p.join(templatesDirectory, '${template.id}.md'));
      if (!existingIds.contains(template.id)) {
        if (!await templateFile.exists()) {
          await templateFile.writeAsString(
            template.content,
            encoding: utf8,
            flush: true,
          );
        }
        updated.add(<String, Object?>{
          'id': template.id,
          'name': template.name,
          'isBuiltIn': true,
        });
        changed = true;
      } else if (!await templateFile.exists()) {
        await templateFile.writeAsString(
          template.content,
          encoding: utf8,
          flush: true,
        );
      }
    }

    if (changed) {
      await _writeTemplateIndex(updated);
    }
  }

  bool _isSafeTemplateId(String id) =>
      RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id);

  Future<List<Map<String, dynamic>>> _readTemplateIndex() async {
    if (!await File(templatesIndexFile).exists()) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(await File(templatesIndexFile).readAsString(encoding: utf8));
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _writeTemplateIndex(List<Map<String, Object?>> entries) async {
    await File(templatesIndexFile).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
      encoding: utf8,
      flush: true,
    );
  }
}
