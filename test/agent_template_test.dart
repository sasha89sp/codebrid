import 'package:code_bridge_mini/services/agent_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentTemplate', () {
    test('includes built-in Flutter Monorepo AGENTS.md template', () {
      final templates = AgentTemplate.builtInTemplates();
      final agents = templates.firstWhere(
        (item) => item.id == 'flutter-monorepo-agents',
      );

      expect(agents.isBuiltIn, isTrue);
      expect(agents.name, 'Flutter Monorepo (AGENTS.md)');
      expect(agents.content, contains('ROOT_MAP.md'));
      expect(agents.content, contains('MAP.md'));
      expect(agents.content, contains('HANDOFF.yaml'));
      expect(agents.content, contains('<<<END_PROJECT>>>'));
    });

    test('renders project variables inside AGENTS.md template', () {
      final agents = AgentTemplate.builtInTemplates().firstWhere(
        (item) => item.id == 'flutter-monorepo-agents',
      );

      final rendered = AgentTemplate.render(
        template: agents.content,
        projectName: 'Мой Проект',
        projectSlug: 'moy_proekt',
        description: 'Тестовое описание',
      );

      expect(rendered, contains('Мой Проект'));
      expect(rendered, contains('`moy_proekt`'));
      expect(rendered, contains('Тестовое описание'));
      expect(rendered, isNot(contains('{{project_name}}')));
      expect(rendered, isNot(contains('{{project_slug}}')));
      expect(rendered, isNot(contains('{{project_description}}')));
    });
  });
}
