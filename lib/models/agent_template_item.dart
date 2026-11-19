class AgentTemplateItem {
  const AgentTemplateItem({
    required this.id,
    required this.name,
    required this.content,
    required this.isBuiltIn,
  });

  final String id;
  final String name;
  final String content;
  final bool isBuiltIn;

  AgentTemplateItem copyWith({
    String? id,
    String? name,
    String? content,
    bool? isBuiltIn,
  }) {
    return AgentTemplateItem(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }
}
