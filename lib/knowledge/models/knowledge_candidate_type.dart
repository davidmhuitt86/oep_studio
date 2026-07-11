import 'package:flutter/material.dart';

/// Knowledge Candidate types the Engineering Review panel's manual
/// authoring workflow supports (Work Package 007/008). Mirrors five of
/// SDD-015's Layer 3 Engineering Objects — the subset this workspace's
/// manual (non-AI) workflow covers.
enum KnowledgeCandidateType {
  component('Component', Icons.category_outlined),
  procedure('Procedure', Icons.checklist_outlined),
  specification('Specification', Icons.rule_outlined),
  image('Image', Icons.image_outlined),
  document('Document', Icons.description_outlined);

  const KnowledgeCandidateType(this.label, this.icon);

  final String label;
  final IconData icon;
}
