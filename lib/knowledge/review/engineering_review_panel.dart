import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../widgets/knowledge_placeholder.dart';
import 'proposal_form_dialog.dart';
import 'proposal_row.dart';

/// Engineering Review panel (Work Package 007 STUDIO-TASK-000014,
/// SDD-016 Panel 5): the one Knowledge Studio panel with real
/// functionality in this work package — manual proposal creation and
/// Accept/Reject/Edit/Delete. Every other panel is placeholder content
/// (see `docs/tasks/WORK_PACKAGE_007.md`).
class EngineeringReviewPanel extends ConsumerWidget {
  const EngineeringReviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final session = foundation.knowledgeSession;

    if (session == null) {
      return const KnowledgePlaceholder(
        message: 'Create a Knowledge Curation Session to begin proposing Engineering Objects.',
      );
    }

    final proposals = foundation.proposals;
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => showProposalFormDialog(context),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('New Proposal'),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: proposals.isEmpty
              ? const KnowledgePlaceholder(
                  message: 'No proposals yet. Use "New Proposal" to manually propose an Engineering Object.',
                )
              : ListView.separated(
                  itemCount: proposals.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final proposal = proposals[index];
                    return ProposalRow(
                      proposal: proposal,
                      selected: foundation.selectedProposal?.id == proposal.id,
                      onTap: () => notifier.selectProposal(proposal),
                      onAccept: () => notifier.acceptProposal(proposal.id),
                      onReject: () => notifier.rejectProposal(proposal.id),
                      onEdit: () => showProposalFormDialog(context, existing: proposal),
                      onDelete: () => notifier.deleteProposal(proposal.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
