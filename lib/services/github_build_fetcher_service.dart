import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class FetchedBuildItem {
  const FetchedBuildItem({
    required this.sourceId,
    required this.zipPath,
    required this.fileName,
    required this.sourceLabel,
    this.detectedVersion,
  });

  final String sourceId;
  final String zipPath;
  final String fileName;
  final String sourceLabel;
  final String? detectedVersion;
}

class GitHubBuildFailureInfo {
  const GitHubBuildFailureInfo({
    required this.runId,
    required this.workflowName,
    required this.conclusion,
    required this.branch,
    required this.commitTitle,
    this.htmlUrl,
  });

  final String runId;
  final String workflowName;
  final String conclusion;
  final String branch;
  final String commitTitle;
  final String? htmlUrl;

  String get shortSummary {
    final wf = workflowName.isNotEmpty ? ' ($workflowName)' : '';
    final br = branch.isNotEmpty ? ' [$branch]' : '';
    return 'Сборка на GitHub упала: run #$runId$wf$br — статус $conclusion';
  }
}

class GitHubBuildFetchResult {
  const GitHubBuildFetchResult({
    required this.success,
    required this.logs,
    required this.fetchedZips,
    this.errorMessage,
    this.latestFailedBuild,
    this.hasInProgressBuild = false,
  });

  final bool success;
  final List<String> logs;
  final List<FetchedBuildItem> fetchedZips;
  final String? errorMessage;
  final GitHubBuildFailureInfo? latestFailedBuild;
  final bool hasInProgressBuild;
}

class GitHubBuildFetcherService {
  static const Set<String> _failureConclusions = <String>{
    'failure',
    'cancelled',
    'timed_out',
    'startup_failure',
    'action_required',
  };

