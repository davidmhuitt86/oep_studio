import 'proposal_status.dart';
import 'proposal_type.dart';

/// A manually-created Engineering Object proposal within a Knowledge
/// Curation Session (Work Package 007, STUDIO-TASK-000014).
///
/// Exists only in memory, only within its owning session — SDD-018's
/// "Draft" lifecycle state ("Created during an active Knowledge
/// Curation Session. Not yet committed. Visible only within the
/// session."). Carries no AI confidence/evidence/repository-match
/// fields yet — Work Package 007 requires "No AI implementation";
/// those fields belong to the fuller proposal model SDD-016/SDD-020
/// describe once AI analysis exists.
class EngineeringProposal {
  const EngineeringProposal({
    required this.id,
    required this.type,
    required this.name,
    this.description = '',
    this.status = ProposalStatus.pending,
    required this.createdTime,
    this.modifiedTime,
  });

  final String id;
  final ProposalType type;
  final String name;
  final String description;
  final ProposalStatus status;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  EngineeringProposal copyWith({
    ProposalType? type,
    String? name,
    String? description,
    ProposalStatus? status,
    DateTime? modifiedTime,
  }) {
    return EngineeringProposal(
      id: id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      createdTime: createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
    );
  }
}
