import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/project_provider.dart';
import '../services/window_size_listener.dart';

class NewProjectIntent extends Intent {
  const NewProjectIntent();
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class QuitAppIntent extends Intent {
  const QuitAppIntent();
}

class HomeShortcutsWrapper extends StatelessWidget {
  const HomeShortcutsWrapper({
    super.key,
    required this.provider,
    required this.onNewProject,
    required this.onOpenSettings,
    required this.child,
    this.windowSizeListener,
  });

  final ProjectProvider provider;
  final Future<void> Function(BuildContext context, ProjectProvider provider) onNewProject;
  final Future<void> Function(BuildContext context, ProjectProvider provider) onOpenSettings;
  final Widget child;
  final WindowSizeListener? windowSizeListener;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyN, control: true): NewProjectIntent(),
        SingleActivator(LogicalKeyboardKey.comma, control: true): OpenSettingsIntent(),
        SingleActivator(LogicalKeyboardKey.keyQ, control: true): QuitAppIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewProjectIntent: CallbackAction<NewProjectIntent>(
            onInvoke: (_) {
              if (!provider.isWorking) {
                unawaited(onNewProject(context, provider));
              }
              return null;
            },
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) {
              unawaited(onOpenSettings(context, provider));
              return null;
            },
          ),
          QuitAppIntent: CallbackAction<QuitAppIntent>(
            onInvoke: (_) {
              Future<void>(() async {
                await windowSizeListener?.saveNow();
                await provider.prepareForGracefulExit();
                exit(0);
              });
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}
