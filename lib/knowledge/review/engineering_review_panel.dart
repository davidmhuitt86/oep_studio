import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../widgets/knowledge_placeholder.dart';
import 'knowledge_candidate_form_dialog.dart';
import 'knowledge_candidate_row.dart';
import 'relationship_candidate_form_dialog.dart';
import 'relationship_candidate_list_query.dart';
import 'relationship_candidate_row.dart';

enum _ReviewTab { candidates, relationships }

/// Engineering Review panel (Work Package 007 STUDIO-TASK-000014, Work
/// Package 008 STUDIO-TASK-000017, SDD-016 Panel 5): manual Knowledge
/// Candidate creation with Accept/Reject/Edit/Delete, and — as a second
/// tab rather than a separate panel — manual Relationship Candidate
/// authoring (the Relationship View STUDIO-TASK-000017 describes).
///
/// SDD-016 fixes Knowledge Studio's panel layout at seven panels;
/// adding an eighth for Relationship Candidates would conflict with
/// that. A tab within the existing Engineering Review panel keeps both
/// "things awaiting engineering review" together without touching the
/// frozen layout — see `docs/KNOWLEDGE_SESSION_FORMAT.md` § Architectural
/// Observations.
class EngineeringReviewPanel extends ConsumerStatefulWidget {
  const EngineeringReviewPanel({super.key});

  @override
  ConsumerState<EngineeringReviewPanel> createState() => _EngineeringReviewPanelState();
}

class _EngineeringReviewPanelState extends ConsumerState<EngineeringReviewPanel> {
  _ReviewTab _tab = _ReviewTab.candidates;

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final session = foundation.knowledgeSession;

    if (session == null) {
      return const KnowledgePlaceholder(
        message: 'Create a Knowledge Curation Session to begin proposing Engineering Objects.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              _TabButton(
                key: const ValueKey('engineering-review-tab-candidates'),
                label: 'Candidates',
                selected: _tab == _ReviewTab.candidates,
                onTap: () => setState(() => _tab = _ReviewTab.candidates),
              ),
              const SizedBox(width: 8),
              _TabButton(
                key: const ValueKey('engineering-review-tab-relationships'),
                label: 'Relationships',
                selected: _tab == _ReviewTab.relationships,
                onTap: () => setState(() => _tab = _ReviewTab.relationships),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _tab == _ReviewTab.candidates
                  ? showKnowledgeCandidateFormDialog(context)
                  : showRelationshipCandidateFormDialog(context),
              icon: const Icon(Icons.add, size: 14),
              label: Text(_tab == _ReviewTab.candidates ? 'New Candidate' : 'New Relationship'),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _tab == _ReviewTab.candidates ? const _CandidateList() : const _RelationshipCandidateList(),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap, super.key});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StudioColors.selection.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? StudioColors.selection : StudioColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CandidateList extends ConsumerWidget {
  const _CandidateList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final candidates = foundation.candidates;
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final selectedRegion = foundation.selectedEvidenceRegion;
    final linkedCandidateIds = selectedRegion == null
        ? const <String>{}
        : foundation.candidatesLinkedToEvidenceRegion(selectedRegion.id).map((candidate) => candidate.id).toSet();

    if (candidates.isEmpty) {
      return const KnowledgePlaceholder(
        message: 'No Knowledge Candidates yet. Use "New Candidate" to manually propose an Engineering Object.',
      );
    }
    return ListView.separated(
      itemCount: candidates.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final candidate = candidates[index];
        return KnowledgeCandidateRow(
          candidate: candidate,
          selected: foundation.selectedCandidate?.id == candidate.id,
          linkedToSelectedEvidence: linkedCandidateIds.contains(candidate.id),
          onTap: () => notifier.selectKnowledgeCandidate(candidate),
          onAccept: () => notifier.acceptKnowledgeCandidate(candidate.id),
          onReject: () => notifier.rejectKnowledgeCandidate(candidate.id),
          onEdit: () => showKnowledgeCandidateFormDialog(context, existing: candidate),
          onDelete: () => notifier.deleteKnowledgeCandidate(candidate.id),
        );
      },
    );
  }
}

class _RelationshipCandidateList extends ConsumerWidget {
  const _RelationshipCandidateList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final namesById = {for (final candidate in foundation.candidates) candidate.id: candidate.name};
    final resolved = [
      for (final relationship in foundation.relationshipCandidates)
        ResolvedRelationshipCandidate(
          relationship: relationship,
          sourceName: namesById[relationship.sourceCandidateId] ?? relationship.sourceCandidateId,
          targetName: namesById[relationship.targetCandidateId] ?? relationship.targetCandidateId,
        ),
    ];
    const query = RelationshipCandidateListQuery();
    final entries = query.apply(resolved);

    if (entries.isEmpty) {
      return const KnowledgePlaceholder(
        message: 'No Relationship Candidates yet. Use "New Relationship" to connect two Knowledge Candidates.',
      );
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return RelationshipCandidateRow(
          entry: entry,
          selected: foundation.selectedRelationshipCandidate?.id == entry.relationship.id,
          onTap: () => notifier.selectRelationshipCandidate(entry.relationship),
          onEdit: () => showRelationshipCandidateFormDialog(context, existing: entry.relationship),
          onDelete: () => notifier.deleteRelationshipCandidate(entry.relationship.id),
        );
      },
    );
  }
}
