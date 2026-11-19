import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_note.dart';
import '../providers/project_provider.dart';
import 'section_header.dart';

class ProjectNotesTab extends StatefulWidget {
  const ProjectNotesTab({super.key});

  @override
  State<ProjectNotesTab> createState() => _ProjectNotesTabState();
}

class _ProjectNotesTabState extends State<ProjectNotesTab> {
  static const String _allFilter = '__all__';
  static const String _unfiledFilter = '__unfiled__';

  final TextEditingController _newFolderController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String? _loadedProjectId;
  String _selectedFolderFilter = _allFilter;
  String? _selectedNoteId;
  String? _editingNoteFolderId;
  bool _isCreatingFolder = false;
  bool _hasDirtyChanges = false;
  String _statusMessage = '';

  @override
  void dispose() {
    _newFolderController.dispose();
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _syncProject(ProjectProvider provider) {
    final project = provider.currentProject;
    if (project == null) return;
    if (_loadedProjectId != project.id) {
      _loadedProjectId = project.id;
      _selectedFolderFilter = _allFilter;
      _isCreatingFolder = false;
      _newFolderController.clear();
      _searchController.clear();
      _statusMessage = '';
      _hasDirtyChanges = false;
      final notes = provider.currentProjectNotes.notes;
      if (notes.isNotEmpty) {
        _loadNoteIntoEditor(notes.first);
      } else {
        _selectedNoteId = null;
        _editingNoteFolderId = null;
        _titleController.clear();
        _contentController.clear();
      }
      return;
    }

    final store = provider.currentProjectNotes;
    if (_selectedFolderFilter != _allFilter &&
        _selectedFolderFilter != _unfiledFilter &&
        !store.folders.any((f) => f.id == _selectedFolderFilter)) {
      _selectedFolderFilter = _allFilter;
    }

    if (_selectedNoteId != null &&
        !store.notes.any((n) => n.id == _selectedNoteId)) {
      _selectedNoteId = null;
      _editingNoteFolderId = null;
      _hasDirtyChanges = false;
      _titleController.clear();
      _contentController.clear();
    }
  }

  void _loadNoteIntoEditor(ProjectNoteItem note) {
    _selectedNoteId = note.id;
    _editingNoteFolderId = note.folderId;
    _hasDirtyChanges = false;
    _statusMessage = '';
    _titleController.value = TextEditingValue(
      text: note.title,
      selection: TextSelection.collapsed(offset: note.title.length),
    );
    _contentController.value = TextEditingValue(
      text: note.content,
      selection: TextSelection.collapsed(offset: note.content.length),
    );
  }

  List<ProjectNoteItem> _filteredNotes(ProjectNotesStore store) {
    final query = _searchController.text.trim().toLowerCase();
    return store.notes.where((note) {
      if (_selectedFolderFilter == _unfiledFilter) {
        if (note.folderId != null && note.folderId!.isNotEmpty) return false;
      } else if (_selectedFolderFilter != _allFilter) {
        if (note.folderId != _selectedFolderFilter) return false;
      }
      if (query.isEmpty) return true;
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _submitNewFolder(ProjectProvider provider) async {
    final name = _newFolderController.text.trim();
    if (name.isEmpty) {
      setState(() => _isCreatingFolder = false);
      return;
    }
    final created = await provider.createProjectNoteFolder(name);
    if (!mounted) return;
    setState(() {
      _newFolderController.clear();
      _isCreatingFolder = false;
      if (created != null) {
        _selectedFolderFilter = created.id;
      }
    });
  }

  Future<void> _createNote(ProjectProvider provider, {bool isBugTemplate = false}) async {
    final targetFolderId = (_selectedFolderFilter == _allFilter ||
            _selectedFolderFilter == _unfiledFilter)
        ? null
        : _selectedFolderFilter;
    final created = await provider.createProjectNote(
      folderId: targetFolderId,
      title: isBugTemplate ? 'Баг: ' : 'Новая заметка',
      content: isBugTemplate
          ? 'Что сломалось:\n\nКак воспроизвести:\n1. \n2. \n\nОжидаемое поведение:\n'
          : '',
    );
    if (!mounted || created == null) return;
    setState(() {
      _loadNoteIntoEditor(created);
    });
  }

  Future<void> _saveCurrentNote(ProjectProvider provider) async {
    final noteId = _selectedNoteId;
    if (noteId == null) return;
    await provider.saveProjectNote(
      noteId: noteId,
      title: _titleController.text,
      content: _contentController.text,
      folderId: _editingNoteFolderId,
      updateFolder: true,
    );
    if (!mounted) return;
    setState(() {
      _hasDirtyChanges = false;
      _statusMessage = 'Заметка сохранена.';
    });
  }

  Future<void> _deleteCurrentNote(ProjectProvider provider) async {
    final noteId = _selectedNoteId;
    if (noteId == null) return;
    await provider.deleteProjectNote(noteId);
    if (!mounted) return;
    final remaining = _filteredNotes(provider.currentProjectNotes);
    setState(() {
      if (remaining.isNotEmpty) {
        _loadNoteIntoEditor(remaining.first);
      } else {
        _selectedNoteId = null;
        _editingNoteFolderId = null;
        _hasDirtyChanges = false;
        _titleController.clear();
        _contentController.clear();
      }
      _statusMessage = 'Заметка удалена.';
    });
  }

  String _formatShortDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = provider.currentProject;
    if (project == null) {
      return const Center(child: Text('Выберите проект'));
    }
    _syncProject(provider);

    final store = provider.currentProjectNotes;
    final visibleNotes = _filteredNotes(store);
    final selectedNote = store.notes.where((n) => n.id == _selectedNoteId).firstOrNull;
    final validDropdownFolderId = (_editingNoteFolderId != null &&
            store.folders.any((f) => f.id == _editingNoteFolderId))
        ? _editingNoteFolderId
        : null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  title: 'Заметки проекта «${project.name}»',
                  subtitle:
                      'Папки и заметки для багов, идей и чек-листов — привязаны только к этому проекту.',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => unawaited(_createNote(provider, isBugTemplate: true)),
                icon: const Icon(Icons.bug_report_outlined, size: 18),
                label: const Text('Записать баг'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => unawaited(_createNote(provider)),
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: const Text('Новая заметка'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Folders column
                SizedBox(
                  width: 220,
                  child: Container(
                    padding: const EdgeInsets.all(12),
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
                            const Expanded(
                              child: Text(
                                'Папки',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: Color(0xFF1F2A40),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Создать папку',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                setState(() {
                                  _isCreatingFolder = !_isCreatingFolder;
                                  _newFolderController.clear();
                                });
                              },
                              icon: const Icon(Icons.create_new_folder_outlined, size: 19),
                            ),
                          ],
                        ),
                        if (_isCreatingFolder) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newFolderController,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: 'Имя папки...',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 9,
                                    ),
                                  ),
                                  onSubmitted: (_) => unawaited(_submitNewFolder(provider)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Создать',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => unawaited(_submitNewFolder(provider)),
                                icon: const Icon(Icons.check_rounded, size: 18),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: [
                              _FolderTile(
                                icon: Icons.notes_rounded,
                                title: 'Все заметки',
                                count: store.notes.length,
                                selected: _selectedFolderFilter == _allFilter,
                                onTap: () => setState(() => _selectedFolderFilter = _allFilter),
                              ),
                              _FolderTile(
                                icon: Icons.inbox_outlined,
                                title: 'Без папки',
                                count: store.notes
                                    .where((n) => n.folderId == null || n.folderId!.isEmpty)
                                    .length,
                                selected: _selectedFolderFilter == _unfiledFilter,
                                onTap: () => setState(() => _selectedFolderFilter = _unfiledFilter),
                              ),
                              if (store.folders.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Divider(height: 1),
                                ),
                                ...store.folders.map((folder) {
                                  final count = store.notes
                                      .where((n) => n.folderId == folder.id)
                                      .length;
                                  return _FolderTile(
                                    icon: Icons.folder_outlined,
                                    title: folder.name,
                                    count: count,
                                    selected: _selectedFolderFilter == folder.id,
                                    onTap: () =>
                                        setState(() => _selectedFolderFilter = folder.id),
                                    onDelete: () =>
                                        unawaited(provider.deleteProjectNoteFolder(folder.id)),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // 2. Notes list column
                SizedBox(
                  width: 265,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE4E9F2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Поиск по заметкам...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: visibleNotes.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.sticky_note_2_outlined,
                                          size: 32,
                                          color: Color(0xFF9AA4B8),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'В этой папке пока нет заметок',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF7B869B),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextButton.icon(
                                          onPressed: () => unawaited(_createNote(provider)),
                                          icon: const Icon(Icons.add_rounded, size: 17),
                                          label: const Text('Создать заметку'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: visibleNotes.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final item = visibleNotes[index];
                                    final isSelected = item.id == _selectedNoteId;
                                    final preview = item.content
                                        .replaceAll('\n', ' ')
                                        .trim();
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        setState(() {
                                          _loadNoteIntoEditor(item);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFEEF2FF)
                                              : const Color(0xFFF9FAFD),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? Theme.of(context).colorScheme.primary
                                                : const Color(0xFFE7ECF5),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.title,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                      color: Color(0xFF1F2A40),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _formatShortDate(item.updatedAt),
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: Color(0xFF8C96AA),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (preview.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                preview,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Color(0xFF6B768B),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // 3. Inline note editor column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE4E9F2)),
                    ),
                    child: selectedNote == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.edit_note_rounded,
                                  size: 40,
                                  color: Color(0xFF9AA4B8),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Выберите заметку слева или создайте новую',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF6F7B90),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => unawaited(_createNote(provider)),
                                      icon: const Icon(Icons.note_add_outlined, size: 18),
                                      label: const Text('Новая заметка'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          unawaited(_createNote(provider, isBugTemplate: true)),
                                      icon: const Icon(Icons.bug_report_outlined, size: 18),
                                      label: const Text('Записать баг'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: _titleController,
                                      onChanged: (_) {
                                        if (!_hasDirtyChanges || _statusMessage.isNotEmpty) {
                                          setState(() {
                                            _hasDirtyChanges = true;
                                            _statusMessage = '';
                                          });
                                        }
                                      },
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Заголовок заметки',
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String?>(
                                      value: validDropdownFolderId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Папка',
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      items: <DropdownMenuItem<String?>>[
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('Без папки'),
                                        ),
                                        ...store.folders.map(
                                          (f) => DropdownMenuItem<String?>(
                                            value: f.id,
                                            child: Text(
                                              f.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (String? newFolderId) {
                                        setState(() {
                                          _editingNoteFolderId = newFolderId;
                                          _hasDirtyChanges = true;
                                          _statusMessage = '';
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: TextField(
                                  controller: _contentController,
                                  expands: true,
                                  minLines: null,
                                  maxLines: null,
                                  readOnly: false,
                                  textAlignVertical: TextAlignVertical.top,
                                  onChanged: (_) {
                                    if (!_hasDirtyChanges || _statusMessage.isNotEmpty) {
                                      setState(() {
                                        _hasDirtyChanges = true;
                                        _statusMessage = '';
                                      });
                                    }
                                  },
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.55,
                                    color: Color(0xFF283246),
                                  ),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Опишите баг, шаги воспроизведения, заметки по проекту или задачи...',
                                    alignLabelWithHint: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),
                              if (_statusMessage.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _statusMessage,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF267B5D),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => unawaited(_deleteCurrentNote(provider)),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                    label: const Text('Удалить заметку'),
                                  ),
                                  const Spacer(),
                                  FilledButton.icon(
                                    onPressed: () => unawaited(_saveCurrentNote(provider)),
                                    icon: const Icon(Icons.save_outlined, size: 18),
                                    label: Text(
                                      _hasDirtyChanges
                                          ? 'Сохранить заметку*'
                                          : 'Сохранить заметку',
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final IconData icon;
  final String title;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF1FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF5D687E),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: const Color(0xFF232E43),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8892A6),
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 2),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Color(0xFF939DB0),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
