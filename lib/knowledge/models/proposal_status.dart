/// An [EngineeringProposal]'s status within its owning Knowledge
/// Curation Session (Work Package 007: "Each proposal supports:
/// Accept, Reject, Edit, Delete"). Deliberately narrower than
/// SDD-020's full Decision Options (Accept/Reject/Merge/Edit/Postpone/
/// Duplicate) — this work package's manual proposal workflow doesn't
/// implement repository matching, so Merge/Duplicate/Postpone have
/// nothing to act against yet.
enum ProposalStatus {
  pending('Pending'),
  accepted('Accepted'),
  rejected('Rejected');

  const ProposalStatus(this.label);

  final String label;
}
