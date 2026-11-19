import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class FetchedBuildItem {
  const FetchedBuildItem({
    required this.sourceId,
    required this.zipPath,
    required this.fileName,
    required this.sourceLabel,
  });

  final String sourceId;
  final String zipPath;
  final String fileName;
  final String sourceLabel;
}

class GitHubBuildFetchResult {
  const GitHubBuildFetchResult({
    required this.success,
    required this.logs,
    required this.fetchedZips,
    this.errorMessage,
  });

  final bool success;
  final List<String> logs;
  final List<FetchedBuildItem> fetchedZips;
  final String? errorMessage;
}

class GitHubBuildFetcherService {
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

  static Future<GitHubBuildFetchResult> fetchLatestBuilds({
    required String repoUrl,
    String token = '',
    required String downloadDirectory,
    String? lastProcessedId,
    String zipFilter = '',
    bool takeAllBuilds = true,
  }) async {
    bool matchesFilter(String candidateName) {
      final cleanFilter = zipFilter.trim().toLowerCase();
      if (takeAllBuilds || cleanFilter.isEmpty) return true;
      return candidateName.toLowerCase().contains(cleanFilter);
    }
    final logs = <String>[];
    final repoApiBase = parseGitHubRepoUri(repoUrl);
    if (repoApiBase == null) {
      return const GitHubBuildFetchResult(
        success: false,
        logs: <String>['Некорректный или пустой GitHub URL репозитория для автозагрузки сборок.'],
        fetchedZips: <FetchedBuildItem>[],
        errorMessage: 'Не задан корректный GitHub URL репозитория.',
      );
    }

    final cleanToken = token.trim();
    final outDir = Directory(downloadDirectory);
    await outDir.create(recursive: true);

    final client = HttpClient();
    final fetched = <FetchedBuildItem>[];

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
      final runsUri = Uri.parse('${repoApiBase.toString()}/actions/runs?status=completed&per_page=5');
      final runsJson = await getJsonString(runsUri);
      if (runsJson != null) {
        final decodedRuns = jsonDecode(runsJson);
        if (decodedRuns is Map<String, dynamic> && decodedRuns['workflow_runs'] is List) {
          final runs = (decodedRuns['workflow_runs'] as List).whereType<Map<String, dynamic>>().toList();
          Map<String, dynamic>? bestRun;
          for (final r in runs) {
            final conclusion = (r['conclusion'] as String? ?? '').toLowerCase();
            if (conclusion == 'success') {
              bestRun = r;
              break;
            }
          }
          if (bestRun != null) {
            final runId = bestRun['id']?.toString() ?? '';
            final runSourceId = 'run:$runId';
            if (runId.isNotEmpty && runSourceId != lastProcessedId) {
              final artifactsUrlRaw = bestRun['artifacts_url'] as String?;
              final artifactsUri = artifactsUrlRaw != null && artifactsUrlRaw.isNotEmpty
                  ? Uri.parse(artifactsUrlRaw)
                  : Uri.parse('${repoApiBase.toString()}/actions/runs/$runId/artifacts');
              final artJson = await getJsonString(artifactsUri);
              if (artJson != null) {
                final decodedArt = jsonDecode(artJson);
                if (decodedArt is Map<String, dynamic> && decodedArt['artifacts'] is List) {
                  final artifacts = (decodedArt['artifacts'] as List).whereType<Map<String, dynamic>>().toList();
                  for (final art in artifacts) {
                    if (art['expired'] == true) continue;
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
                        await File(outZipPath).writeAsBytes(entry.content as List<int>, flush: true);
                        fetched.add(
                          FetchedBuildItem(
                            sourceId: runSourceId,
                            zipPath: outZipPath,
                            fileName: safeZipName,
                            sourceLabel: 'GitHub Actions run #$runId ($artName)',
                          ),
                        );
                        logs.add('Скачан архив сборки из артефакта: $outZipPath');
                        extractedInner++;
                      }
                    }

                    if (extractedInner == 0) {
                      final safeName = '${artName}_run_$runId.zip';
                      final outZipPath = p.join(outDir.path, safeName);
                      await File(outZipPath).writeAsBytes(zipBytes, flush: true);
                      fetched.add(
                        FetchedBuildItem(
                          sourceId: runSourceId,
                          zipPath: outZipPath,
                          fileName: safeName,
                          sourceLabel: 'GitHub Actions run #$runId ($artName)',
                        ),
                      );
                      logs.add('Сохранён артефакт сборки: $outZipPath');
                    }
                  }
                }
              }
            }
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
            if (tag.isNotEmpty && relSourceId != lastProcessedId && decodedRel['assets'] is List) {
              for (final asset in (decodedRel['assets'] as List).whereType<Map<String, dynamic>>()) {
                final name = (asset['name'] as String? ?? '').trim();
                final dlUrl = asset['browser_download_url'] as String?;
                if (name.isEmpty || dlUrl == null || dlUrl.isEmpty) continue;
                if (!name.toLowerCase().endsWith('.zip') || !matchesFilter(name)) continue;
                final bytes = await downloadBytes(Uri.parse(dlUrl), useAuth: cleanToken.isNotEmpty);
                if (bytes == null || bytes.isEmpty) continue;
                final outZipPath = p.join(outDir.path, name);
                await File(outZipPath).writeAsBytes(bytes, flush: true);
                fetched.add(
                  FetchedBuildItem(
                    sourceId: relSourceId,
                    zipPath: outZipPath,
                    fileName: name,
                    sourceLabel: 'GitHub Release $tag',
                  ),
                );
                logs.add('Скачан релизный ZIP с GitHub ($tag): $outZipPath');
              }
            }
          }
        }
      }

      return GitHubBuildFetchResult(
        success: true,
        logs: logs,
        fetchedZips: fetched,
      );
    } catch (e) {
      final msg = 'Ошибка при проверке/скачивании сборок с GitHub: $e';
      logs.add(msg);
      return GitHubBuildFetchResult(
        success: false,
        logs: logs,
        fetchedZips: fetched,
        errorMessage: msg,
      );
    } finally {
      client.close(force: true);
    }
  }
}
