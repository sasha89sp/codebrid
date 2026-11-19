class AppSettings {
  const AppSettings({
    this.lastProjectId,
    this.windowWidth,
    this.windowHeight,
    this.selectedTemplateId,
    this.downloadsWatchPath,
    this.downloadsWatcherEnabled = false,
  });

  final String? lastProjectId;
  final double? windowWidth;
  final double? windowHeight;
  final String? selectedTemplateId;
  final String? downloadsWatchPath;
  final bool downloadsWatcherEnabled;

  AppSettings copyWith({
    String? lastProjectId,
    double? windowWidth,
    double? windowHeight,
    String? selectedTemplateId,
    String? downloadsWatchPath,
    bool? downloadsWatcherEnabled,
    bool clearLastProject = false,
  }) {
    return AppSettings(
      lastProjectId: clearLastProject ? null : (lastProjectId ?? this.lastProjectId),
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      downloadsWatchPath: downloadsWatchPath ?? this.downloadsWatchPath,
      downloadsWatcherEnabled: downloadsWatcherEnabled ?? this.downloadsWatcherEnabled,
    );
  }

  Map<String, Object?> toJson() => {
        'lastProjectId': lastProjectId,
        'windowWidth': windowWidth,
        'windowHeight': windowHeight,
        'selectedTemplateId': selectedTemplateId,
        'downloadsWatchPath': downloadsWatchPath,
        'downloadsWatcherEnabled': downloadsWatcherEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      lastProjectId: json['lastProjectId'] as String?,
      windowWidth: (json['windowWidth'] as num?)?.toDouble(),
      windowHeight: (json['windowHeight'] as num?)?.toDouble(),
      selectedTemplateId: json['selectedTemplateId'] as String?,
      downloadsWatchPath: json['downloadsWatchPath'] as String?,
      downloadsWatcherEnabled: json['downloadsWatcherEnabled'] == true,
    );
  }
}
