import 'package:flutter/material.dart';

import '../models/proposal_type.dart';

/// Bundles the text/selection state for the New/Edit Proposal dialog
/// (`lib/knowledge/review/proposal_form_dialog.dart`) so both flows
/// share one implementation instead of duplicating three form fields.
class ProposalFormController {
  ProposalFormController({String name = '', ProposalType type = ProposalType.component, String description = ''})
    : nameController = TextEditingController(text: name),
      descriptionController = TextEditingController(text: description),
      typeNotifier = ValueNotifier(type);

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final ValueNotifier<ProposalType> typeNotifier;

  String get name => nameController.text;
  String get description => descriptionController.text;
  ProposalType get type => typeNotifier.value;

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    typeNotifier.dispose();
  }
}