  static Uri? parseGitHubRepoUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    final sshMatch = RegExp(r'^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?/?$').firstMatch(trimmed);
    if (sshMatch != null) {
      return Uri.https('api.github.com', '/repos/${sshMatch.group(1)}/${sshMatch.group(2)}');
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.host.toLowerCase().contains('github.com')) {
      final segments = parsed.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length >= 2) {
        final owner = segments[0];
        var repo = segments[1];
        if (repo.toLowerCase().endsWith('.git')) {
          repo = repo.substring(0, repo.length - 4);
        }
        if (owner.isNotEmpty && repo.isNotEmpty) {
          return Uri.https('api.github.com', '/repos/$owner/$repo');
        }
      }
    }
    return null;
  }

  static String? detectVersionFromArchiveBytes(List<int> zipBytes, {String? fallbackText}) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes, verify: false);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final lower = entry.name.replaceAll('\\', '/').toLowerCase();
        if (lower.endsWith('pubspec.yaml') ||
            lower.endsWith('app_version.dart') ||
            lower.endsWith('version.txt') ||
            lower.endsWith('version.json')) {
          final text = utf8.decode(entry.content as List<int>, allowMalformed: true);
          final found = extractVersionFromText(text);
          if (found != null) return found;
        }
      }
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final found = extractVersionFromText(entry.name);
        if (found != null) return found;
      }
    } catch (_) {}
    if (fallbackText != null) {
      return extractVersionFromText(fallbackText);
    }
    return null;
  }

  static String? extractVersionFromText(String text) {
    final pubspecMatch = RegExp(r'''version\s*:\s*['"]?(\d+\.\d+\.\d+(?:\+\d+)?)['"]?''').firstMatch(text);
    if (pubspecMatch != null) return pubspecMatch.group(1);

    final dartVerMatch = RegExp(r'''currentVersion\s*=\s*['"](\d+\.\d+\.\d+)['"]''').firstMatch(text);
    final dartBuildMatch = RegExp(r'''currentBuildNumber\s*=\s*(\d+)''').firstMatch(text);
    if (dartVerMatch != null) {
      final ver = dartVerMatch.group(1)!;
      final b = dartBuildMatch?.group(1);
      return b != null ? '$ver+$b' : ver;
    }

    final semverMatch = RegExp(r'(?:^|[^0-9.])(\d+\.\d+\.\d+(?:\+\d+)?)(?:[^0-9.]|$)').firstMatch(text);
    if (semverMatch != null) return semverMatch.group(1);
    return null;
  }

  static Future<GitHubBuildFetchResult> fetchLatestBuilds({
    required String repoUrl,
    String token = '',
    required String downloadDirectory,
    String? lastProcessedId,
    String zipFilter = '',
    bool takeAllBuilds = true,
    bool forceRecheck = false,
  }) async {
    bool matchesFilter(String candidateName) {
      final cleanFilter = zipFilter.trim().toLowerCase();
      if (takeAllBuilds || cleanFilter.isEmpty) return true;
      return candidateName.toLowerCase().contains(cleanFilter);
    }

    final logs = <String>[];
    final repoApiBase = parseGitHubRepoUri(repoUrl);
    if (repoApiBase == null) {
      const msg = 'Не задан или некорректен GitHub URL репозитория в настройках проекта.';
      logs.add(msg);
      return const GitHubBuildFetchResult(
        success: false,
        logs: <String>[msg],
        fetchedZips: <FetchedBuildItem>[],
        errorMessage: msg,
      );
    }

    final cleanToken = token.trim();
    final outDir = Directory(downloadDirectory);
    await outDir.create(recursive: true);

    final client = HttpClient();
    final fetched = <FetchedBuildItem>[];
    GitHubBuildFailureInfo? latestFailedBuild;
    var hasInProgressBuild = false;

    Future<String?> getJsonString(Uri uri) async {
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('X-GitHub-Api-Version', '2022-11-28');
      req.headers.set('User-Agent', 'CodeBridgeMini');
      if (cleanToken.isNotEmpty) {
        req.headers.set('Authorization', 'Bearer $cleanToken');
      }
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return body;
      }
      logs.add('GitHub API (${uri.path}) вернул статус ${resp.statusCode}.');
      return null;
    }

    Future<List<int>?> downloadBytes(Uri uri, {bool useAuth = true}) async {
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('X-GitHub-Api-Version', '2022-11-28');
      req.headers.set('User-Agent', 'CodeBridgeMini');
      if (useAuth && cleanToken.isNotEmpty) {
        req.headers.set('Authorization', 'Bearer $cleanToken');
      }
      final resp = await req.close();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in resp) {
          builder.add(chunk);
        }
        return builder.toBytes();
      }
      logs.add('Не удалось скачать файл по $uri (HTTP ${resp.statusCode}).');
      return null;
    }

    try {
      logs.add('Запрос сборок GitHub для ${repoApiBase.path}...');
      final runsUri = Uri.parse('${repoApiBase.toString()}/actions/runs?per_page=12');
      final runsJson = await getJsonString(runsUri);
      if (runsJson != null) {
        final decodedRuns = jsonDecode(runsJson);
        if (decodedRuns is Map<String, dynamic> && decodedRuns['workflow_runs'] is List) {
          final allRuns = (decodedRuns['workflow_runs'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();

          for (final run in allRuns) {
            final status = (run['status'] as String? ?? '').toLowerCase();
            final conclusion = (run['conclusion'] as String? ?? '').toLowerCase();
            if (status != 'completed') {
              hasInProgressBuild = true;
              continue;
            }
            if (conclusion == 'success') {
              // Самый свежий завершённый прогон прошёл успешно — ошибки последней сборки нет.
              break;
            }
            if (_failureConclusions.contains(conclusion)) {
              final failedId = run['id']?.toString() ?? '';
              final wfName = (run['name'] as String? ?? '').trim();
              final branch = (run['head_branch'] as String? ?? '').trim();
              final commitTitle = (run['display_title'] as String? ??
                      run['head_commit']?['message'] as String? ??
                      '')
                  .split('\n')
                  .first
                  .trim();
              final htmlUrl = (run['html_url'] as String?)?.trim();
              final info = GitHubBuildFailureInfo(
                runId: failedId,
                workflowName: wfName,
                conclusion: conclusion,
                branch: branch,
                commitTitle: commitTitle,
                htmlUrl: (htmlUrl != null && htmlUrl.isNotEmpty) ? htmlUrl : null,
              );
              latestFailedBuild = info;
              final titleSuffix = commitTitle.isNotEmpty ? ' — «$commitTitle»' : '';
              logs.add(
                '[ОШИБКА СБОРКИ GITHUB] Run #$failedId${wfName.isNotEmpty ? ' ($wfName)' : ''} завершился со статусом $conclusion$titleSuffix.',
              );
              break;
            }
          }

          final runs = allRuns
              .where((r) =>
                  (r['status'] as String? ?? '').toLowerCase() == 'completed' &&
                  (r['conclusion'] as String? ?? '').toLowerCase() == 'success')
              .toList();
          if (runs.isEmpty) {
            logs.add(
              hasInProgressBuild
                  ? 'Сборка на GitHub ещё выполняется; готовых успешных runs пока нет.'
                  : 'Успешных завершённых workflow runs в Actions пока нет.',
            );
          }
          for (final bestRun in runs.take(5)) {
            final runId = bestRun['id']?.toString() ?? '';
            final runSourceId = 'run:$runId';
            if (runId.isEmpty) continue;
            if (!forceRecheck && runSourceId == lastProcessedId) {
              logs.add('Run #$runId уже был обработан ранее (пропущен).');
              continue;
            }
            final artifactsUrlRaw = bestRun['artifacts_url'] as String?;
            final artifactsUri = artifactsUrlRaw != null && artifactsUrlRaw.isNotEmpty
                ? Uri.parse(artifactsUrlRaw)
                : Uri.parse('${repoApiBase.toString()}/actions/runs/$runId/artifacts');
            final artJson = await getJsonString(artifactsUri);
            if (artJson == null) continue;
            final decodedArt = jsonDecode(artJson);
            if (decodedArt is! Map<String, dynamic> || decodedArt['artifacts'] is! List) continue;
            final artifacts = (decodedArt['artifacts'] as List).whereType<Map<String, dynamic>>().toList();
            if (artifacts.isEmpty) {
              logs.add('В run #$runId нет артефактов.');
              continue;
            }
            for (final art in artifacts) {
              if (art['expired'] == true) {
                logs.add('Артефакт "${art['name'] ?? 'artifact'}" в run #$runId просрочен.');
                continue;
              }
              final artName = (art['name'] as String? ?? 'artifact').trim();
              final dlUrlRaw = art['archive_download_url'] as String?;
              if (dlUrlRaw == null || dlUrlRaw.isEmpty) continue;
              if (cleanToken.isEmpty) {
                logs.add('Артефакт "$artName" найден в run #$runId, но для скачивания артефактов Actions нужен GitHub Token.');
                continue;
              }
              final zipBytes = await downloadBytes(Uri.parse(dlUrlRaw), useAuth: true);
              if (zipBytes == null || zipBytes.isEmpty) continue;

              final outerArchive = ZipDecoder().decodeBytes(zipBytes, verify: false);
              var extractedInner = 0;
              for (final entry in outerArchive) {
                if (!entry.isFile) continue;
                final lowerName = p.basename(entry.name).toLowerCase();
                if (lowerName.endsWith('.zip') && matchesFilter(p.basename(entry.name))) {
                  final safeZipName = p.basename(entry.name);
                  final outZipPath = p.join(outDir.path, safeZipName);
                  final innerBytes = entry.content as List<int>;
                  await File(outZipPath).writeAsBytes(innerBytes, flush: true);
                  final runTitle = (bestRun['display_title'] as String? ?? bestRun['head_commit']?['message'] as String? ?? '').trim();
                  final detectedVer = detectVersionFromArchiveBytes(
                    innerBytes,
                    fallbackText: '$safeZipName $artName $runTitle',
                  );
                  final verSuffix = detectedVer != null ? ' (версия $detectedVer)' : '';
                  fetched.add(
                    FetchedBuildItem(
                      sourceId: runSourceId,
                      zipPath: outZipPath,
                      fileName: safeZipName,
                      sourceLabel: 'GitHub Actions run #$runId ($artName)',
                      detectedVersion: detectedVer,
                    ),
                  );
                  logs.add('Скачан архив сборки из артефакта$verSuffix: $outZipPath');
                  extractedInner++;
                }
              }

              if (extractedInner == 0 && matchesFilter(artName)) {
                final safeName = '${artName}_run_$runId.zip';
                final outZipPath = p.join(outDir.path, safeName);
                await File(outZipPath).writeAsBytes(zipBytes, flush: true);
                final runTitle = (bestRun['display_title'] as String? ?? bestRun['head_commit']?['message'] as String? ?? '').trim();
                final detectedVer = detectVersionFromArchiveBytes(
                  zipBytes,
                  fallbackText: '$artName $runTitle',
                );
                final verSuffix = detectedVer != null ? ' (версия $detectedVer)' : '';
                fetched.add(
                  FetchedBuildItem(
                    sourceId: runSourceId,
                    zipPath: outZipPath,
                    fileName: safeName,
                    sourceLabel: 'GitHub Actions run #$runId ($artName)',
                    detectedVersion: detectedVer,
                  ),
                );
                logs.add('Сохранён артефакт сборки$verSuffix: $outZipPath');
              }
            }
            if (fetched.isNotEmpty) break;
          }
        }
      }

      if (fetched.isEmpty) {
        final relUri = Uri.parse('${repoApiBase.toString()}/releases/latest');
        final relJson = await getJsonString(relUri);
        if (relJson != null) {
          final decodedRel = jsonDecode(relJson);
          if (decodedRel is Map<String, dynamic>) {
            final tag = decodedRel['tag_name']?.toString() ?? decodedRel['id']?.toString() ?? '';
            final relSourceId = 'release:$tag';
            if (tag.isNotEmpty && decodedRel['assets'] is List) {
              if (!forceRecheck && relSourceId == lastProcessedId) {
                logs.add('Релиз $tag уже был обработан ранее.');
              } else {
                for (final asset in (decodedRel['assets'] as List).whereType<Map<String, dynamic>>()) {
                  final name = (asset['name'] as String? ?? '').trim();
                  final dlUrl = asset['browser_download_url'] as String?;
                  if (name.isEmpty || dlUrl == null || dlUrl.isEmpty) continue;
                  if (!name.toLowerCase().endsWith('.zip') || !matchesFilter(name)) continue;
                  final bytes = await downloadBytes(Uri.parse(dlUrl), useAuth: cleanToken.isNotEmpty);
                  if (bytes == null || bytes.isEmpty) continue;
                  final outZipPath = p.join(outDir.path, name);
                  await File(outZipPath).writeAsBytes(bytes, flush: true);
                  final detectedVer = detectVersionFromArchiveBytes(
                    bytes,
                    fallbackText: '$tag $name',
                  ) ?? tag.replaceFirst(RegExp(r'^[vV]'), '');
                  final verSuffix = detectedVer.isNotEmpty ? ' (версия $detectedVer)' : '';
                  fetched.add(
                    FetchedBuildItem(
                      sourceId: relSourceId,
                      zipPath: outZipPath,
                      fileName: name,
                      sourceLabel: 'GitHub Release $tag',
                      detectedVersion: detectedVer.isNotEmpty ? detectedVer : null,
                    ),
                  );
                  logs.add('Скачан релизный ZIP с GitHub$verSuffix: $outZipPath');
                }
              }
            }
          }
        }
      }

      if (fetched.isEmpty) {
        logs.add('Подходящих новых сборок для скачивания не найдено.');
      }

      return GitHubBuildFetchResult(
        success: true,
        logs: logs,
        fetchedZips: fetched,
        latestFailedBuild: latestFailedBuild,
        hasInProgressBuild: hasInProgressBuild,
      );
    } catch (e) {
      final msg = 'Ошибка при проверке/скачивании сборок с GitHub: $e';
      logs.add(msg);
      return GitHubBuildFetchResult(
        success: false,
        logs: logs,
        fetchedZips: fetched,
        errorMessage: msg,
        latestFailedBuild: latestFailedBuild,
        hasInProgressBuild: hasInProgressBuild,
      );
    } finally {
      client.close(force: true);
    }
  }
}
