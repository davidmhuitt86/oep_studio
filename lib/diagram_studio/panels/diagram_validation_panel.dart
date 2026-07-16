import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';

/// Validation panel — shows `ValidationReport` findings for the current
/// graph, with a manual revalidate action (WORK_PACKAGE_024,
/// ENGINE-TASK-000114). A Studio-styled port of the Demonstration
/// Host's `ValidationPanel`.
class DiagramValidationPanel extends StatelessWidget {
  const DiagramValidationPanel({required this.report, required this.onRevalidate, super.key});

  final ValidationReport? report;
  final VoidCallback onRevalidate;

  @override
  Widget build(BuildContext context) {
    final findings = report?.findings ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text(
                findings.isEmpty ? 'Clean — no findings' : '${findings.length} finding(s)',
                style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
              ),
              const Spacer(),
              IconButton(
                iconSize: 16,
                tooltip: 'Revalidate',
                icon: const Icon(Icons.refresh, color: StudioColors.textSecondary),
                onPressed: onRevalidate,
              ),
            ],
          ),
        ),
        Expanded(
          child: findings.isEmpty
              ? const Center(
                  child: Icon(Icons.check_circle_outline, color: StudioColors.success, size: 28),
                )
              : ListView.builder(
                  itemCount: findings.length,
                  itemBuilder: (context, index) {
                    final finding = findings[index];
                    final color = switch (finding.severity) {
                      ValidationSeverity.error => StudioColors.error,
                      ValidationSeverity.warning => StudioColors.warning,
                      ValidationSeverity.info => StudioColors.info,
                    };
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.circle, size: 8, color: color),
                      title: Text(
                        finding.message,
                        style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
