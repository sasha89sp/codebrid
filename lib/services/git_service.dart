import 'dart:io';

import 'package:path/path.dart' as p;

class GitCommandResult {
  const GitCommandResult({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final String command;
  final int exitCode;
  final String stdout;
  final String stderr;

  bool get isSuccess => exitCode == 0;

  String get combinedOutput {
    final parts = <String>[
      if (stdout.trim().isNotEmpty) stdout.trim(),
      if (stderr.trim().isNotEmpty) stderr.trim(),
    ];
    return parts.join('\n');
  }
}

class GitDeployResult {
  const GitDeployResult({
    required this.success,
    required this.message,
    required this.logs,
    this.pushed = false,
    this.nothingToCommit = false,
    this.commitHash,
  });

  final bool success;
  final String message;
  final List<String> logs;
  final bool pushed;
  final bool nothingToCommit;
  final String? commitHash;
}

class GitStatusSummary {
  const GitStatusSummary({
    required this.gitInstalled,
    required this.isRepository,
    this.gitVersion,
    this.branch,
    this.remoteUrl,
    this.error,
  });

  final bool gitInstalled;
  final bool isRepository;
  final String? gitVersion;
  final String? branch;
  final String? remoteUrl;
  final String? error;
}

class GitService {
  static Future<GitCommandResult> run(
    List<String> args, {
    String? workingDirectory,
  }) async {
    try {
      final result = await Process.run(
        'git',
        args,
        workingDirectory: workingDirectory,
        runInShell: false,
      );
      return GitCommandResult(
        command: 'git ${args.join(' ')}',
        exitCode: result.exitCode,
        stdout: result.stdout?.toString() ?? '',
        stderr: result.stderr?.toString() ?? '',
      );
    } on ProcessException catch (error) {
      return GitCommandResult(
        command: 'git ${args.join(' ')}',
        exitCode: -1,
        stdout: '',
        stderr: 'Не удалось запустить git: ${error.message}',
      );
    }
  }

  static Future<GitStatusSummary> inspectDirectory(String directory) async {
    final versionRes = await run(<String>['--version']);
    if (!versionRes.isSuccess) {
      return GitStatusSummary(
        gitInstalled: false,
        isRepository: false,
        error: versionRes.combinedOutput.isEmpty
            ? 'Git не найден в PATH.'
            : versionRes.combinedOutput,
      );
    }

    final gitDir = Directory(p.join(directory, '.git'));
    if (!await gitDir.exists()) {
      return GitStatusSummary(
        gitInstalled: true,
        isRepository: false,
        gitVersion: versionRes.stdout.trim(),
      );
    }

    final branchRes = await run(
      <String>['rev-parse', '--abbrev-ref', 'HEAD'],
      workingDirectory: directory,
    );
    final remoteRes = await run(
      <String>['remote', 'get-url', 'origin'],
      workingDirectory: directory,
    );

    return GitStatusSummary(
      gitInstalled: true,
      isRepository: true,
      gitVersion: versionRes.stdout.trim(),
      branch: branchRes.isSuccess ? branchRes.stdout.trim() : null,
      remoteUrl: remoteRes.isSuccess ? remoteRes.stdout.trim() : null,
    );
  }

  static Future<GitDeployResult> deployDirectory({
    required String directory,
    String repoUrl = '',
    String branch = 'main',
    String? commitMessage,
    bool push = true,
    bool autoSyncOnReject = true,
  }) async {
    final logs = <String>[];
    final targetBranch = branch.trim().isEmpty ? 'main' : branch.trim();
    final trimmedUrl = repoUrl.trim();

    final versionRes = await run(<String>['--version']);
    if (!versionRes.isSuccess) {
      logs.add('Ошибка: Git не установлен или недоступен в PATH.');
      return GitDeployResult(
        success: false,
        message: 'Git не найден в PATH. Установите Git for Windows.',
        logs: logs,
      );
    }

    final gitDir = Directory(p.join(directory, '.git'));
    if (!await gitDir.exists()) {
      logs.add('Инициализация локального Git-репозитория...');
      final initRes = await run(<String>['init'], workingDirectory: directory);
      if (!initRes.isSuccess) {
        logs.add(initRes.combinedOutput);
        return GitDeployResult(
          success: false,
          message: 'Не удалось выполнить git init.',
          logs: logs,
        );
      }
      await run(<String>['branch', '-M', targetBranch], workingDirectory: directory);
    }

    if (trimmedUrl.isNotEmpty) {
      final currentRemote = await run(
        <String>['remote', 'get-url', 'origin'],
        workingDirectory: directory,
      );
      if (!currentRemote.isSuccess) {
        final addRes = await run(
          <String>['remote', 'add', 'origin', trimmedUrl],
          workingDirectory: directory,
        );
        if (!addRes.isSuccess) {
          logs.add(addRes.combinedOutput);
          return GitDeployResult(
            success: false,
            message: 'Не удалось добавить remote origin.',
            logs: logs,
          );
        }
        logs.add('Добавлен remote origin: $trimmedUrl');
      } else if (currentRemote.stdout.trim() != trimmedUrl) {
        final setRes = await run(
          <String>['remote', 'set-url', 'origin', trimmedUrl],
          workingDirectory: directory,
        );
        if (!setRes.isSuccess) {
          logs.add(setRes.combinedOutput);
          return GitDeployResult(
            success: false,
            message: 'Не удалось обновить remote origin.',
            logs: logs,
          );
        }
        logs.add('Обновлён remote origin: $trimmedUrl');
      }
    }

    final addAllRes = await run(<String>['add', '-A'], workingDirectory: directory);
    if (!addAllRes.isSuccess) {
      logs.add(addAllRes.combinedOutput);
      return GitDeployResult(
        success: false,
        message: 'Ошибка git add -A.',
        logs: logs,
      );
    }

    final statusRes = await run(
      <String>['status', '--porcelain'],
      workingDirectory: directory,
    );
    if (!statusRes.isSuccess) {
      logs.add(statusRes.combinedOutput);
      return GitDeployResult(
        success: false,
        message: 'Ошибка git status.',
        logs: logs,
      );
    }

    if (statusRes.stdout.trim().isEmpty) {
      logs.add('Изменений для коммита нет (рабочее дерево совпадает с HEAD).');
      return GitDeployResult(
        success: true,
        nothingToCommit: true,
        message: 'Файлы распакованы, новых изменений для Git нет.',
        logs: logs,
      );
    }

    final message = (commitMessage != null && commitMessage.trim().isNotEmpty)
        ? commitMessage.trim()
        : 'Auto-deploy from CodeBridge Mini (${DateTime.now().toIso8601String()})';

    final commitRes = await run(
      <String>['commit', '-m', message],
      workingDirectory: directory,
    );
    if (!commitRes.isSuccess) {
      logs.add(commitRes.combinedOutput);
      return GitDeployResult(
        success: false,
        message: 'Ошибка git commit. Проверьте git config user.name и user.email.',
        logs: logs,
      );
    }

    final hashRes = await run(
      <String>['rev-parse', '--short', 'HEAD'],
      workingDirectory: directory,
    );
    final commitHash = hashRes.isSuccess ? hashRes.stdout.trim() : null;
    logs.add('Создан коммит ${commitHash ?? ''}: $message');

    if (!push) {
      return GitDeployResult(
        success: true,
        pushed: false,
        commitHash: commitHash,
        message: 'Коммит создан локально ($commitHash).',
        logs: logs,
      );
    }

    final remoteCheck = await run(
      <String>['remote', 'get-url', 'origin'],
      workingDirectory: directory,
    );
    if (!remoteCheck.isSuccess || remoteCheck.stdout.trim().isEmpty) {
      logs.add('Remote origin не настроен — push пропущен.');
      return GitDeployResult(
        success: false,
        pushed: false,
        commitHash: commitHash,
        message: 'Коммит создан ($commitHash), но не указан Git Remote URL (origin).',
        logs: logs,
      );
    }

    logs.add('Выполняется git push -u origin $targetBranch...');
    var pushRes = await run(
      <String>['push', '-u', 'origin', targetBranch],
      workingDirectory: directory,
    );
    if (!pushRes.isSuccess && autoSyncOnReject) {
      final combinedLower = pushRes.combinedOutput.toLowerCase();
      final isRejected = combinedLower.contains('rejected') ||
          combinedLower.contains('fetch first') ||
          combinedLower.contains('non-fast-forward');
      if (isRejected) {
        logs.add('Удалённая ветка опережает локальную — выполняется синхронизация с origin/$targetBranch...');
        var syncRes = await run(
          <String>['pull', '--rebase', '--allow-unrelated-histories', 'origin', targetBranch],
          workingDirectory: directory,
        );
        if (!syncRes.isSuccess) {
          logs.add('Rebase не прошёл, пробуем merge с --allow-unrelated-histories...');
          await run(<String>['rebase', '--abort'], workingDirectory: directory);
          syncRes = await run(
            <String>['pull', '--no-rebase', '--allow-unrelated-histories', 'origin', targetBranch],
            workingDirectory: directory,
          );
        }
        if (!syncRes.isSuccess) {
          logs.add(syncRes.combinedOutput);
          return GitDeployResult(
            success: false,
            pushed: false,
            commitHash: commitHash,
            message: 'Коммит создан ($commitHash), но синхронизация с origin/$targetBranch завершилась с ошибкой.',
            logs: logs,
          );
        }
        if (syncRes.combinedOutput.isNotEmpty) {
          logs.add(syncRes.combinedOutput);
        }
        logs.add('Повторный git push -u origin $targetBranch после синхронизации...');
        pushRes = await run(
          <String>['push', '-u', 'origin', targetBranch],
          workingDirectory: directory,
        );
      }
    }
    if (!pushRes.isSuccess) {
      logs.add(pushRes.combinedOutput);
      return GitDeployResult(
        success: false,
        pushed: false,
        commitHash: commitHash,
        message: 'Коммит создан ($commitHash), но git push завершился с ошибкой.',
        logs: logs,
      );
    }

    if (pushRes.combinedOutput.isNotEmpty) {
      logs.add(pushRes.combinedOutput);
    }
    logs.add('Изменения отправлены на GitHub (origin/$targetBranch).');

    return GitDeployResult(
      success: true,
      pushed: true,
      commitHash: commitHash,
      message: 'Успешно залито на GitHub ($commitHash -> $targetBranch).',
      logs: logs,
    );
  }
}
