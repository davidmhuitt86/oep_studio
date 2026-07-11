import 'package:flutter/material.dart';

/// Knowledge Candidate types the Engineering Review panel's manual
/// authoring workflow supports (Work Package 007/008, expanded to ten
/// types by Work Package 010 STUDIO-TASK-000022). Mirrors SDD-015's
/// Layer 3 Engineering Objects and SDD-021's Evidence Object examples —
/// the subset this workspace's manual (non-AI) workflow covers.
enum KnowledgeCandidateType {
  component('Component', Icons.category_outlined),
  procedure('Procedure', Icons.checklist_outlined),
  specification('Specification', Icons.rule_outlined),
  tool('Tool', Icons.build_outlined),
  material('Material', Icons.layers_outlined),
  fluid('Fluid', Icons.water_drop_outlined),
  warning('Warning', Icons.warning_amber_outlined),
  measurement('Measurement', Icons.straighten_outlined),
  image('Image', Icons.image_outlined),
  document('Document', Icons.description_outlined);

  const KnowledgeCandidateType(this.label, this.icon);

  final String label;
  final IconData icon;
}
