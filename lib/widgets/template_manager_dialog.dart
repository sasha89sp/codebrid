import 'package:flutter/material.dart';

import '../models/agent_template_item.dart';
import '../providers/project_provider.dart';

Future<void> showTemplateManagerDialog(
  BuildContext context,
  ProjectProvider provider,
) async {
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TemplateManagerScreen(provider: provider),
    ),
  );
}

class TemplateManagerScreen extends StatefulWidget {
  const TemplateManagerScreen({
    super.key,
    required this.provider,
  });

  final ProjectProvider provider;

  @override
  State<TemplateManagerScreen> createState() => _TemplateManagerScreenState();
}

class _TemplateManagerScreenState extends State<TemplateManagerScreen> {
  late List<AgentTemplateItem> _templates;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _selectedId;
  String _error = '';
  bool _saving = false;
  bool _isDraftNew = false;

  @override
  void initState() {
    super.initState();
    _templates = List<AgentTemplateItem>.from(widget.provider.templates);
    if (_templates.isNotEmpty) {
      _select(_templates.first.id, isDraftNew: false);
    }
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

  void _select(String id, {bool isDraftNew = false}) {
    final matches = _templates.where((template) => template.id == id).toList();
    if (matches.isEmpty) return;
    final item = matches.first;
    setState(() {
      _selectedId = id;
      _isDraftNew = isDraftNew;
      _nameController.text = item.name;
      _contentController.text = item.content;
      _error = '';
    });
  }

  void _newTemplate() {
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    final template = AgentTemplateItem(
      id: id,
      name: 'Новый шаблон',
      content:
          '# Инструкция для {{project_name}}\n\nОписание задачи:\n{{project_description}}\n\n## Формат файлов\nДля каждого файла используй:\n\n<<<FILE: relative/path>>>\nполное содержимое\n<<<END>>>\n\n<<<END_PROJECT>>>\n',
      isBuiltIn: false,
    );
    setState(() {
      _templates = <AgentTemplateItem>[template, ..._templates];
    });
    _select(id, isDraftNew: true);
  }

  Future<void> _duplicateTemplate() async {
    final current = _selected;
    if (current == null) return;
    final baseTitle = _nameController.text.trim().isEmpty
        ? current.name
        : _nameController.text.trim();
    final duplicate = AgentTemplateItem(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: '$baseTitle — копия',
      content: _contentController.text,
      isBuiltIn: false,
    );
    setState(() {
      _templates = <AgentTemplateItem>[duplicate, ..._templates];
    });
    _select(duplicate.id, isDraftNew: false);
    await _saveTemplate();
  }

  Future<void> _saveTemplate() async {
    final current = _selected;
    if (current == null) return;
    final cleanName = _nameController.text.trim();
    if (cleanName.isEmpty) {
      setState(() => _error = 'Введите название шаблона.');
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    final updated = current.copyWith(
      name: cleanName,
      content: _contentController.text,
      isBuiltIn: false,
    );
    try {
      await widget.provider.saveTemplate(updated);
      if (!mounted) return;
      final merged = List<AgentTemplateItem>.from(widget.provider.templates);
      if (!merged.any((t) => t.id == updated.id)) {
        merged.insert(0, updated);
      }
      setState(() {
        _templates = merged;
        _selectedId = updated.id;
        _isDraftNew = false;
        _error = 'Шаблон сохранён.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Шаблон «${updated.name}» сохранён.')),
      );
    } catch (error) {
      if (mounted) {
        final msg = 'Не удалось сохранить: $error';
        setState(() => _error = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteTemplate() async {
    final current = _selected;
    if (current == null) return;
    if (current.isBuiltIn) {
      setState(
        () => _error =
            'Встроенный шаблон нельзя удалить. Его можно редактировать или копировать.',
      );
      return;
    }
    try {
      await widget.provider.deleteTemplate(current.id);
      if (!mounted) return;
      setState(() {
        _templates = List<AgentTemplateItem>.from(widget.provider.templates);
        _selectedId = _templates.isEmpty ? null : _templates.first.id;
        _isDraftNew = false;
      });
      if (_selectedId != null) {
        _select(_selectedId!, isDraftNew: false);
      } else {
        _nameController.clear();
        _contentController.clear();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Назад к проекту',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.library_books_outlined, size: 22),
            SizedBox(width: 10),
            Text(
              'Библиотека шаблонов AGENT.md',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Готово'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4E9F2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: _saving ? null : _newTemplate,
                            icon: const Icon(Icons.add),
                            label: const Text('Новый шаблон'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: (selected == null || _saving)
                                ? null
                                : _duplicateTemplate,
                            icon: const Icon(Icons.copy),
                            label: const Text('Копировать'),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _templates.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final item = _templates[index];
                                final isCurrent = item.id == _selectedId;
                                final displayName = (isCurrent && _isDraftNew)
                                    ? (_nameController.text.isEmpty
                                        ? item.name
                                        : _nameController.text)
                                    : item.name;
                                return ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  selected: isCurrent,
                                  selectedTileColor: const Color(0xFFEEF1FF),
                                  leading: Icon(
                                    item.isBuiltIn
                                        ? Icons.verified_outlined
                                        : Icons.description_outlined,
                                    size: 18,
                                  ),
                                  title: Text(
                                    displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () =>
                                      _select(item.id, isDraftNew: false),
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
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Название шаблона',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              if (_isDraftNew)
                                const Text(
                                  'Черновик — нажмите «Сохранить шаблон»',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF4F5D75),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _nameController,
                            enabled: selected != null && !_saving,
                            readOnly: false,
                            autocorrect: false,
                            enableSuggestions: false,
                            maxLines: 1,
                            onChanged: (_) {
                              if (_error.isNotEmpty) {
                                setState(() => _error = '');
                              } else if (_isDraftNew) {
                                setState(() {});
                              }
                            },
                            decoration: const InputDecoration(
                              hintText: 'Например, Flutter Desktop + Riverpod',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Текст инструкции Markdown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              if (selected?.isBuiltIn == true)
                                const Chip(
                                  label: Text('Встроенный'),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: TextField(
                              controller: _contentController,
                              enabled: selected != null && !_saving,
                              readOnly: false,
                              autocorrect: false,
                              enableSuggestions: false,
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              onChanged: (_) {
                                if (_error.isNotEmpty) {
                                  setState(() => _error = '');
                                }
                              },
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 12.5,
                                height: 1.5,
                                color: Color(0xFF364158),
                              ),
                              decoration: const InputDecoration(
                                hintText:
                                    'Напишите инструкцию. Переменные: {{project_name}}, {{project_slug}}, {{project_description}}',
                                alignLabelWithHint: true,
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error,
                              style: TextStyle(
                                fontSize: 12,
                                color: _error == 'Шаблон сохранён.'
                                    ? const Color(0xFF267B5D)
                                    : const Color(0xFFB74444),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: (selected == null ||
                                        selected.isBuiltIn ||
                                        _saving)
                                    ? null
                                    : _deleteTemplate,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Удалить'),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: (selected == null || _saving)
                                    ? null
                                    : _saveTemplate,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
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
              const Text(
                'Переменные подставляются автоматически при создании проекта. Изменения шаблона не переписывают AGENT.md старых проектов.',
                style: TextStyle(fontSize: 11, color: Color(0xFF7C879A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
