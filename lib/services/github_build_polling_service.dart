import 'dart:async';

import 'package:path/path.dart' as p;

import '../models/code_project.dart';
import 'app_storage.dart';
import 'build_bundle_service.dart';
import 'github_build_fetcher_service.dart';

class GitHubBuildPollingCoordinator {
  GitHubBuildPollingCoordinator({
    required this.storage,
    required this.getProjects,
    required this.getCurrentProject,
    required this.getGitHubToken,
    required this.getLastSourceId,
    required this.onRecordSourceId,
    required this.onLog,
    required this.onApplyToActiveProject,
    required this.onNotify,
  });

  final AppStorage storage;
  final List<CodeProject> Function() getProjects;
  final CodeProject? Function() getCurrentProject;
  final String Function() getGitHubToken;
  final String? Function(String projectId) getLastSourceId;
  final Future<void> Function(String projectId, String sourceId) onRecordSourceId;
  final void Function(String message) onLog;
  final Future<void> Function(String zipPath, String targetDir) onApplyToActiveProject;
  final void Function() onNotify;

  Timer? _timer;

  void configure() {
    _timer?.cancel();
    _timer = null;
    final enabledProjects = getProjects().where((item) => item.buildAutoFetchEnabled).toList();
    if (enabledProjects.isEmpty) return;
    final minInterval = enabledProjects
        .map((item) => item.buildAutoFetchIntervalMinutes.clamp(1, 120))
        .reduce((a, b) => a < b ? a : b);
    _timer = Timer.periodic(Duration(minutes: minInterval), (_) {
      unawaited(pollAllEnabled());
    });
    unawaited(pollAllEnabled());
  }

  Future<void> pollAllEnabled() async {
    final enabledProjects = getProjects().where((item) => item.buildAutoFetchEnabled).toList();
    if (enabledProjects.isEmpty) return;
    final activeId = getCurrentProject()?.id;
    for (final proj in enabledProjects) {
      if (proj.id == activeId) {
        await onApplyToActiveProject('', '');
      } else {
        await _checkProjectInBackground(proj);
      }
    }
  }

  Future<void> _checkProjectInBackground(CodeProject proj) async {
    try {
      final fetchDir = p.join(storage.dataDirectory, 'builds', '_fetched', proj.packageName);
      final res = await GitHubBuildFetcherService.fetchLatestBuilds(
        repoUrl: proj.gitRepoUrl,
        token: getGitHubToken(),
        downloadDirectory: fetchDir,
        lastProcessedId: getLastSourceId(proj.id),
        zipFilter: proj.buildZipFilter,
        takeAllBuilds: proj.buildTakeAllPublicBuilds,
      );
      for (final line in res.logs) {
        onLog('[${proj.name}] $line');
      }
      for (final item in res.fetchedZips) {
        await onRecordSourceId(proj.id, item.sourceId);
        if (proj.buildCaptureEnabled) {
          final baseBuildsDir = proj.buildTargetDirectory.trim().isNotEmpty
              ? proj.buildTargetDirectory.trim()
              : BuildBundleService.defaultBuildsRootDirectory(storage.dataDirectory);
          final result = await BuildBundleService.applyDownloadedBuild(
            zipPath: item.zipPath,
            buildsRootDirectory: baseBuildsDir,
            preservedPatterns: proj.buildPreservedFiles
                .split(RegExp(r'[,\n;]'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
            overlayPreviousVersion: proj.buildOverlayPrevious,
            clearTargetBeforeApply: proj.buildClearBeforeApply,
          );
          for (final line in result.logs) {
            onLog('[${proj.name}] $line');
          }
        }
      }
      onNotify();
    } catch (error) {
      onLog('[${proj.name}] Ошибка автопроверки сборок GitHub: $error');
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
