import 'package:flutter/material.dart';

import '../models/knowledge_candidate_type.dart';

/// Bundles the text/selection state for the New/Edit Knowledge
/// Candidate dialog (`lib/knowledge/review/knowledge_candidate_form_dialog.dart`)
/// so both flows share one implementation instead of duplicating three
/// form fields.
class KnowledgeCandidateFormController {
  KnowledgeCandidateFormController({
    String name = '',
    KnowledgeCandidateType type = KnowledgeCandidateType.component,
    String description = '',
  }) : nameController = TextEditingController(text: name),
       descriptionController = TextEditingController(text: description),
       typeNotifier = ValueNotifier(type);

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final ValueNotifier<KnowledgeCandidateType> typeNotifier;

  String get name => nameController.text;
  String get description => descriptionController.text;
  KnowledgeCandidateType get type => typeNotifier.value;

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    typeNotifier.dispose();
  }
}
