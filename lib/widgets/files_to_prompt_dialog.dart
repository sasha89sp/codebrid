import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/files_to_prompt.dart';

Future<void> showFilesToPromptDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const FilesToPromptDialog(),
  );
}

class FilesToPromptDialog extends StatefulWidget {
  const FilesToPromptDialog();

  @override
  State<FilesToPromptDialog> createState() => FilesToPromptDialogState();
}

class FilesToPromptDialogState extends State<FilesToPromptDialog> {
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

void _showDialogSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

String _formatShortDate(DateTime date) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}

String _formatFileSize(File file) {
  try {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  } catch (_) {
    return 'Размер неизвестен';
  }
}
