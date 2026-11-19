import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'git_service.dart';

class GitHubRepoProvisionResult {
  const GitHubRepoProvisionResult({
    required this.success,
    required this.logs,
    this.remoteUrl,
    this.htmlUrl,
    this.errorMessage,
  });

  final bool success;
  final List<String> logs;
  final String? remoteUrl;
  final String? htmlUrl;
  final String? errorMessage;
}

class GitHubRepoService {
  static String suggestRepoName(String rawName) {
    final lower = rawName.trim().toLowerCase();
    final replaced = lower
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^[.-]+|[.-]+$'), '');
    return replaced.isEmpty ? 'new-project' : replaced;
  }

  static Future<void> scaffoldStarterFiles({
    required String directory,
    required String projectName,
    required String packageName,
    required String description,
    required String agentContent,
    bool includeReadme = true,
    bool includeGitignore = true,
    bool includeAgentFile = true,
    bool overwriteExisting = false,
  }) async {
    final dir = Directory(directory);
    await dir.create(recursive: true);

    if (includeGitignore) {
      final gitignoreFile = File(p.join(directory, '.gitignore'));
      if (overwriteExisting || !await gitignoreFile.exists()) {
        const content = '# Miscellaneous\n'
            '*.class\n'
            '*.log\n'
            '*.pyc\n'
            '*.swp\n'
            '.DS_Store\n'
            '.atom/\n'
            '.build/\n'
            '.env\n'
            '.idea/\n'
            '.vscode/\n'
            'build/\n'
            'coverage/\n'
            'pubspec.lock\n';
        await gitignoreFile.writeAsString(content, encoding: utf8, flush: true);
      }
    }

    if (includeReadme) {
      final readmeFile = File(p.join(directory, 'README.md'));
      if (overwriteExisting || !await readmeFile.exists()) {
        final descText = description.trim().isEmpty
            ? 'Проект создан в CodeBridge Mini.'
            : description.trim();
        final content = '# $projectName\n\n'
            '$descText\n\n'
            '- Пакет: `$packageName`\n';
        await readmeFile.writeAsString(content, encoding: utf8, flush: true);
      }
    }

    if (includeAgentFile && agentContent.trim().isNotEmpty) {
      final agentFile = File(p.join(directory, 'AGENTS.md'));
      if (overwriteExisting || !await agentFile.exists()) {
        await agentFile.writeAsString(
          agentContent.endsWith('\n') ? agentContent : '$agentContent\n',
          encoding: utf8,
          flush: true,
        );
      }
    }
  }

