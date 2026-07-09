import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// The bottom Status Bar (SDD-003 Status Bar / SDD-004 Workspace Layout).
///
/// Displays placeholder Repository, Runtime State, Validation Status, and
/// Foundation Version — no Foundation Bridge call is made in this work
/// package, per STUDIO-TASK-000001.
class StudioStatusBar extends StatelessWidget {
  const StudioStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(top: BorderSide(color: StudioColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const _StatusDot(color: StudioColors.success),
          const SizedBox(width: 6),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: const [
                  _StatusText('Ready'),
                  _StatusSeparator(),
                  _StatusText('Repository: None Open'),
                  _StatusSeparator(),
                  _StatusText('Runtime: Not Connected'),
                ],
              ),
            ),
          ),
          const Spacer(),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: const [
                  _StatusText('Foundation: 0.0.0 (disconnected)'),
                  _StatusSeparator(),
                  _StatusText('Theme: Dark'),
                  _StatusSeparator(),
                  _StatusText('OEP Studio 0.1.0-alpha'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
    );
  }
}

class _StatusSeparator extends StatelessWidget {
  const _StatusSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: StudioColors.border,
    );
  }
}
