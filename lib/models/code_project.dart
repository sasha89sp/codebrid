class CodeProject {
  const CodeProject({
    required this.id,
    required this.name,
    required this.packageName,
    required this.description,
    required this.createdAt,
    required this.projectDirectory,
    required this.outputPathStored,
    required this.outputPath,
    required this.templateId,
    this.gitRepoUrl = '',
    this.gitBranch = 'main',
    this.autoDeployEnabled = false,
    this.zipNameFilter = '',
    this.deleteZipAfterDeploy = false,
    this.cleanBeforeExtract = false,
    this.buildCaptureEnabled = false,
    this.buildAskTargetBeforeExtract = false,
    this.buildTargetDirectory = '',
    this.buildZipFilter = '',
    this.buildPreservedFiles = '',
    this.buildTakeAllPublicBuilds = true,
  });

  /// Уникальное имя каталога внутри data/projects.
  final String id;

  /// Оригинальное название — может быть на любом языке.
  final String name;

  /// Безопасное ASCII-имя Dart/Flutter-пакета.
  final String packageName;
  final String description;
  final DateTime createdAt;
  final String projectDirectory;
  final String outputPathStored;
  final String outputPath;
  final String templateId;

  /// Настройки авто-деплоя ZIP -> GitHub.
  final String gitRepoUrl;
  final String gitBranch;
  final bool autoDeployEnabled;
  final String zipNameFilter;
  final bool deleteZipAfterDeploy;
  final bool cleanBeforeExtract;
  final bool buildCaptureEnabled;
  final bool buildAskTargetBeforeExtract;
  final String buildTargetDirectory;
  final String buildZipFilter;
  final String buildPreservedFiles;
  final bool buildTakeAllPublicBuilds;

  CodeProject copyWith({
    String? name,
    String? packageName,
    String? description,
    String? outputPathStored,
    String? outputPath,
    String? templateId,
    String? gitRepoUrl,
    String? gitBranch,
    bool? autoDeployEnabled,
    String? zipNameFilter,
    bool? deleteZipAfterDeploy,
    bool? cleanBeforeExtract,
    bool? buildCaptureEnabled,
    bool? buildAskTargetBeforeExtract,
    String? buildTargetDirectory,
    String? buildZipFilter,
    String? buildPreservedFiles,
    bool? buildTakeAllPublicBuilds,
  }) {
    return CodeProject(
      id: id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      description: description ?? this.description,
      createdAt: createdAt,
      projectDirectory: projectDirectory,
      outputPathStored: outputPathStored ?? this.outputPathStored,
      outputPath: outputPath ?? this.outputPath,
      templateId: templateId ?? this.templateId,
      gitRepoUrl: gitRepoUrl ?? this.gitRepoUrl,
      gitBranch: gitBranch ?? this.gitBranch,
      autoDeployEnabled: autoDeployEnabled ?? this.autoDeployEnabled,
      zipNameFilter: zipNameFilter ?? this.zipNameFilter,
      deleteZipAfterDeploy: deleteZipAfterDeploy ?? this.deleteZipAfterDeploy,
      cleanBeforeExtract: cleanBeforeExtract ?? this.cleanBeforeExtract,
      buildCaptureEnabled: buildCaptureEnabled ?? this.buildCaptureEnabled,
      buildAskTargetBeforeExtract: buildAskTargetBeforeExtract ?? this.buildAskTargetBeforeExtract,
      buildTargetDirectory: buildTargetDirectory ?? this.buildTargetDirectory,
      buildZipFilter: buildZipFilter ?? this.buildZipFilter,
      buildPreservedFiles: buildPreservedFiles ?? this.buildPreservedFiles,
      buildTakeAllPublicBuilds: buildTakeAllPublicBuilds ?? this.buildTakeAllPublicBuilds,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'packageName': packageName,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'projectDirectory': projectDirectory,
        'outputPath': outputPathStored,
        'outputPathType': _isAbsoluteLike(outputPathStored) ? 'absolute' : 'relative',
        'templateId': templateId,
        'gitRepoUrl': gitRepoUrl,
        'gitBranch': gitBranch,
        'autoDeployEnabled': autoDeployEnabled,
        'zipNameFilter': zipNameFilter,
        'deleteZipAfterDeploy': deleteZipAfterDeploy,
        'cleanBeforeExtract': cleanBeforeExtract,
        'buildCaptureEnabled': buildCaptureEnabled,
        'buildAskTargetBeforeExtract': buildAskTargetBeforeExtract,
        'buildTargetDirectory': buildTargetDirectory,
        'buildZipFilter': buildZipFilter,
        'buildPreservedFiles': buildPreservedFiles,
        'buildTakeAllPublicBuilds': buildTakeAllPublicBuilds,
      };

  factory CodeProject.fromJson(
    Map<String, dynamic> json, {
    required String projectDirectory,
    required String resolvedOutputPath,
  }) {
    final id = json['id'] as String;
    final rawBranch = (json['gitBranch'] as String?)?.trim() ?? '';
    return CodeProject(
      id: id,
      name: json['name'] as String? ?? id,
      packageName: json['packageName'] as String? ?? id,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      projectDirectory: projectDirectory,
      outputPathStored: json['outputPath'] as String? ?? 'output',
      outputPath: resolvedOutputPath,
      templateId: json['templateId'] as String? ?? 'flutter-monorepo-agents',
      gitRepoUrl: (json['gitRepoUrl'] as String? ?? '').trim(),
      gitBranch: rawBranch.isEmpty ? 'main' : rawBranch,
      autoDeployEnabled: json['autoDeployEnabled'] == true,
      zipNameFilter: (json['zipNameFilter'] as String? ?? '').trim(),
      deleteZipAfterDeploy: json['deleteZipAfterDeploy'] == true,
      cleanBeforeExtract: json['cleanBeforeExtract'] == true,
      buildCaptureEnabled: json['buildCaptureEnabled'] == true,
      buildAskTargetBeforeExtract: json['buildAskTargetBeforeExtract'] == true,
      buildTargetDirectory: json['buildTargetDirectory']?.toString() ?? '',
      buildZipFilter: json['buildZipFilter']?.toString() ?? '',
      buildPreservedFiles: json['buildPreservedFiles']?.toString() ?? '',
      buildTakeAllPublicBuilds: json['buildTakeAllPublicBuilds'] != false,
    );
  }

  static bool _isAbsoluteLike(String value) {
    return value.startsWith('/') ||
        value.startsWith('\\\\') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
  }
}
