import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MacOsWindowTitleBar extends StatefulWidget {
  const MacOsWindowTitleBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  State<MacOsWindowTitleBar> createState() => _MacOsWindowTitleBarState();
}

class _MacOsWindowTitleBarState extends State<MacOsWindowTitleBar> {
  static const MethodChannel _channel = MethodChannel('codebridge/window_controls');
  bool _hoveringGroup = false;
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _refreshMaximized();
  }

  Future<void> _refreshMaximized() async {
    if (!Platform.isWindows) return;
    try {
      final res = await _channel.invokeMethod<bool>('isMaximized');
      if (mounted && res != null) {
        setState(() => _isMaximized = res);
      }
    } catch (_) {}
  }

  Future<void> _minimize() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('minimize');
    } catch (_) {}
  }

  Future<void> _toggleMaximize() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('toggleMaximize');
      await _refreshMaximized();
    } catch (_) {}
  }

  Future<void> _close() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('close');
    } catch (_) {}
  }

  Future<void> _startDrag() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('startDrag');
      await _refreshMaximized();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE3E8F2), width: 1),
        ),
      ),
      child: Row(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _hoveringGroup = true),
            onExit: (_) => setState(() => _hoveringGroup = false),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TrafficLightButton(
                  color: const Color(0xFFFF5F56),
                  borderColor: const Color(0xFFE0443E),
                  glyph: Icons.close_rounded,
                  tooltip: 'Закрыть',
                  showGlyph: _hoveringGroup,
                  onTap: _close,
                ),
                const SizedBox(width: 8),
                _TrafficLightButton(
                  color: const Color(0xFFFFBD2E),
                  borderColor: const Color(0xFFDEA123),
                  glyph: Icons.remove_rounded,
                  tooltip: 'Свернуть',
                  showGlyph: _hoveringGroup,
                  onTap: _minimize,
                ),
                const SizedBox(width: 8),
                _TrafficLightButton(
                  color: const Color(0xFF27C93F),
                  borderColor: const Color(0xFF1AAB29),
                  glyph: _isMaximized ? Icons.unfold_less_rounded : Icons.open_in_full_rounded,
                  tooltip: _isMaximized ? 'Восстановить размер' : 'Развернуть на весь экран',
                  showGlyph: _hoveringGroup,
                  onTap: _toggleMaximize,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => _startDrag(),
              onDoubleTap: _toggleMaximize,
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF273043),
                    ),
                  ),
                  if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF7D879B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
  }
}

class _TrafficLightButton extends StatelessWidget {
  const _TrafficLightButton({
    required this.color,
    required this.borderColor,
    required this.glyph,
    required this.tooltip,
    required this.showGlyph,
    required this.onTap,
  });

  final Color color;
  final Color borderColor;
  final IconData glyph;
  final String tooltip;
  final bool showGlyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 0.7),
          ),
          alignment: Alignment.center,
          child: showGlyph
              ? Icon(
                  glyph,
                  size: 9,
                  color: const Color(0xFF3A1A00).withValues(alpha: 0.78),
                )
              : null,
        ),
      ),
    );
  }
}