  static Future<GitHubRepoProvisionResult> createRemoteRepository({
    required String repoName,
    required bool isPrivate,
    String description = '',
    String token = '',
    String ownerOrOrg = '',
    String branch = 'main',
    String? localDirectory,
    bool pushInitialCommit = false,
    String? commitMessage,
  }) async {
    final logs = <String>[];
    final cleanRepoName = suggestRepoName(repoName);
    final cleanToken = token.trim();
    final cleanOwner = ownerOrOrg.trim();
    final cleanBranch = branch.trim().isEmpty ? 'main' : branch.trim();

    if (cleanToken.isNotEmpty) {
      final endpoint = cleanOwner.isNotEmpty
          ? Uri.parse('https://api.github.com/orgs/$cleanOwner/repos')
          : Uri.parse('https://api.github.com/user/repos');

      logs.add('Создание репозитория "$cleanRepoName" (${isPrivate ? 'приватный' : 'публичный'}) через GitHub API...');
      final client = HttpClient();
      try {
        final request = await client.postUrl(endpoint);
        request.headers.set('Accept', 'application/vnd.github+json');
        request.headers.set('Authorization', 'Bearer $cleanToken');
        request.headers.set('X-GitHub-Api-Version', '2022-11-28');
        request.headers.set('Content-Type', 'application/json; charset=utf-8');
        request.headers.set('User-Agent', 'CodeBridgeMini');

        final payload = <String, Object?>{
          'name': cleanRepoName,
          'private': isPrivate,
          if (description.trim().isNotEmpty) 'description': description.trim(),
          'auto_init': false,
        };
        request.write(utf8.encode(jsonEncode(payload)));

        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            final cloneUrl = (decoded['clone_url'] as String?) ??
                'https://github.com/${cleanOwner.isNotEmpty ? cleanOwner : 'user'}/$cleanRepoName.git';
            final htmlUrl = (decoded['html_url'] as String?) ??
                'https://github.com/${cleanOwner.isNotEmpty ? cleanOwner : 'user'}/$cleanRepoName';
            logs.add('Репозиторий создан на GitHub: $htmlUrl');

            return _configureLocalAndMaybePush(
              logs: logs,
              remoteUrl: cloneUrl,
              htmlUrl: htmlUrl,
              branch: cleanBranch,
              localDirectory: localDirectory,
              pushInitialCommit: pushInitialCommit,
              commitMessage: commitMessage,
            );
          }
        }

        String details = body.trim();
        try {
          final errJson = jsonDecode(body);
          if (errJson is Map<String, dynamic> && errJson['message'] != null) {
            details = errJson['message'].toString();
          }
        } catch (_) {}
        final msg = 'GitHub API вернул статус ${response.statusCode}: $details';
        logs.add(msg);
        return GitHubRepoProvisionResult(
          success: false,
          logs: logs,
          errorMessage: msg,
        );
      } catch (e) {
        final msg = 'Ошибка при создании репозитория через GitHub API: $e';
        logs.add(msg);
        return GitHubRepoProvisionResult(
          success: false,
          logs: logs,
          errorMessage: msg,
        );
      } finally {
        client.close(force: true);
      }
    }

    logs.add('Токен не указан — пробуем создать репозиторий через GitHub CLI (gh repo create)...');
    final args = <String>[
      'repo',
      'create',
      cleanOwner.isNotEmpty ? '$cleanOwner/$cleanRepoName' : cleanRepoName,
      isPrivate ? '--private' : '--public',
      if (description.trim().isNotEmpty) '--description=${description.trim()}',
    ];
    if (localDirectory != null && localDirectory.trim().isNotEmpty) {
      args.addAll(<String>['--source', localDirectory.trim(), '--remote', 'origin']);
      if (pushInitialCommit) {
        args.add('--push');
      }
    }

    try {
      final res = await Process.run('gh', args, runInShell: false);
      final out = <String>[
        if (res.stdout?.toString().trim().isNotEmpty == true) res.stdout.toString().trim(),
        if (res.stderr?.toString().trim().isNotEmpty == true) res.stderr.toString().trim(),
      ].join('\n');
      if (out.isNotEmpty) logs.add(out);

      if (res.exitCode != 0) {
        final msg = out.isEmpty
            ? 'Не удалось выполнить gh repo create. Укажите GitHub Token или авторизуйтесь в gh CLI.'
            : out;
        return GitHubRepoProvisionResult(
          success: false,
          logs: logs,
          errorMessage: msg,
        );
      }

      String? remoteUrl;
      if (localDirectory != null && localDirectory.trim().isNotEmpty) {
        final rem = await GitService.run(
          <String>['remote', 'get-url', 'origin'],
          workingDirectory: localDirectory.trim(),
        );
        if (rem.isSuccess && rem.stdout.trim().isNotEmpty) {
          remoteUrl = rem.stdout.trim();
        }
      }
      remoteUrl ??= cleanOwner.isNotEmpty
          ? 'https://github.com/$cleanOwner/$cleanRepoName.git'
          : 'https://github.com/$cleanRepoName/$cleanRepoName.git';
      final htmlUrl = remoteUrl.endsWith('.git')
          ? remoteUrl.substring(0, remoteUrl.length - 4)
          : remoteUrl;

      return GitHubRepoProvisionResult(
        success: true,
        logs: logs,
        remoteUrl: remoteUrl,
        htmlUrl: htmlUrl,
      );
    } on ProcessException {
      const msg = 'Не найден GitHub CLI (gh) и не указан GitHub Token. Укажите токен или установите gh CLI.';
      logs.add(msg);
      return const GitHubRepoProvisionResult(
        success: false,
        logs: <String>[msg],
        errorMessage: msg,
      );
    }
  }

  static Future<GitHubRepoProvisionResult> attachExistingRepository({
    required String repoUrl,
    required String branch,
    required String localDirectory,
    bool cloneIfEmpty = true,
  }) async {
    final logs = <String>[];
    final cleanUrl = repoUrl.trim();
    final cleanBranch = branch.trim().isEmpty ? 'main' : branch.trim();
    final cleanDir = p.normalize(localDirectory.trim());

    if (cleanUrl.isEmpty) {
      const msg = 'Укажите URL готового Git-репозитория.';
      logs.add(msg);
      return const GitHubRepoProvisionResult(
        success: false,
        logs: <String>[msg],
        errorMessage: msg,
      );
    }

    final statusCheck = await GitService.run(<String>['--version']);
    if (!statusCheck.isSuccess) {
      const msg = 'Git не найден в PATH. Установите Git for Windows.';
      logs.add(msg);
      return const GitHubRepoProvisionResult(
        success: false,
        logs: <String>[msg],
        errorMessage: msg,
      );
    }

    final targetDir = Directory(cleanDir);
    final dirExists = await targetDir.exists();
    var isEmptyOrMissing = !dirExists;
    if (dirExists) {
      final entries = await targetDir.list(followLinks: false).toList();
      isEmptyOrMissing = entries.isEmpty;
    }

    final htmlUrl = cleanUrl.endsWith('.git')
        ? cleanUrl.substring(0, cleanUrl.length - 4)
        : cleanUrl;

    if (isEmptyOrMissing && cloneIfEmpty) {
      logs.add('Локальная папка пуста или отсутствует — выполняется git clone ($cleanUrl)...');
      await targetDir.parent.create(recursive: true);
      if (dirExists) {
        try {
          await targetDir.delete(recursive: true);
        } catch (_) {}
      }
      final cloneArgs = <String>[
        'clone',
        '--branch',
        cleanBranch,
        cleanUrl,
        cleanDir,
      ];
      var cloneRes = await GitService.run(cloneArgs);
      if (!cloneRes.isSuccess) {
        logs.add('Клонирование ветки "$cleanBranch" не удалось — пробуем стандартный git clone...');
        cloneRes = await GitService.run(<String>['clone', cleanUrl, cleanDir]);
      }
      if (cloneRes.combinedOutput.isNotEmpty) {
        logs.add(cloneRes.combinedOutput);
      }
      if (!cloneRes.isSuccess) {
        final msg = cloneRes.combinedOutput.isEmpty
            ? 'Не удалось склонировать репозиторий $cleanUrl.'
            : cloneRes.combinedOutput;
        return GitHubRepoProvisionResult(
          success: false,
          logs: logs,
          remoteUrl: cleanUrl,
          htmlUrl: htmlUrl,
          errorMessage: msg,
        );
      }

      await targetDir.create(recursive: true);
      final inspected = await GitService.inspectDirectory(cleanDir);
      logs.add('Репозиторий склонирован в $cleanDir (ветка: ${inspected.branch ?? cleanBranch}).');
      return GitHubRepoProvisionResult(
        success: true,
        logs: logs,
        remoteUrl: cleanUrl,
        htmlUrl: htmlUrl,
      );
    }

    await targetDir.create(recursive: true);
    final gitDir = Directory(p.join(cleanDir, '.git'));
    if (!await gitDir.exists()) {
      logs.add('Инициализация локального Git-репозитория в существующей папке $cleanDir...');
      final initRes = await GitService.run(<String>['init'], workingDirectory: cleanDir);
      if (!initRes.isSuccess) {
        logs.add(initRes.combinedOutput);
        return GitHubRepoProvisionResult(
          success: false,
          logs: logs,
          errorMessage: 'Не удалось выполнить git init.',
          errorCode: null,
        );
      }
      await GitService.run(<String>['branch', '-M', cleanBranch], workingDirectory: cleanDir);
    }

    final currentRemote = await GitService.run(
      <String>['remote', 'get-url', 'origin'],
      workingDirectory: cleanDir,
    );
    if (!currentRemote.isSuccess) {
      final addRes = await GitService.run(
        <String>['remote', 'add', 'origin', cleanUrl],
        workingDirectory: cleanDir,
      );
      if (!addRes.isSuccess) {
        logs.add(addRes.combinedOutput);
        return GitHubRepoProvisionResult(
          success: false,
          logs: logs,
          errorMessage: 'Не удалось привязать remote origin.',
        );
      }
      logs.add('Привязан remote origin: $cleanUrl');
    } else if (currentRemote.stdout.trim() != cleanUrl) {
      final setRes = await GitService.run(
        <String>['remote', 'set-url', 'origin', cleanUrl],
        workingDirectory: cleanDir,
      );
      if (!setRes.isSuccess) {
        logs.add(setRes.combinedOutput);
        return GitHubRepoProvisionResult(
          success: false,
          logs: logs,
          errorMessage: 'Не удалось обновить remote origin.',
        );
      }
      logs.add('Обновлён remote origin: $cleanUrl');
    } else {
      logs.add('Remote origin уже настроен на $cleanUrl');
    }

    final statusRes = await GitService.run(<String>['status', '--short'], workingDirectory: cleanDir);
    if (statusRes.isSuccess) {
      final trimmedStatus = statusRes.stdout.trim();
      logs.add(
        trimmedStatus.isEmpty
            ? 'Статус Git: рабочее дерево чистое.'
            : 'Статус Git (изменённые/новые файлы):\n$trimmedStatus',
      );
    }

    return GitHubRepoProvisionResult(
      success: true,
      logs: logs,
      remoteUrl: cleanUrl,
      htmlUrl: htmlUrl,
    );
  }

  static Future<GitHubRepoProvisionResult> _configureLocalAndMaybePush({
    required List<String> logs,
    required String remoteUrl,
    required String htmlUrl,
    required String branch,
    String? localDirectory,
    required bool pushInitialCommit,
    String? commitMessage,
  }) async {
    if (localDirectory != null && localDirectory.trim().isNotEmpty && pushInitialCommit) {
      final deployRes = await GitService.deployDirectory(
        directory: localDirectory.trim(),
        repoUrl: remoteUrl,
        branch: branch,
        commitMessage: (commitMessage != null && commitMessage.trim().isNotEmpty)
            ? commitMessage.trim()
            : 'Initial commit via CodeBridge Mini',
        push: true,
      );
      logs.addAll(deployRes.logs);
      if (!deployRes.success) {
        return GitHubRepoProvisionResult(
          success: false,
          logs: logs,
          remoteUrl: remoteUrl,
          htmlUrl: htmlUrl,
          errorMessage: deployRes.message,
        );
      }
    }

    return GitHubRepoProvisionResult(
      success: true,
      logs: logs,
      remoteUrl: remoteUrl,
      htmlUrl: htmlUrl,
    );
  }
}
