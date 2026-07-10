import 'package:flutter/material.dart';

/// Proposal types the Engineering Review panel's manual proposal
/// workflow supports (Work Package 007, STUDIO-TASK-000014). Mirrors
/// five of SDD-015's Layer 3 Engineering Objects — the subset this
/// work package's manual (non-AI) workflow covers.
enum ProposalType {
  component('Component', Icons.category_outlined),
  procedure('Procedure', Icons.checklist_outlined),
  specification('Specification', Icons.rule_outlined),
  image('Image', Icons.image_outlined),
  document('Document', Icons.description_outlined);

  const ProposalType(this.label, this.icon);

  final String label;
  final IconData icon;
}
