class ProjectNoteFolder {
  const ProjectNoteFolder({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  ProjectNoteFolder copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return ProjectNoteFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ProjectNoteFolder.fromJson(Map<String, dynamic> json) {
    return ProjectNoteFolder(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Папка',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ProjectNoteItem {
  const ProjectNoteItem({
    required this.id,
    this.folderId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? folderId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectNoteItem copyWith({
    String? id,
    String? folderId,
    bool clearFolder = false,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectNoteItem(
      id: id ?? this.id,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'folderId': folderId,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ProjectNoteItem.fromJson(Map<String, dynamic> json) {
    final rawFolder = json['folderId']?.toString();
    return ProjectNoteItem(
      id: json['id']?.toString() ?? '',
      folderId: (rawFolder == null || rawFolder.isEmpty) ? null : rawFolder,
      title: json['title']?.toString() ?? 'Без названия',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ProjectNotesStore {
  const ProjectNotesStore({
    this.folders = const <ProjectNoteFolder>[],
    this.notes = const <ProjectNoteItem>[],
  });

  final List<ProjectNoteFolder> folders;
  final List<ProjectNoteItem> notes;

  ProjectNotesStore copyWith({
    List<ProjectNoteFolder>? folders,
    List<ProjectNoteItem>? notes,
  }) {
    return ProjectNotesStore(
      folders: folders ?? this.folders,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() => {
        'folders': folders.map((f) => f.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  factory ProjectNotesStore.fromJson(Map<String, dynamic> json) {
    final rawFolders = json['folders'];
    final rawNotes = json['notes'];
    final folders = (rawFolders is List)
        ? rawFolders
            .whereType<Map<String, dynamic>>()
            .map(ProjectNoteFolder.fromJson)
            .where((f) => f.id.isNotEmpty)
            .toList()
        : <ProjectNoteFolder>[];
    final notes = (rawNotes is List)
        ? rawNotes
            .whereType<Map<String, dynamic>>()
            .map(ProjectNoteItem.fromJson)
            .where((n) => n.id.isNotEmpty)
            .toList()
        : <ProjectNoteItem>[];
    return ProjectNotesStore(folders: folders, notes: notes);
  }
}
