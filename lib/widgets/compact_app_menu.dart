import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../providers/project_provider.dart';
import '../services/window_size_listener.dart';

class CompactAppMenuButton extends StatelessWidget {
  const CompactAppMenuButton({
    super.key,
    required this.provider,
    required this.onNewProject,
    required this.onFilesToPrompt,
    required this.onAbout,
    required this.onOpenFolder,
    required this.onSelectTab,
    this.windowSizeListener,
  });

  final ProjectProvider provider;
  final VoidCallback onNewProject;
  final VoidCallback onFilesToPrompt;
  final VoidCallback onAbout;
  final void Function(String folderPath) onOpenFolder;
  final void Function(String tabId) onSelectTab;
  final WindowSizeListener? windowSizeListener;

  static const Color _bgDark = Color(0xFF222222);
  static const Color _borderDark = Color(0xFF3A3A3A);
  static const Color _mutedText = Color(0xFFBEBEBE);

  Future<void> _openMainMenu(BuildContext buttonContext) async {
    final renderBox = buttonContext.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final buttonOffset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonSize = renderBox.size;
    final position = RelativeRect.fromLTRB(
      buttonOffset.dx,
      buttonOffset.dy + buttonSize.height + 4,
      overlay.size.width - (buttonOffset.dx + buttonSize.width),
      overlay.size.height - (buttonOffset.dy + buttonSize.height + 4),
    );

    final action = await showMenu<_MenuAction>(
      context: buttonContext,
      position: position,
      color: _bgDark,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _borderDark, width: 1),
      ),
      items: <PopupMenuEntry<_MenuAction>>[
        _buildSubmenuTrigger(
          context: buttonContext,
          anchorRect: Rect.fromLTWH(
            buttonOffset.dx,
            buttonOffset.dy + buttonSize.height + 4,
            buttonSize.width,
            buttonSize.height,
          ),
          label: 'Файл',
          entries: <_MenuEntrySpec>[
            _MenuEntrySpec(
              label: 'Новый проект',
              shortcut: 'Ctrl+N',
              onTap: onNewProject,
            ),
            _MenuEntrySpec(
              label: 'Файлы → текст для ИИ',
              onTap: onFilesToPrompt,
            ),
            const _MenuEntrySpec(isDivider: true),
            _MenuEntrySpec(
              label: 'Папка программы',
              onTap: () => onOpenFolder(provider.storage.applicationDirectory),
            ),
            _MenuEntrySpec(
              label: 'Папка данных',
              onTap: () => onOpenFolder(provider.storage.dataDirectory),
            ),
          ],
        ),
        _buildSubmenuTrigger(
          context: buttonContext,
          anchorRect: Rect.fromLTWH(
            buttonOffset.dx,
            buttonOffset.dy + buttonSize.height + 4,
            buttonSize.width,
            buttonSize.height,
          ),
          label: 'Деплой и сборки',
          entries: <_MenuEntrySpec>[
            _MenuEntrySpec(
              label: provider.currentProject != null
                  ? 'Проект: ${provider.currentProject!.name} (${provider.currentProject!.gitBranch})'
                  : 'Проект не выбран',
            ),
            _MenuEntrySpec(
              label: provider.currentProject?.buildAutoFetchEnabled == true
                  ? 'Автосборки GitHub: Вкл (${provider.currentProject!.buildAutoFetchIntervalMinutes} мин)'
                  : 'Автосборки GitHub: Выкл',
            ),
            const _MenuEntrySpec(isDivider: true),
            _MenuEntrySpec(
              label: provider.downloadsWatcherEnabled
                  ? 'Мониторинг «Загрузок»: Вкл'
                  : 'Мониторинг «Загрузок»: Выкл',
              onTap: () async {
                await provider.setDownloadsWatcher(enabled: !provider.downloadsWatcherEnabled);
              },
            ),
            _MenuEntrySpec(
              label: 'Открыть вкладку «Авто-деплой»',
              onTap: () => onSelectTab('auto_deploy'),
            ),
            _MenuEntrySpec(
              label: 'Открыть вкладку «Распаковка сборок»',
              onTap: () => onSelectTab('build_capture'),
            ),
            if (provider.currentProject != null) ...[
              const _MenuEntrySpec(isDivider: true),
              _MenuEntrySpec(
                label: 'Проверить и скачать сборку с GitHub',
                onTap: () async {
                  await provider.checkAndApplyGitHubBuilds(silent: false);
                },
              ),
              _MenuEntrySpec(
                label: 'Открыть папку проекта',
                onTap: () => onOpenFolder(provider.currentProject!.outputPath),
              ),
            ],
          ],
        ),
        _buildSubmenuTrigger(
          context: buttonContext,
          anchorRect: Rect.fromLTWH(
            buttonOffset.dx,
            buttonOffset.dy + buttonSize.height + 4,
            buttonSize.width,
            buttonSize.height,
          ),
          label: 'Бэкап и настройки',
          entries: <_MenuEntrySpec>[
            _MenuEntrySpec(
              label: 'Сделать бэкап сейчас',
              onTap: () async {
                await provider.createBackupNow(isAuto: false, silent: false);
              },
            ),
            _MenuEntrySpec(
              label: provider.autoBackupEnabled
                  ? 'Автобэкап (${provider.autoBackupIntervalMinutes} мин): Вкл'
                  : 'Автобэкап: Выкл',
              onTap: () async {
                await provider.updateBackupSettings(
                  enabled: !provider.autoBackupEnabled,
                  intervalMinutes: provider.autoBackupIntervalMinutes,
                  customBackupDir: provider.backupDirectory,
                );
              },
            ),
            _MenuEntrySpec(
              label: 'Настройки и история версий',
              shortcut: 'Ctrl+,',
              onTap: onAbout,
            ),
          ],
        ),
        _buildSubmenuTrigger(
          context: buttonContext,
          anchorRect: Rect.fromLTWH(
            buttonOffset.dx,
            buttonOffset.dy + buttonSize.height + 4,
            buttonSize.width,
            buttonSize.height,
          ),
          label: 'Окно',
          entries: <_MenuEntrySpec>[
            _MenuEntrySpec(
              label: 'Развернуть / восстановить окно',
              onTap: _toggleMaximize,
            ),
            _MenuEntrySpec(
              label: 'Полноэкранный режим',
              onTap: _toggleFullScreen,
            ),
            const _MenuEntrySpec(isDivider: true),
            _MenuEntrySpec(
              label: 'Папка бэкапов',
              onTap: () => onOpenFolder(
                provider.backupDirectory ?? p.join(p.dirname(provider.storage.dataDirectory), 'backups'),
              ),
            ),
          ],
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<_MenuAction>(
          value: _MenuAction.settings,
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Настройки',
                  style: TextStyle(color: Colors.white, fontSize: 13.5),
                ),
              ),
              SizedBox(width: 18),
              Text(
                'Ctrl+Запятая',
                style: TextStyle(color: _mutedText, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<_MenuAction>(
          value: _MenuAction.exitApp,
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Выйти',
                  style: TextStyle(color: Colors.white, fontSize: 13.5),
                ),
              ),
              SizedBox(width: 18),
              Text(
                'Ctrl+Q',
                style: TextStyle(color: _mutedText, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );

    if (action == _MenuAction.settings) {
      onAbout();
    } else if (action == _MenuAction.exitApp) {
      await _performGracefulExit();
    }
  }

  PopupMenuEntry<_MenuAction> _buildSubmenuTrigger({
    required BuildContext context,
    required Rect anchorRect,
    required String label,
    required List<_MenuEntrySpec> entries,
  }) {
    return PopupMenuItem<_MenuAction>(
      height: 40,
      onTap: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _openSubmenu(context, anchorRect: anchorRect, title: label, entries: entries);
          }
        });
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _mutedText, size: 18),
        ],
      ),
    );
  }

  Future<void> _openSubmenu(
    BuildContext context, {
    required Rect anchorRect,
    required String title,
    required List<_MenuEntrySpec> entries,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final subLeft = (anchorRect.left - 245).clamp(8.0, overlay.size.width - 255);
    final subTop = anchorRect.top.clamp(8.0, overlay.size.height - 220);
    final position = RelativeRect.fromLTRB(
      subLeft,
      subTop,
      overlay.size.width - subLeft - 240,
      overlay.size.height - subTop - 160,
    );

    final items = <PopupMenuEntry<int>>[];
    for (var i = 0; i < entries.length; i++) {
      final spec = entries[i];
      if (spec.isDivider) {
        items.add(const PopupMenuDivider(height: 1));
      } else {
        items.add(
          PopupMenuItem<int>(
            value: i,
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    spec.label ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                if (spec.shortcut != null) ...[
                  const SizedBox(width: 14),
                  Text(
                    spec.shortcut!,
                    style: const TextStyle(color: _mutedText, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    final chosen = await showMenu<int>(
      context: context,
      position: position,
      color: _bgDark,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _borderDark, width: 1),
      ),
      items: items,
    );

    if (chosen != null && chosen >= 0 && chosen < entries.length) {
      entries[chosen].onTap?.call();
    }
  }

  Future<void> _performGracefulExit() async {
    try {
      await windowSizeListener?.saveNow();
      await provider.prepareForGracefulExit();
    } catch (_) {}
    exit(0);
  }

  Future<void> _toggleMaximize() async {
    try {
      final isMax = await windowManager.isMaximized();
      if (isMax) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  Future<void> _toggleFullScreen() async {
    try {
      final isFs = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFs);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.white12,
        onTap: () => _openMainMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _bgDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderDark),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text(
                'Меню',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              Icon(Icons.chevron_right_rounded, color: _mutedText, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MenuAction {
  settings,
  exitApp,
}

class _MenuEntrySpec {
  const _MenuEntrySpec({
    this.label,
    this.shortcut,
    this.onTap,
    this.isDivider = false,
  });

  final String? label;
  final String? shortcut;
  final VoidCallback? onTap;
  final bool isDivider;
}
