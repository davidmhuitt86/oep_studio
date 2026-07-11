import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/format.dart';
import '../../shared/widgets/property_field.dart';
import '../models/candidate_validation_result.dart';
import '../models/knowledge_candidate.dart';
import '../models/knowledge_candidate_type.dart';
import '../workspaces/procedure_builder_dialog.dart';
import '../workspaces/specification_editor_dialog.dart';
import 'evidence_link_entries.dart';
import 'link_evidence_dialog.dart';

/// Property Inspector's Knowledge Candidate mode (Work Package 007/008
/// Property Inspector: "Display: ... Knowledge Candidate"; Work Package
/// 009: "Knowledge Candidate Evidence"; Work Package 010: extended with
/// Notes/Author/Tags, a Validation Status section, and — conditional on
/// [KnowledgeCandidate.type] — a Specification fields section or a
/// Procedure step-count summary with an "Open Procedure Builder"
/// action).
///
/// "Specification" and "Validation Status" are sections *within* this
/// mode rather than separate top-level Property Inspector modes — see
/// `docs/KNOWLEDGE_CANDIDATES.md` § Architectural Observations for why:
/// Work Package 010's Connection Manager section only adds "Current
/// Procedure"/"Current Procedure Step" selection state, not a "Current
/// Specification" or "Current Validation" selection, so neither has a
/// mutually-exclusive selection driving it the way every other
/// top-level mode does.
///
/// Read-only except for the Evidence section's own Unlink buttons and
/// "Link Evidence Region" action, and the Procedure/Specification
/// "Open ... Editor" buttons that launch their own dedicated dialogs —
/// editing the candidate's own core fields happens through the
/// Engineering Review panel's Edit action, not here (SDD-011: the
/// Property Inspector never edits in place).
class KnowledgeCandidateProperties extends ConsumerWidget {
  const KnowledgeCandidateProperties({required this.candidate, required this.links, super.key});

  final KnowledgeCandidate candidate;
  final List<LinkedRegionEntry> links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final validation = foundation.candidateValidation[candidate.id];
    final specification = foundation.specificationDetailsFor(candidate.id);
    final procedureStepCount = foundation.procedureStepsFor(candidate.id).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PropertyField(label: 'Knowledge Candidate ID', value: candidate.id, monospace: true),
        PropertyField(label: 'Type', value: candidate.type.label),
        PropertyField(label: 'Name', value: candidate.name),
        PropertyField(label: 'Status', value: candidate.status.label),
        PropertyField(label: 'Description', value: candidate.description.isEmpty ? '—' : candidate.description),
        PropertyField(label: 'Notes', value: candidate.notes.isEmpty ? '—' : candidate.notes),
        PropertyField(label: 'Author', value: candidate.author.isEmpty ? '—' : candidate.author),
        PropertyField(label: 'Tags', value: candidate.tags.isEmpty ? '—' : candidate.tags.join(', ')),
        PropertyField(label: 'Created', value: formatDateTime(candidate.createdTime)),
        PropertyField(
          label: 'Modified',
          value: candidate.modifiedTime == null ? '—' : formatDateTime(candidate.modifiedTime!),
        ),
        if (validation != null) _ValidationSection(validation: validation),
        if (candidate.type == KnowledgeCandidateType.specification) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Specification',
                  style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Open Specification Editor',
                icon: const Icon(Icons.open_in_new, size: 15),
                onPressed: () => showSpecificationEditorDialog(context, candidateId: candidate.id),
              ),
            ],
          ),
          if (specification == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Not yet specified. Use "Open Specification Editor" to add Type/Value/Unit.',
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5),
              ),
            )
          else ...[
            PropertyField(label: 'Spec Type', value: specification.specType.label),
            PropertyField(label: 'Value', value: specification.value.isEmpty ? '—' : specification.value),
            PropertyField(label: 'Unit', value: specification.unit.isEmpty ? '—' : specification.unit),
            PropertyField(label: 'Spec Notes', value: specification.notes.isEmpty ? '—' : specification.notes),
          ],
        ],
        if (candidate.type == KnowledgeCandidateType.procedure) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Procedure — $procedureStepCount step${procedureStepCount == 1 ? '' : 's'}',
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Open Procedure Builder',
                icon: const Icon(Icons.open_in_new, size: 15),
                onPressed: () async {
                  notifier.openProcedureBuilder(candidate.id);
                  await showProcedureBuilderDialog(context);
                  notifier.closeProcedureBuilder();
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Evidence',
                style: TextStyle(color: StudioColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Link Evidence Region',
              icon: const Icon(Icons.add_link, size: 16),
              onPressed: () => showLinkEvidenceRegionsDialog(context, candidateId: candidate.id),
            ),
          ],
        ),
        if (links.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('No linked evidence.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
          )
        else
          for (final entry in links)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.sourceName} — ${entry.region.label} (p. ${entry.region.page})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Unlink',
                    icon: const Icon(Icons.link_off, size: 15),
                    onPressed: () => notifier.unlinkEvidence(entry.link.id),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// The Validation Status section (Work Package 010 STUDIO-TASK-000025:
/// "Display validation status for every Knowledge Candidate."). Not a
/// selectable field — see this file's top doc comment — just a display
/// of the candidate's current [CandidateValidationResult].
class _ValidationSection extends StatelessWidget {
  const _ValidationSection({required this.validation});

  final CandidateValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (validation.severity) {
      ValidationSeverity.error => (Icons.error_outline, StudioColors.error, 'Error'),
      ValidationSeverity.warning => (Icons.warning_amber_outlined, StudioColors.warning, 'Warning'),
      ValidationSeverity.ok => (Icons.check_circle_outline, StudioColors.success, 'OK'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Validation Status', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
          for (final issue in validation.issues)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $issue', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
            ),
        ],
      ),
    );
  }
}
