class AppSettings {
  const AppSettings({
    this.lastProjectId,
    this.windowWidth,
    this.windowHeight,
    this.windowIsMaximized = false,
    this.windowIsFullScreen = false,
    this.selectedTemplateId,
    this.downloadsWatchPath,
    this.downloadsWatcherEnabled = false,
    this.tabOrder = const <String>['agent', 'import', 'files', 'auto_deploy', 'build_capture'],
    this.githubToken = '',
    this.githubOwner = '',
    this.autoBackupEnabled = true,
    this.autoBackupIntervalMinutes = 30,
    this.backupDirectory,
    this.lastAutoBackupAt,
  });

  final String? lastProjectId;
  final double? windowWidth;
  final double? windowHeight;
  final bool windowIsMaximized;
  final bool windowIsFullScreen;
  final String? selectedTemplateId;
  final String? downloadsWatchPath;
  final bool downloadsWatcherEnabled;
  final List<String> tabOrder;
  final String githubToken;
  final String githubOwner;
  final bool autoBackupEnabled;
  final int autoBackupIntervalMinutes;
  final String? backupDirectory;
  final String? lastAutoBackupAt;

  AppSettings copyWith({
    String? lastProjectId,
    double? windowWidth,
    double? windowHeight,
    bool? windowIsMaximized,
    bool? windowIsFullScreen,
    String? selectedTemplateId,
    String? downloadsWatchPath,
    bool? downloadsWatcherEnabled,
    List<String>? tabOrder,
    String? githubToken,
    String? githubOwner,
    bool? autoBackupEnabled,
    int? autoBackupIntervalMinutes,
    String? backupDirectory,
    String? lastAutoBackupAt,
  bool clearBackupDirectory = false,    bool clearLastProject = false,
  }) {
    return AppSettings(
      lastProjectId: clearLastProject ? null : (lastProjectId ?? this.lastProjectId),
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      windowIsMaximized: windowIsMaximized ?? this.windowIsMaximized,
      windowIsFullScreen: windowIsFullScreen ?? this.windowIsFullScreen,
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      downloadsWatchPath: downloadsWatchPath ?? this.downloadsWatchPath,
      downloadsWatcherEnabled: downloadsWatcherEnabled ?? this.downloadsWatcherEnabled,
      tabOrder: tabOrder ?? this.tabOrder,
      githubToken: githubToken ?? this.githubToken,
      githubOwner: githubOwner ?? this.githubOwner,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupIntervalMinutes: autoBackupIntervalMinutes ?? this.autoBackupIntervalMinutes,
      backupDirectory: clearBackupDirectory ? null : (backupDirectory ?? this.backupDirectory),
      lastAutoBackupAt: lastAutoBackupAt ?? this.lastAutoBackupAt,
    );
  }

  Map<String, Object?> toJson() => {
        'lastProjectId': lastProjectId,
        'windowWidth': windowWidth,
        'windowHeight': windowHeight,
        'windowIsMaximized': windowIsMaximized,
        'windowIsFullScreen': windowIsFullScreen,
        'selectedTemplateId': selectedTemplateId,
        'downloadsWatchPath': downloadsWatchPath,
        'downloadsWatcherEnabled': downloadsWatcherEnabled,
        'tabOrder': tabOrder,
        'githubToken': githubToken,
        'githubOwner': githubOwner,
        'autoBackupEnabled': autoBackupEnabled,
        'autoBackupIntervalMinutes': autoBackupIntervalMinutes,
        'backupDirectory': backupDirectory,
        'lastAutoBackupAt': lastAutoBackupAt,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      lastProjectId: json['lastProjectId'] as String?,
      windowWidth: (json['windowWidth'] as num?)?.toDouble(),
      windowHeight: (json['windowHeight'] as num?)?.toDouble(),
      windowIsMaximized: json['windowIsMaximized'] == true,
      windowIsFullScreen: json['windowIsFullScreen'] == true,
      selectedTemplateId: json['selectedTemplateId'] as String?,
      downloadsWatchPath: json['downloadsWatchPath'] as String?,
      downloadsWatcherEnabled: json['downloadsWatcherEnabled'] == true,
      tabOrder: (json['tabOrder'] is List)
          ? (json['tabOrder'] as List).map((e) => e.toString()).toList()
          : const <String>['agent', 'import', 'files', 'auto_deploy', 'build_capture'],
      githubToken: json['githubToken']?.toString() ?? '',
      githubOwner: json['githubOwner']?.toString() ?? '',
      autoBackupEnabled: json['autoBackupEnabled'] != false,
      autoBackupIntervalMinutes: (json['autoBackupIntervalMinutes'] as num?)?.toInt() ?? 30,
      backupDirectory: json['backupDirectory'] as String?,
      lastAutoBackupAt: json['lastAutoBackupAt'] as String?,
    );
  }
}
