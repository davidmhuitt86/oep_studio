import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/foundation_runtime_state.dart';
import '../../core/theme/studio_colors.dart';

/// The bottom Status Bar (SDD-003/SDD-004, overridden by Work Package 002:
/// displays Runtime, Repository, Theme, and Studio Version — Foundation
/// Version moved to the Dashboard).
class StudioStatusBar extends ConsumerWidget {
  const StudioStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final connected = foundation.phase == FoundationConnectionPhase.connected;
    final repositoryLabel = foundation.isRepositoryOpen
        ? 'Repository: ${foundation.repositoryStatus?.repositoryName ?? "Open"}'
        : 'Repository: None Open';

    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: StudioColors.surface,
        border: Border(top: BorderSide(color: StudioColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _StatusDot(color: connected ? StudioColors.success : StudioColors.warning),
          const SizedBox(width: 6),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const _StatusText('Ready'),
                  const _StatusSeparator(),
                  _StatusText(repositoryLabel),
                  const _StatusSeparator(),
                  _StatusText(
                    connected ? 'Runtime: Connected' : 'Runtime: Disconnected',
                    color: connected ? StudioColors.success : StudioColors.warning,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: const Row(
                children: [
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
  const _StatusText(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: color ?? StudioColors.textSecondary, fontSize: 11),
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
