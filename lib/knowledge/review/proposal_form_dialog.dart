import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../controllers/proposal_form_controller.dart';
import '../models/engineering_proposal.dart';
import '../models/knowledge_validation_exception.dart';
import '../models/proposal_type.dart';

/// The New/Edit Proposal dialog (Work Package 007: "The engineer shall
/// be able to create manual proposals ... Edit"). [existing] is `null`
/// to create a new proposal, or the proposal being edited.
Future<void> showProposalFormDialog(BuildContext context, {EngineeringProposal? existing}) {
  return showDialog<void>(context: context, builder: (context) => _ProposalFormDialog(existing: existing));
}

class _ProposalFormDialog extends ConsumerStatefulWidget {
  const _ProposalFormDialog({required this.existing});

  final EngineeringProposal? existing;

  @override
  ConsumerState<_ProposalFormDialog> createState() => _ProposalFormDialogState();
}

class _ProposalFormDialogState extends ConsumerState<_ProposalFormDialog> {
  // Owned by this State — see `_NewSessionDialogState`'s note on why
  // this must not be disposed via the showDialog Future instead.
  late final _form = ProposalFormController(
    name: widget.existing?.name ?? '',
    type: widget.existing?.type ?? ProposalType.component,
    description: widget.existing?.description ?? '',
  );
  String? _errorMessage;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _submit() {
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    try {
      if (widget.existing == null) {
        notifier.addProposal(type: _form.type, name: _form.name, description: _form.description);
      } else {
        notifier.editProposal(
          widget.existing!.id,
          type: _form.type,
          name: _form.name,
          description: _form.description,
        );
      }
      Navigator.of(context).pop();
    } on KnowledgeValidationException catch (error) {
      setState(() => _errorMessage = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      backgroundColor: StudioColors.surfaceRaised,
      title: Text(isEditing ? 'Edit Proposal' : 'New Proposal'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            ValueListenableBuilder<ProposalType>(
              valueListenable: _form.typeNotifier,
              builder: (context, type, _) => DropdownButtonHideUnderline(
                child: DropdownButton<ProposalType>(
                  value: type,
                  isExpanded: true,
                  dropdownColor: StudioColors.surfaceRaised,
                  style: const TextStyle(fontSize: 13, color: StudioColors.textPrimary),
                  items: [
                    for (final option in ProposalType.values)
                      DropdownMenuItem(value: option, child: Text(option.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) _form.typeNotifier.value = value;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _form.nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(
              controller: _form.descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: StudioColors.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: Text(isEditing ? 'Save Changes' : 'Add Proposal')),
      ],
    );
  }
}
