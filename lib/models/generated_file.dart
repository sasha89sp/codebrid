class GeneratedFile {
  const GeneratedFile({
    required this.path,
    required this.content,
    this.isFragment = false,
    this.selected = true,
    this.sourceFormat = 'markers',
    this.note,
  });

  final String path;
  final String content;
  final bool isFragment;
  final bool selected;
  final String sourceFormat;
  final String? note;

  GeneratedFile copyWith({
    String? path,
    String? content,
    bool? isFragment,
    bool? selected,
    String? sourceFormat,
    String? note,
    bool clearNote = false,
  }) {
    return GeneratedFile(
      path: path ?? this.path,
      content: content ?? this.content,
      isFragment: isFragment ?? this.isFragment,
      selected: selected ?? this.selected,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      note: clearNote ? null : (note ?? this.note),
    );
  }
}
