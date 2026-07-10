import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../models/engineering_proposal.dart';
import '../models/proposal_status.dart';

/// One row in the Engineering Review panel's proposal list (Work
/// Package 007: "Each proposal supports: Accept, Reject, Edit,
/// Delete").
class ProposalRow extends StatelessWidget {
  const ProposalRow({
    required this.proposal,
    required this.selected,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final EngineeringProposal proposal;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? StudioColors.selection.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(proposal.type.icon, size: 15, color: StudioColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5),
                    ),
                    Text(
                      proposal.type.label,
                      style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: proposal.status),
              IconButton(
                tooltip: 'Accept',
                icon: const Icon(Icons.check_circle_outline, size: 16),
                color: StudioColors.success,
                onPressed: onAccept,
              ),
              IconButton(
                tooltip: 'Reject',
                icon: const Icon(Icons.cancel_outlined, size: 16),
                color: StudioColors.error,
                onPressed: onReject,
              ),
              IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined, size: 16), onPressed: onEdit),
              IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 16), onPressed: onDelete),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ProposalStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProposalStatus.accepted => StudioColors.success,
      ProposalStatus.rejected => StudioColors.error,
      ProposalStatus.pending => StudioColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}
